require "rubyfit/type"
require "rubyfit/helpers"
require "rubyfit/message_constants"

class RubyFit::MessageWriter
  extend RubyFit::Helpers

  FIT_PROTOCOL_VERSION = 0x10 # major 1, minor 0
  FIT_PROFILE_VERSION = 1 * 100 + 52 # major 1, minor 52

  MESSAGE_DEFINITIONS = {
    file_id: {
      id: 0,
      fields: {
        serial_number: { id: 3, type: RubyFit::Type.uint32z, required: true },
        time_created: { id: 4, type: RubyFit::Type.timestamp, required: true },
        manufacturer: { id: 1, type: RubyFit::Type.uint16 }, # See FIT_MANUFACTURER_*
        product: { id: 2, type: RubyFit::Type.uint16 },
        type: { id: 0, type: RubyFit::Type.enum, required: true }, # See FIT_FILE_*
      }
    },
    course: {
      id: 31,
      fields: {
        name: { id: 5, type: RubyFit::Type.string(16), required: true },
      }
    },
    lap: {
      id: 19,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true},
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true},
        total_elapsed_time: { id: 7, type: RubyFit::Type.duration, required: true }, 
        total_timer_time: { id: 8, type: RubyFit::Type.duration, required: true }, 
        start_y: { id: 3, type: RubyFit::Type.semicircles },
        start_x: { id: 4, type: RubyFit::Type.semicircles },
        end_y: { id: 5, type: RubyFit::Type.semicircles },
        end_x: { id: 6, type: RubyFit::Type.semicircles },
        total_distance: { id: 9, type: RubyFit::Type.centimeters },
        total_ascent: { id: 21, type: RubyFit::Type.altitude },
        sport: { id: 25, type: RubyFit::Type.enum(RubyFit::MessageConstants::SPORT), required: false },
        subsport: { id: 39, type: RubyFit::Type.enum(RubyFit::MessageConstants::SUBSPORT), required: false },

        event: { id: 0, type: RubyFit::Type.enum(RubyFit::MessageConstants::EVENT), required: false },
        event_type: { id: 1, type: RubyFit::Type.enum(RubyFit::MessageConstants::EVENT_TYPE), required: false },
        avg_heart_rate: { id: 15, type: RubyFit::Type.uint8 },
        max_heart_rate: { id: 16, type: RubyFit::Type.uint8 },
        avg_cadence: { id: 17, type: RubyFit::Type.uint8 },
        max_cadence: { id: 18, type: RubyFit::Type.uint8 },
        avg_power: { id: 19, type: RubyFit::Type.uint16 },
        max_power: { id: 20, type: RubyFit::Type.uint16 },
        total_work: { id: 41, type: RubyFit::Type.uint32 },
        total_calories: { id: 11, type: RubyFit::Type.uint16 },
        lap_trigger: { id: 24, type: RubyFit::Type.enum(RubyFit::MessageConstants::LAP_TRIGGER) },
        normalized_power: { id: 33, type: RubyFit::Type.uint16 },
        total_moving_time: { id: 52, type: RubyFit::Type.duration },
        # time_in_hr_zone: { id: 57, type: RubyFit::Type.uint32 }, # should be array of hr_zone type
        # time_in_power_zone: { id: 60, type: RubyFit::Type.uint32 }, # should be array of power_zone type
        min_heart_rate: { id: 63, type: RubyFit::Type.uint8 },
        enhanced_avg_speed: { id: 65, type: RubyFit::Type.uint32 },
        enhanced_max_speed: { id: 66, type: RubyFit::Type.uint32 }
      },
    },
    course_point: {
      id: 32,
      fields: {
        timestamp: { id: 1, type: RubyFit::Type.timestamp, required: true },
        y: { id: 2, type: RubyFit::Type.semicircles, required: true },
        x: { id: 3, type: RubyFit::Type.semicircles, required: true },
        distance: { id: 4, type: RubyFit::Type.centimeters },
        name: { id: 6, type: RubyFit::Type.string(48) },
        message_index: { id: 254, type: RubyFit::Type.uint16 },
        type: { id: 5, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::COURSE_POINT_TYPE, required: true }
      },
    },
    record: {
      id: 20,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        y: { id: 0, type: RubyFit::Type.semicircles, required: true },
        x: { id: 1, type: RubyFit::Type.semicircles, required: true },
        distance: { id: 5, type: RubyFit::Type.centimeters },
        elevation: { id: 2, type: RubyFit::Type.altitude },
        heart_rate: { id: 3, type: RubyFit::Type.uint8 },
        cadence: { id: 4, type: RubyFit::Type.uint8 },
        power: { id: 7, type: RubyFit::Type.uint16 },
        calories: { id: 33, type: RubyFit::Type.uint16 },
        enhanced_speed: { id: 73, type: RubyFit::Type.uint32 },
        battery_soc: { id: 78, type: RubyFit::Type.uint8 },
      }
    },
    event: {
      id: 21,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        event: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT, required: true },
        event_type: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE, required: true },
        event_group: { id: 4, type: RubyFit::Type.uint8 },
      }
    },
    workout: {
      id: 26,
      fields: {
        sport: { id: 4, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT, required: true },
        # capabilities: { id: 5, type: RubyFit::Type.uint32z, required: true },  # should be workout_capabilities type
        num_valid_steps: { id: 6, type: RubyFit::Type.uint16 },
        wkt_name: { id: 8, type: RubyFit::Type.string(16) },
        sub_sport: { id: 11, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT },
        pool_length: { id: 14, type: RubyFit::Type.uint16 },
        pool_length_unit: { id: 15, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::DISPLAY_MEASURE }
      }
    },
    hr_zone: {
      id: 8,
      fields: {
        high_bpm: { id: 1, type: RubyFit::Type.uint8, required: true },
        name: { id: 2, type: RubyFit::Type.string(16), required: true }
      }
    },
    power_zone: {
      id: 9,
      fields: {
        high_value: { id: 1, type: RubyFit::Type.uint16, required: true },
        name: { id: 2, type: RubyFit::Type.string(16), required: true }
      }
    },
    device_info: {
      id: 23,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        serial_number: { id: 3, type: RubyFit::Type.uint32z, required: true },
        manufacturer: { id: 2, type: RubyFit::Type.uint16 },
        product: { id: 4, type: RubyFit::Type.uint16 },
        software_version: { id: 5, type: RubyFit::Type.uint16 },
        hardware_version: { id: 6, type: RubyFit::Type.uint8 },
        battery_voltage: { id: 10, type: RubyFit::Type.uint16 },
        battery_status: { id: 11, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::BATTERY_STATUS },
        ant_device_number: { id: 21, type: RubyFit::Type.uint16 },
        device_index: { id: 0, type: RubyFit::Type.uint8 }
      }
    },
    workout_step: {
      id: 27,
      fields: {
        message_index: { id: 254, type: RubyFit::Type.uint16 }, # should be message_index type
        wkt_step_name: { id: 0, type: RubyFit::Type.string(16) },
        duration_type: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::DURATION_TYPE, required: true },
        duration_value: { id: 2, type: RubyFit::Type.uint32 },
        target_type: { id: 3, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::TARGET_TYPE },
        target_value: { id: 4, type: RubyFit::Type.uint32 },
        custom_target_value_low: { id: 5, type: RubyFit::Type.uint32 },
        custom_target_value_high: { id: 6, type: RubyFit::Type.uint32 },
        intensity: { id: 7, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::INTENSITY },
        notes: { id: 8, type: RubyFit::Type.string(50) },
        equipment: { id: 9, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::WORKOUT_EQUIPMENT }
      }
    },
    session: {
      id: 18,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        event: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT, required: true },
        event_type: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE, required: true },
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true },
        sport: { id: 5, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT, required: true },
        sub_sport: { id: 6, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT },
        total_elapsed_time: { id: 7, type: RubyFit::Type.duration },
        total_timer_time: { id: 8, type: RubyFit::Type.duration },
        total_distance: { id: 9, type: RubyFit::Type.centimeters },
        total_calories: { id: 11, type: RubyFit::Type.uint16 },
        avg_heart_rate: { id: 16, type: RubyFit::Type.uint8 },
        max_heart_rate: { id: 17, type: RubyFit::Type.uint8 },
        avg_cadence: { id: 18, type: RubyFit::Type.uint8 },
        max_cadence: { id: 19, type: RubyFit::Type.uint8 },
        avg_power: { id: 20, type: RubyFit::Type.uint16 },
        max_power: { id: 21, type: RubyFit::Type.uint16 },
        num_laps: { id: 26, type: RubyFit::Type.uint16 },
        normalized_power: { id: 34, type: RubyFit::Type.uint16 },
        training_stress_score: { id: 35, type: RubyFit::Type.uint16 },
        intensity_factor: { id: 36, type: RubyFit::Type.uint16 },
        threshold_power: { id: 45, type: RubyFit::Type.uint16 },
        total_work: { id: 48, type: RubyFit::Type.uint32 },
        total_moving_time: { id: 59, type: RubyFit::Type.duration },
        min_heart_rate: { id: 64, type: RubyFit::Type.uint8 },
        # time_in_hr_zone: { id: 65, type: RubyFit::Type.uint32 }, # should be array of hr_zone type
        # time_in_power_zone: { id: 68, type: RubyFit::Type.uint32 }, # should be array of power_zone type
        enhanced_avg_speed: { id: 124, type: RubyFit::Type.uint32 },
        enhanced_max_speed: { id: 125, type: RubyFit::Type.uint32 }
        # workout_type: { id: 78, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::WORKOUT_TYPE }
        }
    },
    activity: {
      id: 34,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        total_timer_time: { id: 0, type: RubyFit::Type.duration },
        num_sessions: { id: 1, type: RubyFit::Type.uint16 },
        type: { id: 2, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::ACTIVITY_TYPE },
        event: { id: 3, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT },
        event_type: { id: 4, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE },
        local_timestamp: { id: 5, type: RubyFit::Type.timestamp },
      }
    }
  }

  def self.definition_message(type, local_num)
    pack_bytes do |bytes|
      message_data = MESSAGE_DEFINITIONS[type]
      bytes << header_byte(local_num, true)
      bytes << 0x00 # Reserved uint8
      bytes << 0x01 # Big endian
      bytes.push(*num2bytes(message_data[:id], 2)) # Global message ID
      bytes << message_data[:fields].size # Field count

      message_data[:fields].each do |field, info|
        type = info[:type]
        bytes << info[:id]
        bytes << type.byte_count
        bytes << type.fit_id
      end
    end
  end

  def self.data_message(type, local_num, values)
    pack_bytes do |bytes|
      message_data = MESSAGE_DEFINITIONS[type]
      bytes << header_byte(local_num, false)
      message_data[:fields].each do |field, info|
        field_type = info[:type]
        value = values[field]
        if info[:required] && value.nil?
          raise ArgumentError.new("Missing required field '#{field}' in #{type} data message values")
        end

        if info[:values]
          value = info[:values][value]
          if value.nil?
            raise ArgumentError.new("Invalid value for '#{field}' in #{type} data message values")
          end
        end

        value_bytes = value ? field_type.val2bytes(value) : field_type.default_bytes
        bytes.push(*value_bytes)
      end
    end
  end

  def self.definition_message_size(type)
    message_data = MESSAGE_DEFINITIONS[type]
    raise ArgumentError.new("Unknown message type '#{type}'") unless message_data
    6 + message_data[:fields].count * 3
  end

  def self.data_message_size(type)
    message_data = MESSAGE_DEFINITIONS[type]
    raise ArgumentError.new("Unknown message type '#{type}'") unless message_data
    1 + message_data[:fields].values.map{|info| info[:type].byte_count}.reduce(&:+)
  end

  def self.file_header(data_byte_count = 0) 
    pack_bytes do |bytes|
      bytes << 14 # Header size
      bytes << FIT_PROTOCOL_VERSION # Protocol version
      bytes.push(*num2bytes(FIT_PROFILE_VERSION, 2).reverse) # Profile version (little endian)
      bytes.push(*num2bytes(data_byte_count, 4).reverse) # Data size (little endian)
      bytes.push(*str2bytes(".FIT", 5).take(4)) # Data Type ASCII, no terminator
      crc = 0 #RubyFit::CRC.update_crc(0, bytes2str(bytes))
      bytes.push(*num2bytes(crc, 2).reverse) # Header CRC (little endian)
    end
  end

  def self.crc(crc_value)
    pack_bytes do |bytes|
      bytes.push(*num2bytes(crc_value, 2, false)) # Little endian
    end
  end

  # Internal
  
  def self.header_byte(local_number, definition)
    local_number & 0xF | (definition ? 0x40 : 0x00)
  end
  
  def self.pack_bytes
    bytes = []
    yield bytes
    bytes.pack("C*")
  end
end
