require "rails_helper"

RSpec.describe BookAppointment do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:monday_nine) { "2026-11-09T01:00:00Z" } # 09:00 in Singapore

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    set_hours(professional, 1, 540, 720)
  end

  # starts_at is the real moment of the slot, which the request gives on the professional's clock.
  def book_slot(starts_at, as: member, with: professional)
    described_class.new(member: as, professional: with, **slot_params(Time.iso8601(starts_at), with)).call
  end

  def book_local(appointment_date, start_at, end_at, with: professional)
    described_class.new(member:, professional: with, appointment_date:, start_at:, end_at:).call
  end

  it "creates a 50-minute appointment for a real slot" do
    appointment = book_slot(monday_nine)

    expect(appointment).to be_persisted
    expect(appointment).to have_attributes(
      member:, professional:, status: "booked",
      starts_at_utc: Time.utc(2026, 11, 9, 1, 0), ends_at_utc: Time.utc(2026, 11, 9, 1, 50)
    )
  end

  it "stores the professional's local time and timezone, not the member's" do
    member.update!(timezone: "Asia/Kolkata")

    appointment = book_slot(monday_nine).reload

    expect(appointment.timezone).to eq("Asia/Singapore")
    expect(appointment.appointment_date).to eq(Date.new(2026, 11, 9))
    expect(appointment.start_time.strftime("%H:%M")).to eq("09:00")
    expect(appointment.end_time.strftime("%H:%M")).to eq("09:50")
  end

  it "keeps the stored timezone and time if the professional's timezone changes later" do
    appointment = book_slot(monday_nine)

    professional.update!(timezone: "Europe/London")

    expect(appointment.reload).to have_attributes(timezone: "Asia/Singapore", starts_at_utc: Time.utc(2026, 11, 9, 1, 0))
  end

  it "takes the date and times on the professional's clock, whatever the member's timezone" do
    member.update!(timezone: "Asia/Kolkata")

    appointment = book_local("2026-11-09", "09:00:00", "09:50:00")

    expect(appointment.starts_at_utc).to eq(Time.utc(2026, 11, 9, 1, 0))
  end

  {
    "a time that isn't on the slot grid" => "2026-11-09T01:30:00Z",
    "a day with no working hours" => "2026-11-10T01:00:00Z",
    "a time outside the working hours" => "2026-11-09T09:00:00Z",
    "more than 4 weeks ahead" => "2026-12-07T01:00:00Z"
  }.each do |description, starts_at|
    it "rejects #{description}" do
      expect { book_slot(starts_at) }.to raise_error(described_class::Unavailable, described_class::NOT_A_SLOT)
      expect(Appointment.count).to eq(0)
    end
  end

  {
    "an end time that doesn't match the session length" => [ "2026-11-09", "09:00:00", "10:30:00" ],
    "the right times on the wrong date" => [ "2026-11-10", "09:00:00", "09:50:00" ],
    "text that isn't a time" => [ "tomorrow", "soon", "later" ]
  }.each do |description, (appointment_date, start_at, end_at)|
    it "rejects #{description}" do
      expect { book_local(appointment_date, start_at, end_at) }.to raise_error(described_class::Unavailable, described_class::NOT_A_SLOT)
      expect(Appointment.count).to eq(0)
    end
  end

  context "with a professional in New York when the clocks change" do
    let(:new_york) { create_person("Alex Professional", role: "professional", timezone: "America/New_York") }

    it "rejects 02:30 on the day that time doesn't exist" do
      travel_to Time.utc(2026, 3, 1, 12)
      set_hours(new_york, 0, 60, 300)

      expect { book_local("2026-03-08", "02:30:00", "03:20:00", with: new_york) }
        .to raise_error(described_class::Unavailable, described_class::NOT_A_SLOT)
    end

    {
      "March 2026" => [ Time.utc(2026, 3, 1, 12), "2026-03-08T06:30:00Z" ],
      "March 2027" => [ Time.utc(2027, 3, 7, 12), "2027-03-14T06:30:00Z" ]
    }.each do |description, (now, starts_at)|
      it "rejects 01:30 in #{description}, which would run across the missing hour" do
        travel_to now
        set_hours(new_york, 0, 30, 300)

        expect { book_slot(starts_at, with: new_york) }.to raise_error(described_class::Unavailable, Appointment::INVALID_TIME)
        expect(Appointment.count).to eq(0)
      end
    end

    it "rejects a session running across a 30-minute change" do
      lord_howe = create_person("Jo Professional", role: "professional", timezone: "Australia/Lord_Howe")
      travel_to Time.utc(2026, 9, 27, 12)
      set_hours(lord_howe, 0, 90, 240) # Sunday 01:30, and the clocks jump at 02:00 on 2026-10-04

      expect { book_slot("2026-10-03T15:00:00Z", with: lord_howe) }.to raise_error(described_class::Unavailable, Appointment::INVALID_TIME)
    end

    context "with a member in New York and a professional in India" do
      let(:india) { create_person("Ravi Professional", role: "professional", timezone: "Asia/Kolkata") }

      before { member.update!(timezone: "America/New_York") }

      it "rejects a time running across the member's missing hour" do
        travel_to Time.utc(2027, 3, 7, 12)
        set_hours(india, 0, 660, 810) # Sunday 12:00 in India is 01:30-03:20 for the member

        expect { book_slot("2027-03-14T06:30:00Z", with: india) }.to raise_error(described_class::Unavailable, Appointment::INVALID_TIME)
      end

      it "rejects a time in the member's repeated hour" do
        travel_to Time.utc(2026, 10, 25, 12)
        set_hours(india, 0, 660, 810) # Sunday 11:00 in India is 01:30 for the member, which happens twice

        expect { book_slot("2026-11-01T05:30:00Z", with: india) }.to raise_error(described_class::Unavailable, Appointment::INVALID_TIME)
      end

      it "books a time clear of the member's clock change" do
        travel_to Time.utc(2027, 3, 7, 12)
        set_hours(india, 0, 660, 810) # Sunday 11:00 in India is 00:30-01:20 for the member

        expect(book_slot("2027-03-14T05:30:00Z", with: india)).to be_persisted
      end
    end

    it "books 00:30, which ends before the missing hour" do
      travel_to Time.utc(2026, 3, 1, 12)
      set_hours(new_york, 0, 30, 300)

      appointment = book_slot("2026-03-08T05:30:00Z", with: new_york).reload

      expect(appointment.start_time.strftime("%H:%M")).to eq("00:30")
      expect(appointment.end_time.strftime("%H:%M")).to eq("01:20")
    end

    it "books 03:30, the first slot after the missing hour" do
      travel_to Time.utc(2026, 3, 1, 12)
      set_hours(new_york, 0, 30, 300)

      appointment = book_slot("2026-03-08T07:30:00Z", with: new_york).reload

      expect(appointment.start_time.strftime("%H:%M")).to eq("03:30")
      expect(appointment.end_time.strftime("%H:%M")).to eq("04:20")
    end

    it "books 02:30 on the day the clocks go back, for 50 real minutes" do
      travel_to Time.utc(2026, 10, 25, 12)
      set_hours(new_york, 0, 30, 300)

      appointment = book_slot("2026-11-01T02:30:00-05:00", with: new_york)

      expect(appointment.reload.starts_at_utc).to eq(Time.utc(2026, 11, 1, 7, 30))
      expect(appointment.ends_at_utc).to eq(Time.utc(2026, 11, 1, 8, 20))
    end

    # Stored local time couldn't tell these apart, or would read back as the wrong one.
    [ "2026-11-01T05:30:00Z", "2026-11-01T06:30:00Z" ].each do |starts_at|
      it "rejects #{starts_at}, an appointment touching the repeated hour" do
        travel_to Time.utc(2026, 10, 25, 12)
        set_hours(new_york, 0, 30, 300)

        expect { book_slot(starts_at, with: new_york) }.to raise_error(described_class::Unavailable, described_class::NOT_A_SLOT)
      end
    end

    it "allows the same clock reading in two timezones, because they're different moments" do
      travel_to Time.utc(2026, 11, 5, 0, 0)
      set_hours(new_york, 0, 540, 660) # Sunday 09:00 in New York is 14:00 UTC
      singapore = create_person("Lee Professional", role: "professional", timezone: "Asia/Singapore")
      set_hours(singapore, 0, 540, 660) # Sunday 09:00 in Singapore is 01:00 UTC

      first = book_slot("2026-11-08T14:00:00Z", with: new_york)
      second = book_slot("2026-11-08T01:00:00Z", with: singapore)

      expect([ first.reload.start_time, second.reload.start_time ].map { |time| time.strftime("%H:%M") }).to eq(%w[09:00 09:00])
    end
  end

  describe "when Postgres aborts the insert with a deadlock" do
    it "tells the member they can't book right now, rather than failing with an error" do
      allow(Appointment).to receive(:create!).and_raise(ActiveRecord::Deadlocked, "deadlock detected")

      expect { book_slot(monday_nine) }.to raise_error(described_class::Unavailable, described_class::BOOKING_FAILED)
      expect(Appointment).to have_received(:create!).once
    end
  end

  it "rejects a slot in the past" do
    travel_to Time.utc(2026, 11, 9, 1, 1)

    expect { book_slot(monday_nine) }.to raise_error(described_class::Unavailable, described_class::NOT_A_SLOT)
  end

  it "rejects a slot someone else has booked" do
    book_slot(monday_nine, as: create_person("Other Member", role: "member"))

    expect { book_slot(monday_nine) }.to raise_error(described_class::Unavailable, described_class::SLOT_TAKEN)
    expect(Appointment.count).to eq(1)
  end

  it "lets a member book an overlapping session with a different professional" do
    other = create_person("Alex Professional", role: "professional")
    set_hours(other, 1, 510, 720) # 08:30, so the 09:30 slot overlaps a 09:00 session
    book_slot(monday_nine)

    expect(book_slot("2026-11-09T01:30:00Z", with: other)).to be_persisted
  end
end
