require "rails_helper"

RSpec.describe Reminder do
  include AppointmentHelpers
  describe "#lead_time_label" do
    { 1440 => "24 hours", 60 => "1 hour", 30 => "30 minutes", 1 => "1 minute", 90 => "1 hour 30 minutes", 2880 => "48 hours" }.each do |minutes, label|
      it "describes #{minutes} minutes as #{label.inspect}" do
        expect(described_class.new(minutes_before: minutes).lead_time_label).to eq(label)
      end
    end
  end

  it "needs a positive whole number of minutes, also in the database" do
    expect(described_class.new(minutes_before: 0)).to be_invalid
    member = create_person("Sam Member", role: "member")
    appointment = book(member, create_person("Pat Professional", role: "professional"), Time.utc(2030, 1, 7, 1, 0))

    expect { appointment.reminders.new(user: member, minutes_before: 0, remind_at: Time.current).save!(validate: false) }
      .to raise_error(ActiveRecord::CheckViolation, /reminders_minutes_before_is_positive/)
  end
end
