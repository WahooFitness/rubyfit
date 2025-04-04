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

    writer = RubyFit::Writer.new
    File.open(fit_file_path, 'wb') do |file|
      writer.write(file, {
        start_time: (json['start_time'] || Time.now).to_i,
        duration: json['duration'].to_i || 0,
        course_point_count: (json['course_points']&.size || 0).to_i,
        track_point_count: (json['track_points']&.size || 0).to_i,
        name: json['name'] || 'unnamed',
        tot_dist_m: (json['distance'] || 0),
        tot_ascent_m: (json['ascent'] || 0),
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
    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_input = JSON.parse(json_input)
      assert_equal(json_input['track_points'].size, data[:records].size)
      assert_equal(json_input['course_points'].size, data[:course_points].size)
    end
  end
end