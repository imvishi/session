# Keeps an appointment's undelivered reminders in step with it: one per lead time before the start,
# for the member and the professional, each with its own job queued for that moment. Call it inside
# the transaction that changes the appointment, so the two can't disagree.
class ScheduleReminders
  def initialize(appointment)
    @appointment = appointment
  end

  # Replaces the undelivered reminders and their jobs. A cancelled session gets none, and a reminder
  # whose time has already passed isn't created. Delivered ones are kept, because they're notifications now.
  def call(now: Time.current)
    replaced = @appointment.reminders.pending
    DeliverReminderJob.discard_later(replaced.pluck(:job_id))
    replaced.delete_all
    return unless @appointment.booked?

    [ @appointment.member, @appointment.professional ].product(Reminder::LEAD_TIMES).each do |user, before|
      remind_at = @appointment.starts_at_utc - before
      schedule(user, before, remind_at) if remind_at > now
    end
  end

  private

  # One write: the job_id is chosen up front, so the row is created with it and the job queued under it.
  def schedule(user, before, remind_at)
    reminder = @appointment.reminders.create!(
      user:, minutes_before: before.in_minutes.to_i, remind_at:, job_id: SecureRandom.uuid
    )
    DeliverReminderJob.enqueue_later(reminder)
  end
end
