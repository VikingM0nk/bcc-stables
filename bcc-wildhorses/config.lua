Config = {}

Config.Enabled = true
Config.HostHeartbeat = 4
Config.HerdActivate = 140.0
Config.HerdDespawn = 210.0
Config.HerdSize = { min = 2, max = 4 }
Config.Blips = false

-- Common range coats that trainers already buy/register.
Config.Pool = {
    'a_c_horse_morgan_bay',
    'a_c_horse_morgan_bayroan',
    'a_c_horse_morgan_flaxenchestnut',
    'a_c_horse_kentuckysaddle_grey',
    'a_c_horse_kentuckysaddle_chestnutpinto',
    'a_c_horse_tennesseewalker_chestnut',
    'a_c_horse_tennesseewalker_redroan',
    'a_c_horse_americanpaint_overo',
    'a_c_horse_americanpaint_tobiano',
    'a_c_horse_appaloosa_blanket',
    'a_c_horse_mustang_wildbay',
    'a_c_horse_mustang_grullodun',
    'a_c_horse_nokota_whiteroan',
    'a_c_horse_nokota_blueroan',
    'a_c_horse_hungarianhalfbred_liverchestnut',
    'a_c_horse_thoroughbred_bloodbay',
}

Config.Herds = {
    { key = 'heartlands_east', coords = vector3(478.40, 88.20, 117.90), radius = 16.0 },
    { key = 'heartlands_north', coords = vector3(1186.10, 204.50, 91.80), radius = 18.0 },
    { key = 'bigvalley_south', coords = vector3(-1962.40, -1614.20, 112.80), radius = 18.0 },
    { key = 'bigvalley_west', coords = vector3(-2338.70, -1478.60, 145.70), radius = 16.0 },
    { key = 'gaptooth', coords = vector3(-3558.20, -3066.40, 10.90), radius = 18.0 },
    { key = 'chollar', coords = vector3(-3962.10, -2138.50, -5.20), radius = 16.0 },
    { key = 'cumberland', coords = vector3(228.60, 582.40, 114.80), radius = 16.0 },
    { key = 'scarlett', coords = vector3(1394.80, -398.20, 79.90), radius = 16.0 },
    { key = 'grizzlies', coords = vector3(-1196.40, 428.70, 94.70), radius = 16.0 },
    { key = 'roanoke', coords = vector3(2496.20, 1402.80, 96.80), radius = 16.0 },
}
