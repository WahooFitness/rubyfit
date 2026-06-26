require_relative 'validations'
require_relative 'helpers'
class RubyFit::FitFileParser
    REQUIRED_CALLBACKS = [:definition_message, :get_definition, :data_message]

    def initialize
      @definitions = {}
      @fit_data = {}
      @record_index = 0
      @plural_message_types = {lap: :laps,
                               length: :lengths,
                               hr_zone: :hr_zones,
                               pwr_zone: :pwr_zones,
                               session: :sessions,
                               event: :events,
                               record: :records,
                               course_point: :course_points,
                               device_info: :device_infos,
                               segment_lap: :segment_laps,
                               wahoo_custom_num: :wahoo_custom_nums
      }
      @use_last_message_only = [:wahoo_id, :workout]
    end

    def definition_message(local_num, global_message_number, fields, developer_fields)
      global_message_number = global_message_number.to_i
      @definitions[local_num] = { global_message_number: global_message_number, fields: fields, developer_fields: developer_fields }
    end

    def get_definition(local_num)
      @definitions[local_num] || { fields: [] }
    end

    def data_message(local_num, values, developer_values = [])
      formatted_values = values.map do |key, value|
        formatted_value = if value.is_a?(String)
                            value.bytes.map { |byte| sprintf('%02X', byte) }.join(' ')
                          else
                            value.inspect
                          end
        "#{key}: #{formatted_value}"
      end
      @fit_data[local_num] = formatted_values.join(', ')
    end


    def convert_to_json(fit_data, unpack_directive)
      big_endian = unpack_directive == 'n'
      # Define the message type to look up
      type = RubyFit::MessageConstants::MESSAGE_TYPE.find { |key, value| value == fit_data.keys.first }
      return unless type
      message_type = RubyFit::MessageConstants::MESSAGE_TYPE.find { |key, value| value == fit_data.keys.first }.first
      message_definition = RubyFit::MessageWriter::MESSAGE_DEFINITIONS[message_type]

      # Convert each field in the raw FIT data to a readable format
      readable_data = {}
      raw_values = fit_data.values.first.first
      raw_dev_values = fit_data.values.first.last if fit_data.values.first.size > 1

      # for debugging
      # known_field_ids = message_definition[:fields].map { |_, field_definition| field_definition[:id] }
      # unknown_keys = raw_values.keys - known_field_ids
      # puts("Unknown raw data for message definition #{message_type}: #{unknown_keys}") unless unknown_keys.empty?
      #

      # Iterate through the message definition fields
      message_definition[:fields].each do |field_name, field_definition|
        field_id = field_definition[:id] # This is the key we're looking for in the raw data
        field_definition[:big_endian] = big_endian

        # Check if the field ID is present in the raw FIT data
        if raw_values.key?(field_id)
          raw_value = raw_values[field_id].bytes
          readable_data[field_name] = field_definition[:type].bytes2val(raw_value, **field_definition.slice(:big_endian))
        else
          # If the field is missing, we can either skip it or set it as nil
          readable_data[field_name] = nil
        end
      end

      # Process developer fields
      if raw_dev_values
        raw_dev_values.each do |field_id, raw_value|
          # Check if the field ID exists in DEVELOPER_FIELDS
          field_name = RubyFit::MessageConstants::DEVELOPER_FIELDS.key(field_id)
          next unless field_name

          # Convert raw value to readable format
          readable_value =
            if field_id == 16
              value = raw_value.unpack1('C')
              RubyFit::MessageConstants::WAYPOINT_TYPE.value?(value) ? RubyFit::MessageConstants::WAYPOINT_TYPE.key(value) : value
            elsif field_id == 17
              raw_value.delete("\u0000").force_encoding('UTF-8')
            else
              raw_value
            end
          readable_data[field_name] = readable_value
        end
      end

      { message_type => readable_data }
    end

    def get_valid_data(fit_data, unpack_directive, raw_data)
      big_endian = unpack_directive == 'n'
      # Define the message type to look up
      type = RubyFit::MessageConstants::MESSAGE_TYPE.find { |key, value| value == fit_data.keys.first }
      return unless type
      message_type = RubyFit::MessageConstants::MESSAGE_TYPE.find { |key, value| value == fit_data.keys.first }.first
      message_definition = RubyFit::MessageWriter::MESSAGE_DEFINITIONS[message_type]

      # Convert each field in the raw FIT data to a readable format
      readable_data = {}
      raw_values = fit_data.values.first

      # for debugging
      # known_field_ids = message_definition[:fields].map { |_, field_definition| field_definition[:id] }
      # unknown_keys = raw_values.keys - known_field_ids
      # puts("Unknown raw data for message definition #{message_type}: #{unknown_keys}") unless unknown_keys.empty?
      #

      # Iterate through the message definition fields
      message_definition[:fields].each do |field_name, field_definition|
        field_id = field_definition[:id] # This is the key we're looking for in the raw data
        field_definition[:big_endian] = big_endian

        # Check if the field ID is present in the raw FIT data
        if raw_values.key?(field_id)
          raw_value = raw_values[field_id].bytes
          readable_data[field_name] = field_definition[:type].bytes2val(raw_value, **field_definition.slice(:big_endian))
        end
      end

      valid_data, modified, parsed_data = RubyFit::Validations.validate_message(message_type, readable_data, raw_data)

      [valid_data, modified, parsed_data]
    end

    # Backfill spd_mps from enhanced_spd_mps on a record. Two shapes are supported,
    # both keeping the original definition's local_num so subsequent local-num
    # bindings stay intact:
    #   1. Record has both fields, spd_mps invalid: overwrite spd_mps bytes in place.
    #   2. Record has enhanced_spd_mps but no spd_mps: convert each 4-byte enhanced
    #      slot into a 2-byte spd_mps slot. The matching definition rewrite is
    #      handled in repair_fit_file when the record definition is read.
    # Returns nil when no patch applies.
    def patch_record_spd_mps(record_header, values, developer_values, definition, unpack_directive)
      has_spd_mps_field = definition[:fields].any? { |f| f[:id] == 6 }
      enhanced_field = definition[:fields].find { |f| f[:id] == 73 }
      return nil unless enhanced_field && values[73]

      big_endian = unpack_directive == 'n'
      enhanced_val = RubyFit::Type.enhanced_speed.bytes2val(values[73].bytes, big_endian: big_endian)

      if has_spd_mps_field
        return nil unless values[6]
        spd_mps_val = RubyFit::Type.uint16_scale1000.bytes2val(values[6].bytes, big_endian: big_endian)
        return nil unless spd_mps_val.nil? && !enhanced_val.nil?
      end

      scaled = enhanced_val.nil? ? 0xFFFF : (enhanced_val * 1000).to_i.clamp(0, 0xFFFE)
      new_spd_bytes = [scaled].pack(big_endian ? 'n' : 'v')

      out = String.new(encoding: 'ASCII-8BIT')
      out << [record_header].pack('C')
      definition[:fields].each do |field|
        if has_spd_mps_field
          out << (field[:id] == 6 ? new_spd_bytes : values[field[:id]])
        else
          # enhanced_spd_mps slot becomes the spd_mps slot (4 bytes -> 2 bytes).
          out << (field[:id] == 73 ? new_spd_bytes : values[field[:id]])
        end
      end
      (definition[:developer_fields] || []).each do |field|
        out << developer_values[field[:id]]
      end
      out
    end

    # When a record's definition has enhanced_spd_mps (id 73) but no spd_mps (id 6),
    # rewrite the definition message so the enhanced_spd_mps field descriptor is
    # replaced with the spd_mps descriptor. Field descriptors are 3 bytes each, so
    # the definition's byte length is unchanged. Each subsequent record will be
    # shrunk by 2 bytes (4-byte uint32 -> 2-byte uint16) at the data-message stage.
    # Returns nil when no rewrite applies.
    def patch_record_definition_for_spd_mps(record_header, architecture, global_message_number, fields, developer_fields)
      return nil unless global_message_number == 20
      return nil if fields.any? { |f| f[:id] == 6 }
      return nil unless fields.any? { |f| f[:id] == 73 }

      big_endian = architecture == 1
      new_fields = fields.map do |f|
        f[:id] == 73 ? { id: 6, size: 2, type: 0x84 } : f
      end

      has_dev_fields = developer_fields && !developer_fields.empty?
      header = 0x40 | (record_header & 0x0F)
      header |= 0x20 if has_dev_fields

      out = String.new(encoding: 'ASCII-8BIT')
      out << [header].pack('C')
      out << [0x00].pack('C')
      out << [architecture].pack('C')
      out << [global_message_number].pack(big_endian ? 'n' : 'v')
      out << [new_fields.size].pack('C')
      new_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      if has_dev_fields
        out << [developer_fields.size].pack('C')
        developer_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      end
      out
    end

    # Overwrite the altitude field in a single record (global msg 20) data message
    # with new_alt_m (meters), preserving the rest of the record byte-for-byte.
    # Mirrors patch_record_spd_mps. Prefers enhanced_altitude (id 78, uint32) and
    # falls back to altitude (id 2, uint16); both use FIT scale 5 / offset 500, so
    # raw = (meters + 500) * 5. Field sizes come from the definition, so the record
    # length is unchanged. Returns nil when the record has no altitude field or
    # new_alt_m is nil.
    def patch_record_alt_m(record_header, values, developer_values, definition, unpack_directive, new_alt_m)
      return nil if new_alt_m.nil?

      target = definition[:fields].find { |f| f[:id] == 78 } ||
        definition[:fields].find { |f| f[:id] == 2 }
      return nil unless target && values[target[:id]]

      big_endian = unpack_directive == 'n'
      raw = ((new_alt_m + 500) * 5).round
      new_bytes = if target[:id] == 78
                    [raw.clamp(0, 0xFFFFFFFE)].pack(big_endian ? 'N' : 'V')
                  else
                    [raw.clamp(0, 0xFFFE)].pack(big_endian ? 'n' : 'v')
                  end

      out = String.new(encoding: 'ASCII-8BIT')
      out << [record_header].pack('C')
      definition[:fields].each do |field|
        out << (field[:id] == target[:id] ? new_bytes : values[field[:id]])
      end
      (definition[:developer_fields] || []).each do |field|
        out << developer_values[field[:id]]
      end
      out
    end

    # Encode new_alt_m (meters) as the 2-byte altitude raw value (FIT uint16,
    # scale 5 / offset 500: raw = (meters + 500) * 5), clamped below the 0xFFFF
    # invalid sentinel. big_endian follows the record's architecture.
    def encode_alt_m_bytes(new_alt_m, big_endian)
      raw = ((new_alt_m + 500) * 5).round.clamp(0, 0xFFFE)
      [raw].pack(big_endian ? 'n' : 'v')
    end

    # Append an altitude field descriptor (id 2, uint16, 2 bytes) to a record
    # (global msg 20) definition message that has no altitude field, so each
    # subsequent record can carry a patched altitude. Field descriptors are 3
    # bytes, so the definition grows by 3 bytes and each data record grows by 2.
    # Returns the rewritten definition bytes.
    def append_altitude_to_definition(record_header, architecture, global_message_number, fields, developer_fields)
      big_endian = architecture == 1
      new_fields = fields + [{ id: 2, size: 2, type: 0x84 }]
      has_dev_fields = developer_fields && !developer_fields.empty?

      header = 0x40 | (record_header & 0x0F)
      header |= 0x20 if has_dev_fields

      out = String.new(encoding: 'ASCII-8BIT')
      out << [header].pack('C')
      out << [0x00].pack('C')
      out << [architecture].pack('C')
      out << [global_message_number].pack(big_endian ? 'n' : 'v')
      out << [new_fields.size].pack('C')
      new_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      if has_dev_fields
        out << [developer_fields.size].pack('C')
        developer_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      end
      out
    end

    # Rebuild a record (global msg 20) data message whose definition was augmented
    # with a trailing altitude field, appending the 2-byte altitude for new_alt_m.
    # The original field bytes are preserved; the altitude bytes are inserted after
    # the regular fields and before any developer fields, matching the augmented
    # definition's field order. Returns nil when new_alt_m is nil.
    def append_record_alt_m(record_header, values, developer_values, definition, big_endian, new_alt_m)
      return nil if new_alt_m.nil?

      out = String.new(encoding: 'ASCII-8BIT')
      out << [record_header].pack('C')
      definition[:fields].each { |field| out << values[field[:id]] }
      out << encode_alt_m_bytes(new_alt_m, big_endian)
      (definition[:developer_fields] || []).each { |field| out << developer_values[field[:id]] }
      out
    end

    # Set per-record altitude (msg 20) and session/lap total ascent/descent
    # (msg 18 fields 22/23, msg 19 fields 21/22) in a single pass.
    #   * altitudes[i] (meters)            -> i-th record
    #   * session_totals[i] = [asc_m, desc_m] -> i-th session
    #   * lap_totals[i]     = [asc_m, desc_m] -> i-th lap
    # Each array is aligned to its message type's stream order; nil leaves a
    # message unchanged. When a definition already carries the target field(s) the
    # value is overwritten in place; when it has none, the field(s) are appended to
    # the definition (and bytes to each message), so the file grows. Everything
    # else is preserved. Record indexing matches #parse (only normal data-message
    # records are counted). Yields the rewritten raw bytes.
    def patch_altitudes(raw, altitudes, session_totals: [], lap_totals: [])
      modified_messages = []
      record_index = 0
      session_index = 0
      lap_index = 0
      # Per-local-number state. altitude_mode: :inplace/:append/nil. totals_spec:
      # {ascent_id:, descent_id:, missing:[ids appended to the definition]} or nil.
      altitude_mode = {}
      totals_spec_by_local = {}
      architecture_by_local = {}

      io = StringIO.new(raw)
      header = io.read(12)
      raise "Invalid FIT file: unable to read header" unless header && header.size == 12

      header_size, _protocol_version, _profile_version, data_size, data_type = header.unpack('C C v V a4')
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"

      io.seek(header_size) if io.pos < header_size

      unpack_directive = 'v'
      buffer = io.read(header_size + data_size - io.pos)
      buffer_io = StringIO.new(buffer)

      while buffer_io.pos < buffer.size
        record_start = buffer_io.pos
        record_header = buffer_io.read(1)&.unpack1('C')
        raise "Invalid FIT file: unable to read record header" unless record_header

        if record_header & 0x80 == 0x80
          # Compressed-timestamp data message: consume its bytes; not counted as a
          # record by #parse, so do not touch record_index or patch it.
          local_num = (record_header & 0x60) >> 5
          definition = get_definition(local_num)
          definition[:fields].each { |field| buffer_io.read(field[:size]) }
        elsif record_header & 0x40 == 0x40
          local_num = record_header & 0x0F
          _reserved, architecture = buffer_io.read(2).unpack('C C')
          unpack_directive = 'n' if architecture == 1
          global_message_number, field_count = buffer_io.read(3).unpack("#{unpack_directive} C")

          fields = field_count.times.map do
            field_def = buffer_io.read(3).unpack('C*')
            { id: field_def[0], size: field_def[1], type: field_def[2] }
          end
          developer_fields = if record_header & 0x20 == 0x20
                               dev_count = buffer_io.read(1).unpack1('C')
                               dev_count.times.map do
                                 fd = buffer_io.read(3).unpack('C*')
                                 { id: fd[0], size: fd[1], type: fd[2] }
                               end
                             else
                               []
                             end

          # Register the original (unmodified) definition so the data bytes
          # following it are read with the layout actually present in the file.
          definition_message(local_num, global_message_number, fields, developer_fields)

          case global_message_number
          when 20
            architecture_by_local[local_num] = architecture
            totals_spec_by_local[local_num] = nil
            has_altitude = fields.any? { |f| f[:id] == 78 || f[:id] == 2 }
            if has_altitude
              altitude_mode[local_num] = :inplace
            else
              altitude_mode[local_num] = :append
              new_def = append_altitude_to_definition(record_header, architecture, global_message_number, fields, developer_fields)
              modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: new_def }
            end
          when 18, 19
            altitude_mode[local_num] = nil
            architecture_by_local[local_num] = architecture
            ascent_id, descent_id = global_message_number == 18 ? [22, 23] : [21, 22]
            present = [ascent_id, descent_id].select { |id| fields.any? { |f| f[:id] == id } }
            missing = [ascent_id, descent_id] - present
            totals_spec_by_local[local_num] = { ascent_id: ascent_id, descent_id: descent_id, missing: missing }
            if missing.any?
              new_def = append_totals_to_definition(record_header, architecture, global_message_number, fields, developer_fields, missing)
              modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: new_def }
            end
          else
            altitude_mode[local_num] = nil
            totals_spec_by_local[local_num] = nil
          end
        else
          local_num = record_header & 0x0F
          definition = get_definition(local_num)
          raise "Unknown definition for local number #{local_num}" unless definition

          values = {}
          definition[:fields].each { |field| values[field[:id]] = buffer_io.read(field[:size]) }
          developer_values = {}
          (definition[:developer_fields] || []).each { |field| developer_values[field[:id]] = buffer_io.read(field[:size]) }

          if definition[:global_message_number] == 20
            new_alt_m = altitudes[record_index]
            patched = if altitude_mode[local_num] == :append
                        big_endian = architecture_by_local[local_num] == 1
                        append_record_alt_m(record_header, values, developer_values, definition, big_endian, new_alt_m)
                      else
                        patch_record_alt_m(record_header, values, developer_values, definition, unpack_directive, new_alt_m)
                      end
            record_index += 1
            if patched
              modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: patched }
            end
          elsif definition[:global_message_number] == 18 || definition[:global_message_number] == 19
            is_session = definition[:global_message_number] == 18
            totals = is_session ? session_totals[session_index] : lap_totals[lap_index]
            if is_session
              session_index += 1
            else
              lap_index += 1
            end

            spec = totals_spec_by_local[local_num]
            # In append mode every message of this local type MUST emit the appended
            # bytes (even when totals is nil -> invalid sentinel) to keep the layout
            # consistent with the rewritten definition.
            if spec && (spec[:missing].any? || totals)
              big_endian = architecture_by_local[local_num] == 1
              patched = patch_record_totals(record_header, values, developer_values, definition, big_endian, spec, totals && totals[0], totals && totals[1])
              if patched
                modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: patched }
              end
            end
          end
        end
      end

      yield edit_fit_file_raw(raw, [], modified_messages, [])
    end

    # Set total_ascent/total_descent (meters, uint16 scale 1) on a session/lap
    # data message. Fields already in the definition are overwritten in place;
    # fields in spec[:missing] (appended to the definition by
    # append_totals_to_definition) are appended here, in the same order, so the
    # data layout matches. A nil value writes the FIT invalid sentinel for an
    # appended field, and is left unchanged for an in-place field. Returns new
    # bytes, or nil when nothing changed.
    def patch_record_totals(record_header, values, developer_values, definition, big_endian, spec, ascent_m, descent_m)
      pack = big_endian ? 'n' : 'v'
      meters_by_id = { spec[:ascent_id] => ascent_m, spec[:descent_id] => descent_m }

      replacements = {}
      appended = []
      meters_by_id.each do |id, meters|
        if spec[:missing].include?(id)
          raw = meters ? meters.round.clamp(0, 0xFFFE) : 0xFFFF
          appended << [raw].pack(pack)
        elsif meters && values[id]
          replacements[id] = [meters.round.clamp(0, 0xFFFE)].pack(pack)
        end
      end

      return nil if replacements.empty? && appended.empty?

      out = String.new(encoding: 'ASCII-8BIT')
      out << [record_header].pack('C')
      definition[:fields].each { |field| out << (replacements[field[:id]] || values[field[:id]]) }
      appended.each { |bytes| out << bytes }
      (definition[:developer_fields] || []).each { |field| out << developer_values[field[:id]] }
      out
    end

    # Rewrite a session/lap definition message to append uint16 (type 0x84)
    # descriptors for the given missing field ids (total_ascent/total_descent),
    # mirroring append_altitude_to_definition. 3 bytes per descriptor; each data
    # message of this local type then grows by 2 bytes per appended field.
    def append_totals_to_definition(record_header, architecture, global_message_number, fields, developer_fields, missing_ids)
      big_endian = architecture == 1
      new_fields = fields + missing_ids.map { |id| { id: id, size: 2, type: 0x84 } }

      has_dev_fields = developer_fields && !developer_fields.empty?
      header = 0x40 | (record_header & 0x0F)
      header |= 0x20 if has_dev_fields

      out = String.new(encoding: 'ASCII-8BIT')
      out << [header].pack('C')
      out << [0x00].pack('C')
      out << [architecture].pack('C')
      out << [global_message_number].pack(big_endian ? 'n' : 'v')
      out << [new_fields.size].pack('C')
      new_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      if has_dev_fields
        out << [developer_fields.size].pack('C')
        developer_fields.each { |f| out << [f[:id], f[:size], f[:type]].pack('CCC') }
      end
      out
    end

    def parse(raw)
      all_data = {}
      io = StringIO.new(raw)

      header = io.read(12)
      raise "Invalid FIT file: unable to read header" unless header && header.size == 12

      header_size, protocol_version, profile_version, data_size, data_type = header.unpack('C C v V a4')
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"

      io.seek(header_size) if io.pos < header_size

      unpack_directive = 'v'
      buffer = io.read(header_size + data_size - io.pos)
      buffer_io = StringIO.new(buffer)

      while buffer_io.pos < buffer.size
        record_header = buffer_io.read(1)&.unpack1('C')
        raise "Invalid FIT file: unable to read record header" unless record_header

        if record_header & 0x80 == 0x80
          local_num = (record_header & 0x60) >> 5
          time_offset = record_header & 0x1F

          timestamp = if @previous_timestamp
                        if time_offset >= (@previous_timestamp & 0x1F)
                          (@previous_timestamp & 0xFFFFFFE0) + time_offset
                        else
                          (@previous_timestamp & 0xFFFFFFE0) + time_offset + 0x20
                        end
                      else
                        time_offset
                      end

          @previous_timestamp = timestamp

          definition = get_definition(local_num)
          raise "Unknown definition for local number #{local_num}" unless definition

          values = {}
          definition[:fields].each do |field|
            value = buffer_io.read(field[:size])
            if value.nil? || value.size < field[:size]
              puts "Warning: Missing or incomplete field value for field ID #{field[:id]}"
              next
            end
            values[field[:id]] = value
          end

          @previous_timestamp = values[253].unpack1('V') if values[253]

          data_message(local_num, values)
        else
          if record_header & 0x40 == 0x40
            local_num = record_header & 0x0F
            reserved, architecture = buffer_io.read(2).unpack('C C')
            unpack_directive = 'n' if architecture == 1
            global_message_number, field_count = buffer_io.read(3).unpack("#{unpack_directive} C")

            raise "Invalid FIT file: unable to read definition message" unless global_message_number && field_count

            fields = field_count.times.map do
              field_def = buffer_io.read(3)&.unpack('C*')
              raise "Invalid FIT file: unable to read field definition" unless field_def
              if field_def.nil? || field_def.size < 3
                next
              end
              { id: field_def[0], size: field_def[1], type: field_def[2] }
            end

            developer_fields = if record_header & 0x20 == 0x20
                                 developer_field_count = buffer_io.read(1)&.unpack1('C')
                                 developer_field_count.times.map do
                                   developer_field_def = buffer_io.read(3)&.unpack('C*')
                                   raise "Invalid FIT file: unable to read developer field definition" unless developer_field_def
                                   { id: developer_field_def[0], size: developer_field_def[1], type: developer_field_def[2] }
                                 end
                               else
                                 []
                               end

            definition_message(local_num, global_message_number, fields, developer_fields)
          else
            local_num = record_header & 0x0F
            definition = get_definition(local_num)
            raise "Unknown definition for local number #{local_num}" unless definition

            values = {}
            definition[:fields].each do |field|
              value = buffer_io.read(field[:size])
              if value.nil? || value.size < field[:size]
                puts "Warning: Missing or incomplete field value for field ID #{field[:id]}"
                next
              end
              values[field[:id]] = value
            end

            developer_values = {}
            definition[:developer_fields]&.each do |field|
              value = buffer_io.read(field[:size])
              if value.nil? || value.size < field[:size]
                puts "Warning: Missing or incomplete developer field value for field ID #{field} at #{buffer_io.pos} for parse"
                next
              end
              developer_values[field[:id]] = value
            end

            data_message(local_num, values, developer_values)
            data = convert_to_json({ definition[:global_message_number] => [values, developer_values] }, unpack_directive)

            data&.each do |key, value|
              if key == :record
                value[:sec] = @record_index
                @record_index += 1
              end

              if key == :session
                value[:workout_type_code] = RubyFit::Helpers.get_workout_type_from_sport_and_subsport(value[:sport_code], value[:sub_sport_code])
              end

              if key == :wahoo_id
                value[:workout_token] = value[:app_token] + ':' + value[:workout_num].to_s
              end

              if @plural_message_types.key?(key)
                key = @plural_message_types[key]
                all_data[key] = [] unless all_data[key].is_a?(Array)
                all_data[key] << value
              elsif key == :wahoo_clm
                key, clm = parse_clm(value)
                all_data[:CLM] ||= {}
                all_data[:CLM][key] ||= []
                all_data[:CLM][key] << clm
              elsif all_data.key?(key) && !@use_last_message_only.include?(key)
                all_data[key] = [all_data[key]] unless all_data[key].is_a?(Array)
                all_data[key] << value
              else
                all_data[key] = value
              end
            end
          end
        end
      end
      yield all_data
    end

    def parse_clm(data)
      begin
        # Convert the array of bytes into a binary string
        binary_data = data[:data].pack('C*')
        clm_id = binary_data.unpack1('S<C')

        if clm_id == 73
          # Unpack the binary data using the same format as encoding
          clm_id, wind_is_headwind, dist_m, duration_sec, pwr_watts, spd_mps, grade_perc, wind_spd_mps, wind_resist_coef, roll_resist_coef, weight_kg =
            binary_data.unpack('S<C L< S< S< S< s< S< S< S< S<')
          key = :ROUTE_COURSE_SECTOR
          clm = {
                  clm: {
                    clm_id: clm_id,
                    wind_is_headwind: wind_is_headwind == 1,
                    dist_m: dist_m / 100.0,
                    duration_sec: duration_sec,
                    pwr_watts: pwr_watts,
                    spd_mps: spd_mps / 1000.0,
                    grade_perc: grade_perc / 100.0,
                    wind_spd_mps: wind_spd_mps / 1000.0,
                    wind_resist_coef: wind_resist_coef / 1000.0,
                    roll_resist_coef: roll_resist_coef / 1000.0,
                    weight_kg: weight_kg / 10.0
                  }
                }
        elsif clm_id == 53
          provider_type = binary_data[2].ord

          provider_id_start = 3
          provider_id_end = provider_id_start
          while provider_id_end < binary_data.length && binary_data[provider_id_end].ord != 0
            provider_id_end += 1
          end
          provider_id = binary_data[provider_id_start...provider_id_end]

          percent_complete = binary_data[provider_id_end + 1].ord
          fitness_app_id   = binary_data[provider_id_end + 2, 2].unpack1('S<')

          workout_cloud_id_start = provider_id_end + 4
          workout_cloud_id_end = workout_cloud_id_start
          while workout_cloud_id_end < binary_data.length && binary_data[workout_cloud_id_end].ord != 0
            workout_cloud_id_end += 1
          end

          workout_cloud_id = binary_data[workout_cloud_id_start, workout_cloud_id_end].unpack1('L<')
          workout_cloud_id = nil if workout_cloud_id == 0xFFFFFFFF

          raw = binary_data[workout_cloud_id_end + 1..]
          raw += "\x00" if raw && raw.bytesize < 4
          plan_cloud_id = raw&.unpack1('L<')
          plan_cloud_id = nil if plan_cloud_id == 0xFFFFFFFF


          provider_id = provider_id.delete("\x00")
          key = :WORKOUT_PLAN_INFO
          clm = {
            clm: {
              provider_type: provider_type,
              provider_id: provider_id,
              fitness_app_id: fitness_app_id,
              percent_complete: percent_complete == 0xFF ? nil : percent_complete,
              plan_cloud_id: plan_cloud_id,
              workout_cloud_id: workout_cloud_id
            }
          }
        elsif clm_id == 83
          # Read encode_len (first 2 bytes, little-endian)
          encode_len = binary_data[2, 4].unpack1('S<')

          # Take a subdata slice based on encode_len (like C subdecoder)
          subdata = binary_data[4, encode_len]
          offset = 0

          # Read cloud_user_id (4 bytes) — we don't need it
          offset += 4

          # Read cloud_id (4 bytes, little-endian)
          cloud_id = subdata[offset, 4].unpack1('V')
          cloud_id = nil if cloud_id == 0xFFFFFFFF
          offset += 4

          # Skip token
          offset += 7

          # Skip update_abs_time_ms (4 bytes) + is_deleted (1 byte)
          offset += 4 + 1

          # Read location_type (1 byte)
          location_type_code = subdata[offset].ord
          location_type = case location_type_code
                          when 0 then "INDOOR"
                          when 1 then "OUTDOOR"
                          else "UNKNOWN"
                          end
          offset += 1

          # Read 4dp power fields sequentially (2 bytes each)
          power_5s  = subdata[offset, 2].unpack1('S<'); offset += 2
          power_1m  = subdata[offset, 2].unpack1('S<'); offset += 2
          power_5m  = subdata[offset, 2].unpack1('S<'); offset += 2
          power_20m = subdata[offset, 2].unpack1('S<'); offset += 2

          # Build simplified CLM JSON
          clm = {
            clm: {
              cloud_id: cloud_id,
              location_type: location_type,
              location_type_code: location_type_code,
              power_5s: power_5s == 0xFFFF ? nil : power_5s,
              power_1m: power_1m == 0xFFFF ? nil : power_1m,
              power_5m: power_5m == 0xFFFF ? nil : power_5m,
              power_20m: power_20m == 0xFFFF ? nil : power_20m
            }
          }
          key = :BIKING_PROFILE
        end
        [key, clm] || [:unknown, data]
      rescue => e
          puts "Error parsing CLM data: #{e.message}"
      end
    end


    def repair_fit_file(raw)
      invalid_offsets = [] # To store offsets and lengths of invalid messages
      modified_messages = [] # To store modified messages
      added_messages = [] # To store added messages
      original_data_info = {}

      processed_sessions = false
      processed_laps = false
      processed_workout = false
      processed_wahoo_id = false
      io = StringIO.new(raw)

      header = io.read(12)
      raise "Invalid FIT file: unable to read header" unless header && header.size == 12

      header_size, protocol_version, profile_version, data_size, data_type = header.unpack('C C v V a4')
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"

      io.seek(header_size) if io.pos < header_size

      unpack_directive = 'v'
      buffer = io.read(header_size + data_size - io.pos)
      buffer_io = StringIO.new(buffer)

      while buffer_io.pos < buffer.size
        record_start = buffer_io.pos # Track the start of the record
        record_header = buffer_io.read(1)&.unpack1('C')
        raise "Invalid FIT file: unable to read record header" unless record_header

        if record_header & 0x40 == 0x40
          local_num = record_header & 0x0F
          reserved, architecture = buffer_io.read(2).unpack('C C')
          unpack_directive = 'n' if architecture == 1
          global_message_number, field_count = buffer_io.read(3).unpack("#{unpack_directive} C")

          fields = field_count.times.map do
            field_def = buffer_io.read(3)&.unpack('C*')
            if field_def.nil? || field_def.size < 3
              next
            end
            { id: field_def[0], size: field_def[1], type: field_def[2] }
          end.compact

          developer_fields = if record_header & 0x20 == 0x20
                               developer_field_count = buffer_io.read(1)&.unpack1('C')
                               developer_field_count.times.map do
                                 developer_field_def = buffer_io.read(3)&.unpack('C*')
                                 { id: developer_field_def[0], size: developer_field_def[1], type: developer_field_def[2] }
                               end
                             else
                               []
                             end
          definition_message(local_num, global_message_number, fields, developer_fields)

          patched_def = patch_record_definition_for_spd_mps(record_header, architecture, global_message_number, fields, developer_fields)
          if patched_def
            modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: patched_def }
          end
        else
          local_num = record_header & 0x0F
          definition = get_definition(local_num)
          raise "Unknown definition for local number #{local_num}" unless definition

          truncated = false
          values = {}
          definition[:fields].each do |field|
            value = buffer_io.read(field[:size])
            if value.nil? || value.size < field[:size]
              puts "Warning: Missing or incomplete field value for field ID #{field[:id]}"
              truncated = true
              next
            end
            values[field[:id]] = value
          end

          developer_values = {}
          (definition[:developer_fields] || []).each do |field|
            value = buffer_io.read(field[:size])
            if value.nil? || value.size < field[:size]
              puts "Warning: Missing or incomplete developer field value for field ID #{field[:id]}  at #{buffer_io.pos}"
              truncated = true
              next
            end
            developer_values[field[:id]] = value
          end

          data_message(local_num, values)
          data, modified, parsed_data = get_valid_data({ definition[:global_message_number] => values }, unpack_directive, raw)
          if definition[:global_message_number] == 18
            processed_sessions = true
          end
          if definition[:global_message_number] == 19
            processed_laps = true
          end
          if definition[:global_message_number] == 26
            processed_workout = true
          end
          if definition[:global_message_number] == 65281
            processed_wahoo_id = true
          end

          if !truncated && definition[:global_message_number] == 20
            patched = patch_record_spd_mps(record_header, values, developer_values, definition, unpack_directive)
            if patched
              data = patched
              modified = true
            end
          end

          original_data_info[definition[:global_message_number]] ||= []
          original_data_info[definition[:global_message_number]] << { start: record_start, length: buffer_io.pos - record_start }

          if truncated
            # The record was cut off mid-read. Exclude it from the repaired file so that
            # bytes from any subsequently appended message are not mistakenly consumed as
            # the remainder of this incomplete record during re-parsing.
            invalid_offsets << { start: record_start, length: buffer_io.pos - record_start }
          elsif data.nil? && modified
            # Record the offset and length of the invalid message
            invalid_offsets << { start: record_start, length: buffer_io.pos - record_start }
          elsif data && modified
            modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: data, parsed_message: parsed_data }
          end
        end
      end

      added_messages, modified_messages, invalid_offsets = post_parse_repairs(raw, processed_laps, processed_sessions, added_messages, modified_messages, original_data_info, invalid_offsets, processed_workout, processed_wahoo_id)
      yield edit_fit_file_raw(raw, invalid_offsets, modified_messages, added_messages)
    end

    def post_parse_repairs(raw, processed_laps, processed_sessions, added_messages, modified_messages, original_data_info, invalid_offsets, processed_workout, processed_wahoo_id)
      parser = RubyFit::FitFileParser.new
      parser.parse(raw) do |parsed_data|
        if !processed_laps && !processed_sessions
          lap_data, session_data, modified = RubyFit::Validations.build_lap_and_session(parsed_data)
          added_messages << { new_data: lap_data } if lap_data && modified
          added_messages << { new_data: session_data } if session_data && modified
        elsif !processed_laps
          lap_data, modified = RubyFit::Validations.build_lap(parsed_data)
          added_messages << { new_data: lap_data } if lap_data && modified
        elsif !processed_sessions
          session_data, modified = RubyFit::Validations.build_session(parsed_data)
          added_messages << { new_data: session_data } if session_data && modified
        end
        activity_data, modified = RubyFit::Validations.post_parsed_activity(parsed_data)
        activity_info = original_data_info[34][0] if original_data_info[34]
        if activity_data && modified && activity_info
          added_messages << { new_data: activity_data } if activity_data && modified
          invalid_offsets << { start: activity_info[:start], length: activity_info[:length] } if invalid_offsets.empty? || !invalid_offsets.any? { |offset| offset[:start] == activity_info[:start] && offset[:length] == activity_info[:length] }
        end
        unless processed_workout
          workout_data, modified = RubyFit::Validations.build_workout(parsed_data)
          added_messages << { new_data: workout_data } if workout_data && modified
        end
        unless processed_wahoo_id
          wahoo_id_data, modified = RubyFit::Validations.build_wahoo_id(parsed_data)
          added_messages << { new_data: wahoo_id_data } if wahoo_id_data && modified
        end

        events_data, modified = RubyFit::Validations.post_parsed_events(parsed_data)
        events_info = original_data_info[21] if original_data_info[21]
        if events_data && modified && events_info && events_info.size == events_data.size
          events_data.each_with_index do |event_data, index|
            if event_data.present?
              added_messages << { new_data: event_data } if event_data && modified
              invalid_offsets << { start: events_info[index][:start], length: events_info[index][:length] } if invalid_offsets.empty? || !invalid_offsets.any? { |offset| offset[:start] == events_info[index][:start] && offset[:length] == events_info[index][:length] }
            end
          end
        end
      end
      [added_messages, modified_messages, invalid_offsets]
    end


    def edit_fit_file_raw(raw, invalid_offsets, modified_messages, added_messages)
      io = StringIO.new(raw)

      # Read and parse the header
      header = io.read(12)
      raise "Invalid FIT file: unable to read header" unless header && header.size == 12

      header_size, protocol_version, profile_version, data_size, data_type = header.unpack('C C v V a4')
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"
      # Parse the data section
      io.seek(header_size)
      buffer = io.read(data_size)
      buffer_io = StringIO.new(buffer)

      # Rebuild the data section, skipping invalid offsets
      modified_buffer = ""
      while buffer_io.pos < buffer.size
        record_start = buffer_io.pos
        record_header = buffer_io.read(1)
        break unless record_header

        # Check if this record is invalid
        invalid = invalid_offsets.find do |offset|
          record_start >= offset[:start] && record_start < (offset[:start] + offset[:length])
        end

        modified = modified_messages.find do |offset|
          record_start >= offset[:start] && record_start < (offset[:start] + offset[:length])
        end

        if invalid
          # Skip the invalid record
          buffer_io.seek(invalid[:start] + invalid[:length])
        elsif modified
          # Replace the invalid record with the modified one
          modified_buffer << modified[:new_data]
          buffer_io.seek(modified[:start] + modified[:length])
        else
          # Include the valid record
          modified_buffer << record_header
          modified_buffer << buffer_io.read(buffer_io.pos - record_start - 1)
        end
      end

      # Append added messages
      added_messages.each do |message|
        modified_buffer << message[:new_data]
      end

      # Recalculate the data size
      new_data_size = modified_buffer.bytesize

      # Update the header with the new data size
      new_header = [header_size, protocol_version, profile_version, new_data_size, data_type].pack('C C v V a4')

      # Only append a header CRC if the original file had a 14-byte header (header_size >= 14).
      # A 12-byte header has no CRC field; writing one would shift the data start by 2 bytes
      # while header_size still says 12, causing parse to read from the wrong offset.
      if header_size >= 14
        new_header_crc = RubyFit::Helpers.update_crc(0, new_header)
        new_header += [new_header_crc].pack('v')
      end

      # Recalculate the CRC for the modified data
      new_crc = RubyFit::Helpers.update_crc(0, new_header + modified_buffer)

      # Combine the new header, modified data, and CRC
      repaired_fit_file = new_header + modified_buffer + [new_crc].pack('v')

      repaired_fit_file
    end
end