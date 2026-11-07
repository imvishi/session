class Appointment < ApplicationRecord
  INVALID_TIME = "This time isn't valid for you or the professional. Please choose another."

  belongs_to :member, class_name: "User", inverse_of: :member_appointments
  belongs_to :professional, class_name: "User", inverse_of: :professional_appointments

  enum :status, { booked: 0, cancelled: 1 }, validate: true

  validates :appointment_date, :start_time, :end_time, presence: true
  validates :timezone, iana_timezone: true
  validate :end_time_after_start_time
  validate :member_is_a_member
  validate :professional_is_a_professional
  validate :time_is_valid_for_both_people, if: :time_changing?

  # The real start and end of each row, converted using its own timezone.
  STARTS_AT_SQL = "((appointments.appointment_date + appointments.start_time) AT TIME ZONE appointments.timezone)"
  ENDS_AT_SQL = "((appointments.appointment_date + appointments.end_time) AT TIME ZONE appointments.timezone)"

  # from, to and now are real moments.
  scope :overlapping, ->(from, to) { where("#{STARTS_AT_SQL} < ? AND #{ENDS_AT_SQL} > ?", to, from) }
  # A session that has started but not ended is still upcoming. Soonest first.
  scope :upcoming, ->(now) { where("#{ENDS_AT_SQL} > ?", now).order(Arel.sql(STARTS_AT_SQL), :id) }
  # Most recent first.
  scope :past, ->(now) { where("#{ENDS_AT_SQL} <= ?", now).order(Arel.sql("#{STARTS_AT_SQL} DESC"), id: :desc) }

  def starts_at_utc
    time_at_utc(start_time)
  end
  
  def ends_at_utc
    time_at_utc(end_time)
  end

  private

  def time_at_utc(time)
    ActiveSupport::TimeZone[timezone].local(*clock_reading(time)).utc
  end

  def clock_reading(time)
    [ appointment_date.year, appointment_date.month, appointment_date.day, time.hour, time.min, time.sec ]
  end

  def time_changing?
    will_save_change_to_appointment_date? || will_save_change_to_start_time? ||
      will_save_change_to_end_time? || will_save_change_to_timezone?
  end

  def time_is_valid_for_both_people
    return if errors.any?

    professional_clock = [ start_time, end_time ].map { |time| Time.utc(*clock_reading(time)) }
    member_clock = [ starts_at_utc, ends_at_utc ].map { |time| time.in_time_zone(member.timezone) }

    return if clear_on_clock?(timezone, professional_clock) && clear_on_clock?(member.timezone, member_clock)

    errors.add(:base, INVALID_TIME)
  end

  # A clock time is in no period if the clocks skip it, and in two if they repeat it. Both ends in
  # the same single period means each has one meaning and the clocks don't change during the session.
  def clear_on_clock?(zone_name, clock_times)
    start_periods, end_periods = clock_times.map { |time| ActiveSupport::TimeZone[zone_name].periods_for_local(time) }

    start_periods.one? && start_periods == end_periods
  end

  def end_time_after_start_time
    return unless start_time && end_time && end_time <= start_time

    errors.add(:end_time, "must be after the start time")
  end

  def member_is_a_member
    errors.add(:member, "must be a member") if member && !member.member?
  end

  def professional_is_a_professional
    errors.add(:professional, "must be a professional") if professional && !professional.professional?
  end
end
