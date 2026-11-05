require "rails_helper"

RSpec.describe WeeklyAvailability do
  let(:professional) do
    User.create!(
      name: "Test Professional", email: "professional@example.com", password: "password123",
      role: "professional", timezone: "Asia/Kolkata"
    )
  end

  subject(:availability) { described_class.new(professional).to_h }

  describe "#replace" do
    let(:monday) { { day_of_week: 1, start_minute: 540, end_minute: 1020 } }
    let(:tuesday) { { day_of_week: 2, start_minute: 600, end_minute: 720 } }
    let(:week) { described_class.new(professional) }

    def saved_days(user = professional)
      user.working_hours.reload.map(&:day_of_week)
    end

    it "replaces the existing week and returns no errors" do
      week.replace([ monday ])

      expect(week.replace([ tuesday ])).to eq([])
      expect(saved_days).to eq([ 2 ])
    end

    it "clears the week when given no rows" do
      week.replace([ monday ])

      expect(week.replace([])).to eq([])
      expect(saved_days).to be_empty
    end

    it "keeps the old week and names the day when any new row is invalid" do
      week.replace([ monday ])

      errors = week.replace([ tuesday, { day_of_week: 3, start_minute: "nope", end_minute: 720 } ])

      expect(errors).to eq([ "Wednesday: Start time is not a number" ])
      expect(saved_days).to eq([ 1 ])
    end

    it "reports the error for every invalid row, not just the first" do
      errors = week.replace([ monday.merge(end_minute: 570), tuesday.merge(start_minute: 615) ])

      expect(errors).to eq([
        "Monday: End time must be at least 50 minutes after the start time",
        "Tuesday: Start time must be in 30-minute steps"
      ])
    end

    it "accepts the shortest hours that fit a session" do
      expect(week.replace([ monday.merge(end_minute: 600) ])).to eq([])
    end

    it "rejects hours too short for a session, and writes nothing" do
      errors = week.replace([ monday.merge(end_minute: 570) ])

      expect(errors).to eq([ "Monday: End time must be at least 50 minutes after the start time" ])
      expect(saved_days).to be_empty
    end

    it "doesn't touch the week when validation fails" do
      week.replace([ monday ])

      expect { week.replace([ tuesday.merge(end_minute: "nope") ]) }
        .not_to(change { professional.working_hours.reload.map(&:id) })
    end

    it "rejects the same day given twice, and keeps the old week" do
      week.replace([ tuesday ])

      expect(week.replace([ monday, monday ])).to eq([ "Monday: Day is listed more than once" ])
      expect(saved_days).to eq([ 2 ])
    end

    it "doesn't report an invalid day as a duplicate of Sunday" do
      errors = week.replace([
        { day_of_week: "abc", start_minute: 540, end_minute: 1020 },
        { day_of_week: 0, start_minute: 540, end_minute: 1020 }
      ])

      expect(errors).to eq([ "Day of week is not a number" ])
    end

    it "rejects hours for a member" do
      member = User.create!(
        name: "Test Member", email: "member@example.com", password: "password123",
        role: "member", timezone: "Asia/Kolkata"
      )

      expect(described_class.new(member).replace([ monday ])).to eq([ "Monday: Professional must be a professional" ])
      expect(saved_days(member)).to be_empty
    end

    it "doesn't touch another professional's week" do
      other = User.create!(
        name: "Other", email: "other@example.com", password: "password123",
        role: "professional", timezone: "Asia/Kolkata"
      )
      described_class.new(other).replace([ monday ])

      week.replace([ tuesday ])

      expect(saved_days(other)).to eq([ 1 ])
    end

    it "shows the new week straight away" do
      week.replace([ monday ])

      expect(week.to_h[:days].first).to include(working: true, slot_count: 8)
    end
  end

  it "lists all seven days from Monday, with default hours and no slots when nothing is saved" do
    expect(availability[:days].map { |day| day[:name] })
      .to eq(%w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday])
    expect(availability[:days].map { |day| day[:day_of_week] }).to eq([ 1, 2, 3, 4, 5, 6, 0 ])
    expect(availability[:days].first).to include(working: false, start_minute: 540, end_minute: 1020, slot_count: nil)
  end

  it "merges in saved hours with their slot count" do
    professional.working_hours.create!(day_of_week: 2, start_minute: 600, end_minute: 750)

    tuesday = availability[:days].find { |day| day[:name] == "Tuesday" }

    expect(tuesday).to include(working: true, start_minute: 600, end_minute: 750, slot_count: 2)
  end

  it "describes the slot layout" do
    expect(availability).to include(session_minutes: 50, slot_interval_minutes: 60, break_minutes: 10)
  end

  describe "slot counts" do
    [
      [ 540, 1020, 8 ], # 09:00-17:00, with the last slot at 16:00-16:50
      [ 600, 750, 2 ],  # 10:00-12:30
      [ 540, 600, 1 ],  # 09:00-10:00
      [ 540, 630, 1 ],  # 09:00-10:30, too short for a second slot
      [ 540, 660, 2 ],  # 09:00-11:00
      [ 540, 570, 0 ]   # 09:00-09:30, too short for a session
    ].each do |start_minute, end_minute, expected|
      it "is #{expected} for minutes #{start_minute}-#{end_minute}" do
        professional.working_hours.create!(day_of_week: 1, start_minute:, end_minute:)

        expect(availability[:days].first[:slot_count]).to eq(expected)
      end
    end
  end

  it "offers every 30 minutes of the day, with a value and a label" do
    options = availability[:time_options]

    expect(options.size).to eq(48)
    expect(options.first(2)).to eq([ { value: 0, label: "00:00" }, { value: 30, label: "00:30" } ])
    expect(options[19]).to eq(value: 570, label: "09:30")
    expect(options.last).to eq(value: 1410, label: "23:30")
  end

  it "offers only times WorkingHour accepts" do
    availability[:time_options].first(47).each do |option|
      hour = WorkingHour.new(professional:, day_of_week: 1, start_minute: option[:value], end_minute: 1410)

      expect(hour).to be_valid
    end
  end

  it "labels the timezone with its offset" do
    expect(availability[:timezone_label]).to eq("Asia/Kolkata (GMT+05:30)")
  end

  it "uses today's offset in a timezone with daylight saving" do
    professional.update!(timezone: "America/New_York")

    travel_to(Time.utc(2026, 7, 1)) { expect(described_class.new(professional).to_h[:timezone_label]).to end_with("(GMT-04:00)") }
    travel_to(Time.utc(2026, 12, 1)) { expect(described_class.new(professional).to_h[:timezone_label]).to end_with("(GMT-05:00)") }
  end
end
