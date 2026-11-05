require "rails_helper"

RSpec.describe "Availability", type: :request do
  let(:path) { "/api/v1/availability" }
  let(:monday) { { day_of_week: 1, start_minute: 540, end_minute: 1020 } }
  let(:tuesday) { { day_of_week: 2, start_minute: 600, end_minute: 750 } }

  def create_user(role: "professional", email: "professional@example.com")
    User.create!(name: "Test User", email:, password: "password123", role:, timezone: "Asia/Singapore")
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def save_week(*rows)
    put path, params: { working_hours: rows }, as: :json
  end

  def json
    response.parsed_body
  end

  # The saved days, reduced to what these tests compare.
  def working_days
    json["days"].select { |day| day["working"] }
                .map { |day| day.slice("day_of_week", "start_minute", "end_minute", "slot_count") }
  end

  def expected(row, slot_count)
    row.merge(slot_count:).stringify_keys
  end

  context "when logged in as a professional" do
    let!(:professional) { create_user.tap { |user| log_in(user) } }

    it "returns a full week with nothing saved, plus everything the screen needs" do
      get path

      expect(response).to have_http_status(:ok)
      expect(json).to include(
        "timezone_label" => "Asia/Singapore (GMT+08:00)",
        "session_minutes" => WeeklyAvailability::SESSION_MINUTES,
        "slot_interval_minutes" => WeeklyAvailability::SLOT_INTERVAL_MINUTES,
        "break_minutes" => 10
      )
      expect(json["time_options"].first).to eq("value" => 0, "label" => "00:00")
      expect(json["days"].size).to eq(7)
      expect(working_days).to be_empty
    end

    it "saves a week and returns it with each day's slot count" do
      save_week(tuesday, monday)

      expect(response).to have_http_status(:ok)
      expect(working_days).to eq([ expected(monday, 8), expected(tuesday, 2) ])
    end

    it "ignores a slot count sent by the client" do
      save_week(monday.merge(slot_count: 99))

      expect(working_days).to eq([ expected(monday, 8) ])
    end

    it "returns the saved week on a later request" do
      save_week(monday)
      get path

      expect(working_days).to eq([ expected(monday, 8) ])
    end

    it "treats a day left out as a day off" do
      save_week(monday, tuesday)
      save_week(tuesday)

      expect(working_days).to eq([ expected(tuesday, 2) ])
    end

    it "clears the week when given an empty list" do
      save_week(monday)
      save_week

      expect(response).to have_http_status(:ok)
      expect(working_days).to be_empty
    end

    it "rejects a request with no working_hours, rather than clearing the week" do
      save_week(monday)
      put path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(professional.working_hours.count).to eq(1)
    end

    it "names the day in validation errors, and keeps the old week" do
      save_week(monday)
      save_week(tuesday.merge(end_minute: 630))

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", "working_hours")).to eq(
        [ "Tuesday: End time must be at least 50 minutes after the start time" ]
      )
      expect(professional.working_hours.pluck(:day_of_week)).to eq([ 1 ])
    end

    it "rejects a time that isn't one of the offered options" do
      save_week(monday.merge(start_minute: 555))

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", "working_hours")).to eq([ "Monday: Start time must be in 30-minute steps" ])
    end

    it "ignores times sent in the old HH:MM format" do
      save_week(day_of_week: 1, start_time: "09:00", end_time: "17:00")

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("errors", "working_hours")).to include("Monday: Start time is not a number")
    end

    it "ignores a professional_id sent by the client" do
      other = create_user(email: "other@example.com")

      put path, params: { professional_id: other.id, working_hours: [ monday ] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(other.working_hours.count).to eq(0)
      expect(professional.working_hours.count).to eq(1)
    end

    it "doesn't show another professional's hours" do
      other = create_user(email: "other@example.com")
      other.working_hours.create!(monday)

      get path

      expect(working_days).to be_empty
    end
  end

  context "when logged in as a member" do
    before { log_in(create_user(role: "member", email: "member@example.com")) }

    it "can't read availability" do
      get path

      expect(response).to have_http_status(:forbidden)
      expect(json["error"]).to eq("Only professionals can do this.")
    end

    it "can't save availability" do
      save_week(monday)

      expect(response).to have_http_status(:forbidden)
      expect(WorkingHour.count).to eq(0)
    end
  end

  context "when logged out" do
    it "requires a login to read" do
      get path, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it "requires a login to save" do
      save_week(monday)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
