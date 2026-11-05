require "rails_helper"

RSpec.describe ProfessionalCalendar do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional", timezone: "Asia/Singapore") }

  # A Thursday, in the middle of the week.
  before { travel_to Time.utc(2026, 11, 5, 0, 0) }

  subject(:calendar) { described_class.new(professional:, member:).to_h }

  def day(date)
    calendar[:days].find { |entry| entry[:date] == date }
  end

  def labels(date)
    day(date)[:slots].map { |slot| slot[:label] }
  end

  it "describes the professional and the member's timezone" do
    expect(calendar[:professional]).to eq("id" => professional.id, "name" => "Pat Professional")
    expect(calendar[:timezone_label]).to eq("Asia/Kolkata (GMT+05:30)")
    expect(calendar[:session_minutes]).to eq(50)
  end

  it "gives whole weeks from Monday, so the days line up under the weekday names" do
    expect(calendar[:weekdays].first).to eq("Mon")
    expect(calendar[:days].first[:date]).to eq("2026-11-02")
    expect(calendar[:days].size % 7).to eq(0)
    expect(Date.parse(calendar[:days].last[:date]).sunday?).to be(true)
  end

  it "labels the days" do
    expect(day("2026-11-09")).to include(label: "Monday, 9 November", short_label: "9 Nov")
  end

  it "shows times in the member's timezone, not the professional's" do
    set_hours(professional, 1, 540, 600) # 09:00 in Singapore

    expect(labels("2026-11-09")).to eq([ "6:30 AM" ])
    expect(day("2026-11-09")[:slots].first).to include(appointment_date: "2026-11-09", start_at: "09:00:00", end_at: "09:50:00")
  end

  it "also gives each time on the professional's clock, including their date" do
    set_hours(professional, 1, 60, 120) # 01:00 on Monday in Singapore is 22:30 on Sunday in Kolkata

    expect(day("2026-11-08")[:slots].first).to include(
      appointment_date: "2026-11-09", start_at: "01:00:00", end_at: "01:50:00",
      label: "10:30 PM", professional_label: "Monday, 9 November at 1:00 AM (Asia/Singapore)"
    )
  end

  it "groups a slot under the member's own date when it's a different day for them" do
    set_hours(professional, 1, 60, 120) # 01:00 on Monday in Singapore is 22:30 on Sunday in Kolkata

    expect(labels("2026-11-08")).to eq([ "10:30 PM" ])
    expect(labels("2026-11-09")).to be_empty
  end

  it "covers the next 4 weeks and no further" do
    set_hours(professional, 4, 540, 600) # Thursdays, 09:00 in Singapore

    expect(calendar[:days].flat_map { |entry| entry[:slots] }.map { |slot| slot[:appointment_date] }).to eq(
      %w[2026-11-05 2026-11-12 2026-11-19 2026-11-26]
    )
  end

  it "leaves out slots that have already started" do
    set_hours(professional, 4, 480, 660) # 08:00, 09:00 and 10:00 on Thursday in Singapore
    travel_to Time.utc(2026, 11, 5, 1, 30) # 09:30 in Singapore

    expect(day("2026-11-05")[:slots].map { |slot| slot[:start_at] }).to eq([ "10:00:00" ])
  end

  it "leaves out booked slots, and shows them again once cancelled" do
    set_hours(professional, 1, 540, 660) # 09:00 and 10:00 in Singapore
    appointment = book(member, professional, Time.utc(2026, 11, 9, 1, 0))

    expect(labels("2026-11-09")).to eq([ "7:30 AM" ])

    appointment.cancelled!

    expect(described_class.new(professional:, member:).to_h[:days].find { |entry| entry[:date] == "2026-11-09" }[:slots].size).to eq(2)
  end

  it "leaves out a slot overlapped by an appointment made before the hours changed" do
    set_hours(professional, 1, 540, 660)
    book(member, professional, Time.utc(2026, 11, 9, 0, 30))

    expect(labels("2026-11-09")).to eq([ "7:30 AM" ])
  end

  it "only considers this professional's appointments" do
    other = create_person("Alex Professional", role: "professional")
    set_hours(professional, 1, 540, 600)
    book(member, other, Time.utc(2026, 11, 9, 1, 0))

    expect(labels("2026-11-09")).to eq([ "6:30 AM" ])
  end

  context "with a professional in New York and a member in India" do
    let(:professional) { create_person("Pat Professional", role: "professional", timezone: "America/New_York") }

    it "skips the missing hour when New York's clocks go forward" do
      travel_to Time.utc(2026, 3, 1, 12)
      set_hours(professional, 0, 60, 300) # Sunday 01:00-05:00 in New York

      expect(labels("2026-03-08")).to eq([ "11:30 AM", "12:30 PM", "1:30 PM" ])
    end

    it "still shows a time running across the missing hour, which booking then refuses" do
      travel_to Time.utc(2026, 3, 1, 12)
      set_hours(professional, 0, 90, 300) # Sunday 01:30-05:00 in New York

      expect(labels("2026-03-08")).to include("12:00 PM")
    end

    it "leaves out times touching the repeated hour when New York's clocks go back" do
      travel_to Time.utc(2026, 10, 25, 12)
      set_hours(professional, 0, 30, 300) # Sunday 00:30-05:00 in New York

      # New York's 00:30 EDT, 02:30 EST and 03:30 EST.
      expect(labels("2026-11-01")).to eq([ "10:00 AM", "1:00 PM", "2:00 PM" ])
    end
  end

  it "never includes who has booked" do
    set_hours(professional, 1, 540, 660)
    book(create_person("Secret Person", role: "member"), professional, Time.utc(2026, 11, 9, 1, 0))

    expect(calendar.to_json).not_to match(/Secret Person|secret-person/)
  end
end
