require "rails_helper"

RSpec.describe RescheduleAppointment do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:monday_nine) { Time.utc(2026, 11, 9, 1, 0) } # 09:00 in Singapore
  let(:monday_ten) { Time.utc(2026, 11, 9, 2, 0) }
  let(:tuesday_nine) { Time.utc(2026, 11, 10, 1, 0) }
  let!(:appointment) { book(member, professional, monday_nine) }

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    (1..2).each { |day| set_hours(professional, day, 540, 720) }
  end

  def reschedule(to, session = appointment)
    described_class.new(appointment: session, **slot_params(to, professional)).call
  end

  it "moves the same appointment to the new time, still booked" do
    reschedule(tuesday_nine)

    expect(appointment.reload).to have_attributes(status: "booked", starts_at_utc: tuesday_nine, ends_at_utc: tuesday_nine + 50.minutes)
    expect(Appointment.count).to eq(1)
  end

  it "can be done again and again" do
    reschedule(tuesday_nine)
    reschedule(monday_ten)

    expect(appointment.reload).to have_attributes(status: "booked", starts_at_utc: monday_ten)
  end

  it "can move to a time that overlaps the current one" do
    professional.working_hours.find_by(day_of_week: 1).update!(start_minute: 510) # Slots at 08:30, 09:30, ...

    expect(reschedule(Time.utc(2026, 11, 9, 1, 30)).reload.starts_at_utc).to eq(Time.utc(2026, 11, 9, 1, 30))
  end

  it "frees the old time for someone else" do
    reschedule(tuesday_nine)

    expect { book(create_person("Other Member", role: "member"), professional, monday_nine) }.not_to raise_error
  end

  it "keeps the old time if the new one is taken" do
    book(create_person("Other Member", role: "member"), professional, tuesday_nine)

    expect { reschedule(tuesday_nine) }.to raise_error(BookAppointment::Unavailable, BookAppointment::SLOT_TAKEN)
    expect(appointment.reload).to have_attributes(status: "booked", starts_at_utc: monday_nine)
  end

  it "keeps the old time if the new one isn't a slot" do
    expect { reschedule(Time.utc(2026, 11, 9, 1, 15)) }.to raise_error(BookAppointment::Unavailable, BookAppointment::NOT_A_SLOT)
    expect(appointment.reload.starts_at_utc).to eq(monday_nine)
  end

  it "refuses within 24 hours of the current time, and changes nothing" do
    travel_to Time.utc(2026, 11, 8, 2, 0)

    expect { reschedule(tuesday_nine) }.to raise_error(AppointmentPolicy::NotAllowed, AppointmentPolicy::TOO_LATE)
    expect(appointment.reload.starts_at_utc).to eq(monday_nine)
  end

  it "refuses a cancelled session" do
    stale = Appointment.find(appointment.id)
    appointment.cancelled!

    expect { reschedule(tuesday_nine, stale) }.to raise_error(AppointmentPolicy::NotAllowed, AppointmentPolicy::NOT_BOOKED)
    expect(appointment.reload).to be_cancelled
  end
end
