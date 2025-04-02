class RubyFit::FitFileParser
    REQUIRED_CALLBACKS = [:definition_message, :get_definition, :data_message]

    def initialize
      @definitions = {}
      @fit_data = {}
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
      # puts("Unknown message type: #{fit_data.keys.first}") unless type
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


    def parse(raw)
      # json_file = File.open("fit_data.json", "w")
      all_data = {}
      io = StringIO.new(raw)

      header_size = io.read(1)&.unpack1('C')
      raise "Invalid FIT file: unable to read header size" unless header_size

      protocol_version = io.read(1)&.unpack1('C')
      raise "Invalid FIT file: unable to read protocol version" unless protocol_version

      profile_version = io.read(2)&.unpack('v')&.first
      raise "Invalid FIT file: unable to read profile version" unless profile_version

      data_size = io.read(4)&.unpack('V')&.first
      raise "Invalid FIT file: unable to read data size" unless data_size

      data_type = io.read(4)
      raise "Invalid FIT file: invalid data type" unless data_type == ".FIT"

      if io.pos < header_size
        io.seek(header_size)
      end

      unpack_directive = 'v'
      while io.pos < header_size + data_size
        record_header = io.read(1)&.unpack1('C')
        raise "Invalid FIT file: unable to read record header" unless record_header

        if record_header & 0x80 == 0x80
          # Handle compressed timestamp header
          local_num = (record_header & 0x60) >> 5
          time_offset = record_header & 0x1F

          # Calculate timestamp with respect to the previous timestamp
          if @previous_timestamp
            if time_offset >= (@previous_timestamp & 0x1F)
              timestamp = (@previous_timestamp & 0xFFFFFFE0) + time_offset
            else
              timestamp = (@previous_timestamp & 0xFFFFFFE0) + time_offset + 0x20
            end
          else
            timestamp = time_offset
          end

          @previous_timestamp = timestamp

          definition = get_definition(local_num)
          raise "Unknown definition for local number #{local_num}" unless definition

          values = {}
          definition[:fields].each do |field|
            value = io.read(field[:size])
            if value.nil? || value.size < field[:size]
              puts "Warning: Missing or incomplete field value for field ID #{field[:id]}"
              next
            else
              values[field[:id]] = value
            end
          end

          # Check if the data message contains a timestamp (id: 253)
          if values[253]
            @previous_timestamp = values[253].unpack1('V')
          end

          data_message(local_num, values)
        else
          # Check if the record is a definition message by looking at the seventh bit (1 for definition, 0 for data)
          if record_header & 0x40 == 0x40
            local_num = record_header & 0x0F
            reserved = io.read(1)
            architecture = io.read(1)&.unpack1('C')

            if architecture == 1
              unpack_directive = 'n'
            end
            global_message_number = io.read(2)&.unpack(unpack_directive)&.first
            field_count = io.read(1)&.unpack1('C')

            raise "Invalid FIT file: unable to read definition message" unless architecture && global_message_number && field_count

            fields = []
            field_count.times do
              field_def = io.read(3)&.unpack('C*')
              raise "Invalid FIT file: unable to read field definition" unless field_def
              fields << { id: field_def[0], size: field_def[1], type: field_def[2] }
            end

            # developer data flag is set
            developer_fields = []
            if (record_header & 0x20) == 0x20
              developer_field_count = io.read(1)&.unpack1('C')
              developer_field_count.times do
                developer_field_def = io.read(3)&.unpack('C*')
                raise "Invalid FIT file: unable to read developer field definition" unless developer_field_def
                developer_fields << { id: developer_field_def[0], size: developer_field_def[1], type: developer_field_def[2] }
              end
            end


            definition_message(local_num, global_message_number, fields, developer_fields)
          else
            # Data Message
            local_num = record_header & 0x0F
            definition = get_definition(local_num)
            raise "Unknown definition for local number #{local_num}" unless definition

            values = {}
            definition[:fields].each do |field|
              value = io.read(field[:size])
              if value.nil? || value.size < field[:size]
                puts "Warning: Missing or incomplete field value for field ID #{field[:id]}"
                next
              end
              values[field[:id]] = value
            end

            developer_values = {}
            definition[:developer_fields]&.each do |field|
              value = io.read(field[:size])
              if value.nil? || value.size < field[:size]
                puts "Warning: Missing or incomplete developer field value for field ID #{field[:id]}"
                next
              end
              developer_values[field[:id]] = value
            end

            data_message(local_num, values)
            data = self.convert_to_json({ definition[:global_message_number] => values }, unpack_directive)

            data&.each do |key, value|
              if all_data.key?(key)
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

    def parse2(raw)
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
              if all_data.key?(key)
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

    def parse3(raw)
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

          definition = @definitions[local_num] || { fields: [] }
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

          formatted_values = values.map do |key, value|
            formatted_value = if value.is_a?(String)
                                value.bytes.map { |byte| sprintf('%02X', byte) }.join(' ')
                              else
                                value.inspect
                              end
            "#{key}: #{formatted_value}"
          end
          @fit_data[local_num] = formatted_values.join(', ')
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

            @definitions[local_num] = { global_message_number: global_message_number, fields: fields, developer_fields: developer_fields }
          else
            local_num = record_header & 0x0F
            definition = @definitions[local_num] || { fields: [] }
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

            formatted_values = values.map do |key, value|
              formatted_value = if value.is_a?(String)
                                  value.bytes.map { |byte| sprintf('%02X', byte) }.join(' ')
                                else
                                  value.inspect
                                end
              "#{key}: #{formatted_value}"
            end
            @fit_data[local_num] = formatted_values.join(', ')

            data = convert_to_json({ definition[:global_message_number] => values }, unpack_directive)

            data&.each do |key, value|
              if all_data.key?(key)
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
end