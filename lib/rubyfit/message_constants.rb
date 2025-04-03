module RubyFit::MessageConstants
  COURSE_POINT_TYPE = {
    invalid: 255,
    generic: 0,
    summit: 1,
    valley: 2,
    water: 3,
    food: 4,
    danger: 5,
    left: 6,
    right: 7,
    straight: 8,
    first_aid: 9,
    fourth_category: 10,
    third_category: 11,
    second_category: 12,
    first_category: 13,
    hors_category: 14,
    sprint: 15,
    left_fork: 16,
    right_fork: 17,
    middle_fork: 18,
    slight_left: 19,
    sharp_left: 20,
    slight_right: 21,
    sharp_right: 22,
    u_turn: 23,
    segment_start: 24,
    checkpoint: 35,
    toilet: 39,
    segment_end: 25
  }.freeze

  EVENT_TYPE = {
    start: 0,
    stop: 1,
    consecutive_depreciated: 2,
    marker: 3,
    stop_all: 4,
    begin_depreciated: 5,
    end_depreciated: 6,
    end_all_depreciated: 7,
    stop_disable: 8,
    stop_disable_all: 9,
  }.freeze

  EVENT = {
    timer: 0, # Group 0.  Start / stop_all
    workout: 3, # start / stop
    workout_step: 4, # Start at beginning of workout.  Stop at end of each step.
    power_down: 5, # stop_all group 0
    power_up: 6, # stop_all group 0
    off_course: 7, # start / stop group 0
    session: 8, # Stop at end of each session.
    lap: 9, # Stop at end of each lap.
    course_point: 10, # marker
    battery: 11, # marker
    virtual_partner_pace: 12, # Group 1. Start at beginning of activity if VP enabled, when VP pace is changed during activity or VP enabled mid activity.  stop_disable when VP disabled.
    hr_high_alert: 13, # Group 0.  Start / stop when in alert condition.
    hr_low_alert: 14, # Group 0.  Start / stop when in alert condition.
    speed_high_alert: 15, # Group 0.  Start / stop when in alert condition.
    speed_low_alert: 16, # Group 0.  Start / stop when in alert condition.
    cad_high_alert: 17, # Group 0.  Start / stop when in alert condition.
    cad_low_alert: 18, # Group 0.  Start / stop when in alert condition.
    power_high_alert: 19, # Group 0.  Start / stop when in alert condition.
    power_low_alert: 20, # Group 0.  Start / stop when in alert condition.
    recovery_hr: 21, # marker
    battery_low: 22, # marker
    time_duration_alert: 23, # Group 1.  Start if enabled mid activity (not required at start of activity). Stop when duration is reached.  stop_disable if disabled.
    distance_duration_alert: 24, # Group 1.  Start if enabled mid activity (not required at start of activity). Stop when duration is reached.  stop_disable if disabled.
    calorie_duration_alert: 25, # Group 1.  Start if enabled mid activity (not required at start of activity). Stop when duration is reached.  stop_disable if disabled.
    activity: 26, # Group 1..  Stop at end of activity.
    fitness_equipment: 27, # marker
    length: 28, # Stop at end of each length.
    user_marker: 32, # marker
    sport_point: 33, # marker
    calibration: 36, # start/stop/marker
    front_gear_change: 42, # marker
    rear_gear_change: 43, # marker
    rider_position_change: 44, # marker
    elev_high_alert: 45, # Group 0.  Start / stop when in alert condition.
    elev_low_alert: 46, # Group 0.  Start / stop when in alert condition.
    comm_timeout: 47, # marker
  }.freeze

  SPORT = {
    generic: 0,
    running: 1,
    cycling: 2,
    transition: 3,
    fitness_equipment: 4,
    swimming: 5,
    walking: 6,
    sedentary: 8,
    all: 254,
  }.freeze

  SUBSPORT = {
    generic: 0,
    treadmill: 1,
    street: 2,
    trail: 3,
    track: 4,
    spin: 5,
    indoor_cycling: 6,
    road: 7,
    mountain: 8,
    downhill: 9,
    recumbent: 10,
    cyclocross: 11,
    hand_cycling: 12,
    track_cycling: 13,
    indoor_rowing: 14,
    elliptical: 15,
    stair_climbing: 16,
    lap_swimming: 17,
    open_water: 18,
    flexibility_training: 19,
    strength_training: 20,
    warm_up: 21,
    match: 22,
    exercise: 23,
    challenge: 24,
    indoor_skiing: 25,
    cardio_training: 26,
    indoor_walking: 27,
    e_bike_fitness: 28,
    bmx: 29,
    casual_walking: 30,
    speed_walking: 31,
    bike_to_run_transition: 32,
    run_to_bike_transition: 33,
    swim_to_bike_transition: 34,
    atv: 35,
    motocross: 36,
    backcountry: 37,
    resort: 38,
    rc_drone: 39,
    wingsuit: 40,
    whitewater: 41,
    skate_skiing: 42,
    yoga: 43,
    pilates: 44,
    indoor_running: 45,
    gravel_cycling: 46,
    e_bike_mountain: 47,
    communting: 48,
    mixed_surface: 49,
    navigate: 50,
    track_me: 51,
    map: 52,
    single_gas_diving: 53,
    multi_gas_diving: 54,
    gauge_diving: 55,
    apnea_diving: 56,
    apnea_hunting: 57,
    virtual_activity: 58,
    obstacle: 59,
    breathing: 62,
    sail_race: 65,
    ultra: 67,
    indoor_climbing: 68,
    bouldering: 69,
    all: 254
  }.freeze

  DISPLAY_MEASURE = {
    metric: 0,
    stature: 1,
    nautical: 2
  }.freeze

  DURATION_TYPE = {
    time: 0,
    distance: 1,
    hr_less_than: 2,
    hr_greater_than: 3,
    calories: 4,
    open: 5,
    repeat_until_steps_cmplt: 6,
    repeat_until_time: 7,
    repeat_until_distance: 8,
    repeat_until_calories: 9,
    repeat_until_hr_less_than: 10,
    repeat_until_hr_greater_than: 11,
    repeat_until_power_less_than: 12,
    repeat_until_power_greater_than: 13,
    power_less_than: 14,
    power_greater_than: 15,
    training_peaks_tss: 16,
    repeat_until_power_last_lap_less_than: 17,
    repeat_until_max_power_last_lap_less_than: 18,
    power_3s_less_than: 19,
    power_10s_less_than: 20,
    power_30s_less_than: 21,
    power_3s_greater_than: 22,
    power_10s_greater_than: 23,
    power_30s_greater_than: 24,
    power_lap_less_than: 25,
    power_lap_greater_than: 26,
    repeat_until_training_peaks_tss: 27,
    repetition_time: 28,
    reps: 29,
    time_only: 31
  }.freeze

  TARGET_TYPE = {
    speed: 0,
    heart_rate: 1,
    open: 2,
    cadence: 3,
    power: 4,
    grade: 5,
    resistance: 6,
    power_3s: 7,
    power_10s: 8,
    power_30s: 9,
    power_lap: 10,
    swim_stroke: 11,
    speed_lap: 12,
    heart_rate_lap: 13
  }.freeze

  INTENSITY = {
    active: 0,
    rest: 1,
    warmup: 2,
    cooldown: 3,
    recovery: 4,
    interval: 5,
    other: 6
  }.freeze

  WORKOUT_EQUIPMENT = {
    none: 0,
    swim_fins: 1,
    swim_kickboard: 2,
    swim_paddles: 3,
    swim_pull_buoy: 4,
    swim_snorkel: 5
  }.freeze

  ACTIVITY_TYPE = {
    generic: 0,
    running: 1,
    cycling: 2,
    transition: 3,
    fitness_equipment: 4,
    swimming: 5,
    walking: 6,
    sedentary: 8,
    all: 254
  }.freeze

  LENGTH_TYPE = {
    idle: 0,
    active: 1
  }.freeze

  SWIM_STROKE = {
    freestyle: 0,
    backstroke: 1,
    breaststroke: 2,
    butterfly: 3,
    drill: 4,
    mixed: 5,
    im: 6
  }.freeze

  LAP_TRIGGER = {
    manual: 0,
    time: 1,
    distance: 2,
    position_start: 3,
    position_lap: 4,
    position_waypoint: 5,
    position_marked: 6,
    session_end: 7,
    fitness_equipment: 8
  }.freeze

  FIT_BASE_TYPE = {
    enum: 0,
    sint8: 1,
    uint8: 2,
    sint16: 131,
    uint16: 132,
    sint32: 133,
    uint32: 134,
    string: 7,
    float32: 136,
    float64: 137,
    uint8z: 10,
    uint16z: 139,
    uint32z: 140,
    byte: 13,
    sint64: 142,
    uint64: 143,
    uint64z: 144
  }.freeze


  MESSAGE_TYPE = {
    file_id: 0,
    event: 21,
    record: 20,
    lap: 19,
    course: 31,
    course_point: 32,
    session: 18,
    workout: 26,
    hr_zone: 8,
    power_zone: 9,
    activity: 34,
    device_info: 23,
    sport: 12,
    workout_step: 27,
    segment_lap: 142,
    wahoo_custom_num: 65284,
    wahoo_clm: 65285,
    wahoo_id: 65281,
    developer_data_id: 207,
    field_description: 206
  }.freeze

  BATTERY_STATUS = {
    new: 1,
    good: 2,
    ok: 3,
    low: 4,
    critical: 5,
    charging: 6,
    unknown: 7
  }.freeze

  SOURCE_TYPE = {
    ant: 0,
    antplus: 1,
    bluetooth: 2,
    bluetooth_low_energy: 3,
    wifi: 4,
    local: 5
  }.freeze
end
