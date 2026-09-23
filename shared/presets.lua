--[[
    Extra named coats that reuse a vanilla model plus optional appearance tints.
    Keys are unique; cfg.model is the spawn hash. Preview/buy resolve through Catalog.
]]

local EXTRA = {
    {
        breed = 'Morgan',
        id = 'preset_morgan_darkbay',
        model = 'a_c_horse_morgan_bay',
        color = 'Dark Bay',
        cashPrice = 80, goldPrice = 3, invLimit = 200,
        breedingColor = 'Bay', breedingPattern = 'Solid', genotype = 'Bay',
        appearance = { tint0 = 18, tint1 = 12, tint2 = 8, scale = 0.98 },
    },
    {
        breed = 'Morgan',
        id = 'preset_morgan_sooty',
        model = 'a_c_horse_morgan_bayroan',
        color = 'Sooty Bay Roan',
        cashPrice = 95, goldPrice = 4, invLimit = 200,
        breedingColor = 'Roan', breedingPattern = 'Solid', genotype = 'Roan',
        appearance = { tint0 = 22, tint1 = 16, tint2 = 20, scale = 0.99 },
    },
    {
        breed = 'Kentucky Saddler',
        id = 'preset_kentucky_liver',
        model = 'a_c_horse_kentuckysaddle_chestnutpinto',
        color = 'Liver Chestnut Pinto',
        cashPrice = 90, goldPrice = 4, invLimit = 200,
        breedingColor = 'Chestnut', breedingPattern = 'Tobiano', genotype = 'Chestnut + Tobiano',
        appearance = { tint0 = 28, tint1 = 14, tint2 = 10, scale = 1.0 },
    },
    {
        breed = 'American Paint',
        id = 'preset_paint_bayovero',
        model = 'a_c_horse_americanpaint_overo',
        color = 'Bay Overo',
        cashPrice = 180, goldPrice = 8, invLimit = 200,
        breedingColor = 'Bay', breedingPattern = 'Overo', genotype = 'Bay + Overo',
        appearance = { tint0 = 32, tint1 = 24, tint2 = 18, scale = 1.01 },
    },
    {
        breed = 'Mustang',
        id = 'preset_mustang_reddun',
        model = 'a_c_horse_mustang_grullodun',
        color = 'Red Dun',
        cashPrice = 420, goldPrice = 20, invLimit = 200,
        breedingColor = 'Dun', breedingPattern = 'Solid', genotype = 'Dun',
        appearance = { tint0 = 48, tint1 = 30, tint2 = 22, scale = 0.97 },
    },
    {
        breed = 'Arabian',
        id = 'preset_arabian_fleabitten',
        model = 'a_c_horse_arabian_grey',
        color = 'Fleabitten Grey',
        cashPrice = 1200, goldPrice = 58, invLimit = 160,
        breedingColor = 'Grey', breedingPattern = 'Solid', genotype = 'Grey',
        appearance = { tint0 = 78, tint1 = 74, tint2 = 70, scale = 0.94 },
    },
    {
        breed = 'Shire',
        id = 'preset_shire_steel',
        model = 'a_c_horse_shire_lightgrey',
        color = 'Steel Grey',
        cashPrice = 160, goldPrice = 7, invLimit = 220,
        breedingColor = 'Grey', breedingPattern = 'Solid', genotype = 'Grey',
        appearance = { tint0 = 42, tint1 = 40, tint2 = 38, scale = 1.08 },
    },
    {
        breed = 'Turkoman',
        id = 'preset_turkoman_bronze',
        model = 'a_c_horse_turkoman_gold',
        color = 'Bronze',
        cashPrice = 980, goldPrice = 47, invLimit = 200,
        breedingColor = 'Palomino', breedingPattern = 'Solid', genotype = 'Palomino',
        appearance = { tint0 = 55, tint1 = 38, tint2 = 24, scale = 1.02 },
    },
    {
        breed = 'Nokota',
        id = 'preset_nokota_blueovero',
        model = 'a_c_horse_nokota_blueroan',
        color = 'Blue Roan Overo',
        cashPrice = 240, goldPrice = 11, invLimit = 150,
        breedingColor = 'Roan', breedingPattern = 'Overo', genotype = 'Roan + Overo',
        appearance = { tint0 = 36, tint1 = 40, tint2 = 48, scale = 0.96 },
    },
    {
        breed = 'Criollo',
        id = 'preset_criollo_buckskin',
        model = 'a_c_horse_criollo_dun',
        color = 'Buckskin Dun',
        cashPrice = 220, goldPrice = 10, invLimit = 200,
        breedingColor = 'Buckskin', breedingPattern = 'Solid', genotype = 'Bay + Cream',
        appearance = { tint0 = 50, tint1 = 36, tint2 = 20, scale = 0.95 },
    },
}

local function applyAppearance(ped, appearance)
    if not ped or ped == 0 or type(appearance) ~= 'table' then return end
    local tint0 = tonumber(appearance.tint0) or 0
    local tint1 = tonumber(appearance.tint1) or 0
    local tint2 = tonumber(appearance.tint2) or 0
    -- Horse body / head tags (rdr3 metaped). Safe no-op if hashes missing on a build.
    pcall(function()
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped,
            `p_c_horse_01_hand_000`,
            `mp_horse_01_hand_000_c0_835_ab`,
            `p_c_horse_01_hand_000_c0_000_nm`,
            `p_c_horse_01_hand_000_c0_000_m`,
            `metaped_tint_horse`,
            tint0, tint1, tint2)
    end)
    pcall(function()
        Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped,
            `p_c_horse_01_head_000`,
            `p_c_horse_01_head_000_c0_895_ab`,
            `p_c_horse_01_head_000_c0_000_nm`,
            `p_c_horse_01_head_000_c0_000_m`,
            `metaped_tint_horse`,
            tint0, tint1, tint2)
    end)
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    local scale = tonumber(appearance.scale)
    if scale and scale > 0 then
        pcall(SetPedScale, ped, scale)
        pcall(function()
            Citizen.InvokeNative(0x25ACFC07BDC14771, ped, scale)
        end)
    end
end

function Catalog.ApplyAppearance(ped, appearance)
    applyAppearance(ped, appearance)
end

CreateThread(function()
    Wait(50)
    if type(Horses) ~= 'table' then return end
    for i = 1, #EXTRA do
        local row = EXTRA[i]
        local breedCfg
        for h = 1, #Horses do
            if Horses[h].breed == row.breed then
                breedCfg = Horses[h]
                break
            end
        end
        if not breedCfg then
            breedCfg = { breed = row.breed, colors = {} }
            Horses[#Horses + 1] = breedCfg
        end
        breedCfg.colors = breedCfg.colors or {}
        if not breedCfg.colors[row.id] then
            breedCfg.colors[row.id] = {
                color = row.color,
                cashPrice = row.cashPrice,
                goldPrice = row.goldPrice,
                invLimit = row.invLimit,
                job = {},
                model = row.model,
                breedingColor = row.breedingColor,
                breedingPattern = row.breedingPattern,
                genotype = row.genotype,
                appearance = row.appearance,
                breedable = true,
            }
        end
    end
    Catalog._enriched = false
    Catalog.Enrich()
end)
