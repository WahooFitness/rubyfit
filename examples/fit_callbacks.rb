class FitCallbacks
  attr_reader :definitions, :fit_data

  def initialize
    @definitions = {}
    @fit_data = {}
  end

  callbacks = {
    definition_message: ->(local_num, global_message_number, fields, developer_fields) {
      global_message_number = global_message_number.to_i
      # Store the definition for the local number
      @definitions[local_num] = { global_message_number: global_message_number, fields: fields, developer_fields: developer_fields }
    },
    get_definition: ->(local_num) {
      # Retrieve the definition for the local number
      @definitions[local_num] || { fields: [] }
    },
    data_message: ->(local_num, values) {

      formatted_values = values.map do |key, value|
        formatted_value = if value.is_a?(String)
                            value.bytes.map { |byte| sprintf('%02X', byte) }.join(' ')  # For byte arrays, convert each byte to hex
                          else
                            value.inspect  # For non-byte arrays, just inspect the value
                          end
        "#{key}: #{formatted_value}"

      end

      @fit_data[local_num] = formatted_values.join(', ')
    },
    end_of_file: -> {
      File.open('fit_data.json', 'r') do |file|
        json_output = JSON.parse(file.read)
        json_input = JSON.parse(json_input)
      end
    }
  }
end
