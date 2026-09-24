HorseTraining = HorseTraining or {}
HorseTraining.Levels = {
    speed = 0, health = 0, stamina = 0, bravery = 0, bond = 0,
}
HorseTraining.Applied = {
    speed = 0, health = 0, stamina = 0, bravery = 0, bond = 0,
}
HorseTraining.LastHorse = 0

local Core = exports.vorp_core:GetCore()
local TrainPrompt, TrainGroup
local TrainingBusy = false
local rateThread = false

local ATTR = {
    HEALTH = 0,
    STAMINA = 1,
    COURAGE = 3,
    AGILITY = 4,
    SPEED = 5,
    ACCEL = 6,
    BOND = 7,
}

local function cfg()
    return Config.HorseTraining or {}
end

local function asInt(n)
    if n == true then return 1 end
    if n == false or n == nil then return 0 end
    return math.floor(tonumber(n) or 0)
end

local function setBonusRank(horse, attr, bonus)
    bonus = math.max(0, math.min(10, asInt(bonus)))
    pcall(function()
        Citizen.InvokeNative(0x920F9488BD115EFB, horse, attr, bonus) -- SetAttributeBonusRank
    end)
end

local function fillCore(horse, core, value)
    value = math.max(0, math.min(100, math.floor(tonumber(value) or 0)))
    Citizen.InvokeNative(0xC6258F41D86676E0, horse, core, value) -- SetAttributeCoreValue
end

local function startRateThread()
    if rateThread then return end
    rateThread = true
    CreateThread(function()
        while true do
            Wait(1000)
            local lvl = tonumber(HorseTraining.Levels.speed) or 0
            if MyHorse and MyHorse ~= 0 and DoesEntityExist(MyHorse) and lvl > 0 then
                local rate = 1.0 + (lvl * (cfg().SpeedPerLevel or 0.06))
                pcall(SetPedMoveRateOverride, MyHorse, rate)
                pcall(function()
                    Citizen.InvokeNative(0x085BFDF83E2CF4E4, MyHorse, rate)
                end)
            end
        end
    end)
end

function HorseTraining.Apply(horse, data)
    if not horse or horse == 0 or not DoesEntityExist(horse) then return end
    data = data or {}
    if data.id then HorseTraining.HorseId = data.id end
    if data.horseId then HorseTraining.HorseId = data.horseId end
    local levels = data.levels or {
        speed = data.train_speed,
        health = data.train_health,
        stamina = data.train_stamina,
        bravery = data.train_bravery,
        bond = data.train_bond,
    }
    HorseTraining.Levels = {
        speed = asInt(levels.speed),
        health = asInt(levels.health),
        stamina = asInt(levels.stamina),
        bravery = asInt(levels.bravery),
        bond = asInt(levels.bond),
    }

    local wanted = HorseTraining.Levels
    local coreBoost = tonumber(cfg().CorePerLevel) or 12

    if wanted.speed > 0 then
        setBonusRank(horse, ATTR.SPEED, wanted.speed * 2)
        setBonusRank(horse, ATTR.ACCEL, wanted.speed * 2)
        setBonusRank(horse, ATTR.AGILITY, wanted.speed)
        startRateThread()
    end

    if wanted.health > 0 then
        setBonusRank(horse, ATTR.HEALTH, wanted.health * 2)
        fillCore(horse, 0, math.min(100, 70 + wanted.health * coreBoost))
        local extra = wanted.health * 40
        pcall(function()
            if HorseTraining.LastHorse ~= horse or not HorseTraining.BaseMaxHealth then
                HorseTraining.BaseMaxHealth = GetEntityMaxHealth(horse)
            end
            local base = HorseTraining.BaseMaxHealth or GetEntityMaxHealth(horse) or 150
            SetEntityMaxHealth(horse, base + extra)
            SetEntityHealth(horse, math.min(base + extra, GetEntityHealth(horse) + extra), 0)
        end)
    end

    if wanted.stamina > 0 then
        setBonusRank(horse, ATTR.STAMINA, wanted.stamina * 2)
        fillCore(horse, 1, math.min(100, 70 + wanted.stamina * coreBoost))
        pcall(function()
            Citizen.InvokeNative(0x675680D089BFA21F, horse, wanted.stamina * 20.0)
        end)
    end

    if wanted.bravery > 0 then
        setBonusRank(horse, ATTR.COURAGE, wanted.bravery * 2)
        Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 113, wanted.bravery >= 1)
        Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 312, wanted.bravery >= 2)
        if wanted.bravery >= 4 then
            Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 471, true)
        end
    end

    if data.xp then
        Citizen.InvokeNative(0x09A59688C26D88DF, horse, ATTR.BOND, tonumber(data.xp) or 0)
        Citizen.InvokeNative(0x75415EE0CB583760, horse, ATTR.BOND, 0)
    end

    HorseTraining.LastHorse = horse
    HorseTraining.Applied = {
        speed = wanted.speed, health = wanted.health, stamina = wanted.stamina,
        bravery = wanted.bravery, bond = wanted.bond,
    }
