class AppointmentPolicy
  class NotAllowed < StandardError; end

  MEMBER_NOTICE = 24.hours
  NOT_BOOKED = "This session has already been cancelled."
  ENDED = "This session has already ended."
  TOO_LATE = "Sessions can't be cancelled or rescheduled within 24 hours of the start."

  def initialize(appointment, user, now: Time.current)
    @appointment = appointment
    @user = user
    @now = now
  end

  # nil when the change is allowed, otherwise a message for the person.
  def refusal
    return NOT_BOOKED unless @appointment.booked?
    return ENDED if @appointment.ends_at_utc <= @now

    TOO_LATE if @user.member? && @appointment.starts_at_utc - @now < MEMBER_NOTICE
  end

  def check!
    reason = refusal
    raise NotAllowed, reason if reason
  end
end
