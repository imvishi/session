# What a member sees on a professional's profile: free slots only, in the member's timezone.
# It never includes who else has booked.
class ProfessionalCalendar
  WEEKDAYS = %w[Mon Tue Wed Thu Fri Sat Sun].freeze

  def initialize(professional:, member:)
    @professional = professional
    @zone = ActiveSupport::TimeZone[member.timezone]
    @from = Time.current
    @to = @from + SlotGenerator::APPOINTMENT_WINDOW
  end

  def to_h
    {
      professional: @professional.slice(:id, :name),
      timezone_label: "#{@zone.tzinfo.name} (GMT#{@zone.now.formatted_offset})",
      session_minutes: SlotGenerator::SESSION_MINUTES,
      weekdays: WEEKDAYS,
      days:
    }
  end

  private

  # Whole weeks from Monday, so the frontend can lay them out in rows as they come.
  def days
    slots_by_date = available_slots.group_by { |slot| local(slot.starts_at).to_date }
    first_date = local(@from).to_date.beginning_of_week(:monday)
    last_date = local(@to).to_date.end_of_week(:monday)

    (first_date..last_date).map do |date|
      {
        date: date.iso8601,
        label: date.strftime("%A, %-d %B"),
        short_label: date.strftime("%-d %b"),
        slots: slots_by_date.fetch(date, []).map { |slot| slot_json(slot) }
      }
    end
  end

  def slot_json(slot)
    professional_time = slot.local_attributes(@professional.timezone)

    {
      appointment_date: professional_time[:appointment_date].iso8601,
      start_at: professional_time[:start_time],
      end_at: professional_time[:end_time],
      label: local(slot.starts_at).strftime("%-l:%M %p"),
      professional_label: professional_label(slot)
    }
  end

  def professional_label(slot)
    timezone = @professional.timezone

    "#{slot.starts_at.in_time_zone(timezone).strftime("%A, %-d %B at %-l:%M %p")} (#{timezone})"
  end

  def available_slots
    appointments = @professional.professional_appointments.booked.overlapping(@from, @to).to_a

    SlotGenerator.new(@professional).slots(from: @from, to: @to).reject do |slot|
      appointments.any? { |appointment| appointment.starts_at_utc < slot.ends_at && appointment.ends_at_utc > slot.starts_at }
    end
  end

  def local(time)
    time.in_time_zone(@zone)
  end
end
