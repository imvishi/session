require "rails_helper"

RSpec.describe "Cancelling and rescheduling", type: :request do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:tuesday_nine) { Time.utc(2026, 11, 10, 1, 0) } # 09:00 in Singapore
  let!(:appointment) { book(member, professional, Time.utc(2026, 11, 9, 1, 0)) }

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    (1..2).each { |day| set_hours(professional, day, 540, 720) }
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def json
    response.parsed_body
  end

  def cancel(id = appointment.id)
    post "/api/v1/appointments/#{id}/cancel", as: :json
  end

  def reschedule(id = appointment.id, to: tuesday_nine)
    post "/api/v1/appointments/#{id}/reschedule", params: slot_params(to, professional), as: :json
  end

  describe "as a member" do
    before { log_in(member) }

    it "cancels a session" do
      cancel

      expect(response).to have_http_status(:ok)
      expect(json["appointment"]).to eq("id" => appointment.id, "status" => "cancelled")
    end

    it "explains why a session within 24 hours can't be cancelled or rescheduled" do
      travel_to Time.utc(2026, 11, 8, 2, 0)
      log_in(member) # The earlier login has expired by now.

      cancel
      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(AppointmentPolicy::TOO_LATE)

      reschedule
      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(AppointmentPolicy::TOO_LATE)
      expect(appointment.reload).to be_booked
    end

    it "reschedules a session, which keeps its id" do
      reschedule

      expect(response).to have_http_status(:ok)
      expect(json["appointment"]).to eq("id" => appointment.id)
      expect(appointment.reload).to have_attributes(status: "booked", starts_at_utc: tuesday_nine)
    end

    it "explains when the new time is taken, and keeps the session" do
      book(create_person("Other Member", role: "member"), professional, tuesday_nine)

      reschedule
      expect(response).to have_http_status(:conflict)
      expect(json["error"]).to eq(BookAppointment::SLOT_TAKEN)
      expect(appointment.reload).to be_booked
    end

    it "needs the new time" do
      post "/api/v1/appointments/#{appointment.id}/reschedule", params: { appointment_date: "2026-11-10" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "can't change someone else's session, which looks like it doesn't exist" do
      other = book(create_person("Other Member", role: "member"), professional, tuesday_nine)

      cancel(other.id)
      expect(response).to have_http_status(:not_found)

      reschedule(other.id, to: Time.utc(2026, 11, 10, 2, 0))
      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_booked
    end
  end

  describe "as a professional" do
    before { log_in(professional) }

    it "cancels a session within 24 hours" do
      travel_to Time.utc(2026, 11, 9, 0, 30)
      log_in(professional) # The earlier login has expired by now.

      cancel
      expect(response).to have_http_status(:ok)
      expect(appointment.reload).to be_cancelled
    end

    it "can't reschedule" do
      reschedule

      expect(response).to have_http_status(:forbidden)
    end

    it "can't cancel another professional's session" do
      log_in(create_person("Alex Professional", role: "professional"))

      cancel
      expect(response).to have_http_status(:not_found)
    end
  end

  it "requires a login" do
    cancel

    expect(response).to have_http_status(:unauthorized)
  end
end
