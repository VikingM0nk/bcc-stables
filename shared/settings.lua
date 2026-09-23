--[[
    Darkwood extras for bcc-stables: care, ownership, auction, admin, breeding flags.
]]

Config.maxPlayerHorses = 15
Config.maxTrainerHorses = 20
Config.MaxOwnedStables = 1

Config.AdminAce = 'stables.admin'
Config.AdminGroups = { 'admin', 'god', 'superadmin', 'owner' }

Config.Care = {
    HungerDecayPerMinute = 1.0,
    ThirstDecayPerMinute = 1.2,
    CleanDecayPerMinute = 0.4,
    CleanDecayRiding = 1.6,
    LoveDecayPerMinute = 0.15,
    RidingHungerMult = 1.4,
    FeedHunger = 35,
    GrazeHunger = 22,
    WaterThirst = 45,
    BrushClean = 55,
    WallowDirt = 12,
    PatLove = 4,
    BondingFeed = 2,
    LowNeed = 25,
    LoveCapFromNeeds = true,
    IgnoreCallChance = 0.45,
    GallopPenalty = 0.72,
    AgingEnabled = true,
    AgeDaySeconds = 3600, -- 1 real hour = 1 horse day
    OldAgeDays = 120,
    SaveSeconds = 60,
}

Config.Ownership = {
    DefaultPrice = 2500,
    OwnerCut = 1.0,      -- share of shop sale credited to owner till
    SupplierCut = 0.0,
    SellBackFromTill = true,
    ResalePercent = 0.50, -- selling the business back
}

Config.Auction = {
    Enabled = true,
    MinMinutes = 10,
    MaxMinutes = 120,
    DefaultMinutes = 30,
    MinIncrement = 5,
    HouseCut = 0.10,
    Currency = 0, -- cash
    Yards = {
        {
            key = 'valentine',
            label = 'Valentine Horse Auction',
            coords = vector3(-365.40, 791.80, 116.04),
            heading = 180.0,
            stable = 'valentine',
            blip = true,
            model = 'a_m_m_valtownfolk_01',
            npcDistance = 80.0,
        },
        {
            key = 'saintdenis',
            label = 'Saint Denis Horse Auction',
            coords = vector3(2503.20, -1450.40, 46.31),
            heading = 90.0,
            stable = 'saintdenis',
            blip = true,
            model = 'a_m_m_valtownfolk_01',
            npcDistance = 80.0,
        },
        {
            key = 'blackwater',
            label = 'Blackwater Horse Auction',
            coords = vector3(-873.10, -1366.40, 43.47),
            heading = 90.0,
            stable = 'blackwater',
            blip = true,
            model = 'u_m_m_bwmstablehand_01',
            npcDistance = 80.0,
        },
    },
}

Config.BreedingJob = {
    RequiredJobs = { { name = 'horse_breeder', grade = 0 } },
    AdminBypass = true,
}

Config.GeldCost = 75

-- Darkwood trainer jobs (active job or viking_multijob entry)
Config.trainerJob = {
    { name = 'trainer', grade = 0 },
    { name = 'horse_trainer', grade = 0 },
}

-- Player trainers (job) can school any owned horse, not just wild tames.
-- One skill rank per visit. Owner must bring the horse back for the next rank.
Config.HorseTraining = {
    Enabled = true,
    MaxLevel = 5,
    CooldownMinutes = 60,
    SessionMs = 12000,
    YardDistance = 8.0,
    OwnerMustBePresent = true,
    AllowOwnHorse = true,
    SpeedPerLevel = 0.045, -- move-rate bonus per speed rank
    CorePerLevel = 8,      -- extra health/stamina core per rank
    BondXpPerLevel = 450,
    Fee = {
        speed = 20,
        health = 20,
        stamina = 20,
        bravery = 20,
        bond = 25,
    },
}

local BREEDING_SITES = {
    valentine = true,
    strawberry = true,
    blackwater = true,
}

CreateThread(function()
    Wait(0)
    if type(Stables) ~= 'table' then return end
    for key, site in pairs(Stables) do
        if type(site) == 'table' then
            if site.purchasable == nil then site.purchasable = true end
            site.purchasePrice = tonumber(site.purchasePrice) or Config.Ownership.DefaultPrice
            site.society = site.society or ('stable_' .. tostring(key))
            if site.breeding == nil then
                site.breeding = BREEDING_SITES[key] == true
            end
        end
    end
end)
