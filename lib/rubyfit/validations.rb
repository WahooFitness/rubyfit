class RubyFit::Validations

  def self.validate_message(message_type, data)
    if message_type == :lap
      data, modified = self.lap(data)
    elsif message_type == :activity
      data, modified = self.activity(data)
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
end