end

function HorseTraining.InfoLines()
    local l = HorseTraining.Levels or {}
    local maxLevel = tonumber(cfg().MaxLevel) or 5
    return {
        ('Schooling  Spd %s/%s  HP %s/%s  Stam %s/%s'):format(l.speed or 0, maxLevel, l.health or 0, maxLevel, l.stamina or 0, maxLevel),
        ('Schooling  Brave %s/%s  Bond %s/%s'):format(l.bravery or 0, maxLevel, l.bond or 0, maxLevel),
    }
end

local function skillLabel(skill)
    if skill == 'speed' then return _U('trainSpeed') end
    if skill == 'health' then return _U('trainHealth') end
    if skill == 'stamina' then return _U('trainStamina') end
    if skill == 'bravery' then return _U('trainBravery') end
    if skill == 'bond' then return _U('trainBond') end
    return skill
end

local function playLesson(horse)
    local ped = PlayerPedId()
    if horse and horse ~= 0 and DoesEntityExist(horse) then
        pcall(function()
            Citizen.InvokeNative(0xCD181A959CFDD7F4, ped, horse, `Interaction_Brush`, `p_brushHorse02x`, true)
        end)
    end
    Wait(tonumber(cfg().SessionMs) or 12000)
    ClearPedTasks(ped)
end

local function openSkillPage(menu, target, maxLevel, fees)
    local page = menu:RegisterPage('train:skills')
    page:RegisterElement('header', { value = target.horseName, slot = 'header' })
    local l = target.levels or {}
    page:RegisterElement('textdisplay', {
        value = ('Owner: %s\nSpeed %s/%s | Health %s/%s | Stamina %s/%s\nBravery %s/%s | Bond %s/%s'):format(
            target.ownerName or 'Unknown',
            l.speed or 0, maxLevel, l.health or 0, maxLevel, l.stamina or 0, maxLevel,
            l.bravery or 0, maxLevel, l.bond or 0, maxLevel
        )
    })
    if (tonumber(target.cooldown) or 0) > 0 then
        page:RegisterElement('textdisplay', {
            value = ('Needs rest: %sm'):format(math.ceil(target.cooldown / 60))
        })
        page:RegisterElement('button', { label = 'Back' }, function()
            menu:Close()
        end)
        return page
    end

    local skills = { 'speed', 'health', 'stamina', 'bravery', 'bond' }
    for i = 1, #skills do
        local skill = skills[i]
        local rank = tonumber(l[skill]) or 0
        local nextLevel = rank + 1
        local cost = math.floor((tonumber(fees[skill]) or 20) * nextLevel)
        local label
        if rank >= maxLevel then
            label = skillLabel(skill) .. ' — maxed'
        else
            label = ('%s  %s/%s  $%s'):format(skillLabel(skill), nextLevel, maxLevel, cost)
        end
        page:RegisterElement('button', { label = label }, function()
            if rank >= maxLevel then
                Core.NotifyRightTip(_U('trainMaxed'), 4000)
                return
            end
            menu:Close()
            if TrainingBusy then return end
            TrainingBusy = true
            CreateThread(function()
                local horse = (target.ownerSrc == GetPlayerServerId(PlayerId()) and MyHorse) or 0
                if horse == 0 then
                    local players = GetActivePlayers()
                    for p = 1, #players do
                        local ped = GetPlayerPed(players[p])
                        local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped)
                        if mount and mount ~= 0 then
                            horse = mount
                            break
                        end
                    end
                    if (not horse or horse == 0) and MyHorse ~= 0 then
                        horse = MyHorse
                    end
                end
                playLesson(horse)
                local payload = Core.Callback.TriggerAwait('bcc-stables:TrainHorse', {
                    horseId = target.horseId,
                    skill = skill,
                    ownerSrc = target.ownerSrc,
                })
                TrainingBusy = false
                if type(payload) == 'table' and payload.levels then
                    if horse and horse ~= 0 and DoesEntityExist(horse) then
                        HorseTraining.Apply(horse, payload)
                    end
                    Wait(250)
                    HorseTraining.OpenMenu()
                end
            end)
        end)
    end
    return page
