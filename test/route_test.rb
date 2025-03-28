require 'minitest/autorun'
require 'json'
require_relative '../lib/rubyfit/writer'
require_relative '../lib/rubyfit/message_constants'
require_relative '../lib/rubyfit/fit_parser'
require_relative '../examples/fit_callbacks'
class RubyFitIntegrationTest < Minitest::Test
  def test_integration
    json_input = File.read('test/fixtures/example_route_json.json')
    fit_file_path = 'route.fit'
    json = JSON.parse(json_input, symbolize_names: false)

    sport = RubyFit::MessageConstants::SPORT.key(json['sport_code'])
    subsport = RubyFit::MessageConstants::SUBSPORT.key(json['subsport_code']) || :generic
    puts("subby", subsport, sport)


    writer = RubyFit::Writer.new
    File.open(fit_file_path, 'wb') do |file|
      writer.write(file, {
        start_time: (json['start_time'] || Time.now).to_i,
        duration: json['duration'].to_i || 0,
        course_point_count: (json['course_points']&.size || 0).to_i,
        track_point_count: (json['track_points']&.size || 0).to_i,
        name: json['name'] || 'unnamed',
        total_distance: (json['distance'] || 0),
        total_ascent: (json['ascent'] / 5.0 - 500 || 0),
        time_created: (json['created_at'] || Time.now).to_i,
        start_x: (json['first_lng'] || 0),
        start_y: (json['first_lat'] || 0),
        end_x: (json['last_lng'] || 0),
        end_y: (json['last_lat'] || 0),
        manufacturer: json['manufacturer_code'] || 32,
        product: json['product'] || 0,
        sport: sport,
        subsport: subsport
      }) do
        writer.track_points do
          json['track_points']&.each do |record|
            record = record.transform_keys(&:to_sym)
            writer.track_point(record)
          end
        end

        writer.course_points do
          json['course_points']&.each do |point|
            point = point.transform_keys(&:to_sym).merge(type: point['type'].to_sym)
            writer.course_point(point)
          end
        end
      end
    end

    raw = IO.read(fit_file_path)

    definitions = {}
    fit_data = {}

    callbacks = {
      definition_message: ->(local_num, global_message_number, fields, developer_fields) {
        global_message_number = global_message_number.to_i
        # Store the definition for the local number
        definitions[local_num] = { global_message_number: global_message_number, fields: fields, developer_fields: developer_fields }
      },
      get_definition: ->(local_num) {
        # Retrieve the definition for the local number
        definitions[local_num] || { fields: [] }
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

        fit_data[local_num] = formatted_values.join(', ')
      },
      end_of_file: -> {
        File.open('fit_data.json', 'r') do |file|
          json_output = JSON.parse(file.read)
          json_input = JSON.parse(json_input)

          assert_equal(json_input['track_points'].size, json_output['record'].size)
          assert_equal(json_input['course_points'].size, json_output['course_point'].size)
          puts(json_output)
        end
      }
    }
    parser = RubyFit::FitParser.new(callbacks)
    parser.parse(raw)
  end
end