require "rails_helper"

RSpec.describe "Authentication", type: :request do
  let(:signup_path) { "/api/v1/auth/signup" }
  let(:login_path) { "/api/v1/auth/login" }
  let(:logout_path) { "/api/v1/auth/logout" }
  let(:me_path) { "/api/v1/me" }
  let(:cookie_name) { JwtCookie::COOKIE_NAME }

  def signup_params(**overrides)
    {
      name: "Test Member",
      email: "member@example.com",
      password: "password123",
      role: "member",
      timezone: "Asia/Singapore"
    }.merge(overrides)
  end

  def create_user(**overrides)
    User.create!(signup_params(**overrides))
  end

  def login(email: "member@example.com", password: "password123")
    post login_path, params: { user: { email:, password: } }, as: :json
  end

  def set_cookie_header
    Array(response.headers["Set-Cookie"]).join("\n")
  end

  # Bypasses the test client's cookie jar, to replay a specific token.
  def get_me_with_token(token)
    cookies.delete(cookie_name)
    get me_path, headers: { "Cookie" => "#{cookie_name}=#{token}" }
  end

  describe "POST /api/v1/auth/signup" do
    %w[member professional].each do |role|
      it "creates a #{role} and logs them in" do
        email = "#{role}@example.com"
        post signup_path, params: { user: signup_params(role:, email:) }, as: :json

        expect(response).to have_http_status(:created)
        expect(response.parsed_body.dig("user", "role")).to eq(role)

        get me_path
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.dig("user", "email")).to eq(email)
      end
    end

    it "rejects a role other than member or professional" do
      expect { post signup_path, params: { user: signup_params(role: "admin") }, as: :json }
        .not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", "role")).to be_present
      expect(set_cookie_header).not_to include(cookie_name)
    end

    it "rejects an invalid timezone" do
      post signup_path, params: { user: signup_params(timezone: "+08:00") }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", "timezone")).to be_present
    end

    it "rejects a duplicate email in any case" do
      create_user

      post signup_path, params: { user: signup_params(email: "MEMBER@example.com") }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", "email")).to be_present
    end

    it "answers a duplicate that gets past validation (a race) with a 422, not a 500" do
      allow_any_instance_of(User).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)

      post signup_path, params: { user: signup_params }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", "email")).to be_present
    end

    it "ignores fields the client isn't allowed to set" do
      post signup_path,
        params: { user: signup_params(id: 999_999, encrypted_password: "chosen-by-client") },
        as: :json

      expect(response).to have_http_status(:created)
      user = User.find_by!(email: "member@example.com")
      expect(user.id).not_to eq(999_999)
      expect(user.encrypted_password).not_to eq("chosen-by-client")
    end

    it "returns a 400 with no user params" do
      post signup_path, params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "the auth cookie" do
    before do
      create_user
      login
    end

    it "is an HttpOnly, SameSite=Strict session cookie" do
      expect(response).to have_http_status(:ok)
      expect(set_cookie_header).to include("#{cookie_name}=")
      expect(set_cookie_header).to match(/httponly/i).and match(/samesite=strict/i)
      expect(set_cookie_header).not_to match(/expires|max-age/i)
    end

    it "is the only place the token appears, so JavaScript never sees it" do
      expect(response.headers["Authorization"]).to be_nil
      expect(response.body).not_to include(cookies[cookie_name])
    end

    it "comes with a response that has no sensitive fields" do
      expect(response.parsed_body["user"].keys).to contain_exactly("id", "name", "email", "role", "timezone")
    end
  end

  describe "POST /api/v1/auth/login" do
    before { create_user }

    it "accepts an email in any case" do
      login(email: "MEMBER@example.com")

      expect(response).to have_http_status(:ok)
    end

    it "gives a wrong password and an unknown email an identical 401" do
      login(password: "wrong-password")
      expect(response).to have_http_status(:unauthorized)
      expect(set_cookie_header).not_to include(cookie_name)
      wrong_password_body = response.body

      login(email: "nobody@example.com")
      expect(response).to have_http_status(:unauthorized)
      expect(response.body).to eq(wrong_password_body)
    end

    it "returns a 401 with no params" do
      post login_path, params: {}, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    context "when already logged in as someone else" do
      before do
        create_user(email: "other@example.com")
        login
      end

      it "doesn't let a valid cookie stand in for a wrong password" do
        login(email: "other@example.com", password: "wrong-password")

        expect(response).to have_http_status(:unauthorized)
      end

      it "switches to the new user on a correct password" do
        login(email: "other@example.com")
        expect(response).to have_http_status(:ok)

        get me_path
        expect(response.parsed_body.dig("user", "email")).to eq("other@example.com")
      end
    end
  end

  describe "GET /api/v1/me" do
    it "requires a login, and answers with JSON rather than a redirect" do
      get me_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to be_present
    end

    it "identifies the user from the token, never from client-supplied params" do
      create_user
      other = create_user(email: "other@example.com")
      login

      get me_path, params: { id: other.id, user_id: other.id }

      expect(response.parsed_body.dig("user", "email")).to eq("member@example.com")
    end

    it "rejects a tampered token" do
      create_user
      login

      get_me_with_token("#{cookies[cookie_name]}tampered")

      expect(response).to have_http_status(:unauthorized)
    end

    it "accepts a token until it expires after 1 hour" do
      create_user
      login

      travel 59.minutes
      get me_path
      expect(response).to have_http_status(:ok)

      travel 2.minutes
      get me_path
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "clears the cookie, which logs the browser out" do
      create_user
      login

      delete logout_path

      expect(response).to have_http_status(:no_content)
      expect(set_cookie_header).to match(/#{cookie_name}=;/).and match(/httponly/i)

      get me_path
      expect(response).to have_http_status(:unauthorized)
    end

    # Documents the accepted trade-off of stateless JWTs, rather than desired behaviour.
    it "leaves a copy of the token working until it expires" do
      create_user
      login
      token = cookies[cookie_name]

      delete logout_path

      get_me_with_token(token)
      expect(response).to have_http_status(:ok)

      travel 1.hour + 1.minute
      get_me_with_token(token)
      expect(response).to have_http_status(:unauthorized)
    end

    it "succeeds without a cookie" do
      delete logout_path

      expect(response).to have_http_status(:no_content)
    end

    it "still clears an expired token's cookie" do
      create_user
      login

      travel 2.hours
      delete logout_path

      expect(response).to have_http_status(:no_content)
      expect(set_cookie_header).to match(/#{cookie_name}=;/)
    end

    it "still clears a garbage token's cookie" do
      delete logout_path, headers: { "Cookie" => "#{cookie_name}=garbage" }

      expect(response).to have_http_status(:no_content)
      expect(set_cookie_header).to match(/#{cookie_name}=;/)
    end
  end

  describe "routes" do
    it "doesn't expose Devise's account management routes" do
      paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

      expect(paths.grep(%r{password|users|cancel|edit})).to be_empty
    end
  end

  describe "CORS" do
    def preflight(origin)
      options login_path, headers: { "Origin" => origin, "Access-Control-Request-Method" => "POST" }
    end

    it "allows the frontend origin with credentials" do
      preflight("http://localhost:5173")

      expect(response.headers["Access-Control-Allow-Origin"]).to eq("http://localhost:5173")
      expect(response.headers["Access-Control-Allow-Credentials"]).to eq("true")
    end

    it "doesn't allow other origins" do
      preflight("https://evil.example.com")

      expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    end
  end
end
