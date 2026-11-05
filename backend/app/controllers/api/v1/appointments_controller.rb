module Api
  module V1
    class AppointmentsController < ApplicationController
      before_action :require_member!

      def create
        professional = User.professional.find(params.require(:professional_id))
        appointment_date, start_at, end_at = params.require(%i[appointment_date start_at end_at])
        appointment = BookAppointment.new(member: current_user, professional:, appointment_date:, start_at:, end_at:).call

        render json: { appointment: { id: appointment.id } }, status: :created
      rescue BookAppointment::Unavailable => error
        render json: { error: error.message }, status: :conflict
      end
    end
  end
end
