local Core = exports.vorp_core:GetCore()

local SKILLS = {
    speed = 'train_speed',
    health = 'train_health',
    stamina = 'train_stamina',
    bravery = 'train_bravery',
    bond = 'train_bond',
}

local function cfg()
    return Config.HorseTraining or {}
end

local function characterOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

local function normJob(name)
    if type(name) ~= 'string' then return '' end
    return name:lower():gsub('%s+', '')
end

local function jobAllowed(name, grade)
    name = normJob(name)
    grade = tonumber(grade) or 0
    if name == '' then return false end
    for _, job in pairs(Config.trainerJob or {}) do
        if name == normJob(job.name) and grade >= tonumber(job.grade or 0) then
            return true
        end
    end
    return false
end

function HasTrainerJob(src, character)
    character = character or characterOf(src)
    if not character then return false end
    if jobAllowed(character.job, character.jobGrade) then
        return true
    end
    if GetResourceState('viking_multijob') == 'started' then
        for _, job in pairs(Config.trainerJob or {}) do
            local ok, has = pcall(function()
                return exports.viking_multijob:HasJob(src, job.name)
            end)
            if ok and has then
                return true
            end
        end
    end
    return false
end

local function isTrainer(character, src)
    return HasTrainerJob(src, character)
end

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearTrainerYard(coords)
    if not coords then return false end
    local maxDist = tonumber(cfg().YardDistance) or 8.0
    for _, site in pairs(Trainers or {}) do
        local npc = site and site.npc
        if npc and npc.coords then
            local c = npc.coords
            local pos = vector3(tonumber(c.x) or 0.0, tonumber(c.y) or 0.0, tonumber(c.z) or 0.0)
            if #(coords - pos) <= maxDist then
                return true
            end
        end
    end
    return false
end

local function asInt(n)
    if n == true then return 1 end
    if n == false or n == nil then return 0 end
    return math.floor(tonumber(n) or 0)
end

local function clampLevel(n)
    n = asInt(n)
    local maxLevel = tonumber(cfg().MaxLevel) or 5
    if n < 0 then return 0 end
    if n > maxLevel then return maxLevel end
    return n
end

local function trainingSnapshot(row)
    return {
        speed = clampLevel(row.train_speed),
        health = clampLevel(row.train_health),
        stamina = clampLevel(row.train_stamina),
        bravery = clampLevel(row.train_bravery),
        bond = clampLevel(row.train_bond),
        last_train_at = tonumber(row.last_train_at) or 0,
    }
end

local function cooldownLeft(row)
    local minutes = tonumber(cfg().CooldownMinutes) or 60
    local last = tonumber(row.last_train_at) or 0
    if last <= 0 then return 0 end
    local remain = (last + (minutes * 60)) - os.time()
    if remain < 0 then return 0 end
    return remain
end

local function findOwnerSource(identifier, charid)
    charid = tonumber(charid)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = characterOf(src)
        if character and character.identifier == identifier and tonumber(character.charIdentifier) == charid then
            return src
        end
    end
    return nil
end

