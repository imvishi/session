require "rails_helper"

RSpec.describe ScheduleReminders do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:starts_at) { Time.utc(2026, 11, 9, 1, 0) }
  let(:appointment) { book(member, professional, starts_at) }

  before { travel_to Time.utc(2026, 11, 5, 0, 0) }

  def schedule(now: Time.current)
    described_class.new(appointment).call(now:)
  end

  def pending
    appointment.reminders.pending.order(:remind_at, :user_id).map { |reminder| [ reminder.user, reminder.minutes_before, reminder.remind_at ] }
  end

  it "schedules reminders 24 hours and 1 hour before, for both people" do
    schedule

    expect(pending).to contain_exactly(
      [ member, 1440, starts_at - 24.hours ], [ professional, 1440, starts_at - 24.hours ],
      [ member, 60, starts_at - 1.hour ], [ professional, 60, starts_at - 1.hour ]
    )
  end

  it "queues a job for each reminder at its time, and remembers the job" do
    expect { schedule }.to have_enqueued_job(DeliverReminderJob).exactly(4).times

    appointment.reminders.each do |reminder|
      expect(DeliverReminderJob).to have_been_enqueued.with(reminder.id).at(reminder.remind_at)
      expect(ActiveJob::Base.queue_adapter.enqueued_jobs.pluck("job_id")).to include(reminder.job_id)
    end
  end

  it "queues nothing if the change is rolled back" do
    expect do
      Appointment.transaction do
        schedule
        raise ActiveRecord::Rollback
      end
    end.not_to have_enqueued_job(DeliverReminderJob)
  end

  it "discards the jobs of the reminders it replaces" do
    schedule
    old_job_ids = appointment.reminders.pluck(:job_id)
    allow(DeliverReminderJob).to receive(:discard_later)

    schedule

    expect(DeliverReminderJob).to have_received(:discard_later).with(match_array(old_job_ids))
  end

  it "doesn't create a reminder whose time has already passed" do
    schedule(now: starts_at - 2.hours)

    expect(pending.map(&:second).uniq).to eq([ 60 ])
  end

  it "creates none when both times have passed" do
    schedule(now: starts_at - 30.minutes)

    expect(pending).to be_empty
  end

  it "replaces the pending reminders when the time changes" do
    schedule
    appointment.update!(appointment_date: "2026-11-10")

    schedule

    expect(appointment.reminders.count).to eq(4)
    expect(pending.map(&:third).uniq).to contain_exactly(starts_at + 1.day - 24.hours, starts_at + 1.day - 1.hour)
  end

  it "uses whatever lead times are configured" do
    stub_const("Reminder::LEAD_TIMES", [ 2.days, 30.minutes ])

    schedule

    expect(pending.map(&:second).uniq).to contain_exactly(2880, 30)
  end

  it "removes the pending reminders of a cancelled session, and keeps delivered ones" do
    schedule
    delivered = appointment.reminders.find_by(minutes_before: 1440).tap { |reminder| reminder.update!(delivered_at: Time.current, message: "Sent") }

    appointment.cancelled!
    schedule

    expect(appointment.reminders.reload).to eq([ delivered ])
  end
end
