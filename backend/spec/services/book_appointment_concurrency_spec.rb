require "rails_helper"

# Uses real threads and real commits, because a transaction shared by the whole test
# couldn't show two connections racing. It cleans up after itself.
RSpec.describe BookAppointment, "at the same moment" do
  include AppointmentHelpers

  self.use_transactional_tests = false

  after do
    Reminder.delete_all
    Appointment.delete_all
    WorkingHour.delete_all
    User.delete_all
  end

  # Each attempt is a block, run in its own thread and connection, all starting together.
  def race(attempts)
    start = Concurrent::CountDownLatch.new(1)
    threads = attempts.map do |attempt|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          start.wait
          attempt.call
          :booked
        rescue BookAppointment::Unavailable, AppointmentPolicy::NotAllowed => error
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

    results = race(members.map { |member| -> { book_now(member, professional, starts_at) } })

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

    results = race([ -> { book_now(member, first, first_slot) }, -> { book_now(member, second, second_slot) } ])

    expect(results).to eq(%i[booked booked])
    expect(Appointment.booked.count).to eq(2)
  end

  it "runs two reschedules of the same session one after the other, leaving one session" do
    professional = working_every_day("Pat Professional")
    member = create_person("Sam Member", role: "member")
    first_slot, second_slot, third_slot = SlotGenerator.new(professional).slots(from: 2.days.from_now, to: 2.weeks.from_now).first(3).map(&:starts_at)
    appointment = book_now(member, professional, first_slot)

    results = race([ second_slot, third_slot ].map do |slot|
      -> { RescheduleAppointment.new(appointment: Appointment.find(appointment.id), **slot_params(slot, professional)).call }
    end)

    # The lock makes them take turns, so the session ends at whichever ran last.
    expect(results).to eq(%i[booked booked])
    expect(Appointment.booked.where(member:).count).to eq(1)
    expect([ second_slot, third_slot ]).to include(appointment.reload.starts_at_utc)
  end

  it "delivers a reminder once when its job runs twice at the same moment" do
    professional = working_every_day("Pat Professional")
    member = create_person("Sam Member", role: "member")
    slot = SlotGenerator.new(professional).slots(from: 2.days.from_now, to: 2.weeks.from_now).first.starts_at
    reminder = book_now(member, professional, slot).reminders.first

    results = race(Array.new(2) { -> { DeliverReminder.new(reminder.id).call } })

    expect(results).to eq(%i[booked booked])
    expect(reminder.reload.delivered_at).to be_present
    expect(Reminder.delivered.count).to eq(1)
  end

  def book_now(member, professional, starts_at)
    described_class.new(member:, professional:, **slot_params(starts_at, professional)).call
  end
end
