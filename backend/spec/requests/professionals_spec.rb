require "rails_helper"

RSpec.describe "Professionals", type: :request do
  let(:path) { "/api/v1/professionals" }

  def create_user(name:, role:)
    User.create!(
      name:, role:, email: "#{name.parameterize}@example.com", password: "password123", timezone: "Asia/Singapore"
    )
  end

  def log_in(user)
    post "/api/v1/auth/login", params: { user: { email: user.email, password: "password123" } }, as: :json
  end

  def json
    response.parsed_body
  end

  context "when logged in as a member" do
    let!(:member) { create_user(name: "Sam Member", role: "member").tap { |user| log_in(user) } }

    it "lists only professionals, by name" do
      create_user(name: "Zoe Professional", role: "professional")
      create_user(name: "Alex Professional", role: "professional")
      create_user(name: "Other Member", role: "member")

      get path

      expect(response).to have_http_status(:ok)
      expect(json["professionals"].map { |professional| professional["name"] })
        .to eq([ "Alex Professional", "Zoe Professional" ])
    end

    it "shows only the public fields, never an email or password" do
      professional = create_user(name: "Alex Professional", role: "professional")

      get path

      expect(json["professionals"]).to eq(
        [ { "id" => professional.id, "name" => "Alex Professional", "timezone" => "Asia/Singapore" } ]
      )
      expect(response.body).not_to include("alex-professional@example.com")
    end

    it "includes a professional who hasn't set any hours yet" do
      create_user(name: "New Professional", role: "professional")

      get path

      expect(json["professionals"].size).to eq(1)
    end

    it "returns an empty list when there are no professionals" do
      get path

      expect(response).to have_http_status(:ok)
      expect(json["professionals"]).to eq([])
    end
  end

  it "doesn't let a professional see the list" do
    log_in(create_user(name: "Alex Professional", role: "professional"))

    get path

    expect(response).to have_http_status(:forbidden)
    expect(json["error"]).to eq("Only members can do this.")
  end

  it "requires a login" do
    get path, as: :json

    expect(response).to have_http_status(:unauthorized)
  end
end
