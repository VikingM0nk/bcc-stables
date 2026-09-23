local Core = exports.vorp_core:GetCore()

local function characterOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

exports('MaxHorses', function(isTrainer)
    if isTrainer then return tonumber(Config.maxTrainerHorses) or 20 end
    return tonumber(Config.maxPlayerHorses) or 15
end)

exports('GetCatalog', function()
    Catalog.Enrich()
    return Horses
end)

exports('CanBreedHorse', function(row)
    if not row then return false end
    if tonumber(row.gelded) == 1 or tonumber(row.pregnant) == 1 or tonumber(row.locked) == 1 then
        return false
    end
    local key = row.catalog_id
    if not key or key == '' then key = row.model end
    local breedCfg, cfg = Catalog.Find(key)
    return Catalog.IsBreedable(cfg, breedCfg and breedCfg.breed)
end)

exports('FindHorse', function(idOrModel)
    return Catalog.Find(idOrModel)
end)

exports('RollFoal', function(male, female)
    return Genetics.RollFoal(male, female)
end)

exports('GetOwnedHorses', function(src)
    local character = characterOf(src)
    if not character then return {} end
    return MySQL.query.await(
        'SELECT * FROM player_horses WHERE identifier = ? AND charid = ? AND dead = 0 ORDER BY selected DESC, id ASC',
        { character.identifier, character.charIdentifier }
    ) or {}
end)

exports('GetHorse', function(id)
    return HorseUtil.GetOwned(id)
end)

exports('InsertOwnedHorse', function(row)
    return HorseUtil.InsertOwned(row)
end)

exports('SetHorseLock', function(id, locked, reason)
    MySQL.update.await('UPDATE player_horses SET locked = ?, lock_reason = ? WHERE id = ?', {
        locked and 1 or 0, reason or '', id
    })
end)

exports('SetPregnant', function(id, pregnant, phase)
    MySQL.update.await('UPDATE player_horses SET pregnant = ?, foal_phase = ? WHERE id = ?', {
        pregnant and 1 or 0, tonumber(phase) or -1, id
    })
end)

exports('TransferHorse', function(id, identifier, charid)
    MySQL.update.await('UPDATE player_horses SET identifier = ?, charid = ?, selected = 0 WHERE id = ?', {
        identifier, charid, id
    })
end)

exports('CreditStableSale', function(stableKey, amount)
    if StableBiz then StableBiz.CreditSale(stableKey, amount) end
end)

exports('IsBreeder', function(src)
    local character = characterOf(src)
    if not character then return false end
    if Config.BreedingJob and Config.BreedingJob.AdminBypass and StableBiz.IsAdmin(src) then
        return true
    end
    local jobs = (Config.BreedingJob and Config.BreedingJob.RequiredJobs) or {}
    for i = 1, #jobs do
        local job = jobs[i]
        if character.job == job.name and tonumber(character.jobGrade) >= tonumber(job.grade or 0) then
            return true
        end
    end
    return false
end)

RegisterNetEvent('bcc-stables:SaveCare', function(horseId, hunger, thirst, clean, love)
    local src = source
    local character = characterOf(src)
    if not character then return end
    horseId = tonumber(horseId)
    local horse = HorseUtil.GetOwned(horseId)
    if not HorseUtil.Owns(horse, character.identifier, character.charIdentifier) then return end
    MySQL.update.await(
        'UPDATE player_horses SET care_hunger = ?, care_thirst = ?, care_clean = ?, care_love = ?, last_care_at = ? WHERE id = ?',
        {
            math.max(0, math.min(100, math.floor(tonumber(hunger) or 0))),
            math.max(0, math.min(100, math.floor(tonumber(thirst) or 0))),
            math.max(0, math.min(100, math.floor(tonumber(clean) or 0))),
            math.max(0, math.min(100, math.floor(tonumber(love) or 0))),
            os.time(),
            horseId,
        }
    )
end)

Core.Callback.Register('bcc-stables:GeldHorse', function(source, cb, horseId)
    local src = source
    local character = characterOf(src)
    if not character then return cb(false) end
    local horse = HorseUtil.GetOwned(tonumber(horseId))
    if not HorseUtil.Owns(horse, character.identifier, character.charIdentifier) then return cb(false) end
    if tonumber(horse.gelded) == 1 then
        Core.NotifyRightTip(src, 'Already gelded or spayed.', 4000)
        return cb(false)
    end
    if tonumber(horse.pregnant) == 1 then
        Core.NotifyRightTip(src, 'Cannot geld a pregnant mare.', 4000)
        return cb(false)
    end
    local cost = tonumber(Config.GeldCost) or 75
    if character.money < cost then
        Core.NotifyRightTip(src, _U('shortCash'), 4000)
        return cb(false)
    end
    character.removeCurrency(0, cost)
    MySQL.update.await('UPDATE player_horses SET gelded = 1 WHERE id = ?', { horse.id })
    Core.NotifyRightTip(src, 'The horse has been gelded / spayed.', 4000)
    cb(true)
end)
