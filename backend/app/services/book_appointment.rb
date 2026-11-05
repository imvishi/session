class BookAppointment
  class Unavailable < StandardError; end

  NOT_A_SLOT = "This time is no longer available. Please choose another."
  SLOT_TAKEN = "This time has just been booked by someone else. Please choose another."
  BOOKING_FAILED = "We can't book this time right now. Please try again later."

  # appointment_date, start_at and end_at are on the professional's clock, as the calendar sends them.
  def initialize(member:, professional:, appointment_date:, start_at:, end_at:)
    @member = member
    @professional = professional
    @requested = [ appointment_date, start_at, end_at ].map(&:to_s)
  end

  # Returns the appointment, or raises Unavailable with a message for the member.
  def call
    slot = requested_slot or raise Unavailable, NOT_A_SLOT

    create_appointment(slot)
  rescue ActiveRecord::ExclusionViolation
    # The database decides, so an appointment can't slip in between a check here and the insert.
    raise Unavailable, SLOT_TAKEN
  rescue ActiveRecord::RecordInvalid => error
    raise Unavailable, error.record.errors.full_messages.to_sentence
  rescue ActiveRecord::Deadlocked
    # Two overlapping inserts can each wait on the other's constraint check, and Postgres then aborts one.
    raise Unavailable, BOOKING_FAILED
  end

  private

  def create_appointment(slot)
    Appointment.create!(
      member: @member, professional: @professional,
      **slot.local_attributes(@professional.timezone)
    )
  end

  # It must be a real slot right now, which also rules out past and made-up times.
  def requested_slot
    now = Time.current

    SlotGenerator.new(@professional).slots(from: now, to: now + SlotGenerator::APPOINTMENT_WINDOW).find do |slot|
      local = slot.local_attributes(@professional.timezone)

      [ local[:appointment_date].iso8601, local[:start_time], local[:end_time] ] == @requested
    end
  end
end
