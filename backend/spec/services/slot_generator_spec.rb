require "rails_helper"

RSpec.describe SlotGenerator do
  MONDAY = 1
  SUNDAY = 0

  def professional_with(timezone:, hours:)
    professional = User.create!(
      name: "Test Professional", email: "professional@example.com", password: "password123",
      role: "professional", timezone:
    )
    hours.each do |day_of_week, (start_time, end_time)|
      # Skips validation, so these tests can use any time. The 30-minute steps are a rule
      # for what professionals can save, and the generator has to handle whatever is stored.
      professional.working_hours.new(day_of_week:, start_minute: minutes(start_time), end_minute: minutes(end_time))
                  .save!(validate: false)
    end
    professional
  end

  def minutes(time)
    hours, mins = time.split(":").map(&:to_i)
    (hours * 60) + mins
  end

  def utc(string)
    Time.utc(*string.scan(/\d+/).map(&:to_i))
  end

  def slot_starts(professional, from:, to:)
    described_class.new(professional).slots(from: utc(from), to: utc(to)).map(&:starts_at)
  end

  describe "laying out slots" do
    # 2026-11-09 is a Monday, and Singapore has no daylight saving.
    let(:from) { "2026-11-09 00:00" }
    let(:to) { "2026-11-10 00:00" }

    it "starts a 50-minute slot every hour, with the last one ending inside the hours" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:00 17:00] })

      slots = described_class.new(professional).slots(from: utc(from), to: utc(to))

      expect(slots.size).to eq(8)
      expect(slots.first.starts_at).to eq(utc("2026-11-09 01:00"))
      expect(slots.first.ends_at).to eq(utc("2026-11-09 01:50"))
      expect(slots.last.starts_at).to eq(utc("2026-11-09 08:00"))
      expect(slots.last.ends_at).to eq(utc("2026-11-09 08:50"))
    end

    it "lays slots out from the start of the working day, not the top of the hour" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:30 11:30] })

      expect(slot_starts(professional, from:, to:)).to eq([ utc("2026-11-09 01:30"), utc("2026-11-09 02:30") ])
    end

    it "includes a final slot that ends exactly when the working hours end" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:00 10:50] })

      expect(slot_starts(professional, from:, to:)).to eq([ utc("2026-11-09 01:00"), utc("2026-11-09 02:00") ])
    end

    it "has no slots on a day with no working hours" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { SUNDAY => %w[09:00 17:00] })

      expect(slot_starts(professional, from:, to:)).to be_empty
    end

    it "has no slots when stored hours are too short for a session" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:00 09:49] })

      expect(slot_starts(professional, from:, to:)).to be_empty
    end

    it "repeats the hours every week" do
      professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:00 10:00] })

      expect(slot_starts(professional, from: "2026-11-09 00:00", to: "2026-12-07 00:00")).to eq(
        [ utc("2026-11-09 01:00"), utc("2026-11-16 01:00"), utc("2026-11-23 01:00"), utc("2026-11-30 01:00") ]
      )
    end
  end

  describe "the requested time range" do
    let(:professional) { professional_with(timezone: "Asia/Singapore", hours: { MONDAY => %w[09:00 12:00] }) }

    it "leaves out slots that start before it" do
      starts = slot_starts(professional, from: "2026-11-09 01:01", to: "2026-11-10 00:00")

      expect(starts).to eq([ utc("2026-11-09 02:00"), utc("2026-11-09 03:00") ])
    end

    it "includes a slot starting exactly at the beginning, and excludes one exactly at the end" do
      starts = slot_starts(professional, from: "2026-11-09 01:00", to: "2026-11-09 02:00")

      expect(starts).to eq([ utc("2026-11-09 01:00") ])
    end
  end

  describe "timezones" do
    it "reads the hours in the professional's timezone" do
      professional = professional_with(timezone: "America/New_York", hours: { MONDAY => %w[09:00 10:00] })

      expect(slot_starts(professional, from: "2026-11-09 00:00", to: "2026-11-10 00:00")).to eq([ utc("2026-11-09 14:00") ])
    end

    it "handles offsets that aren't whole hours" do
      professional = professional_with(timezone: "Asia/Kathmandu", hours: { MONDAY => %w[09:00 10:00] })

      expect(slot_starts(professional, from: "2026-11-09 00:00", to: "2026-11-10 00:00")).to eq([ utc("2026-11-09 03:15") ])
    end

    it "picks the day from the professional's date, even when it's a different day in UTC" do
      professional = professional_with(timezone: "Pacific/Auckland", hours: { MONDAY => %w[09:00 10:00] })

      # 09:00 on Monday the 9th in Auckland is 20:00 on Sunday the 8th in UTC. This range
      # is entirely on the 8th in UTC, so it only finds the slot using Auckland's date.
      expect(slot_starts(professional, from: "2026-11-08 19:00", to: "2026-11-08 21:00")).to eq([ utc("2026-11-08 20:00") ])
    end
  end

  # New York's clocks change at 02:00 on 2026-03-08 (forward) and 2026-11-01 (back).
  describe "daylight saving" do
    it "keeps the same wall-clock time on either side of a change" do
      professional = professional_with(timezone: "America/New_York", hours: { MONDAY => %w[09:00 10:00] })

      expect(slot_starts(professional, from: "2026-03-02 00:00", to: "2026-03-10 00:00")).to eq(
        [ utc("2026-03-02 14:00"), utc("2026-03-09 13:00") ]
      )
    end

    it "has no slot in the missing hour when the clocks go forward" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[01:00 05:00] })

      # 01:00 EST, then 03:00 and 04:00 EDT.
      expect(slot_starts(professional, from: "2026-03-08 00:00", to: "2026-03-09 00:00")).to eq(
        [ utc("2026-03-08 06:00"), utc("2026-03-08 07:00"), utc("2026-03-08 08:00") ]
      )
    end

    it "still shows a slot running across the missing hour, which booking then refuses" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[00:30 05:30] })

      # 00:30 EST, 01:30 EST (ending at 03:20 EDT), then 03:30 and 04:30 EDT.
      expect(slot_starts(professional, from: "2026-03-08 00:00", to: "2026-03-09 00:00")).to eq(
        [ utc("2026-03-08 05:30"), utc("2026-03-08 06:30"), utc("2026-03-08 07:30"), utc("2026-03-08 08:30") ]
      )
    end

    it "leaves out a slot whose real 50 minutes run past the hours when the clocks go forward" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[01:30 03:00] })

      # Starting at 01:30 EST, 50 minutes later is 03:20 EDT.
      expect(slot_starts(professional, from: "2026-03-08 00:00", to: "2026-03-09 00:00")).to be_empty
    end

    it "leaves out a slot starting in the repeated hour when the clocks go back" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[01:00 03:00] })

      # 01:00 EDT, then 01:00 EST which local time can't tell apart, then 02:00 EST.
      expect(slot_starts(professional, from: "2026-11-01 00:00", to: "2026-11-02 00:00")).to eq(
        [ utc("2026-11-01 05:00"), utc("2026-11-01 07:00") ]
      )
    end

    # Lord Howe Island's clocks go forward by 30 minutes, at 02:00 on 2026-10-04.
    it "doesn't overlap slots when the clocks move by less than an hour" do
      professional = professional_with(timezone: "Australia/Lord_Howe", hours: { SUNDAY => %w[01:30 04:00] })

      slots = described_class.new(professional).slots(from: utc("2026-10-03 00:00"), to: utc("2026-10-05 00:00"))

      expect(slots.map(&:starts_at)).to eq([ utc("2026-10-03 15:00"), utc("2026-10-03 16:00") ])
      expect(slots.first.ends_at).to be <= slots.last.starts_at
    end

    describe "working hours touching the missing hour on 2026-03-08" do
      [
        [ "ending in it, with no room for a session", %w[01:30 02:30], [] ],
        [ "ending in it, with room for one session", %w[01:00 02:30], [ "2026-03-08 06:00" ] ],
        [ "ending in it, without room for a second session", %w[00:30 02:30], [ "2026-03-08 05:30" ] ],
        [ "ending exactly as the clocks jump", %w[01:00 02:00], [ "2026-03-08 06:00" ] ],
        [ "starting in it, which moves an hour later", %w[02:30 05:30], [ "2026-03-08 07:30", "2026-03-08 08:30" ] ],
        [ "spanning it", %w[01:00 05:00], [ "2026-03-08 06:00", "2026-03-08 07:00", "2026-03-08 08:00" ] ]
      ].each do |description, hours, expected|
        it "handles #{hours.join("-")}, #{description}" do
          professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => hours })

          expect(slot_starts(professional, from: "2026-03-08 00:00", to: "2026-03-09 00:00"))
            .to eq(expected.map { |time| utc(time) })
        end
      end
    end

    it "ends the day when the clocks jump in a timezone with a 30-minute change" do
      professional = professional_with(timezone: "Australia/Lord_Howe", hours: { SUNDAY => %w[01:30 02:15] })

      # 02:15 doesn't exist on 2026-10-04, and only 30 real minutes pass after 01:30.
      expect(slot_starts(professional, from: "2026-10-03 00:00", to: "2026-10-05 00:00")).to be_empty
    end

    it "leaves out slots that end in or cross the repeated hour, but keeps 02:30, when the clocks go back" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[00:30 05:00] })

      # 00:30 EDT is fine. 01:30 EDT ends at 01:20 EST, before it starts on the clock.
      # 01:30 EST is the repeated time. 02:30 and 03:30 EST are ordinary.
      expect(slot_starts(professional, from: "2026-11-01 00:00", to: "2026-11-02 00:00")).to eq(
        [ utc("2026-11-01 04:30"), utc("2026-11-01 07:30"), utc("2026-11-01 08:30") ]
      )
    end

    it "never produces overlapping slots across a change" do
      professional = professional_with(timezone: "America/New_York", hours: { SUNDAY => %w[00:00 23:59] })

      [ %w[2026-03-08 2026-03-09], %w[2026-11-01 2026-11-02] ].each do |day, next_day|
        slots = described_class.new(professional).slots(from: utc("#{day} 00:00"), to: utc("#{next_day} 12:00"))

        slots.each_cons(2) { |earlier, later| expect(earlier.ends_at).to be <= later.starts_at }
      end
    end
  end

  describe ".slots_per_day" do
    [
      [ "09:00", "17:00", 8 ],
      [ "10:00", "12:30", 2 ],
      [ "09:00", "09:50", 1 ],
      [ "09:00", "10:49", 1 ],
      [ "09:00", "10:50", 2 ]
    ].each do |start_time, end_time, expected|
      it "is #{expected} for #{start_time}-#{end_time}, matching the slots generated on an ordinary day" do
        professional = professional_with(timezone: "Asia/Singapore", hours: { MONDAY => [ start_time, end_time ] })

        expect(described_class.slots_per_day(professional.working_hours.first)).to eq(expected)
        expect(slot_starts(professional, from: "2026-11-09 00:00", to: "2026-11-10 00:00").size).to eq(expected)
      end
    end
  end
end
