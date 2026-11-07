require "rails_helper"

RSpec.describe "Notifications", type: :request do
  include AppointmentHelpers

  let(:member) { create_person("Sam Member", role: "member", timezone: "Asia/Kolkata") }
  let(:professional) { create_person("Pat Professional", role: "professional") }
  let(:starts_at) { Time.utc(2026, 11, 9, 1, 0) }

  before do
    travel_to Time.utc(2026, 11, 5, 0, 0)
    appointment = book(member, professional, starts_at)
    ScheduleReminders.new(appointment).call
    appointment.reminders.each { |reminder| DeliverReminder.new(reminder.id).call(now: reminder.remind_at) }
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def json
    response.parsed_body
  end

  it "lists a person's delivered reminders, newest first, on their own clock" do
    log_in(member)
    get "/api/v1/notifications"

    expect(response).to have_http_status(:ok)
    expect(json["unread_count"]).to eq(2)
    expect(json["notifications"].map { |notification| notification.slice("read", "delivered_label") }).to eq([
      { "read" => false, "delivered_label" => "9 Nov, 5:30 AM" },
      { "read" => false, "delivered_label" => "8 Nov, 6:30 AM" }
    ])
    expect(json["notifications"].first["message"]).to start_with("Your session with Pat Professional starts in 1 hour")
  end

  it "doesn't include reminders that haven't been delivered, or anyone else's" do
    other = create_person("Other Member", role: "member")
    ScheduleReminders.new(book(other, professional, starts_at + 1.day)).call
    log_in(other)
    get "/api/v1/notifications"

    expect(json).to eq("unread_count" => 0, "notifications" => [])
  end

  def newest_delivered_at
    get "/api/v1/notifications"
    json["notifications"].first["delivered_at"]
  end

  it "marks all as read, for that person only" do
    log_in(member)
    post "/api/v1/notifications/read_all", params: { delivered_until: newest_delivered_at }, as: :json

    expect(response).to have_http_status(:no_content)
    get "/api/v1/notifications"
    expect(json["unread_count"]).to eq(0)
    expect(json["notifications"].pluck("read")).to all(be(true))
    expect(professional.reminders.unread.count).to eq(2)
  end

  it "leaves a reminder delivered after the list was loaded unread" do
    log_in(member)
    seen = newest_delivered_at
    newer = book(member, professional, starts_at + 2.days)
    ScheduleReminders.new(newer).call
    arrived = newer.reminders.find_by!(user: member, minutes_before: 1440)
    DeliverReminder.new(arrived.id).call(now: arrived.remind_at)

    post "/api/v1/notifications/read_all", params: { delivered_until: seen }, as: :json

    expect(member.reminders.unread).to eq([ arrived ])
  end

  it "refuses to mark all as read without knowing what was seen" do
    log_in(member)
    post "/api/v1/notifications/read_all", as: :json

    expect(response).to have_http_status(:bad_request)
    expect(member.reminders.unread.count).to eq(2)
  end

  it "requires a login" do
    get "/api/v1/notifications", as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
