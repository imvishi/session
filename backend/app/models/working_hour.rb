# A professional's hours for one day of the week, on their own wall clock.
class WorkingHour < ApplicationRecord
  TIME_STEP_MINUTES = 30

  belongs_to :professional, class_name: "User", inverse_of: :working_hours

  validates :day_of_week, numericality: { only_integer: true, in: 0..6 }
  validates :start_minute, :end_minute, numericality: { only_integer: true, in: 0..1439 }
  validate :owner_is_a_professional
  validate :times_are_valid

  def day_name
    Date::DAYNAMES[day_of_week] if errors[:day_of_week].empty?
  end

  private

  def owner_is_a_professional
    errors.add(:professional, "must be a professional") if professional && !professional.professional?
  end

  def step_message
    "must be in #{TIME_STEP_MINUTES}-minute steps"
  end

  def times_are_valid
    return if errors[:start_minute].any? || errors[:end_minute].any?

    errors.add(:start_minute, step_message) if start_minute % TIME_STEP_MINUTES != 0
    errors.add(:end_minute, step_message) if end_minute % TIME_STEP_MINUTES != 0
    errors.add(:end_minute, "must be after the start time") if end_minute <= start_minute
  end
end
