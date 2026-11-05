require "rails_helper"

RSpec.describe WorkingHour, type: :model do
  def create_user(role: "professional", email: "professional@example.com")
    User.create!(name: "Test User", email:, password: "password123", role:, timezone: "Asia/Singapore")
  end

  let(:professional) { create_user }

  def build_hour(**overrides)
    described_class.new({ professional:, day_of_week: 1, start_minute: 540, end_minute: 1020 }.merge(overrides))
  end

  describe "validations" do
    it "accepts a normal working day" do
      expect(build_hour).to be_valid
    end

    [ { start_minute: 555 }, { end_minute: 1065 }, { start_minute: 545 } ].each do |times|
      it "rejects #{times}, which isn't on a 30-minute step" do
        hour = build_hour(**times)

        expect(hour).not_to be_valid
        expect(hour.errors[times.keys.first]).to include("must be in 30-minute steps")
      end
    end

    it "rejects an end equal to the start" do
      hour = build_hour(start_minute: 540, end_minute: 540)

      expect(hour).not_to be_valid
      expect(hour.errors[:end_minute]).to include("must be after the start time")
    end

    it "leaves the session length to the code that uses it" do
      expect(build_hour(start_minute: 540, end_minute: 570)).to be_valid
    end

    it "rejects an end before the start, so hours can't run past midnight" do
      expect(build_hour(start_minute: 1320, end_minute: 120)).not_to be_valid
    end

    [ -30, 1440, 1.5, "abc", "09:00", "", nil ].each do |value|
      it "rejects #{value.inspect} as a start, without raising" do
        hour = build_hour(start_minute: value)

        expect(hour).not_to be_valid
        expect(hour.errors).to have_key(:start_minute)
      end
    end

    it "calls the minutes start and end time in messages" do
      hour = build_hour(start_minute: "abc", end_minute: "abc")

      hour.valid?

      expect(hour.errors.full_messages).to include("Start time is not a number", "End time is not a number")
    end

    [ -1, 7, 1.5, "abc", nil ].each do |value|
      it "rejects #{value.inspect} as a day" do
        hour = build_hour(day_of_week: value)

        expect(hour).not_to be_valid
        expect(hour.errors).to have_key(:day_of_week)
      end
    end

    it "rejects hours for a member" do
      hour = build_hour(professional: create_user(role: "member", email: "member@example.com"))

      expect(hour).not_to be_valid
      expect(hour.errors).to have_key(:professional)
    end
  end

  describe "database constraints" do
    it "allows only one set of hours per day for each professional" do
      build_hour.save!

      expect { build_hour.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "lets different professionals have hours on the same day" do
      build_hour.save!

      expect { build_hour(professional: create_user(email: "other@example.com")).save! }.not_to raise_error
    end

    it "rejects an end that isn't after the start, even when validations are skipped" do
      hour = build_hour.tap(&:save!)

      expect { hour.update_columns(end_minute: hour.start_minute) }
        .to raise_error(ActiveRecord::CheckViolation)
    end
  end
end
