class WeeklyAvailability
  SESSION_MINUTES = 50
  SLOT_INTERVAL_MINUTES = 60
  DISPLAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ].freeze
  DEFAULT_START_MINUTE = 9 * 60
  DEFAULT_END_MINUTE = 17 * 60

  def initialize(professional)
    @professional = professional
  end

  def replace(rows)
    records = rows.map { |row| WorkingHour.new(row.to_h.merge(professional: @professional)) }
    errors = validation_errors(records)
    return errors if errors.any?

    # The lock stops two simultaneous saves from mixing their weeks together.
    @professional.with_lock do
      @professional.working_hours.delete_all
      records.each(&:save!)
    end

    []
  end

  def to_h
    {
      timezone_label:,
      session_minutes: SESSION_MINUTES,
      slot_interval_minutes: SLOT_INTERVAL_MINUTES,
      break_minutes: SLOT_INTERVAL_MINUTES - SESSION_MINUTES,
      time_options:,
      days:
    }
  end

  private

  # The value is what the API stores and accepts, and the label is what people see.
  def time_options
    (0...(24 * 60)).step(WorkingHour::TIME_STEP_MINUTES).map do |minutes|
      { value: minutes, label: format("%02d:%02d", *minutes.divmod(60)) }
    end
  end

  def validation_errors(records)
    records.flat_map { |record| row_errors(record) } + duplicate_day_errors(records)
  end

  def row_errors(record)
    messages = record.valid? ? session_length_errors(record) : record.errors.full_messages

    messages.map { |message| [ record.day_name, message ].compact.join(": ") }
  end

  def session_length_errors(record)
    return [] if record.end_minute - record.start_minute >= SESSION_MINUTES

    [ "End time must be at least #{SESSION_MINUTES} minutes after the start time" ]
  end

  # Runs after validation, so an invalid day isn't reported as a duplicate as well.
  def duplicate_day_errors(records)
    records.select { |record| record.errors[:day_of_week].empty? }
           .group_by(&:day_of_week)
           .select { |_day, same_day| same_day.size > 1 }
           .map { |day, _same_day| "#{Date::DAYNAMES[day]}: Day is listed more than once" }
  end

  # The offset is today's, so it changes with daylight saving.
  def timezone_label
    offset = ActiveSupport::TimeZone[@professional.timezone].now.formatted_offset
    "#{@professional.timezone} (GMT#{offset})"
  end

  def slot_count(hours)
    hours.start_minute.step(hours.end_minute - SESSION_MINUTES, SLOT_INTERVAL_MINUTES).count
  end

  def days
    hours_by_day = @professional.working_hours.reload.index_by(&:day_of_week)

    DISPLAY_ORDER.map do |day_of_week|
      hours = hours_by_day[day_of_week]

      {
        day_of_week:,
        name: Date::DAYNAMES[day_of_week],
        working: hours.present?,
        start_minute: hours&.start_minute || DEFAULT_START_MINUTE,
        end_minute: hours&.end_minute || DEFAULT_END_MINUTE,
        slot_count: hours && slot_count(hours)
      }
    end
  end
end
