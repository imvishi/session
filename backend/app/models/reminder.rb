# A reminder for one person about one session. Once delivered, it is an in-app notification.
class Reminder < ApplicationRecord
  # When reminders are sent, before each session. Changing this only affects reminders scheduled afterwards.
  LEAD_TIMES = [ 24.hours, 1.hour ].freeze

  belongs_to :appointment
  belongs_to :user

  scope :pending, -> { where(delivered_at: nil) }
  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :unread, -> { delivered.where(read_at: nil) }

  validates :remind_at, presence: true
  validates :minutes_before, numericality: { only_integer: true, greater_than: 0 }

  # For a message: "24 hours", "1 hour", "30 minutes", "1 hour 30 minutes".
  def self.duration_label(total_minutes)
    hours, minutes = total_minutes.divmod(60)

    [ ("#{hours} #{"hour".pluralize(hours)}" if hours.positive?),
      ("#{minutes} #{"minute".pluralize(minutes)}" if minutes.positive?) ].compact.join(" ")
  end

  def lead_time_label
    self.class.duration_label(minutes_before)
  end
end
