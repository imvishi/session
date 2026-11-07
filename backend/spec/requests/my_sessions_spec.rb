require "rails_helper"

RSpec.describe "My sessions", type: :request do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional") }

  before do
    travel_to Time.utc(2026, 11, 5, 12, 0)
    book(member, professional, Time.utc(2026, 11, 9, 1, 0))
    book(member, professional, Time.utc(2026, 11, 2, 1, 0))
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def json
    response.parsed_body
  end

  it "gives a member their upcoming and past sessions, with the professional's name" do
    log_in(member)
    get "/api/v1/appointments"

    expect(response).to have_http_status(:ok)
    expect(json["timezone"]).to eq("Asia/Kolkata")
    expect(json["upcoming"].map { |session| session.values_at("date_label", "time_label") }).to eq([ [ "Monday, 9 November 2026", "6:30 AM – 7:20 AM" ] ])
    expect(json["upcoming"].first["professional"]).to eq("id" => professional.id, "name" => "Pat Professional")
    expect(json["past"].size).to eq(1)
  end

  it "gives a professional their upcoming schedule, with the member's name and no email" do
    log_in(professional)
    get "/api/v1/appointments"

    expect(response).to have_http_status(:ok)
    expect(json.keys).to contain_exactly("timezone", "upcoming")
    expect(json["upcoming"].first["member"]).to eq("id" => member.id, "name" => "Sam Member")
    expect(response.body).not_to include(member.email)
  end

  it "requires a login" do
    get "/api/v1/appointments", as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
