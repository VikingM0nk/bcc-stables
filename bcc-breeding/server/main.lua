local Core = exports.vorp_core:GetCore()

local PHASE = {
    FAMILIARISE = 0,
    EXERCISE = 1,
    REST = 2,
    PREGNANT = 3,
    READY = 4,
}

local PHASE_NAME = {
    [0] = 'Familiarising',
    [1] = 'Exercise',
    [2] = 'Rest',
    [3] = 'Pregnancy',
    [4] = 'Ready',
}

local cooldownUntil = {}

local function notify(src, msg)
    Core.NotifyRightTip(src, msg, 4000)
end

local function characterOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

local function stablesReady()
    return GetResourceState('bcc-stables') == 'started'
end

local function isBreeder(src)
    if not stablesReady() then return false end
    return exports['bcc-stables']:IsBreeder(src) == true
end

local function getYard(key)
    for i = 1, #Config.Yards do
        if Config.Yards[i].key == key then return Config.Yards[i] end
    end
end

local function atYard(src, key)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, nil end
    local coords = GetEntityCoords(ped)
    for i = 1, #Config.Yards do
        local yard = Config.Yards[i]
        if (not key or yard.key == key) and #(coords - yard.menu) <= (Config.PromptDistance or 3.0) + 2.5 then
            return true, yard
        end
    end
    return false, nil
end

local function atExercise(src, yard)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not yard then return false end
    return #(GetEntityCoords(ped) - yard.exercise) <= (Config.ExerciseDistance or 18.0)
end

local function scaled(seconds)
    return math.max(5, math.floor((tonumber(seconds) or 0) * (Config.TimerScale or 1.0)))
end

local function charKey(character)
    return tostring(character.identifier) .. ':' .. tostring(character.charIdentifier)
end

local function horseOf(id)
    if not stablesReady() then return nil end
    return exports['bcc-stables']:GetHorse(id)
end

local function lockHorse(id, on, reason)
    if not stablesReady() then return end
    exports['bcc-stables']:SetHorseLock(id, on and true or false, reason or '')
end

local function setPregnant(id, on, phase)
    if not stablesReady() then return end
    exports['bcc-stables']:SetPregnant(id, on and true or false, phase or -1)
end

local function breedableHorse(row)
    if not row or tonumber(row.dead) == 1 then return false end
    if tonumber(row.gelded) == 1 then return false end
    if tonumber(row.pregnant) == 1 then return false end
    if tonumber(row.locked) == 1 then return false end
    if not stablesReady() then return false end
    return exports['bcc-stables']:CanBreedHorse(row) == true
end

CreateThread(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcc_breeding_sessions` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `yard` VARCHAR(40) NOT NULL,
          `identifier` VARCHAR(80) NOT NULL,
          `charid` INT NOT NULL,
          `male_id` INT NOT NULL,
          `female_id` INT NOT NULL,
          `phase` INT NOT NULL DEFAULT 0,
          `ready_at` BIGINT NOT NULL DEFAULT 0,
          `exercised` TINYINT(1) NOT NULL DEFAULT 0,
          `created_at` BIGINT NOT NULL,
          PRIMARY KEY (`id`),
          INDEX `idx_breed_char` (`identifier`, `charid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])
end)

local function sessionOf(id)
    return MySQL.single.await('SELECT * FROM bcc_breeding_sessions WHERE id = ?', { tonumber(id) })
end

local function sessionsFor(character)
    return MySQL.query.await(
        'SELECT * FROM bcc_breeding_sessions WHERE identifier = ? AND charid = ? ORDER BY id DESC',
        { character.identifier, character.charIdentifier }
    ) or {}
end

local function horseLabel(row)
    if not row then return 'Unknown horse' end
    return ('%s (%s %s)'):format(row.name or 'Horse', row.gender or '?', row.genotype ~= '' and row.genotype or row.model)
end

local function describe(row)
    local male = horseOf(row.male_id)
    local female = horseOf(row.female_id)
    local now = os.time()
    local wait = math.max(0, (tonumber(row.ready_at) or 0) - now)
    return {
        id = row.id,
        yard = row.yard,
        phase = tonumber(row.phase) or 0,
        phaseName = PHASE_NAME[tonumber(row.phase) or 0] or 'Unknown',
        readyAt = tonumber(row.ready_at) or 0,
        wait = wait,
        exercised = tonumber(row.exercised) == 1,
        male = horseLabel(male),
        female = horseLabel(female),
        canAdvance = wait <= 0,
        canCollect = (tonumber(row.phase) or 0) == PHASE.READY,
    }
end

