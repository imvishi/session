# Delivers one reminder at its time. ScheduleReminders queues it with wait_until, and Solid Queue keeps
# it in Postgres, so it still runs after a server restart (late, if the server was down at the time).
#
# The queue is a separate database, so jobs are queued and discarded only once the appointment's
# transaction commits. By then the change is saved, so a queue failure is reported and swallowed rather
# than turning a successful booking, reschedule or cancellation into an error for the user.
class DeliverReminderJob < ApplicationJob
  queue_as :default

  # Queues the reminder's job, under the job_id already stored on it, once the current transaction
  # commits. A rolled-back change queues nothing.
  def self.enqueue_later(reminder)
    job = new(reminder.id)
    job.job_id = reminder.job_id
    remind_at = reminder.remind_at

    ActiveRecord.after_all_transactions_commit do
      job.enqueue(wait_until: remind_at)
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { reminder_id: reminder.id })
    end
  end

  # Removes queued jobs once the current transaction commits, so a rolled-back change keeps them.
  # A job that is already running can't be removed. It then finds its reminder gone and does nothing,
  # and so does one that a queue failure kept from being removed.
  def self.discard_later(job_ids)
    job_ids = job_ids.compact
    return if job_ids.empty? || queue_adapter_name != "solid_queue"

    ActiveRecord.after_all_transactions_commit do
      queued_jobs(job_ids).each do |job|
        job.discard
      rescue SolidQueue::Execution::UndiscardableError
        nil
      end
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { job_ids: })
    end
  end

  def self.queued_jobs(job_ids)
    SolidQueue::Job.where(active_job_id: job_ids).to_a
  end

  def perform(reminder_id)
    DeliverReminder.new(reminder_id).call
  end
end
