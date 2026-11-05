require "rails_helper"

RSpec.describe IanaTimezoneValidator do
  let(:model) do
    Class.new do
      include ActiveModel::Model

      attr_accessor :home_timezone, :billing_timezone

      validates :home_timezone, iana_timezone: true
      validates :billing_timezone, iana_timezone: true, allow_nil: true

      def self.name = "Clinic"
    end
  end

  it "works on any attribute name, including several on one model" do
    record = model.new(home_timezone: "America/New_York", billing_timezone: "Asia/Kolkata")

    expect(record).to be_valid
  end

  it "adds the error to the attribute it checked" do
    record = model.new(home_timezone: "Not/AZone", billing_timezone: "Also/Wrong")

    expect(record).not_to be_valid
    expect(record.errors[:home_timezone]).to eq([ "is not a valid IANA timezone" ])
    expect(record.errors[:billing_timezone]).to eq([ "is not a valid IANA timezone" ])
  end

  it "rejects a missing value unless the model allows it" do
    record = model.new(home_timezone: nil, billing_timezone: nil)

    expect(record).not_to be_valid
    expect(record.errors).to have_key(:home_timezone)
    expect(record.errors).not_to have_key(:billing_timezone)
  end
end
