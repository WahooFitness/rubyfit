require 'minitest/autorun'
require 'json'
require_relative '../lib/rubyfit/writer'
require_relative '../lib/rubyfit/message_constants'
require_relative '../lib/rubyfit/fit_parser'
require_relative '../examples/fit_callbacks'
require_relative '../lib/rubyfit/helpers'
class FitParserTest < Minitest::Test
  def test_extremely_large_file
    start = Time.now
    fit_file_path = 'test/fixtures/2025-03-29-143824-ELEMNT_BOLT_EAB9-2-0.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_output = data
    end
    finish = Time.now
    puts("Time to load test: #{finish - start}")
  end

  def test_little_endian_file_decoding
    fit_file_path = 'test/fixtures/2025-01-03-143057-WAHOOAPPIOS62BB-3-0.fit'
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|

      json_output = JSON.parse(data.to_json)

      assert_equal(32, json_output['file_id']['manufacturer_code'])
      assert_equal(4, json_output['file_id']['type_code'])
      assert_equal(0, json_output['file_id']['product'])
      assert_equal("2025-01-03 14:30:57 UTC", json_output['file_id']['time_created'])

      assert_equal("2025-01-03 14:35:05 UTC", json_output['activity']['timestamp'])
      assert_equal(247.886, json_output['activity']['tot_timer_time_sec'])
      assert_equal(1, json_output['activity']['num_sessions'])
      assert_equal(26, json_output['activity']['event_code'])
      assert_equal(1, json_output['activity']['event_type_code'])

      assert_equal(2, json_output['workout'][0]['sport_code'])
      assert_equal(6, json_output['workout'][0]['sub_sport_code'])
      assert_equal('Indoor Cycling', json_output['workout'][0]['wkt_name'])

      assert_equal('WAHOOAPPIOS62BB', json_output['wahoo_id']['app_token'])
      assert_equal(3, json_output['wahoo_id']['workout_num'])
      assert_equal(12, json_output['wahoo_id']['workout_type'])

      assert_equal(2, json_output['sessions'][0]['sport_code'])
      assert_equal(6, json_output['sessions'][0]['sub_sport_code'])
      assert_equal(247.886, json_output['sessions'][0]['tot_timer_time_sec'])
      assert_equal(17, json_output['sessions'][0]['tot_cal'])
      assert_equal(137, json_output['sessions'][0]['max_hr_bpm'])
      assert_equal(108, json_output['sessions'][0]['avg_hr_bpm'])
      assert_equal(124.2, json_output['sessions'][0]['tot_dist_m'])
      assert_equal(2.1, json_output['sessions'][0]['tss'])
      assert_equal(0.592, json_output['sessions'][0]['if'])
      assert_equal(124, json_output['sessions'][0]['ftp'])

      assert_equal([202.88, 46.528, 0, 0, 0], json_output['laps'][0]['time_in_hr_zone_sec'])
      assert_equal([205.307, 2.88, 35.999, 0.0, 0.0, 0.0, 0.0, 0.0], json_output['laps'][0]['time_in_pwr_zone_sec'])

      assert_equal(2, json_output['laps'][0]['sport_code'])
      assert_equal(6, json_output['laps'][0]['sub_sport_code'])
      assert_equal(247.886, json_output['laps'][0]['tot_timer_time_sec'])
      assert_equal(17, json_output['laps'][0]['tot_cal'])
      assert_equal(137, json_output['laps'][0]['max_hr_bpm'])
      assert_equal(108, json_output['laps'][0]['avg_hr_bpm'])
      assert_equal(124.2, json_output['laps'][0]['tot_dist_m'])
      assert_equal(17304, json_output['laps'][0]['tot_work_j'])
      assert_equal([202.88, 46.528, 0, 0, 0], json_output['laps'][0]['time_in_hr_zone_sec'])
      assert_equal([205.307, 2.88, 35.999, 0.0, 0.0, 0.0, 0.0, 0.0], json_output['laps'][0]['time_in_pwr_zone_sec'])

      assert_equal(98, json_output['records'][1]['hr_bpm'])
      assert_equal(0, json_output['records'][1]['pwr_watts'])
      assert_equal(0, json_output['records'][1]['cal'])
      assert_equal(85, json_output['records'][0]['batt_soc_perc'])
      assert_equal(0, json_output['records'][0]['sec'])

      assert_equal(85.0, json_output['records'][0]['batt_soc_perc'])
      assert_equal(110, json_output['records'][242]['pwr_watts'])
      assert_equal(124.2, json_output['records'][242]['dist_m'])
      assert_equal(0.134, json_output['records'][242]['spd_mps'])


      assert_equal(5, json_output['hr_zones'].size)
      assert_equal(0, json_output['hr_zones'][0]['message_index'])
      assert_equal(1, json_output['hr_zones'][1]['message_index'])
      assert_equal(2, json_output['hr_zones'][2]['message_index'])
      assert_equal(3, json_output['hr_zones'][3]['message_index'])
      assert_equal(4, json_output['hr_zones'][4]['message_index'])

      assert_equal(6, json_output['pwr_zones'].size)
      assert_equal(0, json_output['pwr_zones'][0]['message_index'])
      assert_equal(1, json_output['pwr_zones'][1]['message_index'])
      assert_equal(2, json_output['pwr_zones'][2]['message_index'])
      assert_equal(3, json_output['pwr_zones'][3]['message_index'])
      assert_equal(4, json_output['pwr_zones'][4]['message_index'])
      assert_equal(5, json_output['pwr_zones'][5]['message_index'])

      assert_equal(68, json_output['pwr_zones'][0]['high_pwr_watts'])
      assert_equal(87, json_output['pwr_zones'][1]['high_pwr_watts'])
      assert_equal(113, json_output['pwr_zones'][2]['high_pwr_watts'])
      assert_equal(119, json_output['pwr_zones'][3]['high_pwr_watts'])
      assert_equal(128, json_output['pwr_zones'][4]['high_pwr_watts'])
      assert_equal(65534, json_output['pwr_zones'][5]['high_pwr_watts'])

      assert_equal(0, json_output['device_infos'][0]['device_index'])
      assert_equal(32, json_output['device_infos'][0]['manufacturer_code'])
      assert_equal(0, json_output['device_infos'][0]['product'])
      assert_equal("WAHOO APP", json_output['device_infos'][0]['product_name'])

    end
  end

  def test_fit_file_with_invalid_lap
    fit_file_path = 'test/fixtures/zwift-activity.fit'
    new_fit_file_path = 'test/fixtures/zwift-activity-new.fit'
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end

    raw = IO.read(new_fit_file_path)
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      assert_nil(json_output['activity']['local_timestamp'])
      assert_equal(1, json_output['laps'].size)
    end
  end

  def test_fit_file_with_no_session
    fit_file_path = 'test/fixtures/2025-05-08-114933-ELEMNT_ACE_115C-42-0.fit'
    new_fit_file_path = 'test/fixtures/2025-05-08-114933-ELEMNT_ACE_115C-42-0-new.fit'
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end

    raw = IO.read(new_fit_file_path)
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      assert_equal(1, json_output['sessions'].size)
    end
  end

  def test_fit_file_with_no_session_and_no_laps
    fit_file_path = 'test/fixtures/2025-05-24-145948-WAHOOAPPIOS010F-131-0_fixed.fit'
    new_fit_file_path = 'test/fixtures/2025-05-24-145948-WAHOOAPPIOS010F-131-0_fixed-new.fit'

    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end

    raw = IO.read(new_fit_file_path)
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      refute_nil(json_output)

      assert_equal(1, json_output['sessions'].size)
      assert_equal(1, json_output['laps'].size)
    end
  end

  def test_fit_file_with_rpe
    fit_file_path = 'test/fixtures/2-very-strong.fit'
    new_fit_file_path = 'test/fixtures/2-very-strong-new.fit'
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end

    raw = IO.read(new_fit_file_path)
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      refute_nil(json_output)
      assert_equal(1, json_output['sessions'].size)
      assert_equal(20, json_output['sessions'][0]['workout_rpe'])
    end
  end


  def test_total_vs_timer_time
    fit_file_path = 'test/fixtures/chip_zwift_run.fit'
    new_fit_file_path = 'test/fixtures/chip_zwift_run-new.fit'
    raw = IO.read(fit_file_path)

    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end

    raw = IO.read(new_fit_file_path)
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      refute_nil(json_output)
      assert_equal(4116, json_output['activity']['tot_timer_time_sec'])
    end
  end
end