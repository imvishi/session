module AppointmentHelpers
  def create_person(name, role:, timezone: "Asia/Singapore")
    User.create!(name:, role:, timezone:, email: "#{name.parameterize}@example.com", password: "password123")
  end

  def set_hours(professional, day_of_week, start_minute, end_minute)
    professional.working_hours.create!(day_of_week:, start_minute:, end_minute:)
  end

  # What the calendar gives for the slot starting at this real moment, and booking takes back.
  def slot_params(starts_at, professional)
    local = local_attributes(starts_at, professional)

    { appointment_date: local[:appointment_date].iso8601, start_at: local[:start_time], end_at: local[:end_time] }
  end

  # starts_at is a real moment, stored the way booking stores it: local to the professional.
  def book(member, professional, starts_at, status: "booked")
    Appointment.create!(member:, professional:, status:, **local_attributes(starts_at, professional))
  end

  def local_attributes(starts_at, professional)
    SlotGenerator::Slot.new(starts_at:, ends_at: starts_at + 50.minutes).local_attributes(professional.timezone)
  end
end
