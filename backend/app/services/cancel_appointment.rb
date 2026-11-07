class CancelAppointment
  def initialize(appointment:, user:)
    @appointment = appointment
    @user = user
  end

  # Returns the appointment, or raises AppointmentPolicy::NotAllowed with a message.
  def call
    @appointment.with_lock do
      AppointmentPolicy.new(@appointment, @user).check!
      @appointment.cancelled!
    end

    @appointment
  end
end
