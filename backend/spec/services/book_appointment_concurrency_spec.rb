require "rails_helper"

# Uses real threads and real commits, because a transaction shared by the whole test
# couldn't show two connections racing. It cleans up after itself.
RSpec.describe BookAppointment, "at the same moment" do
  include AppointmentHelpers

  self.use_transactional_tests = false

  after do
    Appointment.delete_all
    WorkingHour.delete_all
    User.delete_all
  end

  def race(attempts)
    start = Concurrent::CountDownLatch.new(1)
    threads = attempts.map do |attempt|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.wait
          described_class.new(**attempt).call
          :booked
        rescue described_class::Unavailable => error
          error.message
        rescue StandardError => error
          # Reported in the results, so every thread finishes before the cleanup runs.
          error
        end
      end
    end
    start.count_down
    threads.map(&:value)
  end

  def next_slot(professional)
    SlotGenerator.new(professional).slots(from: Time.current, to: 2.weeks.from_now).first.starts_at
  end

  # The next 09:00-style slot that has a 09:30-style slot starting during it.
  def overlapping_slots(first, second)
    second_starts = SlotGenerator.new(second).slots(from: Time.current, to: 2.weeks.from_now).map(&:starts_at)
    first_start = SlotGenerator.new(first).slots(from: Time.current, to: 2.weeks.from_now).map(&:starts_at)
                               .find { |start| second_starts.include?(start + 30.minutes) }

    [ first_start, first_start + 30.minutes ]
  end

  def working_every_day(name, start_minute: 540)
    create_person(name, role: "professional").tap do |professional|
      (0..6).each { |day| set_hours(professional, day, start_minute, 1020) }
    end
  end

  it "lets only one of several members book the same slot" do
    professional = working_every_day("Pat Professional")
    starts_at = next_slot(professional)
    members = (1..4).map { |number| create_person("Member #{number}", role: "member") }

    results = race(members.map { |member| { member:, professional:, **slot_params(starts_at, professional) } })

    # A request that deadlocks on the constraint check is told to try later instead.
    expect(results.count(:booked)).to eq(1)
    expect(results - [ :booked ]).to all(eq(described_class::SLOT_TAKEN).or(eq(described_class::BOOKING_FAILED)))
    expect(Appointment.booked.count).to eq(1)
  end

  it "lets a member book overlapping sessions with different professionals" do
    first = working_every_day("Pat Professional", start_minute: 540)
    second = working_every_day("Alex Professional", start_minute: 570)
    member = create_person("Sam Member", role: "member")
    first_slot, second_slot = overlapping_slots(first, second)

    results = race([
      { member:, professional: first, **slot_params(first_slot, first) },
      { member:, professional: second, **slot_params(second_slot, second) }
    ])

    expect(results).to eq(%i[booked booked])
    expect(Appointment.booked.count).to eq(2)
  end
end
