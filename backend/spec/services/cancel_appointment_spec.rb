require "rails_helper"

RSpec.describe CancelAppointment do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:appointment) { book(member, professional, Time.utc(2026, 11, 9, 1, 0)) }

  before { travel_to Time.utc(2026, 11, 5, 0, 0) }

  def cancel(by)
    described_class.new(appointment:, user: by).call
  end

  it "lets a member cancel more than 24 hours ahead" do
    expect(cancel(member).reload).to be_cancelled
  end

  it "removes the reminders that haven't been delivered" do
    ScheduleReminders.new(appointment).call

    expect { cancel(member) }.to change { appointment.reminders.pending.count }.from(4).to(0)
  end

  it "stops a member cancelling within 24 hours, and keeps the session" do
    travel_to Time.utc(2026, 11, 8, 2, 0)

    expect { cancel(member) }.to raise_error(AppointmentPolicy::NotAllowed, AppointmentPolicy::TOO_LATE)
    expect(appointment.reload).to be_booked
  end

  it "lets a professional cancel within 24 hours" do
    travel_to Time.utc(2026, 11, 9, 0, 30)

    expect(cancel(professional).reload).to be_cancelled
  end

  it "refuses to cancel twice" do
    cancel(member)

    expect { cancel(member) }.to raise_error(AppointmentPolicy::NotAllowed, AppointmentPolicy::NOT_BOOKED)
  end

  it "sees a change made since the appointment was loaded" do
    stale = Appointment.find(appointment.id)
    cancel(professional)

    expect { described_class.new(appointment: stale, user: member).call }
      .to raise_error(AppointmentPolicy::NotAllowed, AppointmentPolicy::NOT_BOOKED)
  end

  it "frees the time for someone else" do
    cancel(member)

    expect { book(create_person("Other Member", role: "member"), professional, Time.utc(2026, 11, 9, 1, 0)) }.not_to raise_error
  end
end
