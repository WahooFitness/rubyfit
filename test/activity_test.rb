require 'minitest/autorun'
require 'json'
# require "rubyfit/message_writer"
# require "rubyfit/writer"
require_relative '../lib/rubyfit/writer'
require_relative '../lib/rubyfit/message_constants'
require_relative '../lib/rubyfit/fit_parser'
require_relative '../examples/fit_callbacks'
class RubyFitIntegrationTest < Minitest::Test
  def test_rubyfit_integration
    json_input = File.read('test/fixtures/example_activity_json.json')
    fit_file_path = 'output.fit'

    # Parse JSON input
    json = JSON.parse(json_input, symbolize_names: true)
    json[:laps] = json[:laps].map { |lap| lap.transform_keys(&:to_sym).merge(sport: lap[:sport].to_sym, sub_sport: lap[:sub_sport].to_sym, event: lap[:event].to_sym, event_type: lap[:event_type].to_sym, lap_trigger: lap[:lap_trigger].to_sym) }
    json[:sessions] = json[:sessions].map { |session| session.transform_keys(&:to_sym).merge(sport: session[:sport].to_sym, sub_sport: session[:sub_sport].to_sym, event: session[:event].to_sym, event_type: session[:event_type].to_sym) }

    # Write FIT file
    writer = RubyFit::Writer.new
    File.open(fit_file_path, 'wb') do |file|
      writer.write_activity_file(file, {
        start_time: (json[:start_time]).to_i,
        include_wahoo_id: 1,
        app_token: json[:wahoo_id][:app_token],
        workout_num: json[:wahoo_id][:workout_num],
        workout_type: json[:wahoo_id][:workout_type],
        timestamp: (json[:timestamp]).to_i,
        total_timer_time: (json[:total_timer_time]).to_i,
        local_timestamp: (json[:local_timestamp]).to_i,
        duration: json[:duration].to_i || 0,
        sessions_count: (json[:sessions]&.size).to_i,
        lap_count: (json[:laps]&.size).to_i,
        power_zone_count: json[:power_zones]&.size || 0,
        hr_zone_count: json[:hr_zones]&.size || 0,
        length_count: json[:lengths]&.size || 0,
        record_count: json[:records]&.size || 0,
        device_info_count: json[:device_infos]&.size || 0,
        wahoo_custom_num_count: json[:wahoo_custom_nums]&.size || 0,
        wahoo_clm_count: json[:wahoo_clms]&.size || 0,
        name: json[:name] || 'unnamed',
        total_distance: (json[:total_distance] || 0),
        total_ascent: (json[:total_ascent] || 0),
        time_created: (json[:created_at] || Time.now).to_i,
        start_x: (json[:first_lng] || 0),
        start_y: (json[:first_lat] || 0),
        end_x: (json[:last_lng] || 0),
        end_y: (json[:last_lat] || 0),
        manufacturer: json[:manufacturer],
        product: 1,
        product_name: json[:product_name] || 'unnamed',
        sport: json[:sport]&.downcase&.to_sym,
        subsport: json[:sub_sport]&.downcase&.to_sym,
        intensity: json[:intensity] || 0,
        session_count: json[:sessions]&.size || 0,
        total_calories: json[:calories] || 0,
        workout_step_count: json[:workout_steps]&.size || 0,
        num_valid_steps: json[:num_valid_steps] || 0,
        event_count: 0,
        type: :generic,
        event: :activity,
        event_type: :stop
      }) do
        writer.records do
          json[:records]&.each do |record|
            writer.record(record)
          end
        end
        writer.laps do
          json[:laps]&.each do |lap|
            writer.lap(lap)
          end
        end
        writer.sessions do
          json[:sessions]&.each do |session|
            writer.session(session)
          end
        end
        writer.lengths do
          json[:lengths]&.each do |length|
            writer.length(length)
          end
        end
        writer.hr_zones do
          json[:hr_zones]&.each do |zone|
            writer.hr_zone(zone)
          end
        end
        writer.power_zones do
          json[:power_zones]&.each do |zone|
            writer.power_zone(zone)
          end
        end
        writer.device_infos do
          json[:device_infos]&.each do |device|
            writer.device_info(device)
          end
        end
        writer.wahoo_custom_nums do
          json[:wahoo_custom_nums]&.each do |num|
            writer.wahoo_custom_num(num)
          end
        end
        writer.wahoo_clms do
          json[:wahoo_clms]&.each do |clm|
            writer.wahoo_clm(clm)
          end
        end
      end
    end

    # Read FIT file
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      json_input = JSON.parse(json_input)
      assert_equal json_output['file_id']['manufacturer'], json_input['manufacturer']
      assert_equal json_output['activity']['timestamp'], json_input['timestamp']
      assert_equal json_output['activity']['total_timer_time'], json_input['total_timer_time']
      assert_equal json_output['activity']['total_timer_time'], json_input['total_timer_time']
      assert_equal json_output['activity']['local_timestamp'], json_input['local_timestamp']
      assert_equal json_output['workout']['sport'], RubyFit::MessageConstants::SPORT[json_input['sport'].to_sym]
      assert_equal json_output['workout']['sub_sport'], RubyFit::MessageConstants::SUBSPORT[json_input['sub_sport'].to_sym]
      assert_equal json_output['workout']['wkt_name'], json_input['name']
      assert_equal json_output['sport']['sport'], RubyFit::MessageConstants::SPORT[json_input['sport'].to_sym]
      assert_equal json_output['sport']['sub_sport'], RubyFit::MessageConstants::SUBSPORT[json_input['sub_sport'].to_sym]
      assert_equal json_output['wahoo_id']['app_token'], json_input['wahoo_id']['app_token']
      assert_equal json_output['wahoo_id']['workout_num'], json_input['wahoo_id']['workout_num']
      assert_equal json_output['wahoo_id']['workout_type'], json_input['wahoo_id']['workout_type']
      if json_input['records'].size > 1
        assert_equal json_output['records'].size, json_input['records'].size
        assert_equal json_output['records'].last['timestamp'], json_input['records'].last['timestamp']
        assert_equal json_output['records'].last['y'].round(2), json_input['records'].last['y'].round(2)
        assert_equal json_output['records'].last['x'].round(2), json_input['records'].last['x'].round(2)
        assert_equal json_output['records'].last['distance'].round(2), json_input['records'].last['distance'].round(2)
        assert_equal json_output['records'].last['elevation'].round(2), json_input['records'].last['elevation'].round(2)
        assert_equal json_output['records'].last['heart_rate'], json_input['records'].last['heart_rate']
        assert_equal json_output['records'].last['cadence'], json_input['records'].last['cadence']
        assert_equal json_output['records'].last['power'], json_input['records'].last['power']
        assert_equal json_output['records'].last['enhanced_speed'], json_input['records'].last['enhanced_speed']
        assert_equal json_output['records'].last['battery_soc'], json_input['records'].last['battery_soc']
        assert_equal json_output['records'].last['grade'], json_input['records'].last['grade']
      elsif json_input['records'].size > 0
        assert_equal json_output['record']['timestamp'], json_input['records'].last['timestamp']
        assert_equal json_output['record']['y'].round(2), json_input['records'].last['y'].round(2)
        assert_equal json_output['record']['x'].round(2), json_input['records'].last['x'].round(2)
        assert_equal json_output['record'].last['distance'].round(2), json_input['records'].last['distance'].round(2)
        assert_equal json_output['record'].last['elevation'].round(2), json_input['records'].last['elevation'].round(2)
        assert_equal json_output['record']['heart_rate'], json_input['records'].last['heart_rate']
        assert_equal json_output['record']['cadence'], json_input['records'].last['cadence']
        assert_equal json_output['record']['power'], json_input['records'].last['power']
        assert_equal json_output['record']['enhanced_speed'], json_input['records'].last['enhanced_speed']
        assert_equal json_output['record']['battery_soc'], json_input['records'].last['battery_soc']
        assert_equal json_output['record']['grade'], json_input['records'].last['grade']

      end
      if json_input['laps'].size > 1
        assert_equal json_output['laps'].size, json_input['laps'].size
        assert_equal json_output['laps'].last['start_time'], json_input['laps'].last['start_time']
        assert_equal json_output['laps'].last['total_timer_time'], json_input['laps'].last['total_timer_time']
        assert_equal json_output['laps'].last['total_distance'], json_input['laps'].last['total_distance']
        assert_equal json_output['laps'].last['total_ascent'], json_input['laps'].last['total_ascent']
        assert_equal json_output['laps'].last['sport'], RubyFit::MessageConstants::SPORT[json_input['laps'].last['sport'].to_sym]
        assert_equal json_output['laps'].last['sub_sport'], RubyFit::MessageConstants::SUBSPORT[json_input['laps'].last['sub_sport'].to_sym]
        assert_equal json_output['laps'].last['total_calories'], json_input['laps'].last['total_calories']
        assert_equal json_output['laps'].last['event'], RubyFit::MessageConstants::EVENT[json_input['laps'].last['event'].to_sym]
        assert_equal json_output['laps'].last['event_type'], RubyFit::MessageConstants::EVENT_TYPE[json_input['laps'].last['event_type'].to_sym]
        assert_equal json_output['laps'].last['lap_trigger'], RubyFit::MessageConstants::LAP_TRIGGER[json_input['laps'].last['lap_trigger'].to_sym]
      elsif json_input['laps'].size > 0
        assert_equal json_output['lap']['start_time'], json_input['laps'].last['start_time']
        assert_equal json_output['lap']['total_timer_time'], json_input['laps'].last['total_timer_time']
        assert_equal json_output['lap']['total_distance'], json_input['laps'].last['total_distance']
        assert_equal json_output['lap']['total_ascent'], json_input['laps'].last['total_ascent']
        assert_equal json_output['lap'].last['total_calories'], json_input['laps'].last['total_calories']
        assert_equal json_output['lap'].last['sport'], RubyFit::MessageConstants::SPORT[json_input['laps'].last['sport'].to_sym]
        assert_equal json_output['lap'].last['sub_sport'],  RubyFit::MessageConstants::SUBSPORT[json_input['laps'].last['sub_sport'].to_sym]
        assert_equal json_output['lap'].last['event'], RubyFit::MessageConstants::EVENT[json_input['laps'].last['event'].to_sym]
        assert_equal json_output['lap'].last['event_type'], RubyFit::MessageConstants::EVENT_TYPE[json_input['laps'].last['event_type'].to_sym]
        assert_equal json_output['lap'].last['lap_trigger'], RubyFit::MessageConstants::LAP_TRIGGER[json_input['laps'].last['lap_trigger'].to_sym]
      end
      if json_input['sessions'].size > 1
        assert_equal json_output['sessions'].size, json_input['sessions'].size
        assert_equal json_output['sessions'].last['start_time'], json_input['sessions'].last['start_time']
        assert_equal json_output['sessions'].last['total_timer_time'], json_input['sessions'].last['total_timer_time']
        assert_equal json_output['sessions'].last['total_distance'], json_input['sessions'].last['total_distance']
        assert_equal json_output['sessions'].last['total_ascent'], json_input['sessions'].last['total_ascent']
        assert_equal json_output['sessions'].last['total_calories'], json_input['sessions'].last['total_calories']
        assert_equal json_output['sessions'].last['sport'], RubyFit::MessageConstants::SPORT[json_input['sessions'].last['sport'].to_sym]
        assert_equal json_output['sessions'].last['sub_sport'], RubyFit::MessageConstants::SUBSPORT[json_input['sessions'].last['sub_sport'].to_sym]
        assert_equal json_output['sessions'].last['event'], RubyFit::MessageConstants::EVENT[json_input['sessions'].last['event'].to_sym]
        assert_equal json_output['sessions'].last['event_type'], RubyFit::MessageConstants::EVENT_TYPE[json_input['sessions'].last['event_type'].to_sym]
      elsif json_input['sessions'].size > 0
        assert_equal json_output['session']['start_time'], json_input['sessions'].last['start_time']
        assert_equal json_output['session']['total_timer_time'], json_input['sessions'].last['total_timer_time']
        assert_equal json_output['session']['total_distance'], json_input['sessions'].last['total_distance']
        assert_equal json_output['session']['sport'], RubyFit::MessageConstants::SPORT[json_input['sessions'].last['sport'].to_sym]
        assert_equal json_output['session']['sub_sport'], RubyFit::MessageConstants::SUBSPORT[json_input['sessions'].last['sub_sport'].to_sym]
        assert_equal json_output['session']['total_ascent'], json_input['sessions'].last['total_ascent']
        assert_equal json_output['session']['total_calories'], json_input['sessions'].last['total_calories']
        assert_equal json_output['session']['event'], RubyFit::MessageConstants::EVENT[json_input['sessions'].last['event'].to_sym]
        assert_equal json_output['session']['event_type'], RubyFit::MessageConstants::EVENT_TYPE[json_input['sessions'].last['event_type'].to_sym]
      end
      if json_input['device_infos'].size > 1
        assert_equal json_output['device_infos'].size, json_input['device_infos'].size
        assert_equal json_output['device_infos'].last['timestamp'], json_input['device_infos'].last['timestamp']
        assert_equal json_output['device_infos'].last['serial_number'], json_input['device_infos'].last['serial_number']
        assert_equal json_output['device_infos'].last['manufacturer'], json_input['device_infos'].last['manufacturer']
        assert_equal json_output['device_infos'].last['product'], json_input['device_infos'].last['product']
        assert_equal json_output['device_infos'].last['software_version'], json_input['device_infos'].last['software_version']
        assert_equal json_output['device_infos'].last['battery_voltage'], json_input['device_infos'].last['battery_voltage']
        assert_equal json_output['device_infos'].last['device_index'], json_input['device_infos'].last['device_index']
      elsif json_input['device_infos'].size > 0
        assert_equal json_output['device_info']['timestamp'], json_input['device_infos'].last['timestamp']
        assert_equal json_output['device_info']['serial_number'], json_input['device_infos'].last['serial_number']
        assert_equal json_output['device_info']['manufacturer'], json_input['device_infos'].last['manufacturer']
        assert_equal json_output['device_info']['product'], json_input['device_infos'].last['product']
        assert_equal json_output['device_info']['software_version'], json_input['device_infos'].last['software_version']
        assert_equal json_output['device_info']['device_index'], json_input['device_infos'].last['device_index']
      end
    end
  end
end