class RubyFit::Validations

  def self.validate_message(message_type, data, raw_data)
    if message_type == :lap
        data, modified = self.lap(data)
    elsif message_type == :activity
      data, modified = self.activity(data)
    elsif message_type == :session
      data, modified = self.session(data)
    end
    [data, modified]
  end


  def self.lap(lap)
    raw_lap = nil
    modified = false
    if lap[:timestamp].nil? || lap[:timestamp] == 0 || lap[:timestamp].to_s == "1989-12-31 00:00:00 UTC"
      if !lap[:start_time].nil? && !lap[:tot_elapsed_time_sec].nil?
        lap[:timestamp] = lap[:start_time] + lap[:tot_elapsed_time_sec]

        definition = RubyFit::MessageWriter.definition_message(:lap, 0)
        data = RubyFit::MessageWriter.data_message(:lap, 0, lap)
        raw_lap = definition + data
      else
        # Lap is totally invalid, so we set it to nil
        raw_lap = nil
      end
      modified = true
    end
    [raw_lap, modified]
  end

  def self.build_lap(parsed_data)
    lap = {}
    records = parsed_data[:records]
    events = parsed_data[:events]
    sport = parsed_data[:sport] || {}

    # calculates lap values and sets them in the lap hash if there is no lap
    lap[:timestamp] = records.first[:timestamp]
    lap[:start_time] = records.first[:timestamp]
    lap[:start_lat_deg] = records.first[:lat_deg]
    lap[:start_lon_deg] = records.first[:lon_deg]
    lap[:tot_elapsed_time_sec] = records.last[:timestamp].to_i - records.first[:timestamp].to_i
    lap[:tot_timer_time_sec] = RubyFit::Helpers.calculate_timer_time(events)
    lap[:tot_dist_m] = records.last[:dist_m]
    lap[:event_code] = 9
    lap[:event_type_code] = 1
    lap[:sport_code] = sport[:sport_code] || 2
    lap[:sub_sport_code] = sport[:sub_sport_code] || 0

    definition = RubyFit::MessageWriter.definition_message(:lap, 0)
    data = RubyFit::MessageWriter.data_message(:lap, 0, lap)
    raw_lap = definition + data
    modified = true

    [raw_lap, modified]
  end

  def self.build_session(parsed_data)
    session = {}

    laps = parsed_data[:laps]
    return if laps.empty?
    sport = parsed_data[:sport] || {}

    session[:timestamp] = laps.last[:timestamp]
    session[:start_time] = laps.first[:start_time]
    session[:tot_elapsed_time_sec] = laps.sum { |lap| lap[:tot_elapsed_time_sec] }
    session[:tot_timer_time_sec] = laps.sum { |lap| lap[:tot_timer_time_sec] }
    session[:tot_dist_m] = laps.sum { |lap| lap[:tot_dist_m] }
    session[:event_code] = 8
    session[:event_type_code] = 0
    session[:sport_code] = sport[:sport_code] || 2
    session[:sub_sport_code] = sport[:sub_sport_code] || 0

    definition = RubyFit::MessageWriter.definition_message(:session, 0)
    data = RubyFit::MessageWriter.data_message(:session, 0, session)
    raw_session = definition + data
    modified = true

    [raw_session, modified]
  end

  def self.build_lap_and_session(parsed_data)
    lap = {}
    session = {}

    records = parsed_data[:records]
    events = parsed_data[:events]
    sport = parsed_data[:sport] || {}

    lap[:timestamp] = records.first[:timestamp]
    lap[:start_time] = records.first[:timestamp]
    lap[:start_lat_deg] = records.first[:lat_deg]
    lap[:start_lon_deg] = records.first[:lon_deg]
    lap[:tot_elapsed_time_sec] = records.last[:timestamp].to_i - records.first[:timestamp].to_i
    lap[:tot_elapsed_time_sec] = 0
    lap[:tot_timer_time_sec] = RubyFit::Helpers.calculate_timer_time(events)
    lap[:tot_dist_m] = records.last[:dist_m]
    lap[:event_code] = 9
    lap[:event_type_code] = 1
    lap[:sport_code] = sport[:sport_code] || 2
    lap[:sub_sport_code] = sport[:sub_sport_code] || 0

    session[:timestamp] = lap[:timestamp]
    session[:start_time] = lap[:start_time]
    session[:tot_elapsed_time_sec] = lap[:tot_elapsed_time_sec]
    session[:tot_timer_time_sec] = lap[:tot_timer_time_sec]
    session[:tot_dist_m] = lap[:tot_dist_m]
    session[:event_code] = 8
    session[:event_type_code] = 1
    session[:sport_code] = sport[:sport_code] || 2
    session[:sub_sport_code] = sport[:sub_sport_code] || 0

    definition = RubyFit::MessageWriter.definition_message(:lap, 0)
    data = RubyFit::MessageWriter.data_message(:lap, 0, lap)
    raw_lap = definition + data

    definition = RubyFit::MessageWriter.definition_message(:session, 0)
    data = RubyFit::MessageWriter.data_message(:session, 0, session)
    raw_session = definition + data

    modified = true

    [raw_lap, raw_session, modified]
  end

  def self.activity(activity)
    raw_activity = nil
    modified = false

    if activity[:local_timestamp].to_s == "1989-12-31 00:00:00 UTC"
      if activity[:timestamp]
        # Remove the local timestamp to avoid confusion in CRUX
        activity[:local_timestamp] = nil

        definition = RubyFit::MessageWriter.definition_message(:activity, 0)
        data = RubyFit::MessageWriter.data_message(:activity, 0, activity)
        raw_activity = definition + data
        modified = true
      end
    end

    [raw_activity, modified]
  end

  def self.post_parsed_activity(parsed_data)
    activity = parsed_data[:activity] || {}
    sessions = parsed_data[:sessions] || []
    total_timer_time_from_sessions = sessions.sum { |s| s[:tot_timer_time_sec] || 0 }

    if activity[:tot_timer_time_sec].present? && activity[:tot_timer_time_sec] != total_timer_time_from_sessions
      activity[:tot_timer_time_sec] = total_timer_time_from_sessions
      definition = RubyFit::MessageWriter.definition_message(:activity, 0)
      data = RubyFit::MessageWriter.data_message(:activity, 0, activity)
      raw_activity = definition + data
      modified = true
    else
      raw_activity = nil
      modified = false
    end
    [raw_activity, modified]
  end

  def self.session(session)
    raw_session = nil
    modified = false

    [raw_session, modified]
  end

end