class DeliverReminder
  # How late a job can run and still say its configured lead time ("starts in 1 hour").
  ON_TIME = 5.minutes

  def initialize(reminder_id)
    @reminder_id = reminder_id
  end

  # Returns true if this call delivered it.
  def call(now: Time.current)
    Reminder.transaction do
      appointment = locked_appointment
      reminder = appointment&.reminders&.pending&.find_by(id: @reminder_id)
      next false unless reminder

      if out_of_date?(reminder, appointment, now)
        reminder.destroy!
        next false
      end

      reminder.update!(delivered_at: now, message: message(reminder, appointment, now))
      true
    end
  end

  private

  def locked_appointment
    appointment_id = Reminder.pending.where(id: @reminder_id).pick(:appointment_id)
    appointment_id && Appointment.lock.find_by(id: appointment_id)
  end

  def out_of_date?(reminder, appointment, now)
    !appointment.booked? ||
      now >= appointment.starts_at_utc ||
      appointment.reminders.where(user_id: reminder.user_id)
                 .where("remind_at > ? AND remind_at <= ?", reminder.remind_at, now).exists?
  end

  # On the recipient's own clock, naming the other person in the session.
  def message(reminder, appointment, now)
    user = reminder.user
    other = user == appointment.member ? appointment.professional : appointment.member
    starts_at = appointment.starts_at_utc.in_time_zone(user.timezone)

    "Your session with #{other.name} starts in #{time_left(reminder, appointment, now)}, " \
      "on #{starts_at.strftime("%A, %-d %B %Y at %-l:%M %p")} (#{user.timezone})."
  end

  def time_left(reminder, appointment, now)
    return reminder.lead_time_label if now - reminder.remind_at <= ON_TIME

    Reminder.duration_label([ ((appointment.starts_at_utc - now) / 60).round, 1 ].max)
  end
end
