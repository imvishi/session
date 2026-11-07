class RescheduleAppointment
  # appointment_date, start_at and end_at are the new slot on the professional's clock, as for booking.
  def initialize(appointment:, appointment_date:, start_at:, end_at:)
    @appointment = appointment
    @new_slot = { appointment_date:, start_at:, end_at: }
  end

  # Returns the appointment. Raises AppointmentPolicy::NotAllowed or BookAppointment::Unavailable,
  # in which case the session keeps its old time.
  def call
    professional = @appointment.professional

    BookAppointment.explaining_failures do
      # The lock reloads the row, and makes a second change to the same session wait for this one.
      @appointment.with_lock do
        AppointmentPolicy.new(@appointment, @appointment.member).check!
        slot = SlotGenerator.new(professional).find(**@new_slot) or raise BookAppointment::Unavailable, BookAppointment::NOT_A_SLOT

        @appointment.update!(slot.local_attributes(professional.timezone))
        ScheduleReminders.new(@appointment).call
      end
    end

    @appointment
  end
end
