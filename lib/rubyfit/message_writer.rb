require_relative 'type'
require_relative 'helpers'
require_relative 'message_constants'

class RubyFit::MessageWriter
  extend RubyFit::Helpers

  FIT_PROTOCOL_VERSION = 0x10 # major 1, minor 0
  FIT_PROFILE_VERSION = 1 * 100 + 52 # major 1, minor 52

  MESSAGE_DEFINITIONS = {
    file_id: {
      id: 0,
      fields: {
        serial_number: { id: 3, type: RubyFit::Type.uint32z, required: false },
        time_created: { id: 4, type: RubyFit::Type.timestamp, required: true },
        manufacturer_code: { id: 1, type: RubyFit::Type.uint16 },
        product: { id: 2, type: RubyFit::Type.uint16 },
        type_code: { id: 0, type: RubyFit::Type.enum, required: true },
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
        event_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT },
        event_type_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE },
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true},
        start_lat_deg: { id: 3, type: RubyFit::Type.semicircles },
        start_lon_deg: { id: 4, type: RubyFit::Type.semicircles },
        end_lat_deg: { id: 5, type: RubyFit::Type.semicircles },
        end_lon_deg: { id: 6, type: RubyFit::Type.semicircles },
        tot_elapsed_time_sec: { id: 7, type: RubyFit::Type.duration, required: true },
        tot_timer_time_sec: { id: 8, type: RubyFit::Type.duration, required: true },
        tot_dist_m: { id: 9, type: RubyFit::Type.centimeters },
        tot_cal: { id: 11, type: RubyFit::Type.uint16 },
        avg_spd_mps: { id: 13, type: RubyFit::Type.uint16_scale1000 },
        max_spd_mps: { id: 14, type: RubyFit::Type.uint16_scale1000 },
        avg_hr_bpm: { id: 15, type: RubyFit::Type.uint8 },
        max_hr_bpm: { id: 16, type: RubyFit::Type.uint8 },
        avg_cad_rpm: { id: 17, type: RubyFit::Type.uint8 },
        max_cad_rpm: { id: 18, type: RubyFit::Type.uint8 },
        avg_pwr_watts: { id: 19, type: RubyFit::Type.uint16 },
        max_pwr_watts: { id: 20, type: RubyFit::Type.uint16 },
        tot_ascent_m: { id: 21, type: RubyFit::Type.ascent},
        tot_descent_m: { id: 22, type: RubyFit::Type.ascent },
        lap_trigger_code: { id: 24, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::LAP_TRIGGER },
        sport_code: { id: 25, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT, required: false },
        norm_pwr_watts: { id: 33, type: RubyFit::Type.uint16 },
        sub_sport_code: { id: 39, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT, required: false},
        tot_work_j: { id: 41, type: RubyFit::Type.uint32 },
        avg_alt_m: { id: 42, type: RubyFit::Type.altitude },
        max_alt_m: { id: 43, type: RubyFit::Type.altitude },
        avg_grade_perc: { id: 45, type: RubyFit::Type.grade },
        max_pos_grade_perc: { id: 48, type: RubyFit::Type.grade },
        max_neg_grade_perc: { id: 49, type: RubyFit::Type.grade },
        avg_temp_deg_c: { id: 50, type: RubyFit::Type.sint8 },
        max_temp_deg_c: { id: 51, type: RubyFit::Type.sint8 },
        tot_moving_time_sec: { id: 52, type: RubyFit::Type.duration },
        time_in_hr_zone_sec: { id: 57, type: RubyFit::Type.uint32_array(5) },
        time_in_pwr_zone_sec: { id: 60, type: RubyFit::Type.uint32_array(8) },
        min_alt_m: { id: 62, type: RubyFit::Type.altitude },
        min_hr_bpm: { id: 63, type: RubyFit::Type.uint8 },
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
      }
    },

    record: {
      id: 20,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        lat_deg: { id: 0, type: RubyFit::Type.semicircles },
        lon_deg: { id: 1, type: RubyFit::Type.semicircles },
        alt_m: { id: 2, type: RubyFit::Type.altitude },
        hr_bpm: { id: 3, type: RubyFit::Type.uint8 },
        cad_rpm: { id: 4, type: RubyFit::Type.uint8 },
        dist_m: { id: 5, type: RubyFit::Type.centimeters },
        spd_mps: { id: 6, type: RubyFit::Type.uint16_scale1000 },
        pwr_watts: { id: 7, type: RubyFit::Type.uint16 },
        grade_perc: { id: 9, type: RubyFit::Type.grade},
        temp_deg_c: { id: 13, type: RubyFit::Type.sint8 },
        gps_acc_m: { id: 31, type: RubyFit::Type.uint8 },
        cal: { id: 33, type: RubyFit::Type.uint16 },
        left_torque_effect_perc: { id: 43, type: RubyFit::Type.uint8_scale2 },
        right_torque_effect_perc: { id: 44, type: RubyFit::Type.uint8_scale2 },
        left_pedal_smooth_perc: { id: 45, type: RubyFit::Type.uint8_scale2 },
        right_pedal_smooth_perc: { id: 46, type: RubyFit::Type.uint8_scale2 },
        enhanced_spd_mps: { id: 73, type: RubyFit::Type.enhanced_speed},
        batt_soc_perc: { id: 81, type: RubyFit::Type.uint8_scale2 }
      }
    },

    event: {
      id: 21,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        event_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT.merge(RubyFit::MessageConstants::EVENT.values.map { |v| [v, v] }.to_h), required: false },
        event_type_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE.merge(RubyFit::MessageConstants::EVENT_TYPE.values.map { |v| [v, v] }.to_h), required: false },
        data16: { id: 2, type: RubyFit::Type.uint16 },
        data: { id: 3, type: RubyFit::Type.uint32 },
        event_group: { id: 4, type: RubyFit::Type.uint8 },
        front_gear_num: { id: 9, type: RubyFit::Type.uint8z },
        front_gear: { id: 10, type: RubyFit::Type.uint8z },
        rear_gear_num: { id: 11, type: RubyFit::Type.uint8z },
        rear_gear: { id: 12, type: RubyFit::Type.uint8z },
      }
    },

    workout: {
      id: 26,
      fields: {
        sport_code: { id: 4, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT.merge(RubyFit::MessageConstants::SPORT.values.map { |v| [v, v] }.to_h), required: true },
        # capabilities: { id: 5, type: RubyFit::Type.uint32z, required: true },  # should be workout_capabilities type
        num_valid_steps: { id: 6, type: RubyFit::Type.uint16 },
        wkt_name: { id: 8, type: RubyFit::Type.string(64) },
        sub_sport_code: { id: 11, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT.merge(RubyFit::MessageConstants::SUBSPORT.values.map { |v| [v, v] }.to_h) },
        # pool_length: { id: 14, type: RubyFit::Type.uint16 },
        # pool_length_unit: { id: 15, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::DISPLAY_MEASURE }
      }
    },

    sport: {
      id: 12,
      fields: {
        sport_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT.merge(RubyFit::MessageConstants::SPORT.values.map { |v| [v, v] }.to_h), required: true },
        sub_sport_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT }
      }
    },

    hr_zone: {
      id: 8,
      fields: {
        message_index: { id: 254, type: RubyFit::Type.uint16 },
        high_hr_bpm: { id: 1, type: RubyFit::Type.uint8, required: true },
        name: { id: 2, type: RubyFit::Type.string(16), required: true }
      }
    },

    pwr_zone: {
      id: 9,
      fields: {
        message_index: { id: 254, type: RubyFit::Type.uint16 },
        high_pwr_watts: { id: 1, type: RubyFit::Type.uint16, required: true },
        name: { id: 2, type: RubyFit::Type.string(16), required: true }
      }
    },

    device_info: {
      id: 23,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        device_type: { id: 1, type: RubyFit::Type.uint8 },
        serial_number: { id: 3, type: RubyFit::Type.uint32z },
        manufacturer_code: { id: 2, type: RubyFit::Type.uint16 },
        product: { id: 4, type: RubyFit::Type.uint16 },
        software_version: { id: 5, type: RubyFit::Type.uint16 },
        hardware_version: { id: 6, type: RubyFit::Type.uint8 },
        battery_status: { id: 11, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::BATTERY_STATUS },
        ant_device_number: { id: 21, type: RubyFit::Type.uint16 },
        device_index: { id: 0, type: RubyFit::Type.uint8 },
        source_type_code: { id: 25,type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SOURCE_TYPE },
        product_name: { id: 27, type: RubyFit::Type.string(20) }
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
        event_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT.merge(RubyFit::MessageConstants::EVENT.values.map { |v| [v, v] }.to_h), required: true },
        event_type_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE.merge(RubyFit::MessageConstants::EVENT_TYPE.values.map { |v| [v, v] }.to_h), required: true },
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true },
        sport_code: { id: 5, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SPORT.merge(RubyFit::MessageConstants::SPORT.values.map { |v| [v, v] }.to_h), required: true },
        sub_sport_code: { id: 6, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SUBSPORT.merge(RubyFit::MessageConstants::SUBSPORT.values.map { |v| [v, v] }.to_h) },
        tot_elapsed_time_sec: { id: 7, type: RubyFit::Type.duration },
        tot_timer_time_sec: { id: 8, type: RubyFit::Type.duration },
        tot_dist_m: { id: 9, type: RubyFit::Type.centimeters },
        tot_cal: { id: 11, type: RubyFit::Type.uint16 },
        avg_spd_mps: { id: 14, type: RubyFit::Type.uint16_scale1000},
        max_spd_mps: { id: 15, type: RubyFit::Type.uint16_scale1000},
        avg_hr_bpm: { id: 16, type: RubyFit::Type.uint8 },
        max_hr_bpm: { id: 17, type: RubyFit::Type.uint8 },
        avg_cad_rpm: { id: 18, type: RubyFit::Type.uint8 },
        max_cad_rpm: { id: 19, type: RubyFit::Type.uint8 },
        avg_pwr_watts: { id: 20, type: RubyFit::Type.uint16 },
        max_pwr_watts: { id: 21, type: RubyFit::Type.uint16 },
        tot_ascent_m: { id: 22, type: RubyFit::Type.ascent },
        tot_descent_m: { id: 23, type: RubyFit::Type.ascent },
        num_laps: { id: 26, type: RubyFit::Type.uint16 },
        norm_pwr_watts: { id: 34, type: RubyFit::Type.uint16 },
        tss: { id: 35, type: RubyFit::Type.tss },
        if: { id: 36, type: RubyFit::Type.if },
        ftp: { id: 45, type: RubyFit::Type.uint16 },
        tot_work_j: { id: 48, type: RubyFit::Type.uint32 },
        avg_alt_m: { id: 49, type: RubyFit::Type.altitude },
        max_alt_m: { id: 50, type: RubyFit::Type.altitude },
        avg_grade_perc: { id: 52, type: RubyFit::Type.grade },
        max_pos_grade_perc: { id: 55, type: RubyFit::Type.grade },
        max_neg_grade_perc: { id: 56, type: RubyFit::Type.grade },
        avg_temp_deg_c: { id: 57, type: RubyFit::Type.sint8 },
        max_temp_deg_c: { id: 58, type: RubyFit::Type.sint8 },
        tot_moving_time_sec: { id: 59, type: RubyFit::Type.duration },
        min_hr_bpm: { id: 64, type: RubyFit::Type.uint8 },
        time_in_hr_zone_sec: { id: 65, type: RubyFit::Type.uint32_array(5) },
        time_in_pwr_zone_sec: { id: 68, type: RubyFit::Type.uint32_array(8) },
        min_alt_m: { id: 71, type: RubyFit::Type.altitude },
        enhanced_avg_speed: { id: 124, type: RubyFit::Type.uint32 },
        enhanced_max_speed: { id: 125, type: RubyFit::Type.uint32 },
        workout_rpe: { id: 193, type: RubyFit::Type.uint8_scale10 },
      }
    },

    activity: {
      id: 34,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        tot_timer_time_sec: { id: 0, type: RubyFit::Type.duration },
        num_sessions: { id: 1, type: RubyFit::Type.uint16 },
        type_code: { id: 2, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::ACTIVITY_TYPE.merge(RubyFit::MessageConstants::ACTIVITY_TYPE.values.map { |v| [v, v] }.to_h) },
        event_code: { id: 3, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT.merge(RubyFit::MessageConstants::EVENT.values.map { |v| [v, v] }.to_h) },
        event_type_code: { id: 4, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE.merge(RubyFit::MessageConstants::EVENT_TYPE.values.map { |v| [v, v] }.to_h) },
        local_timestamp: { id: 5, type: RubyFit::Type.timestamp },
      }
    },

    length: {
      id: 101,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        event_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT.merge(RubyFit::MessageConstants::EVENT.values.map { |v| [v, v] }.to_h), required: true },
        event_type_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE.merge(RubyFit::MessageConstants::EVENT_TYPE.values.map { |v| [v, v] }.to_h), required: true },
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true },
        total_elapsed_time: { id: 3, type: RubyFit::Type.duration },
        tot_timer_time_sec: { id: 4, type: RubyFit::Type.duration },
        total_strokes: { id: 5, type: RubyFit::Type.uint16 },
        avg_speed: { id: 6, type: RubyFit::Type.uint16 },
        swim_stroke: { id: 7, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::SWIM_STROKE },
        avg_swimming_cadence: { id: 9, type: RubyFit::Type.uint8 },
        total_calories: { id: 11, type: RubyFit::Type.uint16 },
        length_type: { id: 12, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::LENGTH_TYPE },
        player_score: { id: 18, type: RubyFit::Type.uint16 },
        opponent_score: { id: 19, type: RubyFit::Type.uint16 },
        stroke_count: { id: 20, type: RubyFit::Type.uint16 },
        zone_count: { id: 21, type: RubyFit::Type.uint16 },
        enhanced_avg_respiration_rate: { id: 22, type: RubyFit::Type.uint16 },
        enhanced_max_respiration_rate: { id: 23, type: RubyFit::Type.uint16 },
        avg_respiration_rate: { id: 24, type: RubyFit::Type.uint8 },
        max_respiration_rate: { id: 25, type: RubyFit::Type.uint8 }
      }
    },

    segment_lap: {
      id: 142,
      fields: {
        timestamp: { id: 253, type: RubyFit::Type.timestamp, required: true },
        event_code: { id: 0, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT.merge(RubyFit::MessageConstants::EVENT.values.map { |v| [v, v] }.to_h), required: true },
        event_type_code: { id: 1, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::EVENT_TYPE.merge(RubyFit::MessageConstants::EVENT_TYPE.values.map { |v| [v, v] }.to_h), required: true },
        start_time: { id: 2, type: RubyFit::Type.timestamp, required: true },
        start_lat_deg: { id: 3, type: RubyFit::Type.semicircles },
        start_lon_deg: { id: 4, type: RubyFit::Type.semicircles },
        end_lat_deg: { id: 5, type: RubyFit::Type.semicircles },
        end_lon_deg: { id: 6, type: RubyFit::Type.semicircles },
        tot_elapsed_time_sec: { id: 7, type: RubyFit::Type.duration },
        tot_timer_time_sec: { id: 8, type: RubyFit::Type.duration },
        name: { id: 29, type: RubyFit::Type.string(32) },
        uuid: { id: 65, type: RubyFit::Type.string(16) }
      }
    },

    wahoo_id: {
      id: 0xFF01,
      fields: {
        app_token: { id: 0, type: RubyFit::Type.string(32), required: false },
        workout_num: { id: 1, type: RubyFit::Type.uint32, required: false },
        workout_type: { id: 2, type: RubyFit::Type.uint16, required: true },
        # workout_token: { id: 3, type: RubyFit::Type.string(32), required: true },
      }
    },

    wahoo_custom_num: {
      id: 0xFF04,
      fields: {
        value: { id: 0, type: RubyFit::Type.float64, required: true },
        timestamp: { id: 1, type: RubyFit::Type.timestamp, required: false },
        sub_type_code: { id: 2, type: RubyFit::Type.uint16, required: true },
        type_code: { id: 3, type: RubyFit::Type.uint8, required: true }
      }
    },

    wahoo_clm: {
      id: 0xFF05,
      fields: {
        timestamp: { id: 0, type: RubyFit::Type.timestamp, required: false },
        device_index: { id: 1, type: RubyFit::Type.uint8, required: false },
        data_len: { id: 2, type: RubyFit::Type.uint8, required: true },
        data: { id: 3, type: RubyFit::Type.byte_array(23), required: true }
      }
    },

    field_description: {
      # Must be logged before developer field is used
      id: 206,
      fields: {
        developer_data_index: { id: 0, type: RubyFit::Type.uint8 },
        field_definition_number: { id: 1, type: RubyFit::Type.uint8 },
        fit_base_type_id: { id: 2, type: RubyFit::Type.enum, values: RubyFit::MessageConstants::FIT_BASE_TYPE },
        field_name: { id: 3, type: RubyFit::Type.string(32) },
        units: { id: 8, type: RubyFit::Type.string(16) },
      }
    },

    developer_data_id: {
      # Must be logged before field description
      id: 207,
      fields: {
        developer_id: { id: 0, type: RubyFit::Type.uint8 },
        manufacturer_id: { id: 2, type: RubyFit::Type.uint16 },
        developer_data_index: { id: 3, type: RubyFit::Type.uint8 }
      }
    }

  }

  def self.definition_message(type, local_num, developer_fields = nil)
    pack_bytes do |bytes|
      message_data = MESSAGE_DEFINITIONS[type]
      bytes << header_byte(local_num, true, developer_fields&.present?)
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

      if developer_fields
        bytes << developer_fields.length # Developer field count
        developer_fields.each do |field|
          field_size = 1
          if field[:field_definition_number]&.to_i == 17
            field_size = 48
          end
          bytes << field[:field_definition_number]&.to_i # Field number:	Maps to the field_definition_number of a field_description Message
          bytes << field_size
          bytes << field[:developer_data_index]&.to_i # Developer Data Index: Maps to the developer_data_index of a developer_data_id Message
        end
      end
    end
  end

  def self.data_message(type, local_num, values, developer_fields = nil)
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
          if info[:required] && value.nil?
            raise ArgumentError.new("Invalid value for '#{field}' in #{type} data message values")
          end
        end
        value_bytes = value ? field_type.val2bytes(value) : field_type.default_bytes
        bytes.push(*value_bytes)
      end

      # Add developer fields if provided
      if developer_fields
        developer_fields.each do |field|
          if field[:field_definition_number]&.to_i == 17
            type = RubyFit::Type.string(48)
          elsif field[:field_definition_number]&.to_i == 16
            type = RubyFit::Type.uint8
          else
            type = nil
          end
          value = field[:data]
          value_bytes = type ? type.val2bytes(value) : [value].pack("C*").bytes
          bytes.push(*value_bytes)
        end
      end
    end
  end

  def self.definition_message_size(type, developer_fields = nil)
    message_data = MESSAGE_DEFINITIONS[type]
    raise ArgumentError.new("Unknown message type '#{type}'") unless message_data

    # Base size: header (6 bytes) + fields (3 bytes per field)
    base_size = 6 + message_data[:fields].count * 3

    # Add developer fields size (1 byte to store the count then 3 bytes per developer field)
    developer_fields_size = developer_fields ? 1 + developer_fields.size * 3 : 0
    base_size + developer_fields_size
  end

  def self.data_message_size(type, developer_fields = nil)
    message_data = MESSAGE_DEFINITIONS[type]
    raise ArgumentError.new("Unknown message type '#{type}'") unless message_data

    # Base size: header (1 byte) + field data sizes
    base_size = 1 + message_data[:fields].values.map { |info| info[:type].byte_count }.reduce(&:+)

    # Add developer field data sizes
    developer_fields_size = developer_fields ? developer_fields.sum { |field| field[:data].is_a?(Array) ? field[:data].size : field[:data] } : 0
    base_size + developer_fields_size
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
  def self.header_byte(local_number, definition, developer = false)
    local_number & 0xF | (definition ? 0x40 : 0x00) | (developer ? 0x20 : 0x00)
  end
  
  def self.pack_bytes
    bytes = []
    yield bytes
    bytes.pack("C*")
  end
end
