# A person's own sessions, with dates and times on their own clock.
class SessionList
  def initialize(user)
    @user = user
    @zone = ActiveSupport::TimeZone[user.timezone]
    @now = Time.current
  end

  def to_h
    @user.member? ? member_sessions : professional_schedule
  end

  private

  # Cancelled sessions are kept, so a member can see what happened to them.
  def member_sessions
    appointments = @user.member_appointments.includes(:professional)

    {
      timezone: @user.timezone,
      upcoming: appointments.upcoming(@now).map { |appointment| session_json(appointment, professional: appointment.professional) },
      past: appointments.past(@now).map { |appointment| session_json(appointment, professional: appointment.professional) }
    }
  end

  # Only sessions that are still going ahead.
  def professional_schedule
    appointments = @user.professional_appointments.booked.includes(:member).upcoming(@now)

    {
      timezone: @user.timezone,
      upcoming: appointments.map { |appointment| session_json(appointment, member: appointment.member) }
    }
  end

  # person is the other person in the session: { professional: user } or { member: user }.
  def session_json(appointment, **person)
    starts_at = appointment.starts_at_utc.in_time_zone(@zone)
    ends_at = appointment.ends_at_utc.in_time_zone(@zone)

    {
      id: appointment.id,
      status: appointment.status,
      date_label: starts_at.strftime("%A, %-d %B %Y"),
      time_label: "#{starts_at.strftime("%-l:%M %p")} – #{ends_at.strftime("%-l:%M %p")}",
      **person.transform_values { |user| user.slice(:id, :name) },
      **changes(appointment)
    }
  end

  # What the person can do now. Only a member can reschedule, and they're told when it's too late.
  def changes(appointment)
    refusal = AppointmentPolicy.new(appointment, @user, now: @now).refusal

    {
      can_cancel: refusal.nil?,
      can_reschedule: refusal.nil? && @user.member?,
      notice: (refusal if refusal == AppointmentPolicy::TOO_LATE)
    }
  end
end
