# Keeps the JWT in an HttpOnly cookie so that browser JavaScript can never read it.
#
# devise-jwt only understands the Authorization header, so this middleware sits
# outside it and translates in both directions:
#   request:  cookie -> Authorization header
#   response: Authorization header -> cookie (the header itself is removed)
class JwtCookie
  COOKIE_NAME = "auth_token"
  CLEAR_COOKIE_ENV_KEY = "jwt_cookie.clear"

  def initialize(app, secure:)
    @app = app
    @secure = secure
  end

  def call(env)
    token = Rack::Request.new(env).cookies[COOKIE_NAME]
    env["HTTP_AUTHORIZATION"] ||= "Bearer #{token}" if token.present?

    status, headers, body = @app.call(env)

    # Header names are lowercase under Rack 3, but not every response uses Rack::Headers.
    issued = headers.delete("authorization") || headers.delete("Authorization")

    if env[CLEAR_COOKIE_ENV_KEY]
      Rack::Utils.delete_cookie_header!(headers, COOKIE_NAME, cookie_attributes)
    elsif issued
      Rack::Utils.set_cookie_header!(
        headers, COOKIE_NAME, cookie_attributes.merge(value: issued.delete_prefix("Bearer "))
      )
    end

    [ status, headers, body ]
  end

  private

  # No expires/max-age: this is a browser session cookie. The JWT inside it
  # still has its own expiry, which the server enforces.
  def cookie_attributes
    { path: "/", httponly: true, secure: @secure, same_site: :strict }
  end
end
