# frozen_string_literal: true

Devise.setup do |config|
  require "devise/orm/active_record"

  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]

  # JSON API with no server-side session: never store the user in a session,
  # and answer failures with a 401 rather than a redirect to a login page.
  config.skip_session_storage = [ :http_auth, :params_auth ]
  config.navigational_formats = []

  # Same error, and similar timing, whether the email exists or not.
  config.paranoid = true

  config.stretches = Rails.env.test? ? 1 : 12
  # bcrypt ignores everything past 72 bytes.
  config.password_length = 8..72
  config.email_regexp = /\A[^@\s]+@[^@\s]+\z/

  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  config.jwt do |jwt|
    # Derived from secret_key_base, so there's no extra secret to manage or to
    # share with anyone cloning the repo. Rotating secret_key_base logs everyone out.
    jwt.secret = Rails.application.key_generator.generate_key("devise-jwt", 64).unpack1("H*")
    # Short, because a stateless token can't be revoked: this is the longest a
    # stolen token keeps working. There's no refresh token, so users log in again after it.
    jwt.expiration_time = 1.hour.to_i
    jwt.dispatch_requests = [
      [ "POST", %r{\A/api/v1/auth/login\z} ],
      [ "POST", %r{\A/api/v1/auth/signup\z} ]
    ]
  end
end
