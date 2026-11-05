module Api
  module V1
    module Auth
      class SessionsController < Devise::SessionsController
        # Devise's versions of these redirect, which makes no sense for a JSON API.
        skip_before_action :require_no_authentication, :verify_signed_out_user

        def create
          # A cookie can't satisfy this: devise-jwt's strategy skips its dispatch paths,
          # so only the password check runs here.
          user = warden.authenticate!(auth_options)
          render json: { user: user_json(user) }
        end

        # JWTs are stateless, so logout only clears the cookie. The token itself stays
        # valid until it expires. Always succeeds, whatever state the cookie is in.
        def destroy
          request.env[JwtCookie::CLEAR_COOKIE_ENV_KEY] = true
          head :no_content
        end
      end
    end
  end
end
