class RubyFit::Validations

  def self.validate_message(message_type, data, raw_data)
    if message_type == :lap
        data, modified, parsed_data = self.lap(data)
    elsif message_type == :activity
      data, modified, parsed_data = self.activity(data)
    elsif message_type == :session
      data, modified, parsed_data = self.session(data)
    end
    [data, modified, parsed_data]
  end


  def self.lap(lap)
    raw_lap = nil
    modified = false
    if lap[:timestamp].nil? || lap[:timestamp] == 0 || lap[:timestamp].to_s == "1989-12-31 00:00:00 UTC" || (lap[:sport_code] == 1 && lap[:sub_sport_code] == 45)
      if !lap[:start_time].nil? && !lap[:tot_elapsed_time_sec].nil?
        lap[:timestamp] = lap[:start_time] + lap[:tot_elapsed_time_sec]

        if lap[:sport_code] == 1 && lap[:sub_sport_code] == 45
          lap[:sub_sport_code] = 1
          if lap[:event_type_code].nil?
            lap[:event_type_code] = 1
          end
          if lap[:event_code].nil?
            lap[:event_code] = 9
          end
        end
        definition = RubyFit::MessageWriter.definition_message(:lap, 0)
        data = RubyFit::MessageWriter.data_message(:lap, 0, lap)
        raw_lap = definition + data
      else
        # Lap is totally invalid, so we set it to nil
        raw_lap = nil
      end
      modified = true
    end
    [raw_lap, modified, lap]
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
    sport = parsed_data[:sport].is_a?(Array) ? parsed_data[:sport].last : (parsed_data[:sport] || {})

    return [nil, nil, false] if records.nil?

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

  def self.build_workout(parsed_data)
    workout = {}

    return if parsed_data[:sessions].nil?

    sport = parsed_data[:sport] || {}
    sport_code = sport&.[](:sport_code) || parsed_data[:sessions]&.first[:sport_code] || 2
    sub_sport_code = sport&.[](:sub_sport_code) || parsed_data[:sessions]&.first[:sub_sport_code] || 0
    if sport_code == 1 && sub_sport_code == 45
      sport_code = 1
      sub_sport_code = 1
    end

    workout[:sport_code] = sport_code
    workout[:sub_sport_code] = sub_sport_code

    if sub_sport_code == 0
      workout[:wkt_name] = RubyFit::MessageConstants::SPORT.key(sport_code).to_s.capitalize
    else
      subsport_name = RubyFit::MessageConstants::SUBSPORT.key(sub_sport_code).to_s
      if subsport_name.include?('_')
        workout[:wkt_name] = subsport_name.split('_').map(&:capitalize).join(' ')
      else
        workout[:wkt_name] = subsport_name.capitalize + ' ' + RubyFit::MessageConstants::SPORT.key(sport_code).to_s.capitalize
      end
    end

    definition = RubyFit::MessageWriter.definition_message(:workout, 0)
    data = RubyFit::MessageWriter.data_message(:workout, 0, workout)
    raw_workout = definition + data
    modified = true

    [raw_workout, modified]
  end

  def self.build_wahoo_id(parsed_data)
    return if parsed_data[:file_id].nil? || (parsed_data[:sessions].nil? && parsed_data[:sport].nil?)

    wahoo_id = {}

    time_created = parsed_data[:file_id][:time_created] || Time.now
    fit_epoch = Time.utc(1989, 12, 31, 0, 0, 0)
    time_created_fit = (time_created - fit_epoch).to_i

    sport = parsed_data[:sport] || {}
    sport_code = sport&.[](:sport_code) || parsed_data[:sessions]&.first[:sport_code] || 2
    sub_sport_code = sport&.[](:sub_sport_code) || parsed_data[:sessions]&.first[:sub_sport_code] || 0

    if sport_code == 1 && sub_sport_code == 45
      sport_code = 1
      sub_sport_code = 1
    end

    workout_type = RubyFit::Helpers.get_workout_type_from_sport_and_subsport(sport_code, sub_sport_code) || 47

    wahoo_id[:app_token] = "FID14 #{time_created_fit.to_i.to_s(16).upcase.rjust(8, '0')}"
    wahoo_id[:workout_num] = 0
    wahoo_id[:workout_type] = workout_type

    definition = RubyFit::MessageWriter.definition_message(:wahoo_id, 0)
    data = RubyFit::MessageWriter.data_message(:wahoo_id, 0, wahoo_id)
    raw_wahoo_id = definition + data
    modified = true

    [raw_wahoo_id, modified]
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

    [raw_activity, modified, activity]
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

  def self.post_parsed_events(parsed_data)
    events = parsed_data[:events] || []
    records = parsed_data[:records] || []
    raw_events = []
    modified = false

    events.each do |event|
      if (event[:event_type_code] == 4 || event[:event_type_code] == 1) && records.last && records.last[:timestamp] && event[:timestamp] && event[:timestamp] > (records.last[:timestamp] + 5)
        event[:timestamp] = records.last[:timestamp]

        definition = RubyFit::MessageWriter.definition_message(:event, 0)
        data = RubyFit::MessageWriter.data_message(:event, 0, event)

        raw_event = definition + data
        modified = true
        raw_events << raw_event
      else
        raw_event = nil
        raw_events << raw_event
      end
    end

    [raw_events, modified]
  end

  def self.session(session)
    raw_session = nil
    modified = false

    if session[:sport_code] == 1 && session[:sub_sport_code] == 45
      session[:sub_sport_code] = 1
      if session[:event_type_code].nil?
        session[:event_type_code] = 1
      end
      if session[:event_code].nil?
        session[:event_code] = 8
      end
      definition = RubyFit::MessageWriter.definition_message(:session, 0)
      data = RubyFit::MessageWriter.data_message(:session, 0, session)
      raw_session = definition + data
      modified = true
    end

    [raw_session, modified, session]
  end

end