end

function HorseTraining.OpenMenu()
    if cfg().Enabled == false then return end
    if TrainingBusy then return end
    local result = Core.Callback.TriggerAwait('bcc-stables:GetTrainTargets')
    if not result or not result.ok then
        if result and result.reason == 'job' then
            return Core.NotifyRightTip(_U('trainNeedJob'), 4000)
        end
        if result and result.reason == 'yard' then
            return Core.NotifyRightTip(_U('trainNoTargets'), 4000)
        end
        return Core.NotifyRightTip(_U('trainNoTargets'), 4000)
    end
    if not result.list or #result.list == 0 then
        return Core.NotifyRightTip(_U('trainNoTargets'), 4000)
    end

    local menu = FeatherMenu:RegisterMenu('bcc-stables:train', {
        top = '12%', left = '3%',
        ['1080width'] = '460px',
        contentslot = { style = { ['min-height'] = '280px' } },
        canclose = true, draggable = true,
    })
    local home = menu:RegisterPage('train:home')
    home:RegisterElement('header', { value = _U('trainMenu'), slot = 'header' })
    home:RegisterElement('textdisplay', {
        value = 'One rank per visit. The owner must bring this horse back for the next lesson.'
    })
    for i = 1, #result.list do
        local target = result.list[i]
        local cd = tonumber(target.cooldown) or 0
        local suffix = cd > 0 and (' (rest %sm)'):format(math.ceil(cd / 60)) or ''
        home:RegisterElement('button', {
            label = (target.horseName or 'Horse') .. ' — ' .. (target.ownerName or 'Owner') .. suffix
        }, function()
            local skills = openSkillPage(menu, target, result.maxLevel or 5, result.fee or {})
            menu:Open({ startupPage = skills })
        end)
    end
    menu:Open({ startupPage = home })
end

RegisterNetEvent('bcc-stables:ApplyTraining', function(payload)
    if type(payload) ~= 'table' then return end
    if HorseTraining.HorseId and tonumber(payload.horseId) ~= tonumber(HorseTraining.HorseId) then return end
    if MyHorse and MyHorse ~= 0 and DoesEntityExist(MyHorse) then
        HorseTraining.Apply(MyHorse, payload)
    else
        HorseTraining.Levels = payload.levels or HorseTraining.Levels
    end
end)

local function nearTrainer(coords)
    local maxDist = 3.0
    for _, site in pairs(Trainers or {}) do
        if site.shop and tonumber(site.shop.distance) then
            maxDist = tonumber(site.shop.distance)
        end
        local npc = site.npc
        if npc and npc.coords then
            local c = npc.coords
            local pos = vector3(tonumber(c.x) or 0.0, tonumber(c.y) or 0.0, tonumber(c.z) or 0.0)
            if #(coords - pos) <= maxDist then
                return site
            end
        end
    end
    return nil
end

CreateThread(function()
    Wait(1500)
    TrainGroup = GetRandomIntInRange(0, 0xffffff)
    TrainPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(TrainPrompt, Config.keys.shop)
    UiPromptSetText(TrainPrompt, CreateVarString(10, 'LITERAL_STRING', _U('trainPrompt')))
    UiPromptSetVisible(TrainPrompt, true)
    UiPromptSetEnabled(TrainPrompt, true)
    UiPromptSetStandardMode(TrainPrompt, true)
    UiPromptSetGroup(TrainPrompt, TrainGroup, 0)
    UiPromptRegisterEnd(TrainPrompt)

    while true do
        local sleep = 1000
        if cfg().Enabled ~= false and not TrainingBusy then
            local ped = PlayerPedId()
            local site = nearTrainer(GetEntityCoords(ped))
            local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, ped)
            local onWildTame = mount and mount ~= 0 and mount ~= MyHorse
            if site and not IsEntityDead(ped) and not onWildTame then
                sleep = 0
                local title = (site.shop and site.shop.prompt) or _U('trainMenu')
                UiPromptSetActiveGroupThisFrame(TrainGroup, CreateVarString(10, 'LITERAL_STRING', title), 1, 0, 0, 0)
                if UiPromptHasStandardModeCompleted(TrainPrompt, 0) then
                    HorseTraining.OpenMenu()
                end
            end
        end
        Wait(sleep)
    end
end)
