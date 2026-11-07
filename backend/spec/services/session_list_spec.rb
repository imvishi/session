require "rails_helper"

RSpec.describe SessionList do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional", timezone: "Asia/Singapore") }

  # Thursday 5 November 2026, 12:00 UTC.
  before { travel_to Time.utc(2026, 11, 5, 12, 0) }

  def ids(sessions)
    sessions.map { |session| session[:id] }
  end

  describe "for a member" do
    subject(:list) { described_class.new(member).to_h }

    it "gives the date and time on the member's clock, and who the session is with" do
      appointment = book(member, professional, Time.utc(2026, 11, 9, 1, 0)) # 09:00 in Singapore

      expect(list[:timezone]).to eq("Asia/Kolkata")
      expect(list[:upcoming]).to eq([ {
        id: appointment.id, status: "booked", date_label: "Monday, 9 November 2026", time_label: "6:30 AM – 7:20 AM",
        professional: { "id" => professional.id, "name" => "Pat Professional" },
        can_cancel: true, can_reschedule: true, notice: nil
      } ])
    end

    it "explains when a session is too close to change, and offers nothing" do
      book(member, professional, Time.utc(2026, 11, 6, 1, 0)) # 13 hours away

      expect(list[:upcoming].first).to include(can_cancel: false, can_reschedule: false, notice: AppointmentPolicy::TOO_LATE)
    end

    it "offers no changes to a past or cancelled session, and gives no notice" do
      book(member, professional, Time.utc(2026, 11, 2, 1, 0))
      book(member, professional, Time.utc(2026, 11, 9, 1, 0)).cancelled!

      expect(list[:past] + list[:upcoming]).to all(include(can_cancel: false, can_reschedule: false, notice: nil))
    end

    it "lists upcoming sessions soonest first, and past ones most recent first" do
      later = book(member, professional, Time.utc(2026, 11, 10, 1, 0))
      sooner = book(member, professional, Time.utc(2026, 11, 9, 1, 0))
      older = book(member, professional, Time.utc(2026, 11, 2, 1, 0))
      recent = book(member, professional, Time.utc(2026, 11, 3, 1, 0))

      expect(ids(list[:upcoming])).to eq([ sooner.id, later.id ])
      expect(ids(list[:past])).to eq([ recent.id, older.id ])
    end

    it "orders by the real moment, not the clock time, across professionals' timezones" do
      new_york = create_person("Nia Professional", role: "professional", timezone: "America/New_York")
      new_york_nine = book(member, new_york, Time.utc(2026, 11, 9, 14, 0)) # 09:00 in New York
      singapore_ten = book(member, professional, Time.utc(2026, 11, 9, 2, 0)) # 10:00 in Singapore, but earlier

      expect(ids(list[:upcoming])).to eq([ singapore_ten.id, new_york_nine.id ])
    end

    it "keeps a session that has started, but not ended, in upcoming" do
      in_progress = book(member, professional, Time.utc(2026, 11, 5, 11, 30))
      other = create_person("Alex Professional", role: "professional")
      ended = book(member, other, Time.utc(2026, 11, 5, 11, 10)) # Ends at 12:00, exactly now

      expect(ids(list[:upcoming])).to eq([ in_progress.id ])
      expect(ids(list[:past])).to eq([ ended.id ])
    end

    it "includes cancelled sessions, marked as cancelled" do
      book(member, professional, Time.utc(2026, 11, 9, 1, 0)).cancelled!

      expect(list[:upcoming].map { |session| session[:status] }).to eq([ "cancelled" ])
    end

    it "only includes the member's own sessions" do
      book(create_person("Other Member", role: "member"), professional, Time.utc(2026, 11, 9, 1, 0))

      expect(list).to include(upcoming: [], past: [])
    end
  end

  describe "for a professional" do
    subject(:schedule) { described_class.new(professional).to_h }

    it "gives upcoming sessions on the professional's clock, with the member's name" do
      appointment = book(member, professional, Time.utc(2026, 11, 9, 1, 0))

      expect(schedule).to eq(
        timezone: "Asia/Singapore",
        upcoming: [ {
          id: appointment.id, status: "booked", date_label: "Monday, 9 November 2026", time_label: "9:00 AM – 9:50 AM",
          member: { "id" => member.id, "name" => "Sam Member" },
          can_cancel: true, can_reschedule: false, notice: nil
        } ]
      )
    end

    it "lets the professional cancel a session that starts soon" do
      book(member, professional, Time.utc(2026, 11, 5, 13, 0)) # 1 hour away

      expect(schedule[:upcoming].first).to include(can_cancel: true, notice: nil)
    end

    it "leaves out past and cancelled sessions" do
      book(member, professional, Time.utc(2026, 11, 2, 1, 0))
      book(member, professional, Time.utc(2026, 11, 9, 1, 0)).cancelled!
      upcoming = book(member, professional, Time.utc(2026, 11, 10, 1, 0))

      expect(ids(schedule[:upcoming])).to eq([ upcoming.id ])
    end

    it "only includes the professional's own sessions" do
      book(member, create_person("Alex Professional", role: "professional"), Time.utc(2026, 11, 9, 1, 0))

      expect(schedule[:upcoming]).to be_empty
    end
  end
end
