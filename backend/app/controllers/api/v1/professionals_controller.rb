module Api
  module V1
    class ProfessionalsController < ApplicationController
      before_action :require_member!

      def show
        professional = User.professional.find(params[:id])

        render json: ProfessionalCalendar.new(professional:, member: current_user).to_h
      end

      def index
        professionals = User.professional.order(:name, :id)

        # An explicit list, so a member never sees a professional's email.
        render json: { professionals: professionals.map { |user| user.slice(:id, :name, :timezone) } }
      end
    end
  end
end
