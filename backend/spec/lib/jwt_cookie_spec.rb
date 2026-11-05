require "rails_helper"

RSpec.describe JwtCookie do
  def call(secure: true, env: {}, headers: {}, &downstream)
    downstream ||= ->(_env) { [ 200, headers, [] ] }
    JwtCookie.new(downstream, secure:).call(Rack::MockRequest.env_for("/", env))
  end

  describe "on the response" do
    let(:token_headers) { { "authorization" => "Bearer abc" } }

    it "moves the token into a Secure cookie when configured to (production)" do
      _status, headers, = call(secure: true, headers: token_headers)

      expect(headers["set-cookie"]).to match(/auth_token=abc/).and match(/secure/i)
    end

    it "omits Secure otherwise, for plain-http local development" do
      _status, headers, = call(secure: false, headers: token_headers)

      expect(headers["set-cookie"]).not_to match(/secure/i)
    end

    it "removes the Authorization header" do
      _status, headers, = call(headers: token_headers)

      expect(headers).not_to have_key("authorization")
    end
  end

  describe "on the request" do
    def authorization_seen_by_app(env: {})
      seen = nil
      call(env:) do |app_env|
        seen = app_env["HTTP_AUTHORIZATION"]
        [ 200, {}, [] ]
      end
      seen
    end

    it "copies the cookie into the Authorization header for the app" do
      expect(authorization_seen_by_app(env: { "HTTP_COOKIE" => "auth_token=abc" })).to eq("Bearer abc")
    end

    it "leaves requests without the cookie alone" do
      expect(authorization_seen_by_app).to be_nil
    end
  end
end
