module Api
  module V1
    # A person's delivered reminders, which are their in-app notifications.
    class NotificationsController < ApplicationController
      LIMIT = 50

      def index
        notifications = current_user.reminders.delivered.order(delivered_at: :desc, id: :desc).limit(LIMIT)
        zone = ActiveSupport::TimeZone[current_user.timezone]

        render json: {
          unread_count: current_user.reminders.unread.count,
          notifications: notifications.map do |reminder|
            {
              id: reminder.id,
              message: reminder.message,
              read: reminder.read_at.present?,
              delivered_at: reminder.delivered_at.iso8601(6),
              delivered_label: reminder.delivered_at.in_time_zone(zone).strftime("%-d %b, %-l:%M %p")
            }
          end
        }
      end

      # Marks as read only what was delivered up to delivered_until, the newest delivered_at the client
      # was shown, so a reminder that arrives after the list was loaded stays unread.
      def read_all
        delivered_until = Time.iso8601(params.require(:delivered_until).to_s)
        current_user.reminders.unread.where(delivered_at: ..delivered_until).update_all(read_at: Time.current)

        head :no_content
      rescue ActionController::ParameterMissing, ArgumentError
        render json: { error: "Reload your notifications and try again." }, status: :bad_request
      end
    end
  end
end