Core.Callback.Register('bcc-stables:GetTrainTargets', function(source, cb)
    local src = source
    if Schema and Schema.Wait then Schema.Wait() end
    local trainer = characterOf(src)
    if not trainer or not isTrainer(trainer, src) then
        return cb({ ok = false, reason = 'job' })
    end
    local trainerCoords = coordsOf(src)
    if not nearTrainerYard(trainerCoords) then
        return cb({ ok = false, reason = 'yard' })
    end

    local maxDist = (tonumber(cfg().YardDistance) or 8.0) + 4.0
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local ownerSrc = tonumber(id)
        local owner = characterOf(ownerSrc)
        if owner then
            if ownerSrc == src and cfg().AllowOwnHorse == false then
                goto nextplayer
            end
            local ownerCoords = coordsOf(ownerSrc)
            if ownerCoords and #(trainerCoords - ownerCoords) <= maxDist then
                local horse = MySQL.single.await(
                    'SELECT * FROM player_horses WHERE identifier = ? AND charid = ? AND selected = 1 AND dead = 0 LIMIT 1',
                    { owner.identifier, owner.charIdentifier }
                )
                if horse then
                    local remain = cooldownLeft(horse)
                    list[#list + 1] = {
                        ownerSrc = ownerSrc,
                        ownerName = ((owner.firstname or '') .. ' ' .. (owner.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                        horseId = horse.id,
                        horseName = horse.name or 'Horse',
                        levels = trainingSnapshot(horse),
                        cooldown = remain,
                        xp = tonumber(horse.xp) or 0,
                    }
                end
            end
        end
        ::nextplayer::
    end
    cb({ ok = true, maxLevel = tonumber(cfg().MaxLevel) or 5, fee = cfg().Fee or {}, list = list })
end)

Core.Callback.Register('bcc-stables:TrainHorse', function(source, cb, horseId, skill, ownerSrc)
    local src = source
    if Schema and Schema.Wait then Schema.Wait() end
    if type(horseId) == 'table' then
        local data = horseId
        horseId = data.horseId
        skill = data.skill
        ownerSrc = data.ownerSrc
    end
    local trainer = characterOf(src)
    if not trainer or not isTrainer(trainer, src) then
        Core.NotifyRightTip(src, _U('trainNeedJob'), 4000)
        return cb(false)
    end

    skill = tostring(skill or '')
    local column = SKILLS[skill]
    if not column then return cb(false) end

    horseId = tonumber(horseId)
    ownerSrc = tonumber(ownerSrc)
    if not horseId or not ownerSrc then return cb(false) end

    local owner = characterOf(ownerSrc)
    if not owner then return cb(false) end
    if ownerSrc == src and cfg().AllowOwnHorse == false then return cb(false) end

    local trainerCoords = coordsOf(src)
    local ownerCoords = coordsOf(ownerSrc)
    if not nearTrainerYard(trainerCoords) or not ownerCoords then return cb(false) end
    local maxDist = (tonumber(cfg().YardDistance) or 8.0) + 4.0
    if #(trainerCoords - ownerCoords) > maxDist then return cb(false) end

    local horse = HorseUtil.GetOwned(horseId)
    if not HorseUtil.Owns(horse, owner.identifier, owner.charIdentifier) then return cb(false) end
    if tonumber(horse.locked) == 1 then
        Core.NotifyRightTip(src, 'This horse cannot be trained right now.', 4000)
        return cb(false)
    end

    local remain = cooldownLeft(horse)
    if remain > 0 then
        local mins = math.ceil(remain / 60)
        Core.NotifyRightTip(src, _U('trainOnCooldown') .. ' (' .. mins .. 'm)', 4000)
        Core.NotifyRightTip(ownerSrc, _U('trainOnCooldown') .. ' (' .. mins .. 'm)', 4000)
        return cb(false)
    end

    local maxLevel = tonumber(cfg().MaxLevel) or 5
    local current = clampLevel(horse[column])
    if current >= maxLevel then
        Core.NotifyRightTip(src, _U('trainMaxed'), 4000)
        return cb(false)
    end

    local nextLevel = current + 1
    local fees = cfg().Fee or {}
    local cost = math.floor((tonumber(fees[skill]) or 20) * nextLevel)
    if cost > 0 and ownerSrc ~= src then
        if (tonumber(owner.money) or 0) < cost then
            Core.NotifyRightTip(src, _U('trainNoCash'), 4000)
            Core.NotifyRightTip(ownerSrc, _U('trainNoCash'), 4000)
            return cb(false)
        end
        owner.removeCurrency(0, cost)
        trainer.addCurrency(0, cost)
    elseif cost > 0 and ownerSrc == src then
        if (tonumber(owner.money) or 0) < cost then
            Core.NotifyRightTip(src, _U('trainNoCash'), 4000)
            return cb(false)
        end
        owner.removeCurrency(0, cost)
    end

    local newXp = tonumber(horse.xp) or 0
    if skill == 'bond' then
        newXp = newXp + (tonumber(cfg().BondXpPerLevel) or 450)
        MySQL.update.await(
            ('UPDATE player_horses SET `%s` = ?, xp = ?, last_train_at = ? WHERE id = ?'):format(column),
            { nextLevel, newXp, os.time(), horseId }
        )
    else
        MySQL.update.await(
            ('UPDATE player_horses SET `%s` = ?, last_train_at = ? WHERE id = ?'):format(column),
            { nextLevel, os.time(), horseId }
        )
    end

    local updated = HorseUtil.GetOwned(horseId)
    local payload = {
        horseId = horseId,
        skill = skill,
        levels = trainingSnapshot(updated),
        xp = tonumber(updated.xp) or newXp,
        nextLevel = nextLevel,
        maxLevel = maxLevel,
        cost = cost,
    }

    TriggerClientEvent('bcc-stables:ApplyTraining', ownerSrc, payload)

    local skillLabel = _U('train' .. skill:gsub('^%l', string.upper))
    if skill == 'bond' then skillLabel = _U('trainBond') end
    Core.NotifyRightTip(src, _U('trainDone') .. ' ' .. (horse.name or '') .. ' — ' .. skillLabel .. ' ' .. nextLevel .. '/' .. maxLevel, 5000)
    if ownerSrc ~= src then
        Core.NotifyRightTip(ownerSrc, _U('trainOwnerDone') .. ' ' .. skillLabel .. ' ' .. nextLevel .. '/' .. maxLevel, 6000)
    end
    cb(payload)
end)
