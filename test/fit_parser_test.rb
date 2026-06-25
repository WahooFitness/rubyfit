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

      assert_equal(2, json_output['workout']['sport_code'])
      assert_equal(6, json_output['workout']['sub_sport_code'])
      assert_equal('Indoor Cycling', json_output['workout']['wkt_name'])

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

  def test_file_with_no_workout_and_no_wahoo_id
    fit_file_path = 'test/fixtures/tp-371176.2025-11-11-21-31-03-088Z.GarminPing.AAAAAGkTqxbgWQ9T.FIT'
    new_fit_file_path = 'test/fixtures/tp-371176.2025-11-11-21-31-03-088Z.GarminPing.AAAAAGkTqxbgWQ9T-repaired.FIT'

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

      assert_equal(4, json_output['workout'].size)
      assert_equal(4, json_output['wahoo_id'].size)

      assert_equal("Road Cycling", json_output['workout']['wkt_name'])
      assert_equal("FID14 43761D44", json_output['wahoo_id']['app_token'])
      assert_equal(15, json_output['wahoo_id']['workout_type'])
      assert_equal("FID14 43761D44:0", json_output['wahoo_id']['workout_token'])
      assert_equal(15, json_output['sessions'][0]['workout_type_code'])
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
      assert_equal(2.0, json_output['sessions'][0]['workout_rpe'])
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
      assert_equal(1, json_output['laps'].size)
    end
  end

  def test_event_time
    fit_file_path = 'test/fixtures/zwift-activity-bad-events.fit'
    new_fit_file_path = 'test/fixtures/zwift-activity-bad-events-new.fit'
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
      assert_equal("2025-06-09 21:02:05 UTC", json_output['events'][1]['timestamp'])
      assert_equal(1, json_output['laps'].size)
    end
  end

  def test_dev_fields
    fit_file_path = 'test/fixtures/DeveloperData.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      puts(json_output.inspect)
    end
  end

  def test_undefined_method_in_field_definition_error_handling
    fit_file_path = 'test/fixtures/2025-04-04-052736-WAHOOAPPIOS1568-146-0.fit'
    new_fit_file_path = 'test/fixtures/2025-04-04-052736-WAHOOAPPIOS1568-146-0-new.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end
  end

  def test_undefined_method_in_validations_error_handling
    fit_file_path = 'test/fixtures/2025-10-25-163604-ManualSummaryFit9639-7357631-0.fit'
    new_fit_file_path = 'test/fixtures/2025-10-25-163604-ManualSummaryFit9639-7357631-0-new.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end
  end

  def test_fit_file_with_no_laps_and_no_records
    fit_file_path = 'test/fixtures/2025-10-24-170242-WAHOOAPPIOSFFAE-397-0.fit'
    new_fit_file_path = 'test/fixtures/2025-10-24-170242-WAHOOAPPIOSFFAE-397-0-new.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end
  end

  def test_conversion_error
    fit_file_path = 'test/fixtures/2025-08-24-091308-ELEMNT_BOLT_F73E-3-0.fit'
    new_fit_file_path = 'test/fixtures/2025-08-24-091308-ELEMNT_BOLT_F73E-3-0-new.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.repair_fit_file(raw) do |data|
      new_file_string = data
      File.open(new_fit_file_path, 'wb') do |file|
        file.write(new_file_string)
      end
    end
  end

  def test_wahoo_clm_workout_plan
    fit_file_path = 'test/fixtures/running_assessment.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      assert_equal(1, json_output['CLM']['WORKOUT_PLAN_INFO'].size)
      assert_equal(10781682, json_output['CLM']['WORKOUT_PLAN_INFO'][0]['clm']['plan_cloud_id'])
    end
  end

  def test_wahoo_clm_parsing_should_not_error
    fit_file_path = 'test/fixtures/clm-parsing-issue.fit'
    raw = IO.read(fit_file_path)
    parser = RubyFit::FitFileParser.new
    parser.parse(raw) do |data|
      json_output = JSON.parse(data.to_json)
      puts(json_output['CLM'].inspect)
      assert_equal(5, json_output['CLM']['WORKOUT_PLAN_INFO'].size)
    end
  end

  def test_coros_indoor_running_repair
    fit_file_path = 'test/fixtures/coros_running_indoor.fit'
    new_fit_file_path = 'test/fixtures/coros_indoor_run-new.fit'
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
      assert_equal(1, json_output['laps'].size)
      assert_equal(1, json_output['sessions'][0]['sport_code'])
      assert_equal(1, json_output['sessions'][0]['sub_sport_code'])
      assert_equal(1, json_output['laps'][0]['sport_code'])
      assert_equal(1, json_output['laps'][0]['sub_sport_code'])
    end
  end

  def test_repair_backfills_spd_mps_from_enhanced_spd_mps
    fit_file_path = 'test/fixtures/missing-spd-mps.fit'
    new_fit_file_path = 'test/fixtures/missing-spd-mps-new.fit'
    raw = IO.read(fit_file_path)

    original_enhanced_by_sec = {}
    RubyFit::FitFileParser.new.parse(raw) do |data|
      (JSON.parse(data.to_json)['records'] || []).each do |r|
        original_enhanced_by_sec[r['sec']] = r['enhanced_spd_mps'] unless r['enhanced_spd_mps'].nil?
      end
    end
    refute_empty(original_enhanced_by_sec, 'expected fixture to have at least one record with enhanced_spd_mps')

    RubyFit::FitFileParser.new.repair_fit_file(raw) do |data|
      File.open(new_fit_file_path, 'wb') { |file| file.write(data) }
    end

    repaired = IO.read(new_fit_file_path)
    RubyFit::FitFileParser.new.parse(repaired) do |data|
      records = JSON.parse(data.to_json)['records']
      refute_nil(records)
      refute_empty(records)

      records.each do |record|
        original_enhanced = original_enhanced_by_sec[record['sec']]
        next if original_enhanced.nil?
        assert_equal(original_enhanced.round(1), record['spd_mps']&.round(1),
                     "record at sec=#{record['sec']} should have spd_mps backfilled from enhanced_spd_mps")
      end
    end
  end

  def test_repair_causing_invalid_field_error
    fit_file_path = 'test/fixtures/2025-06-19-070353-ELEMNT_ROAM_63BA-16-0.fit'
    new_fit_file_path = 'test/fixtures/2025-06-19-070353-ELEMNT_ROAM_63BA-16-0-new.fit'
    puts("Testing repair of file with invalid field that causes error in parsing")
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

  def test_patching_altitudes
    fit_file_path = 'test/fixtures/no-elevation-data.fit'
    new_fit_file_path = 'test/fixtures/added-elevation-data.fit'
    raw = IO.read(fit_file_path)

    # Baseline: parse the original file and grab its records.
    original = nil
    RubyFit::FitFileParser.new.parse(raw) { |data| original = data }
    records = original[:records]
    refute_empty records, "fixture should contain GPS records"

    # Assign a known, distinct altitude (meters) to every record.
    altitudes = records.each_index.map { |i| 100.0 + i }

    # Patch the altitudes in place.
    patched_raw = nil
    RubyFit::FitFileParser.new.patch_altitudes(raw, altitudes) { |data| patched_raw = data }
    refute_nil patched_raw

    File.open(new_fit_file_path, 'wb') { |file| file.write(patched_raw) }

    # The fixture's records have no altitude field, so patching appends one to the
    # record definition (+3 bytes) and 2 bytes per record. The file must therefore
    # grow by exactly 2 bytes per record (definition growth and the recomputed CRC
    # net out separately, so assert the per-record portion at minimum).
    assert_operator patched_raw.bytesize, :>=, raw.bytesize + 2 * records.size

    # Re-parse the patched file and verify the new altitudes round-trip. FIT
    # altitude has scale 5 (0.2 m resolution), so allow a small delta.
    reparsed = nil
    RubyFit::FitFileParser.new.parse(patched_raw) { |data| reparsed = data }
    new_records = reparsed[:records]
    puts("new records: #{new_records.inspect}")

    assert_equal records.size, new_records.size
    new_records.each_with_index do |record, i|
      assert_in_delta altitudes[i], record[:alt_m], 0.2, "record #{i} altitude was not patched"
    end

    # Non-altitude fields must be preserved untouched.
    assert_equal records.first[:lat_deg], new_records.first[:lat_deg]
    assert_equal records.last[:lon_deg],  new_records.last[:lon_deg]
    assert_equal records.first[:timestamp], new_records.first[:timestamp]
  end
end