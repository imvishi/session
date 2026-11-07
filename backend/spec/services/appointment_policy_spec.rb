require "rails_helper"

RSpec.describe AppointmentPolicy do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:starts_at) { Time.utc(2026, 11, 9, 1, 0) }
  let(:appointment) { book(member, professional, starts_at) }

  def refusal(user, now)
    described_class.new(appointment, user, now:).refusal
  end

  describe "for a member" do
    it "allows a change exactly 24 hours before the start" do
      expect(refusal(member, starts_at - 24.hours)).to be_nil
    end

    it "refuses a change less than 24 hours before the start" do
      expect(refusal(member, starts_at - 24.hours + 1.second)).to eq(described_class::TOO_LATE)
    end

    it "counts 24 real hours, even across a clock change" do
      new_york = create_person("Nia Professional", role: "professional", timezone: "America/New_York")
      # 09:00 on Sunday 1 November in New York, the day the clocks go back. 24 real hours
      # earlier is 10:00 on Saturday on New York's clock, not 09:00.
      session = book(member, new_york, Time.utc(2026, 11, 1, 14, 0))

      expect(described_class.new(session, member, now: Time.utc(2026, 10, 31, 14, 0)).refusal).to be_nil
      expect(described_class.new(session, member, now: Time.utc(2026, 10, 31, 14, 1)).refusal).to eq(described_class::TOO_LATE)
    end
  end

  describe "for a professional" do
    it "allows cancelling right up to the end" do
      expect(refusal(professional, starts_at - 1.minute)).to be_nil
      expect(refusal(professional, starts_at + 49.minutes)).to be_nil
    end
  end

  it "refuses a session that has ended, for anyone" do
    expect(refusal(professional, starts_at + 50.minutes)).to eq(described_class::ENDED)
    expect(refusal(member, starts_at + 50.minutes)).to eq(described_class::ENDED)
  end

  it "refuses a session that isn't booked any more" do
    appointment.cancelled!

    expect(refusal(professional, starts_at - 2.days)).to eq(described_class::NOT_BOOKED)
  end

  it "raises the reason from check!" do
    expect { described_class.new(appointment, member, now: starts_at - 1.hour).check! }
      .to raise_error(described_class::NotAllowed, described_class::TOO_LATE)
  end
end
