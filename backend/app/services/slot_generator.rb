class SlotGenerator
  SESSION_MINUTES = 50
  SLOT_INTERVAL_MINUTES = 60
  APPOINTMENT_WINDOW = 4.weeks

  Slot = Data.define(:starts_at, :ends_at) do
    # The date and times on that timezone's clock, as an appointment stores them.
    def local_attributes(timezone)
      local_start = starts_at.in_time_zone(timezone)

      {
        timezone:,
        appointment_date: local_start.to_date,
        start_time: local_start.strftime("%T"),
        end_time: ends_at.in_time_zone(timezone).strftime("%T")
      }
    end
  end

  # On an ordinary day. A day when the clocks change can have a different number.
  def self.slots_per_day(hours)
    hours.start_minute.step(hours.end_minute - SESSION_MINUTES, SLOT_INTERVAL_MINUTES).count
  end

  def initialize(professional)
    @zone = ActiveSupport::TimeZone[professional.timezone]
    @hours_by_day = professional.working_hours.index_by(&:day_of_week)
  end

  # Slots starting in from...to, in UTC and in time order.
  def slots(from:, to:)
    # The professional's own dates decide which day's hours apply.
    dates = from.in_time_zone(@zone).to_date..to.in_time_zone(@zone).to_date

    dates.flat_map { |date| slots_on(date) }
         .select { |slot| slot.starts_at >= from && slot.starts_at < to }
  end

  private

  # Stepping in real time, not wall-clock time, keeps slots from overlapping when the clocks change.
  def slots_on(date)
    hours = @hours_by_day[date.wday]
    return [] unless hours

    first_start = local_time(date, hours.start_minute)
    last_start = end_of_hours(date, hours.end_minute) - SESSION_MINUTES.minutes

    first_start.to_i.step(last_start.to_i, SLOT_INTERVAL_MINUTES.minutes.to_i).filter_map do |seconds|
      starts_at = Time.at(seconds).utc
      ends_at = starts_at + SESSION_MINUTES.minutes
      Slot.new(starts_at:, ends_at:) if storable?(starts_at) && storable?(ends_at)
    end
  end

  def storable?(moment)
    local = moment.in_time_zone(@zone)

    @zone.local(local.year, local.month, local.day, local.hour, local.min, local.sec) == moment
  end

  # An end time in the missing hour means the moment the clocks jumped.
  def end_of_hours(date, minute)
    time = local_time(date, minute)
    exists = (time.hour * 60) + time.min == minute

    exists ? time : time.period.starts_at.to_time
  end

  def local_time(date, minute)
    @zone.local(date.year, date.month, date.day, *minute.divmod(60))
  end
end
