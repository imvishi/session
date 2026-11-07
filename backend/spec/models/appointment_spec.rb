require "rails_helper"

RSpec.describe Appointment, type: :model do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:other_member) { create_person("Other Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:other_professional) { create_person("Alex Professional", role: "professional") }
  let(:nine) { Time.utc(2030, 1, 7, 9, 0) }

  def build_at_nine(**overrides)
    described_class.new({
      member:, professional:, appointment_date: "2030-01-07", start_time: "09:00", end_time: "09:50", timezone: "Asia/Singapore"
    }.merge(overrides))
  end

  # In New York, 02:00-03:00 doesn't exist on 2026-03-08, and 01:00-02:00 happens twice on 2026-11-01.
  describe "a time that must be valid for both people" do
    let(:new_york_member) { create_person("New York Member", role: "member", timezone: "America/New_York") }

    def appointment_at(date, start_time, end_time, timezone: "America/New_York", person: member)
      described_class.new(member: person, professional:, appointment_date: date, start_time:, end_time:, timezone:)
    end

    {
      "starting at a time the professional's clock skips" => [ "2026-03-08", "02:30", "03:20" ],
      "ending at a time the professional's clock skips" => [ "2026-03-08", "01:40", "02:30" ],
      "running across the time the professional's clock skips" => [ "2026-03-08", "01:30", "03:20" ],
      "at a time the professional's clock repeats" => [ "2026-11-01", "01:00", "01:50" ],
      "running into a time the professional's clock repeats" => [ "2026-11-01", "00:30", "01:20" ],
      "starting at a time the professional's clock repeats" => [ "2026-11-01", "01:30", "02:20" ]
    }.each do |description, (date, start_time, end_time)|
      it "rejects a session #{description}" do
        appointment = appointment_at(date, start_time, end_time)

        expect(appointment).not_to be_valid
        expect(appointment.errors[:base]).to eq([ Appointment::INVALID_TIME ])
      end
    end

    {
      "running across the time the member's clock skips" => [ "2027-03-14", "12:00", "12:50" ],
      "at a time the member's clock repeats" => [ "2026-11-01", "11:00", "11:50" ]
    }.each do |description, (date, start_time, end_time)|
      it "rejects a session #{description}, using the professional's time in India" do
        appointment = appointment_at(date, start_time, end_time, timezone: "Asia/Kolkata", person: new_york_member)

        expect(appointment).not_to be_valid
        expect(appointment.errors[:base]).to eq([ Appointment::INVALID_TIME ])
      end
    end

    it "accepts sessions either side of a change" do
      expect(appointment_at("2026-03-08", "00:30", "01:20")).to be_valid
      expect(appointment_at("2026-03-08", "03:30", "04:20")).to be_valid
      expect(appointment_at("2026-11-01", "02:30", "03:20")).to be_valid
    end

    it "accepts the same time for a member whose clock isn't changing" do
      expect(appointment_at("2027-03-14", "12:00", "12:50", timezone: "Asia/Kolkata")).to be_valid
    end

    it "checks again when a saved appointment is moved to a new time" do
      appointment = appointment_at("2026-03-08", "00:30", "01:20")
      appointment.save!

      appointment.assign_attributes(start_time: "01:30", end_time: "03:20")

      expect(appointment).not_to be_valid
      expect(appointment.errors[:base]).to eq([ Appointment::INVALID_TIME ])
    end

    it "doesn't stop a saved appointment being cancelled later" do
      appointment = appointment_at("2026-03-08", "01:30", "03:20")
      appointment.save!(validate: false)

      expect { appointment.cancelled! }.not_to raise_error
    end
  end

  describe "timezone" do
    def build_appointment(timezone)
      build_at_nine(timezone:)
    end

    it "accepts an IANA name" do
      expect(build_appointment("America/New_York")).to be_valid
    end

    [ "EST", "GMT+5", "Not/AZone", "", nil ].each do |value|
      next if TZInfo::Timezone.all_identifiers.include?(value)

      it "rejects #{value.inspect}" do
        appointment = build_appointment(value)

        expect(appointment).not_to be_valid
        expect(appointment.errors[:timezone]).to include("is not a valid IANA timezone")
      end
    end

    it "can't be missing, even when validations are skipped" do
      expect { build_appointment(nil).save!(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "local times" do
    let(:new_york) { create_person("New York Professional", role: "professional", timezone: "America/New_York") }

    it "stores the time on the professional's clock" do
      appointment = book(member, new_york, Time.utc(2030, 1, 7, 14, 0))

      stored = described_class.connection.select_one("SELECT appointment_date, start_time, end_time, timezone FROM appointments WHERE id = #{appointment.id}")

      expect(stored["appointment_date"].to_s).to eq("2030-01-07")
      expect(stored["start_time"].to_s).to eq("09:00:00")
      expect(stored["end_time"].to_s).to eq("09:50:00")
      expect(stored["timezone"]).to eq("America/New_York")
    end

    it "gives the real moments, with daylight saving applied" do
      winter = book(member, new_york, Time.utc(2030, 1, 7, 14, 0))
      summer = book(member, new_york, Time.utc(2030, 7, 8, 13, 0))

      expect(winter.reload.starts_at_utc).to eq(Time.utc(2030, 1, 7, 14, 0))
      expect(summer.reload.starts_at_utc).to eq(Time.utc(2030, 7, 8, 13, 0))
      expect(summer.ends_at_utc).to eq(Time.utc(2030, 7, 8, 13, 50))
    end

    it "finds overlaps by real moment, across different timezones" do
      appointment = book(member, new_york, Time.utc(2030, 1, 7, 14, 0))

      expect(described_class.overlapping(Time.utc(2030, 1, 7, 14, 30), Time.utc(2030, 1, 7, 15, 20))).to eq([ appointment ])
      expect(described_class.overlapping(Time.utc(2030, 1, 7, 14, 50), Time.utc(2030, 1, 7, 15, 40))).to be_empty
      # The same clock reading as the appointment, but in UTC, is a different moment.
      expect(described_class.overlapping(Time.utc(2030, 1, 7, 9, 0), Time.utc(2030, 1, 7, 9, 50))).to be_empty
    end
  end

  it "can find overlaps when joined to users, which also have a timezone" do
    appointment = book(member, professional, nine)

    expect(described_class.joins(:member).overlapping(nine, nine + 10.minutes)).to eq([ appointment ])
  end

  describe "database overlap rules" do
    before { book(member, professional, nine) }

    it "stops two members seeing the same professional at the same time" do
      expect { book(other_member, professional, nine) }.to raise_error(ActiveRecord::ExclusionViolation, /appointments_no_professional_overlap/)
    end

    it "stops a partial overlap with the same professional" do
      expect { book(other_member, professional, nine + 30.minutes) }.to raise_error(ActiveRecord::ExclusionViolation)
    end

    it "allows back-to-back sessions" do
      expect { book(member, professional, nine + 50.minutes) }.not_to raise_error
    end

    it "lets different people book the same time" do
      expect { book(other_member, other_professional, nine) }.not_to raise_error
    end

    it "ignores cancelled sessions, so the time can be booked again" do
      described_class.booked.first.cancelled!

      expect { book(other_member, professional, nine) }.not_to raise_error
    end
  end

  it "rejects an end that isn't after the start" do
    expect(build_at_nine(end_time: "09:00")).not_to be_valid
    expect(build_at_nine(end_time: "08:59")).not_to be_valid
  end

  it "rejects an end that isn't after the start, even when validations are skipped" do
    expect { build_at_nine(end_time: "09:00").save!(validate: false) }.to raise_error(ActiveRecord::CheckViolation)
  end
end
