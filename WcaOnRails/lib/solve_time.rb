# frozen_string_literal: true

class SolveTime
  include ActiveModel::Model
  include Comparable

  EMPTY_STRING = ''
  CLOCK_FORMAT = "%d:%02d:%02d.%02d"
  DOT_STRING = "."
  ZERO_STRING = "0"
  DNF_STRING = "DNF"
  DNS_STRING = "DNS"
  QUESTION_STRING = "?:??:??"

  def initialize(event_id, field, wca_value)
    @event = Event.c_find!(event_id)
    @field = field
    self.wca_value = wca_value
  end

  attr_reader :wca_value, :time_centiseconds, :move_count
  def wca_value=(wca_value)
    @wca_value = wca_value
    @move_count = nil
    @attempted = nil
    @solved = nil
    @time_centiseconds = nil

    if @event.fewest_moves?
      # The average field for 333fm is pretty weird. It's the sum
      # of the solves, multiplied by 100.
      # Otherwise, wca_value is simply the number of moves.
      @move_count = @field == :average ? (wca_value / 100.0) : wca_value
    elsif @event.multiple_blindfolded?
      mb_value = wca_value
      # Extract wca_value parts.
      old = mb_value / 1_000_000_000 != 0
      if old
        time_seconds = mb_value % 100_000
        mb_value /= 100_000
        @attempted = mb_value % 100
        mb_value /= 100
        @solved = 99 - mb_value % 100
      else
        missed = mb_value % 100
        mb_value /= 100
        time_seconds = mb_value % 100_000
        mb_value /= 100_000
        difference = 99 - (mb_value % 100)
        @solved = difference + missed
        @attempted = @solved + missed
      end

      @time_centiseconds = time_seconds == 99_999 ? nil : time_seconds * 100
    else
      @time_centiseconds = wca_value
    end
  end

  def recompute_wca_value
    if @event.fewest_moves?
      @wca_value = @move_count
    elsif @event.multiple_blindfolded?
      missed = @attempted - @solved
      dd = 99 - (@solved - missed)
      ttttt = time_centiseconds / 100

      if @event.id == "333mbf"
        mm = missed
        @wca_value = (dd * 1e7 + ttttt * 1e2 + mm).to_i
      elsif @event.id == "333mbo"
        ss = @solved
        aa = @attempted
        @wca_value = (1 * 1e8 + ss * 1e7 + aa * 1e5 + ttttt).to_i
      else
        raise
      end
    else
      @wca_value = time_centiseconds
    end
  end

  def time_centiseconds=(time_centiseconds)
    raise "time out of range" unless 0 <= time_centiseconds && time_centiseconds <= 99_999 * 100
    @time_centiseconds = time_centiseconds
    recompute_wca_value
  end

  attr_reader :solved, :attempted

  def missed
    self.attempted - self.solved
  end

  def points
    self.solved - self.missed
  end

  def solved=(solved)
    raise "solved out of range" unless (0...100).cover?(solved)
    @solved = solved
    recompute_wca_value
  end

  def attempted=(attempted)
    raise "attempted out of range" unless (0...100).cover?(attempted)
    @attempted = attempted
    recompute_wca_value
  end

  def dn?
    dnf? || dns?
  end

  def dns?
    wca_value == DNS_VALUE
  end

  def dnf?
    wca_value == DNF_VALUE
  end

  def skipped?
    wca_value == SKIPPED_VALUE
  end

  def unskipped?
    !skipped?
  end

  def complete?
    !dn? && unskipped?
  end

  def incomplete?
    !complete?
  end

  def time_seconds
    time_centiseconds / 100.0
  end

  def time_minutes
    time_seconds / 60.0
  end

  protected def to_orderable
    [
      skipped? ? 1 : 0,
      dns? ? 1 : 0,
      dnf? ? 1 : 0,
      wca_value,
    ]
  end

  def <=>(other)
    to_orderable <=> other.to_orderable
  end

  def self.multibld_attempt_to_points(attempt_result)
    SolveTime.new("333mbf", :best, attempt_result).points
  end

  def self.centiseconds_to_clock_format(centiseconds)
    hours = centiseconds / 360_000
    minutes = (centiseconds % 360_000) / 6000
    seconds = (centiseconds % 6000) / 100
    centis = centiseconds % 100

    clock_format = format(CLOCK_FORMAT, hours, minutes, seconds, centis).sub(/^[0:]*/, EMPTY_STRING)
    if clock_format.start_with? DOT_STRING
      clock_format = ZERO_STRING + clock_format
    end
    clock_format
  end

  def clock_format
    if dns?
      return DNS_STRING
    elsif dnf?
      return DNF_STRING
    elsif skipped?
      return EMPTY_STRING
    end

    if @event.fewest_moves?
      format_str = (@field == :average ? "%.2f" : "%.0f")
      format_str % @move_count
    elsif @event.multiple_blindfolded?
      # Build time string.
      if time_centiseconds.nil?
        result = QUESTION_STRING
      else
        result = EMPTY_STRING
        time_seconds = time_centiseconds / 100
        # show 2/2 0:XX instead of 2/2 XX
        if time_seconds < 60
          result = "0:#{time_seconds}"
        else
          while time_seconds >= 60
            result = format(":%02d#{result}", time_seconds % 60)
            time_seconds /= 60
          end
          result = "#{time_seconds}#{result}"
        end
      end

      "#{@solved}/#{@attempted} #{result}"
    else
      SolveTime.centiseconds_to_clock_format(time_centiseconds)
    end
  end

  private def units
    if incomplete?
      ""
    elsif @event.timed_event?
      time_minutes >= 1 ? "" : " seconds"
    elsif @event.fewest_moves?
      " moves"
    elsif @event.multiple_blindfolded?
      ""
    else
      raise "Unrecognized event type #{@event.id}"
    end
  end

  def clock_format_with_units
    "#{clock_format}#{units}"
  end

  validate :wca_value_valid
  def wca_value_valid
    unless wca_value >= -2
      errors.add(:base, "invalid")
    end
  end

  # Enforce https://www.worldcubeassociation.org/regulations/#H1b.
  validate :multiblind_time_limit
  def multiblind_time_limit
    return unless @event.id == "333mbf"

    time_limit_minutes = [60, @attempted * 10].min
    if time_minutes > time_limit_minutes
      errors.add(:base, "should be less than or equal to #{time_limit_minutes} minutes")
    end
  end

  validate :times_over_10_minutes_must_be_rounded
  def times_over_10_minutes_must_be_rounded
    if (@event.timed_event? || @event.multiple_blindfolded?) && time_minutes > 10 && time_centiseconds % 100 > 0
      errors.add(:base, "times over 10 minutes should be rounded")
    end
  end

  DNF_VALUE = -1
  DNF = SolveTime.new('333', nil, DNF_VALUE)
  DNS_VALUE = -2
  DNS = SolveTime.new('333', nil, DNS_VALUE)
  SKIPPED_VALUE = 0
  SKIPPED = SolveTime.new('333', nil, SKIPPED_VALUE)
end
