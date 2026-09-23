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

local function setRank(horse, attr, rank)
    rank = math.max(0, math.min(10, math.floor(tonumber(rank) or 0)))
    pcall(function()
        Citizen.InvokeNative(0x5DA12E025D47D4E5, horse, attr, rank) -- SetAttributeBaseRank
    end)
end

local function addCore(horse, core, amount)
    amount = tonumber(amount) or 0
    if amount == 0 then return end
    local cur = Citizen.InvokeNative(0x36731AC041289BB1, horse, core, Citizen.ResultAsInteger()) or 0
    Citizen.InvokeNative(0xC6258F41D86676E0, horse, core, math.min(100, cur + amount))
end

local function startRateThread()
    if rateThread then return end
    rateThread = true
    CreateThread(function()
        while true do
            Wait(2000)
            local lvl = 0
            if MyHorse and MyHorse ~= 0 and DoesEntityExist(MyHorse) then
                lvl = tonumber(HorseTraining.Levels.speed) or 0
                if lvl > 0 then
                    pcall(SetPedMoveRateOverride, MyHorse, 1.0 + (lvl * (cfg().SpeedPerLevel or 0.045)))
                end
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
        speed = tonumber(levels.speed) or 0,
        health = tonumber(levels.health) or 0,
        stamina = tonumber(levels.stamina) or 0,
        bravery = tonumber(levels.bravery) or 0,
        bond = tonumber(levels.bond) or 0,
    }

    if HorseTraining.LastHorse ~= horse then
        HorseTraining.Applied = { speed = 0, health = 0, stamina = 0, bravery = 0, bond = 0 }
        HorseTraining.LastHorse = horse
    end
    local applied = HorseTraining.Applied
    local wanted = HorseTraining.Levels
    local coreBoost = tonumber(cfg().CorePerLevel) or 8

    local dSpeed = wanted.speed - (applied.speed or 0)
    if dSpeed > 0 then
        local curSpeed = Citizen.InvokeNative(0x147149F2E909323C, horse, ATTR.SPEED, Citizen.ResultAsInteger()) or 0
        local curAccel = Citizen.InvokeNative(0x147149F2E909323C, horse, ATTR.ACCEL, Citizen.ResultAsInteger()) or 0
        setRank(horse, ATTR.SPEED, curSpeed + dSpeed)
        setRank(horse, ATTR.ACCEL, curAccel + dSpeed)
    end
    if wanted.speed > 0 then
        pcall(SetPedMoveRateOverride, horse, 1.0 + (wanted.speed * (cfg().SpeedPerLevel or 0.045)))
        startRateThread()
    end

    local dHealth = wanted.health - (applied.health or 0)
    if dHealth > 0 then
        local cur = Citizen.InvokeNative(0x147149F2E909323C, horse, ATTR.HEALTH, Citizen.ResultAsInteger()) or 0
        setRank(horse, ATTR.HEALTH, cur + dHealth)
        addCore(horse, 0, dHealth * coreBoost)
    end

    local dStamina = wanted.stamina - (applied.stamina or 0)
    if dStamina > 0 then
        local cur = Citizen.InvokeNative(0x147149F2E909323C, horse, ATTR.STAMINA, Citizen.ResultAsInteger()) or 0
        setRank(horse, ATTR.STAMINA, cur + dStamina)
        addCore(horse, 1, dStamina * coreBoost)
    end

    local dBrave = wanted.bravery - (applied.bravery or 0)
    if dBrave > 0 or wanted.bravery > 0 then
        if dBrave > 0 then
            local cur = Citizen.InvokeNative(0x147149F2E909323C, horse, ATTR.COURAGE, Citizen.ResultAsInteger()) or 0
            setRank(horse, ATTR.COURAGE, cur + (dBrave * 2))
        end
        Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 113, wanted.bravery >= 2)
        Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 312, wanted.bravery >= 3)
        if wanted.bravery >= 4 then
            Citizen.InvokeNative(0x1913FE4CBF41C463, horse, 471, true)
        end
    end

    if data.xp then
        Citizen.InvokeNative(0x09A59688C26D88DF, horse, ATTR.BOND, tonumber(data.xp) or 0)
    end

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
                Core.Callback.TriggerAwait('bcc-stables:TrainHorse', target.horseId, skill, target.ownerSrc)
                TrainingBusy = false
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
