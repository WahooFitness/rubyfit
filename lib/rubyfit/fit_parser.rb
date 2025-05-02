require_relative 'validations'
require_relative 'helpers'
class RubyFit::FitFileParser
    REQUIRED_CALLBACKS = [:definition_message, :get_definition, :data_message]

    def initialize
      @definitions = {}
      @fit_data = {}
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
    end

    def definition_message(local_num, global_message_number, fields, developer_fields)
      global_message_number = global_message_number.to_i
      @definitions[local_num] = { global_message_number: global_message_number, fields: fields, developer_fields: developer_fields }
    end

    def get_definition(local_num)
      @definitions[local_num] || { fields: [] }
    end

    def data_message(local_num, values)
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
      # puts("message type: #{fit_data.keys.first}")
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
        else
          # If the field is missing, we can either skip it or set it as nil
          readable_data[field_name] = nil
        end
      end
      { message_type => readable_data }
    end

    def get_valid_data(fit_data, unpack_directive)
      big_endian = unpack_directive == 'n'
      # Define the message type to look up
      type = RubyFit::MessageConstants::MESSAGE_TYPE.find { |key, value| value == fit_data.keys.first }
      # puts("message type: #{fit_data.keys.first}")
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

      valid_data, modified = RubyFit::Validations.validate_message(message_type, readable_data)

      [valid_data, modified]
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
                puts "Warning: Missing or incomplete developer field value for field ID #{field[:id]}"
                next
              end
              developer_values[field[:id]] = value
            end

            data_message(local_num, values)
            data = convert_to_json({ definition[:global_message_number] => values }, unpack_directive)

            data&.each do |key, value|
              if @plural_message_types.key?(key)
                key = @plural_message_types[key]
                all_data[key] = [] unless all_data[key].is_a?(Array)
                all_data[key] << value
              elsif all_data.key?(key)
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


    def repair_fit_file(raw)
      invalid_offsets = [] # To store offsets and lengths of invalid messages
      modified_messages = [] # To store modified messages
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
            { id: field_def[0], size: field_def[1], type: field_def[2] }
          end

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
              puts "Warning: Missing or incomplete developer field value for field ID #{field[:id]}"
              next
            end
            developer_values[field[:id]] = value
          end

          data_message(local_num, values)
          data, modified = get_valid_data({ definition[:global_message_number] => values }, unpack_directive)
          if data.nil? && modified
            # Record the offset and length of the invalid message
            invalid_offsets << { start: record_start, length: buffer_io.pos - record_start }
          elsif data && modified
            modified_messages << { start: record_start, length: buffer_io.pos - record_start, new_data: data }
          end
        end
      end

      # Pass invalid_offsets to the edit_fit_file_raw function
      yield edit_fit_file_raw(raw, invalid_offsets, modified_messages)
    end


    def edit_fit_file_raw(raw, invalid_offsets, modified_messages)
      io = StringIO.new(raw)

      # Read and parse the header
      header = io.read(12)
      raise "Invalid FIT file: unable to read header" unless header && header.size == 12

      header_size, protocol_version, profile_version, data_size, data_type = header.unpack('C C v V a4')
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"
      puts("Header size: #{header_size}, Protocol version: #{protocol_version}, Profile version: #{profile_version}, Data size: #{data_size}, Data type: #{data_type}")
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

      # Recalculate the data size
      new_data_size = modified_buffer.bytesize

      # Update the header with the new data size
      new_header = [header_size, protocol_version, profile_version, new_data_size, data_type].pack('C C v V a4')

      new_header_crc = RubyFit::Helpers.update_crc(0, new_header)
      new_header += [new_header_crc].pack('v')

      # Recalculate the CRC for the modified data
      new_crc = RubyFit::Helpers.update_crc(0, new_header + modified_buffer)

      # Combine the new header, modified data, and CRC
      repaired_fit_file = new_header + modified_buffer + [new_crc].pack('v')

      repaired_fit_file
    end
end