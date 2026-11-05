module Api
  module V1
    module Auth
      class RegistrationsController < ApplicationController
        skip_before_action :authenticate_user!

        def create
          user = User.new(signup_params)

          if user.save
            # Triggers devise-jwt to issue a token, which JwtCookie moves into the cookie.
            sign_in(user, store: false)
            render json: { user: user_json(user) }, status: :created
          else
            render json: { errors: user.errors.to_hash }, status: :unprocessable_content
          end
        rescue ActiveRecord::RecordNotUnique
          # Two sign-ups with one email can both pass validation; the unique index stops the second.
          render json: { errors: { email: [ "has already been taken" ] } }, status: :unprocessable_content
        end

        private

        def signup_params
          params.expect(user: [ :name, :email, :password, :role, :timezone ])
        end
      end
    end
  end
end
