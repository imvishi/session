require "rails_helper"

RSpec.describe "Making an appointment", type: :request do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:monday_nine) { "2026-11-09T01:00:00Z" }

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    set_hours(professional, 1, 540, 720)
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def json
    response.parsed_body
  end

  def book_slot(starts_at = monday_nine, **extra)
    params = { professional_id: professional.id, **slot_params(Time.iso8601(starts_at), professional), **extra }

    post "/api/v1/appointments", params:, as: :json
  end

  it "explains when a time isn't valid for the member, and books nothing" do
    travel_to Time.utc(2027, 3, 7, 12)
    member.update!(timezone: "America/New_York")
    set_hours(professional, 0, 870, 930) # Sunday 14:30 in Singapore is 01:30-03:20 for the member
    log_in(member)

    expect { book_slot("2027-03-14T06:30:00Z") }.not_to change(Appointment, :count)

    expect(response).to have_http_status(:conflict)
    expect(json["error"]).to eq(Appointment::INVALID_TIME)
  end

  describe "as a member" do
    before { log_in(member) }

    it "shows a calendar, books a slot, and stops showing it" do
      get "/api/v1/professionals/#{professional.id}"
      slot = json["days"].find { |day| day["date"] == "2026-11-09" }["slots"].first
      expect(slot).to eq(
        "appointment_date" => "2026-11-09", "start_at" => "09:00:00", "end_at" => "09:50:00", "label" => "6:30 AM",
        "professional_label" => "Monday, 9 November at 9:00 AM (Asia/Singapore)"
      )

      post "/api/v1/appointments", params: slot.slice("appointment_date", "start_at", "end_at").merge(professional_id: professional.id), as: :json
      expect(response).to have_http_status(:created)
      expect(json["appointment"]).to eq("id" => Appointment.last.id)

      get "/api/v1/professionals/#{professional.id}"
      remaining = json["days"].find { |day| day["date"] == "2026-11-09" }["slots"]
      expect(remaining.map { |entry| entry["start_at"] }).not_to include("09:00:00")
    end

    it "takes the member from the login, ignoring a member_id sent by the client" do
      other = create_person("Other Member", role: "member")

      book_slot(monday_nine, member_id: other.id)

      expect(Appointment.last.member).to eq(member)
    end

    it "refuses an end time that doesn't match the slot, and books nothing" do
      expect { book_slot(monday_nine, end_at: "11:30:00") }.not_to change(Appointment, :count)

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(BookAppointment::NOT_A_SLOT)
    end

    it "explains when the slot is taken" do
      book(create_person("Other Member", role: "member"), professional, Time.utc(2026, 11, 9, 1, 0))

      book_slot

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(BookAppointment::SLOT_TAKEN)
    end

    it "explains when the time isn't a slot" do
      book_slot(monday_nine, start_at: "09:30:00", end_at: "10:20:00")

      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(BookAppointment::NOT_A_SLOT)
    end

    %w[appointment_date start_at end_at].each do |name|
      it "requires #{name}" do
        details = slot_params(Time.iso8601(monday_nine), professional).except(name.to_sym)

        post "/api/v1/appointments", params: { professional_id: professional.id, **details }, as: :json

        expect(response).to have_http_status(:bad_request)
      end
    end

    it "gives a 404 when the professional doesn't exist, or is really a member" do
      post "/api/v1/appointments", params: { professional_id: member.id, **slot_params(Time.iso8601(monday_nine), professional) }, as: :json
      expect(response).to have_http_status(:not_found)
      expect(json["error"]).to eq("We couldn't find that.")

      get "/api/v1/professionals/#{member.id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  it "doesn't let a professional book or view a calendar" do
    log_in(create_person("Alex Professional", role: "professional"))

    book_slot
    expect(response).to have_http_status(:forbidden)

    get "/api/v1/professionals/#{professional.id}"
    expect(response).to have_http_status(:forbidden)
  end

  it "requires a login" do
    book_slot
    expect(response).to have_http_status(:unauthorized)

    get "/api/v1/professionals/#{professional.id}", as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
