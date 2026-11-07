require "rails_helper"

RSpec.describe DeliverReminder do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:starts_at) { Time.utc(2026, 11, 9, 1, 0) } # 09:00 in Singapore, 06:30 in Kolkata
  let(:appointment) { book(member, professional, starts_at) }

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    ScheduleReminders.new(appointment).call
  end

  def reminder(user, minutes_before)
    appointment.reminders.find_by!(user:, minutes_before:)
  end

  def deliver(reminder)
    described_class.new(reminder.id).call
  end

  it "delivers the reminder, with a message on the recipient's own clock" do
    expect(deliver(reminder(member, 1440))).to be(true)

    expect(reminder(member, 1440)).to have_attributes(
      delivered_at: Time.current,
      message: "Your session with Pat Professional starts in 24 hours, on Monday, 9 November 2026 at 6:30 AM (Asia/Kolkata)."
    )
  end

  it "names the member for the professional, on the professional's clock" do
    deliver(reminder(professional, 60))

    expect(reminder(professional, 60).message).to eq(
      "Your session with Sam Member starts in 1 hour, on Monday, 9 November 2026 at 9:00 AM (Asia/Singapore)."
    )
  end

  it "delivers only once, however often the job runs" do
    first = reminder(member, 60)
    deliver(first)
    delivered_at = first.reload.delivered_at
    travel 1.minute

    expect(deliver(first)).to be(false)
    expect(first.reload.delivered_at).to eq(delivered_at)
  end

  it "does nothing for a reminder that was removed by rescheduling or cancelling" do
    removed_id = reminder(member, 60).id
    appointment.cancelled!
    ScheduleReminders.new(appointment).call

    expect(described_class.new(removed_id).call).to be(false)
    expect(Reminder.delivered).to be_empty
  end

  context "when the job runs late, after the server was down" do
    it "says how long is really left" do
      late = reminder(member, 1440)

      described_class.new(late.id).call(now: late.remind_at + 3.hours + 20.seconds)

      expect(late.reload.message).to start_with("Your session with Pat Professional starts in 21 hours, on Monday")
    end

    it "still says the lead time when only a few minutes late" do
      late = reminder(member, 60)

      described_class.new(late.id).call(now: late.remind_at + 4.minutes)

      expect(late.reload.message).to include("starts in 1 hour,")
    end

    it "drops the 24 hour reminder once the 1 hour one is due, and delivers that one" do
      now = starts_at - 50.minutes

      expect(described_class.new(reminder(member, 1440).id).call(now:)).to be(false)
      expect(described_class.new(reminder(member, 60).id).call(now:)).to be(true)
      expect(appointment.reminders.where(user: member).map(&:minutes_before)).to eq([ 60 ])
      expect(reminder(member, 60).message).to include("starts in 50 minutes,")
    end

    it "drops a reminder whose session has already started" do
      expect(described_class.new(reminder(member, 60).id).call(now: starts_at + 1.minute)).to be(false)
      expect(appointment.reminders.where(user: member, minutes_before: 60)).to be_empty
    end
  end

  it "is what the job runs" do
    first = reminder(member, 60)

    DeliverReminderJob.perform_now(first.id)

    expect(first.reload.delivered_at).to be_present
  end
end

# Real threads and commits, because one shared test transaction can't show two connections racing.
RSpec.describe DeliverReminder, "while the session is being changed" do
  include AppointmentHelpers

  self.use_transactional_tests = false

  after do
    Reminder.delete_all
    Appointment.delete_all
    WorkingHour.delete_all
    User.delete_all
  end

  it "waits for the change, and doesn't deliver a reminder it replaced" do
    member = create_person("Sam Member", role: "member")
    professional = create_person("Pat Professional", role: "professional")
    appointment = book(member, professional, 3.days.from_now.change(min: 0))
    ScheduleReminders.new(appointment).call
    replaced = appointment.reminders.find_by!(user: member, minutes_before: 60)
    locked = Concurrent::CountDownLatch.new(1)

    changing = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        changed = Appointment.find(appointment.id)
        changed.with_lock do
          locked.count_down
          sleep 0.3 # The delivery starts in the meantime, and has to wait for this lock.
          changed.cancelled!
          ScheduleReminders.new(changed).call
        end
      end
    end
    delivering = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        locked.wait
        described_class.new(replaced.id).call(now: replaced.remind_at)
      end
    end

    changing.join
    expect(delivering.value).to be(false)
    expect(Reminder.delivered).to be_empty
  end
end