Core.Callback.Register('bcc-breeding:Open', function(source, cb, yardKey)
    local src = source
    local near, yard = atYard(src, yardKey)
    if not near then return cb(false) end
    local character = characterOf(src)
    if not character then return cb(false) end
    local sessions = {}
    for _, row in ipairs(sessionsFor(character)) do
        if row.yard == yard.key then
            sessions[#sessions + 1] = describe(row)
        end
    end
    local horses = {}
    if stablesReady() then
        horses = exports['bcc-stables']:GetOwnedHorses(src) or {}
    end
    local list = {}
    for i = 1, #horses do
        local h = horses[i]
        list[#list + 1] = {
            id = h.id,
            name = h.name,
            gender = h.gender,
            genotype = h.genotype,
            breedable = breedableHorse(h),
            locked = tonumber(h.locked) == 1,
            gelded = tonumber(h.gelded) == 1,
            pregnant = tonumber(h.pregnant) == 1,
        }
    end
    cb({
        yard = yard.key,
        label = yard.label,
        isBreeder = isBreeder(src),
        startCost = Config.StartCost,
        skipCost = Config.SkipCost,
        sessions = sessions,
        horses = list,
    })
end)

Core.Callback.Register('bcc-breeding:Create', function(source, cb, yardKey, maleId, femaleId)
    local src = source
    if not isBreeder(src) then
        notify(src, 'Horse breeding is locked to the Horse Breeder job.')
        return cb(false)
    end
    local near, yard = atYard(src, yardKey)
    if not near then return cb(false) end
    local character = characterOf(src)
    if not character then return cb(false) end

    local key = charKey(character)
    if (cooldownUntil[key] or 0) > os.time() then
        notify(src, 'Give the stock a rest before starting another pairing.')
        return cb(false)
    end

    local active = sessionsFor(character)
    if #active >= (Config.MaxSessionsPerCharacter or 3) then
        notify(src, 'You already have too many pairings in progress.')
        return cb(false)
    end

    local male = horseOf(tonumber(maleId))
    local female = horseOf(tonumber(femaleId))
    if not male or not female then
        notify(src, 'Those horses could not be found.')
        return cb(false)
    end
    if male.identifier ~= character.identifier or tonumber(male.charid) ~= tonumber(character.charIdentifier) then
        notify(src, 'You do not own that stallion.')
        return cb(false)
    end
    if female.identifier ~= character.identifier or tonumber(female.charid) ~= tonumber(character.charIdentifier) then
        notify(src, 'You do not own that mare.')
        return cb(false)
    end
    if tostring(male.gender or ''):lower() ~= 'male' or tostring(female.gender or ''):lower() ~= 'female' then
        notify(src, 'Pick one stallion and one mare.')
        return cb(false)
    end
    if not breedableHorse(male) or not breedableHorse(female) then
        notify(src, 'One of those horses cannot be bred.')
        return cb(false)
    end
    if tonumber(male.id) == tonumber(female.id) then
        notify(src, 'Pick two different horses.')
        return cb(false)
    end

    local cost = tonumber(Config.StartCost) or 0
    if cost > 0 then
        if character.money < cost then
            notify(src, 'You do not have enough money.')
            return cb(false)
        end
        character.removeCurrency(0, cost)
        if stablesReady() and yard.stable then
            pcall(function()
                exports['bcc-stables']:CreditStableSale(yard.stable, cost)
            end)
        end
    end

    lockHorse(male.id, true, 'breeding')
    lockHorse(female.id, true, 'breeding')
    local readyAt = os.time() + scaled(Config.Timers.familiarising)
    MySQL.insert.await([[
        INSERT INTO bcc_breeding_sessions
        (yard, identifier, charid, male_id, female_id, phase, ready_at, exercised, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?)
    ]], {
        yard.key, character.identifier, character.charIdentifier,
        male.id, female.id, PHASE.FAMILIARISE, readyAt, os.time(),
    })
    notify(src, 'Pairing started. Let them get used to each other.')
    cb(true)
end)

Core.Callback.Register('bcc-breeding:Advance', function(source, cb, sessionId)
    local src = source
    if not isBreeder(src) then
        notify(src, 'Horse breeding is locked to the Horse Breeder job.')
        return cb(false)
    end
    local character = characterOf(src)
    if not character then return cb(false) end
    local row = sessionOf(sessionId)
    if not row or row.identifier ~= character.identifier or tonumber(row.charid) ~= tonumber(character.charIdentifier) then
        return cb(false)
    end
    local yard = getYard(row.yard)
    local near = atYard(src, row.yard)
    if not near then
        notify(src, 'Return to the breeding yard.')
        return cb(false)
    end

    local phase = tonumber(row.phase) or 0
    if phase >= PHASE.READY then
        notify(src, 'This pairing is ready to collect.')
        return cb(false)
    end

    if phase == PHASE.EXERCISE then
        if not atExercise(src, yard) then
            notify(src, 'Walk them in the exercise ring first.')
            return cb(false)
        end
        MySQL.update.await('UPDATE bcc_breeding_sessions SET exercised = 1, phase = ?, ready_at = ? WHERE id = ?', {
            PHASE.REST, os.time() + scaled(Config.Timers.rest), row.id
        })
        notify(src, 'Exercise done. They need rest.')
        return cb(true)
    end

    if os.time() < (tonumber(row.ready_at) or 0) then
        notify(src, 'They are not ready yet.')
        return cb(false)
    end

    if phase == PHASE.FAMILIARISE then
        MySQL.update.await('UPDATE bcc_breeding_sessions SET phase = ?, ready_at = ? WHERE id = ?', {
            PHASE.EXERCISE, os.time(), row.id
        })
        notify(src, 'Take them to the exercise ring.')
        return cb(true)
    end

    if phase == PHASE.REST then
        setPregnant(row.female_id, true, PHASE.PREGNANT)
        MySQL.update.await('UPDATE bcc_breeding_sessions SET phase = ?, ready_at = ? WHERE id = ?', {
            PHASE.PREGNANT, os.time() + scaled(Config.Timers.pregnancy), row.id
        })
        notify(src, 'The mare is in foal.')
        return cb(true)
    end

    if phase == PHASE.PREGNANT then
        MySQL.update.await('UPDATE bcc_breeding_sessions SET phase = ?, ready_at = ? WHERE id = ?', {
            PHASE.READY, os.time(), row.id
        })
        notify(src, 'The foal is ready to be registered.')
        return cb(true)
    end

    cb(false)
end)

Core.Callback.Register('bcc-breeding:Skip', function(source, cb, sessionId)
    local src = source
    if not isBreeder(src) then return cb(false) end
    local cost = tonumber(Config.SkipCost) or 0
    if cost <= 0 then
        notify(src, 'Paid skips are disabled.')
        return cb(false)
    end
    local character = characterOf(src)
    if not character then return cb(false) end
    local row = sessionOf(sessionId)
    if not row or row.identifier ~= character.identifier or tonumber(row.charid) ~= tonumber(character.charIdentifier) then
        return cb(false)
    end
    if not atYard(src, row.yard) then return cb(false) end
    if character.money < cost then
        notify(src, 'You do not have enough money.')
        return cb(false)
    end
    character.removeCurrency(0, cost)
    MySQL.update.await('UPDATE bcc_breeding_sessions SET ready_at = ? WHERE id = ?', { os.time(), row.id })
    notify(src, 'The wait was shortened.')
    cb(true)
end)

Core.Callback.Register('bcc-breeding:Collect', function(source, cb, sessionId, foalName)
    local src = source
    if not isBreeder(src) then return cb(false) end
    local character = characterOf(src)
    if not character then return cb(false) end
    local row = sessionOf(sessionId)
    if not row or row.identifier ~= character.identifier or tonumber(row.charid) ~= tonumber(character.charIdentifier) then
        return cb(false)
    end
    if not atYard(src, row.yard) then return cb(false) end
    if tonumber(row.phase) ~= PHASE.READY then
        notify(src, 'The foal is not ready yet.')
        return cb(false)
    end

    local male = horseOf(row.male_id)
    local female = horseOf(row.female_id)
    if not male or not female then
        notify(src, 'A parent is missing.')
        return cb(false)
    end

    local countRow = MySQL.single.await(
        'SELECT COUNT(*) AS n FROM player_horses WHERE identifier = ? AND charid = ? AND dead = 0',
        { character.identifier, character.charIdentifier }
    )
    local owned = tonumber(countRow and countRow.n) or 0
    local maxHorses = 15
    if stablesReady() then
        maxHorses = tonumber(exports['bcc-stables']:MaxHorses(false)) or 15
    end
    if owned >= maxHorses then
        notify(src, 'Your stable is full.')
        return cb(false)
    end

    local foal = exports['bcc-stables']:RollFoal(male, female)
    if not foal then
        notify(src, 'Breeding failed to produce a coat.')
        return cb(false)
    end

    local name = tostring(foalName or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'Foal' end
    if #name > 24 then name = name:sub(1, 24) end

    exports['bcc-stables']:InsertOwnedHorse({
        identifier = character.identifier,
        charid = character.charIdentifier,
        name = name,
        catalog_id = foal.catalog_id,
        model = foal.model,
        gender = foal.gender,
        captured = 0,
        breeding_color = foal.breeding_color,
        breeding_pattern = foal.breeding_pattern,
        genotype = foal.genotype,
        personality = foal.personality,
        age_days = 0,
        foal_phase = 0,
    })

    lockHorse(row.male_id, false, '')
    lockHorse(row.female_id, false, '')
    setPregnant(row.female_id, false, -1)
    MySQL.update.await('DELETE FROM bcc_breeding_sessions WHERE id = ?', { row.id })
    cooldownUntil[charKey(character)] = os.time() + (Config.CooldownSeconds or 1800)
    notify(src, ('%s has been added to your stable.'):format(name))
    cb(true)
end)

AddEventHandler('playerDropped', function()
    -- locks stay in DB so a crash cannot orphan a pairing
end)
