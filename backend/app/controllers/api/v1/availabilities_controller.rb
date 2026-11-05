module Api
  module V1
    class AvailabilitiesController < ApplicationController
      before_action :require_professional!

      def show
        render json: week.to_h
      end

      def update
        errors = week.replace(week_params)

        if errors.empty?
          render json: week.to_h
        else
          render json: { errors: { working_hours: errors } }, status: :unprocessable_content
        end
      end

      private

      # Not params.expect, which rejects an empty list. That's a valid week with no working days.
      def week_params
        params.permit(working_hours: [ :day_of_week, :start_minute, :end_minute ]).fetch(:working_hours)
      end

      def week
        WeeklyAvailability.new(current_user)
      end
    end
  end
end
