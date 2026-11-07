module Api
  module V1
    class AppointmentsController < ApplicationController
      before_action :require_member!, only: %i[create reschedule]

      rescue_from BookAppointment::Unavailable, AppointmentPolicy::NotAllowed do |error|
        render json: { error: error.message }, status: :conflict
      end

      # The logged-in person's own sessions, whichever role they have.
      def index
        render json: SessionList.new(current_user).to_h
      end

      def create
        professional = User.professional.find(params.require(:professional_id))
        appointment = BookAppointment.new(member: current_user, professional:, **requested_slot).call

        render json: { appointment: { id: appointment.id } }, status: :created
      end

      def cancel
        appointment = CancelAppointment.new(appointment: own_appointment, user: current_user).call

        render json: { appointment: { id: appointment.id, status: appointment.status } }
      end

      # The same appointment, at its new time.
      def reschedule
        appointment = RescheduleAppointment.new(appointment: own_appointment, **requested_slot).call

        render json: { appointment: { id: appointment.id } }
      end

      private

      # Someone else's session gives the same 404 as one that doesn't exist.
      def own_appointment
        current_user.appointments.find(params[:id])
      end

      # On the professional's clock, as the calendar sends it.
      def requested_slot
        appointment_date, start_at, end_at = params.require(%i[appointment_date start_at end_at])

        { appointment_date:, start_at:, end_at: }
      end
    end
  end
end
