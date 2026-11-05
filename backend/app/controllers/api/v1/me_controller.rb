module Api
  module V1
    class MeController < ApplicationController
      def show
        render json: { user: user_json(current_user) }
      end
    end
  end
end
