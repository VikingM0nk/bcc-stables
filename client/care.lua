HorseCare = HorseCare or {}

local hunger, thirst, clean, love = 100, 100, 100, 50
local personality = 'Easy-going'
local genotype = ''
local lastSave = 0
local lastDecay = 0

local function clamp(n)
    n = tonumber(n) or 0
    if n < 0 then return 0 end
    if n > 100 then return 100 end
    return n
end

local function cfg()
    return Config.Care or {}
end

function HorseCare.OnSpawn(data)
    hunger = clamp(data.care_hunger or 100)
    thirst = clamp(data.care_thirst or 100)
    clean = clamp(data.care_clean or 100)
    love = clamp(data.care_love or 50)
    personality = data.personality or 'Easy-going'
    genotype = data.genotype or ''
    lastDecay = GetGameTimer()
    lastSave = GetGameTimer()
    if data.appearance and MyHorse and MyHorse ~= 0 then
        Catalog.ApplyAppearance(MyHorse, data.appearance)
    end
end

function HorseCare.Get()
    return {
        hunger = hunger, thirst = thirst, clean = clean, love = love,
        personality = personality, genotype = genotype,
    }
end

function HorseCare.InfoLines()
    return {
        ('Hunger: %s | Thirst: %s'):format(math.floor(hunger), math.floor(thirst)),
        ('Coat: %s | Love: %s'):format(math.floor(clean), math.floor(love)),
        ('Personality: %s'):format(personality ~= '' and personality or 'Unknown'),
        ('Genotype: %s'):format(genotype ~= '' and genotype or 'Unknown'),
    }
end

function HorseCare.ShouldIgnoreCall()
    local low = cfg().LowNeed or 25
    if hunger > low and thirst > low then return false end
    return math.random() < (cfg().IgnoreCallChance or 0.45)
end

function HorseCare.Boost(kind)
    if kind == 'feed' then
        hunger = clamp(hunger + (cfg().FeedHunger or 35))
        love = clamp(love + (cfg().BondingFeed or 2))
    elseif kind == 'water' then
        thirst = clamp(thirst + (cfg().WaterThirst or 45))
        love = clamp(love + 1)
    elseif kind == 'brush' then
        clean = clamp(clean + (cfg().BrushClean or 55))
        love = clamp(love + 3)
    elseif kind == 'graze' then
        hunger = clamp(hunger + (cfg().GrazeHunger or 22))
        love = clamp(love + 1)
    elseif kind == 'sleep' then
        thirst = clamp(thirst - 2)
        love = clamp(love + 1)
    elseif kind == 'wallow' then
        clean = clamp(clean - (cfg().WallowDirt or 12))
        love = clamp(love + 1)
    elseif kind == 'pat' then
        love = clamp(love + (cfg().PatLove or 4))
    end
    HorseCare.CapLove()
    HorseCare.Save(true)
end

function HorseCare.CapLove()
    if cfg().LoveCapFromNeeds == false then return end
    local cap = math.min(hunger, thirst)
    if love > cap then love = cap end
end

function HorseCare.Save(force)
    if not MyHorseId then return end
    local now = GetGameTimer()
    if not force and now - lastSave < ((cfg().SaveSeconds or 60) * 1000) then return end
    lastSave = now
    TriggerServerEvent('bcc-stables:SaveCare', MyHorseId, hunger, thirst, clean, love)
end

CreateThread(function()
    while true do
        Wait(15000)
        if not MyHorse or MyHorse == 0 or not DoesEntityExist(MyHorse) then
            goto continue
        end
        local now = GetGameTimer()
        local minutes = (now - lastDecay) / 60000.0
        lastDecay = now
        if minutes <= 0 then goto continue end

        local riding = Citizen.InvokeNative(0x460BC76A0E10655E, PlayerPedId()) and Citizen.InvokeNative(0x4C8B59171957BCF7, PlayerPedId()) == MyHorse
        local hungerRate = (cfg().HungerDecayPerMinute or 1.0) * (riding and (cfg().RidingHungerMult or 1.4) or 1.0)
        local thirstRate = cfg().ThirstDecayPerMinute or 1.2
        local cleanRate = riding and (cfg().CleanDecayRiding or 1.6) or (cfg().CleanDecayPerMinute or 0.4)
        if personality == 'Mud Magnet' then cleanRate = cleanRate * 1.6 end

        hunger = clamp(hunger - hungerRate * minutes)
        thirst = clamp(thirst - thirstRate * minutes)
        clean = clamp(clean - cleanRate * minutes)
        love = clamp(love - (cfg().LoveDecayPerMinute or 0.15) * minutes)
        HorseCare.CapLove()

        local low = cfg().LowNeed or 25
        if hunger < low or thirst < low then
            pcall(function()
                Citizen.InvokeNative(0x06D26A96CA1BCA75, MyHorse, 3, cfg().GallopPenalty or 0.72, 0)
            end)
        end
        if clean < 30 then
            pcall(function()
                Citizen.InvokeNative(0x7528720101A807A5, MyHorse, 1.0)
            end)
        end
        if math.random() < 0.08 and (hunger < low or thirst < low) then
            pcall(function()
                TaskHorseAction(MyHorse, 2, PlayerPedId(), 0)
            end)
        end
        HorseCare.Save(false)
        ::continue::
    end
end)

