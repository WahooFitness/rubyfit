require "rubyfit/message_writer"

class RubyFit::Writer
  PRODUCT_ID = 65534 # Garmin Connect

  def write(stream, opts = {})
    raise "Can't start write mode from #{@state}" if @state
    @state = :write
    @local_nums = {}
    @last_local_num = -1

    @stream = stream

    %i(start_time duration course_point_count track_point_count name
       total_distance time_created start_x start_y end_x end_y).each do |key|
      raise ArgumentError.new("Missing required option #{key}") unless opts[key]
    end

    start_time = opts[:start_time].to_i
    duration = opts[:duration].to_i
    
    @data_crc = 0

    data_size = calculate_data_size(opts[:course_point_count], opts[:track_point_count])
    write_data(RubyFit::MessageWriter.file_header(data_size))

    write_message(:file_id, {
      time_created: opts[:time_created],
      type: 6, # Course file
      manufacturer: opts[:manufacturer],
      product: opts[:product],
      serial_number: 0,
    })

    write_message(:course, { name: opts[:name] })

    write_message(:lap, {
      start_time: start_time,
      timestamp: start_time,
      total_elapsed_time: duration,
      total_timer_time: duration,
      start_x: opts[:start_x],
      start_y: opts[:start_y],
      end_x: opts[:end_x],
      end_y: opts[:end_y],
      total_distance: opts[:total_distance],
      total_ascent: opts[:total_ascent],
      sport: opts[:sport],
      subsport: opts[:subsport]
    })

    write_message(:event, {
      timestamp: start_time,
      event: :timer,
      event_type: :start,
      event_group: 0
    })

    yield

    write_message(:event, {
      timestamp: start_time + duration,
      event: :timer,
      event_type: :stop_disable_all,
      event_group: 0
    })

    write_data(RubyFit::MessageWriter.crc(@data_crc))
    @state = nil
  end

  def write_workout_file(stream, opts = {})
    raise "Can't start write mode from #{@state}" if @state
    @state = :write
    @local_nums = {}
    @last_local_num = -1

    @stream = stream

    %i(start_time).each do |key|
      raise ArgumentError.new("Missing required option #{key}") unless opts[key]
    end

    @data_crc = 0

    data_size = calculate_data_size(0, 0)
    write_data(RubyFit::MessageWriter.file_header(data_size))

    write_message(:file_id, {
      time_created: opts[:time_created],
      type: 5, # workout file
      manufacturer: opts[:manufacturer],
      product: opts[:product],
      serial_number: 0,
    })

    # Every FIT Workout file MUST contain a Workout message as the second message
    write_message(:workout, {
      sport: opts[:sport],
      capabilities: opts[:capabilities],
      num_valid_steps: opts[:num_valid_steps],
      wkt_name: opts[:wkt_name],
      sub_sport: opts[:subsport],
      pool_length: opts[:pool_length],
      pool_length_unit: opts[:pool_length_unit]
    })

    # Every FIT Workout file MUST contain one or more Workout Step messages
    yield

    # Update the data size in the header and calculate the CRC
    write_data(RubyFit::MessageWriter.crc(@data_crc))
    @state = nil
  end

  def write_activity_file(stream, opts = {})
    raise "Can't start write mode from #{@state}" if @state
    @state = :write
    @local_nums = {}
    @last_local_num = -1

    @stream = stream

    %i(start_time duration workout_step_count lap_count session_count event_count record_count power_zone_count hr_zone_count wahoo_custom_num_count).each do |key|
      raise ArgumentError.new("Missing required option #{key}") unless opts[key]
    end

    start_time = opts[:start_time].to_i
    duration = opts[:duration].to_i

    @data_crc = 0

    data_size = calculate_workout_data_size( opts[:workout_step_count], opts[:lap_count], opts[:session_count], opts[:event_count],0, opts[:record_count], opts[:device_info_count], opts[:length_count], opts[:power_zone_count], opts[:hr_zone_count], opts[:wahoo_custom_num_count])
    write_data(RubyFit::MessageWriter.file_header(data_size))

    write_message(:file_id, {
      time_created: opts[:time_created],
      type: 4, # activity file
      manufacturer: opts[:manufacturer],
      product: opts[:product],
      serial_number: 0,
    })

    write_message(:activity, {
      timestamp: opts[:timestamp],
      total_timer_time: opts[:total_timer_time],
      num_sessions: opts[:session_count],
      type: opts[:type],
      event: opts[:event],
      event_type: opts[:event_type],
      local_timestamp: opts[:local_timestamp]
    })

    write_message(:sport, {
      sport: opts[:sport],
      sub_sport: opts[:subsport]
    })

    write_message(:workout, {
      sport: opts[:sport],
      # capabilities: opts[:capabilities],
      num_valid_steps: opts[:num_valid_steps],
      wkt_name: opts[:name],
      sub_sport: opts[:subsport],
      # pool_length: opts[:pool_length],
      # pool_length_unit: opts[:pool_length_unit]
    })

    write_message(:event, {
      timestamp: start_time,
      event: :timer,
      event_type: :start,
      event_group: 0
    })

    yield

    write_message(:event, {
      timestamp: start_time + duration,
      event: :timer,
      event_type: :stop_disable_all,
      event_group: 0
    })

    # Update the data size in the header and calculate the CRC
    write_data(RubyFit::MessageWriter.crc(@data_crc))
    @state = nil
  end

  def course_points
    raise "Can only start course points mode inside 'write' block" if @state != :write
    @state = :course_points
    yield
    @state = :write
  end

  def track_points
    raise "Can only write track points inside 'write' block" if @state != :write
    @state = :track_points
    yield
    @state = :write
  end

  def workout_steps
    raise "Can only write workout steps inside 'write' block" if @state != :write
    @state = :workout_steps
    yield
    @state = :write
  end

  def records
    raise "Can only write records inside 'write' block" if @state != :write
    @state = :records
    yield
    @state = :write
  end

  def laps
    raise "Can only write laps inside 'write' block" if @state != :write
    @state = :laps
    yield
    @state = :write
  end

  def sessions
    raise "Can only write sessions inside 'write' block" if @state != :write
    @state = :sessions
    yield
    @state = :write
  end

  def device_infos
    raise "Can only write device infos inside 'write' block" if @state != :write
    @state = :device_infos
    yield
    @state = :write
  end

  def lengths
    raise "Can only write lengths inside 'write' block" if @state != :write
    @state = :lengths
    yield
    @state = :write
  end

  def hr_zones
    raise "Can only write lengths inside 'write' block" if @state != :write
    @state = :hr_zones
    yield
    @state = :write
  end

  def power_zones
    raise "Can only write lengths inside 'write' block" if @state != :write
    @state = :power_zones
    yield
    @state = :write
  end

  def wahoo_custom_nums
    raise "Can only write lengths inside 'write' block" if @state != :write
    @state = :wahoo_custom_nums
    yield
    @state = :write
  end

  def course_point(values)
    raise "Can only write course points inside 'course_points' block" if @state != :course_points
    write_message(:course_point, values)
  end

  def track_point(values)
    raise "Can only write track points inside 'track_points' block" if @state != :track_points
    write_message(:record, values)
  end

  def workout_step(values)
    raise "Can only write workout steps inside 'workout_steps' block" if @state != :workout_steps
    write_message(:workout_step, values)
  end

  def lap(values)
    raise "Can only write laps inside 'laps' block" if @state != :laps
    write_message(:wkt_lap, values)
  end

  def record(values)
    raise "Can only write records inside 'records' block" if @state != :records
    write_message(:record, values)
  end

  def session(values)
    raise "Can only write sessions inside 'sessions' block" if @state != :sessions
    write_message(:session, values)
  end

  def device_info(values)
    raise "Can only write device infos inside 'device_infos' block" if @state != :device_infos
    write_message(:device_info, values)
  end

  def length(values)
    raise "Can only write lengths inside 'lengths' block" if @state != :lengths
    write_message(:length, values)
  end

  def hr_zone(values)
    raise "Can only write hr zones inside 'hr_zones' block" if @state != :hr_zones
    write_message(:hr_zone, values)
  end

  def power_zone(values)
    raise "Can only write power zones inside 'power_zones' block" if @state != :power_zones
    write_message(:power_zone, values)
  end

  def wahoo_custom_num(values)
    raise "Can only write wahoo custom nums inside 'wahoo_custom_nums' block" if @state != :wahoo_custom_nums
    write_message(:wahoo_custom_num, values)
  end

  protected

  def write_message(type, values)
    puts("writing message", type, values)
    local_num = @local_nums[type]
    unless local_num
      @last_local_num += 1
      local_num = @last_local_num
      @local_nums[type] = local_num
      puts("writing definition message", type, local_num)
      write_data(RubyFit::MessageWriter.definition_message(type, local_num))
    end

    write_data(RubyFit::MessageWriter.data_message(type, local_num, values))
  end

  def write_data(data)
    @stream.write(data)
    prev = @data_crc
    @data_crc = RubyFit::CRC.update_crc(@data_crc, data)
  end

  def calculate_data_size(course_point_count, track_point_count)
    record_counts = {
      file_id: 1,
      course: 1,
      lap: 1,
      event: 2,
      course_point: course_point_count, 
      record: track_point_count,
    }

    data_sizes = record_counts.map do |type, count|
      def_size = RubyFit::MessageWriter.definition_message_size(type)
      data_size = RubyFit::MessageWriter.data_message_size(type) * count 
      result = def_size + data_size
      result
    end

    data_sizes.reduce(&:+)
  end


  def calculate_workout_data_size(workout_step_count, lap_count, session_count, event_count, course_point_count, record_count, device_info_count, length_count, power_zone_count, hr_zone_count, wahoo_custom_num_count)
    record_counts = {
      file_id: 1,
      sport: 1,
      workout: 1,
      activity: 1,
      wkt_lap: lap_count,
      length: length_count,
      event: event_count + 2,
      workout_step: workout_step_count,
      course_point: course_point_count,
      record: record_count,
      session: session_count,
      device_info: device_info_count,
      hr_zone: hr_zone_count,
      power_zone: power_zone_count,
      wahoo_custom_num: wahoo_custom_num_count
    }

    data_sizes = record_counts.map do |type, count|
      def_size = RubyFit::MessageWriter.definition_message_size(type)
      data_size = RubyFit::MessageWriter.data_message_size(type) * count
      result = if count > 0
                 def_size + data_size
               else
                 0
               end
      puts "#{type}: #{result}"
      result
    end

    puts("data sizes", data_sizes.reduce(&:+))
    data_sizes.reduce(&:+)
  end
end
