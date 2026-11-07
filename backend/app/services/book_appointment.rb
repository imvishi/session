class BookAppointment
  class Unavailable < StandardError; end

  NOT_A_SLOT = "This time is no longer available. Please choose another."
  SLOT_TAKEN = "This time has just been booked by someone else. Please choose another."
  BOOKING_FAILED = "We can't book this time right now. Please try again later."

  # Turns the database refusing an appointment's time into Unavailable, with a message for the member.
  def self.explaining_failures
    yield
  rescue ActiveRecord::ExclusionViolation
    # The database decides, so an appointment can't slip in between a check here and the write.
    raise Unavailable, SLOT_TAKEN
  rescue ActiveRecord::RecordInvalid => error
    raise Unavailable, error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::Deadlocked
    # Two overlapping writes can each wait on the other's constraint check, and Postgres then aborts one.
    raise Unavailable, BOOKING_FAILED
  end

  # appointment_date, start_at and end_at are on the professional's clock, as the calendar sends them.
  def initialize(member:, professional:, appointment_date:, start_at:, end_at:)
    @member = member
    @professional = professional
    @requested = { appointment_date:, start_at:, end_at: }
  end

  # Returns the appointment, or raises Unavailable with a message for the member.
  def call
    slot = SlotGenerator.new(@professional).find(**@requested) or raise Unavailable, NOT_A_SLOT

    self.class.explaining_failures do
      Appointment.transaction do
        Appointment.create!(member: @member, professional: @professional, **slot.local_attributes(@professional.timezone))
                   .tap { |appointment| ScheduleReminders.new(appointment).call }
      end
    end
  end
end
