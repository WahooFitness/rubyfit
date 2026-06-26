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
    json[:laps] = json[:laps].map { |lap| lap.transform_keys(&:to_sym).merge(sport_code: lap[:sport].to_sym, sub_sport_code: lap[:sub_sport].to_sym, event_code: lap[:event].to_sym, event_type_code: lap[:event_type].to_sym, lap_trigger_code: lap[:lap_trigger].to_sym) }
    json[:sessions] = json[:sessions].map { |session| session.transform_keys(&:to_sym).merge(sport_code: session[:sport].to_sym, sub_sport_code: session[:sub_sport].to_sym, event_code: session[:event].to_sym, event_type_code: session[:event_type].to_sym) }

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
        tot_timer_time_sec: (json[:tot_timer_time_sec]).to_i,
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
        tot_dist_m: (json[:total_distance] || 0),
        tot_ascent_m: (json[:total_ascent] || 0),
        time_created: (json[:created_at] || Time.now).to_i,
        start_lat_deg: (json[:first_lng] || 0),
        start_lon_deg: (json[:first_lat] || 0),
        end_lat_deg: (json[:last_lng] || 0),
        end_lon_deg: (json[:last_lat] || 0),
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
      assert_equal json_output['file_id']['manufacturer_code'], json_input['manufacturer']
      assert_equal json_output['activity']['timestamp'], Time.at(json_input['timestamp']).utc.to_s
      assert_equal json_output['activity']['tot_timer_time_sec'], json_input['tot_timer_time_sec']
      assert_equal json_output['activity']['tot_timer_time_sec'], json_input['tot_timer_time_sec']
      assert_equal json_output['activity']['local_timestamp'], Time.at(json_input['local_timestamp']).utc.to_s
      assert_equal json_output['workout']['sport_code'], RubyFit::MessageConstants::SPORT[json_input['sport'].to_sym]
      assert_equal json_output['workout']['sub_sport_code'], RubyFit::MessageConstants::SUBSPORT[json_input['sub_sport'].to_sym]
      assert_equal json_output['workout']['wkt_name'], json_input['name']
      assert_equal json_output['sport']['sport_code'], RubyFit::MessageConstants::SPORT[json_input['sport'].to_sym]
      assert_equal json_output['sport']['sub_sport_code'], RubyFit::MessageConstants::SUBSPORT[json_input['sub_sport'].to_sym]
      assert_equal json_output['wahoo_id']['app_token'], json_input['wahoo_id']['app_token']
      assert_equal json_output['wahoo_id']['workout_num'], json_input['wahoo_id']['workout_num']
      assert_equal json_output['wahoo_id']['workout_type'], json_input['wahoo_id']['workout_type']
      assert_equal json_output['records'].size, json_input['records'].size
      assert_equal json_output['records'].last['timestamp'], Time.at(json_input['records'].last['timestamp']).utc.to_s
      assert_equal json_output['records'].last['lat_deg'].round(2), json_input['records'].last['lat_deg'].round(2)
      assert_equal json_output['records'].last['lon_deg'].round(2), json_input['records'].last['lon_deg'].round(2)
      assert_equal json_output['records'].last['dist_m'].round(2), json_input['records'].last['dist_m'].round(2)
      assert_equal json_output['records'].last['alt_m'].round(2), json_input['records'].last['alt_m'].round(2)
      assert_equal json_output['records'].last['hr_bpm'], json_input['records'].last['hr_bpm']
      assert_equal json_output['records'].last['cad_rpm'], json_input['records'].last['cad_rpm']
      assert_equal json_output['records'].last['pwr_watts'], json_input['records'].last['pwr_watts']
      assert_equal json_output['records'].last['enhanced_spd_mps'], json_input['records'].last['enhanced_spd_mps']
      assert_equal json_output['records'].last['batt_soc_perc'], json_input['records'].last['batt_soc_perc']
      assert_equal json_output['records'].last['grade_perc'], json_input['records'].last['grade_perc']
      assert_equal json_output['laps'].size, json_input['laps'].size
      assert_equal json_output['laps'].last['start_time'], Time.at(json_input['laps'].last['start_time']).utc.to_s
      assert_equal json_output['laps'].last['tot_timer_time_sec'], json_input['laps'].last['tot_timer_time_sec']
      assert_equal json_output['laps'].last['tot_dist_m'], json_input['laps'].last['tot_dist_m']
      assert_equal json_output['laps'].last['tot_ascent_m'], json_input['laps'].last['tot_ascent_m']
      assert_equal json_output['laps'].last['sport_code'], RubyFit::MessageConstants::SPORT[json_input['laps'].last['sport'].to_sym]
      assert_equal json_output['laps'].last['sub_sport_code'], RubyFit::MessageConstants::SUBSPORT[json_input['laps'].last['sub_sport'].to_sym]
      assert_equal json_output['laps'].last['tot_cal'], json_input['laps'].last['tot_cal']
      assert_equal json_output['laps'].last['event_code'], RubyFit::MessageConstants::EVENT[json_input['laps'].last['event'].to_sym]
      assert_equal json_output['laps'].last['event_type_code'], RubyFit::MessageConstants::EVENT_TYPE[json_input['laps'].last['event_type'].to_sym]
      assert_equal json_output['laps'].last['lap_trigger_code'], RubyFit::MessageConstants::LAP_TRIGGER[json_input['laps'].last['lap_trigger'].to_sym]
      assert_equal json_output['laps'].last['time_in_hr_zone_sec'], json_input['laps'].last['time_in_hr_zone_sec']
      assert_equal json_output['sessions'].size, json_input['sessions'].size
      assert_equal json_output['sessions'].last['start_time'], Time.at(json_input['sessions'].last['start_time']).utc.to_s
      assert_equal json_output['sessions'].last['tot_timer_time_sec'], json_input['sessions'].last['tot_timer_time_sec']
      assert_equal json_output['sessions'].last['tot_dist_m'], json_input['sessions'].last['tot_dist_m']
      assert_equal json_output['sessions'].last['tot_ascent_m'], json_input['sessions'].last['tot_ascent_m']
      assert_equal json_output['sessions'].last['tot_cal'], json_input['sessions'].last['tot_cal']
      assert_equal json_output['sessions'].last['sport_code'], RubyFit::MessageConstants::SPORT[json_input['sessions'].last['sport'].to_sym]
      assert_equal json_output['sessions'].last['sub_sport_code'], RubyFit::MessageConstants::SUBSPORT[json_input['sessions'].last['sub_sport'].to_sym]
      assert_equal json_output['sessions'].last['event_code'], RubyFit::MessageConstants::EVENT[json_input['sessions'].last['event'].to_sym]
      assert_equal json_output['sessions'].last['event_type_code'], RubyFit::MessageConstants::EVENT_TYPE[json_input['sessions'].last['event_type'].to_sym]
      assert_equal json_output['device_infos'].size, json_input['device_infos'].size
      assert_equal json_output['device_infos'].last['timestamp'], Time.at(json_input['device_infos'].last['timestamp']).utc.to_s
      assert_equal json_output['device_infos'].last['serial_number'], json_input['device_infos'].last['serial_number']
      assert_equal json_output['device_infos'].last['manufacturer_code'], json_input['device_infos'].last['manufacturer_code']
      assert_equal json_output['device_infos'].last['product'], json_input['device_infos'].last['product']
      assert_equal json_output['device_infos'].last['software_version'], json_input['device_infos'].last['software_version']
      assert_equal json_output['device_infos'].last['device_index'], json_input['device_infos'].last['device_index']
    end
  end
end