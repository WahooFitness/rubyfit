class RubyFit::Validations

  def self.validate_message(message_type, data)
    if message_type == :lap
      data = self.lap(data)
    end
    data
  end


  def self.lap(lap)
    if lap[:timestamp].nil? || lap[:timestamp] == 0 || lap[:timestamp].to_s == "1989-12-31 00:00:00 UTC"
      if !lap[:start_time].nil? && !lap[:tot_elapsed_time_sec].nil?
        lap[:timestamp] = lap[:start_time] + lap[:tot_elapsed_time_sec]
      else
        lap = nil
      end
    end
    lap
  end
end