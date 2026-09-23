local Core = exports.vorp_core:GetCore()
local BccUtils = exports['bcc-utils'].initiate()
local CooldownData = {}
local DevModeActive = Config.devMode

local function DebugPrint(message)
    if DevModeActive then
        print('^1[DEV MODE] ^4' .. message)
    end
end

if Config.discord.active == true then
    Discord = BccUtils.Discord.setup(Config.discord.webhookURL, Config.discord.title, Config.discord.avatar)
end

local function LogToDiscord(name, description, embeds)
    if Config.discord.active == true then
        Discord:sendMessage(name, description, embeds)
    end
end

local function SetPlayerCooldown(type, charid)
    CooldownData[type .. tostring(charid)] = os.time()
end

Core.Callback.Register('bcc-stables:BuyHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    local maxHorses = data.isTrainer and tonumber(Config.maxTrainerHorses) or tonumber(Config.maxPlayerHorses)

    local horseCount = MySQL.query.await('SELECT COUNT(*) as count FROM `player_horses` WHERE `charid` = ? AND `dead` = ?', { charid, 0 })[1].count
    if horseCount >= maxHorses then
        Core.NotifyRightTip(src, _U('horseLimit') .. maxHorses .. _U('horses'), 4000)
        return cb(false)
    end

    local model = data.ModelH
    local breedCfg, colorCfg = Catalog.Find(model)

    if not colorCfg then
        print('Horse model not found in the configuration')
        return cb(false)
    end

    if data.IsCash then
        if character.money >= colorCfg.cashPrice then
            cb(true)
        else
            Core.NotifyRightTip(src, _U('shortCash'), 4000)
            cb(false)
        end
    else
        if character.gold >= colorCfg.goldPrice then
            cb(true)
        else
            Core.NotifyRightTip(src, _U('shortGold'), 4000)
            cb(false)
        end
    end
end)

Core.Callback.Register('bcc-stables:RegisterHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    local maxHorses = data.isTrainer and tonumber(Config.maxTrainerHorses) or tonumber(Config.maxPlayerHorses)

    local horseCount = MySQL.query.await('SELECT COUNT(*) as count FROM `player_horses` WHERE `charid` = ? AND `dead` = ?', { charid, 0 })[1].count
    if horseCount >= maxHorses then
        Core.NotifyRightTip(src, _U('horseLimit') .. maxHorses .. _U('horses'), 4000)
        return cb(false)
    end

    if data.IsCash and data.origin == 'tameHorse' then
        if character.money >= Config.regCost then
            return cb(true)
        else
            Core.NotifyRightTip(src, _U('shortCash'), 4000)
            return cb(false)
        end
    end

    cb(false)
end)

Core.Callback.Register('bcc-stables:BuyTack', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local cashPrice = tonumber(data.cashPrice)
    local goldPrice = tonumber(data.goldPrice)

    if cashPrice > 0 and goldPrice > 0 then
        if tonumber(data.currencyType) == 0 then
            if character.money >= cashPrice then
                character.removeCurrency(0, cashPrice)
            else
                Core.NotifyRightTip(src, _U('shortCash'), 4000)
                return cb(false)
            end
        else
            if character.gold >= goldPrice then
                character.removeCurrency(1, goldPrice)
            else
                Core.NotifyRightTip(src, _U('shortGold'), 4000)
                return cb(false)
            end
        end
        Core.NotifyRightTip(src, _U('purchaseSuccessful'), 4000)
        if data.site then
            local price = tonumber(data.currencyType) == 0 and cashPrice or goldPrice
            StableBiz.CreditSale(data.site, price)
        end
        return cb(true)
    end

    cb(false)
end)

Core.Callback.Register('bcc-stables:SaveNewHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local name = data.name
    local model = data.ModelH
    local gender = data.gender
    local captured = data.captured
    local isCash = data.IsCash
    local currencyType = isCash and 0 or 1
    local priceKey = isCash and 'cashPrice' or 'goldPrice'
    local currency = isCash and character.money or character.gold
    local notification = isCash and _U('shortCash') or _U('shortGold')

    local _, colorCfg = Catalog.Find(model)
    if not colorCfg then return cb(false) end
    if currency >= colorCfg[priceKey] then
        character.removeCurrency(currencyType, colorCfg[priceKey])
        HorseUtil.InsertOwned({
            identifier = identifier,
            charid = charid,
            name = name,
            model = model,
            catalog_id = model,
            gender = gender,
            captured = captured,
        })
        if data.site then
            StableBiz.CreditSale(data.site, colorCfg[priceKey])
        end
        LogToDiscord(charid, _U('discordHorsePurchased'))
        return cb(true)
    end
    Core.NotifyRightTip(src, notification, 4000)
    cb(false)
end)

Core.Callback.Register('bcc-stables:SaveTamedHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local regCost = Config.regCost
    local name = data.name
    local model = data.ModelH
    local gender = data.gender
    local captured = data.captured

    if data.IsCash and data.origin == 'tameHorse' then
        if character.money < regCost then
            Core.NotifyRightTip(src, _U('shortCash'), 4000)
            return cb(false)
        end
        character.removeCurrency(0, regCost)
    end

    HorseUtil.InsertOwned({
        identifier = identifier,
        charid = charid,
        name = name,
        model = model,
        catalog_id = model,
        gender = gender,
        captured = captured,
    })

    LogToDiscord(charid, _U('discordTamedPurchased'))
    cb(true)
end)

Core.Callback.Register('bcc-stables:UpdateHorseName', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local newName = data.name
    local horseId = data.horseId

    MySQL.query.await('UPDATE `player_horses` SET `name` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { newName, horseId, identifier, charid })

    cb(true)
end)

RegisterNetEvent('bcc-stables:UpdateHorseXp', function(Xp, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `xp` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { Xp, horseId, identifier, charid })

    LogToDiscord(charid, _U('discordHorseXPGain'))
end)

RegisterNetEvent('bcc-stables:SaveHorseStatsToDb', function(health, stamina, id)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local horseHealth = tonumber(health) or 100
    local horseStamina = tonumber(stamina) or 100
    local horseId = tonumber(id)

    print("Saving horse stats to DB:", horseId, horseHealth, horseStamina)
    MySQL.query.await('UPDATE `player_horses` SET `health` = ?, `stamina` = ? WHERE id = ? AND `identifier` = ? AND `charid` = ?',
    { horseHealth, horseStamina, horseId, identifier, charid })
end)

RegisterNetEvent('bcc-stables:SelectHorse', function(data)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local selectedHorseId = data.horseId

    -- Deselect all horses for the character
    MySQL.query.await('UPDATE `player_horses` SET `selected` = ? WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { 0, charid, identifier, 0 })

    -- Select the specified horse
    MySQL.query.await('UPDATE `player_horses` SET `selected` = ? WHERE `id` = ? AND `charid` = ? AND `identifier` = ?',
    { 1, selectedHorseId, charid, identifier })
end)

RegisterNetEvent('bcc-stables:SetHorseWrithe', function(horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `writhe` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { 1, horseId, identifier, charid })
end)

-- Update Horse Selected and Dead Status After Death Event
RegisterNetEvent('bcc-stables:UpdateHorseStatus', function(horseId, action)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    local selected = (action == 'dead' or action == 'deselect') and 0 or 1
    local dead = action == 'dead' and 1 or 0

    MySQL.query.await('UPDATE `player_horses` SET `selected` = ?, `writhe` = ?, `dead` = ? WHERE `id` = ? AND `identifier` = ? AND `charid` = ?',
    { selected, 0, dead, horseId, identifier, charid })
end)

Core.Callback.Register('bcc-stables:GetHorseData', function(source, cb)
    local src = source
    local user = Core.getUser(src)

    if not user then
        DebugPrint('User not found for source: ' .. tostring(src))
        return cb(false)
    end

    local character = user.getUsedCharacter

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { character.charIdentifier, character.identifier, 0 })

    if #horses == 0 then
        Core.NotifyRightTip(src, _U('noHorses'), 4000)
        return cb(false)
    end

    local selectedHorse = nil
    for _, horse in ipairs(horses) do
        if horse.selected == 1 then
            selectedHorse = horse
            break
        end
    end

    if not selectedHorse then
        Core.NotifyRightTip(src, _U('noSelectedHorse'), 4000)
        return cb(false)
    end

    cb({
        model = selectedHorse.model,
        name = selectedHorse.name,
        components = selectedHorse.components,
        id = selectedHorse.id,
        gender = selectedHorse.gender,
        xp = selectedHorse.xp,
        captured = selectedHorse.captured,
        health = selectedHorse.health,
        stamina = selectedHorse.stamina,
        writhe = selectedHorse.writhe,
        catalog_id = selectedHorse.catalog_id,
        genotype = selectedHorse.genotype,
        personality = selectedHorse.personality,
        gelded = selectedHorse.gelded,
        pregnant = selectedHorse.pregnant,
        locked = selectedHorse.locked,
        lock_reason = selectedHorse.lock_reason,
        care_hunger = selectedHorse.care_hunger,
        care_thirst = selectedHorse.care_thirst,
        care_clean = selectedHorse.care_clean,
        care_love = selectedHorse.care_love,
        age_days = selectedHorse.age_days,
        foal_phase = selectedHorse.foal_phase,
        train_speed = selectedHorse.train_speed,
        train_health = selectedHorse.train_health,
        train_stamina = selectedHorse.train_stamina,
        train_bravery = selectedHorse.train_bravery,
        train_bond = selectedHorse.train_bond,
        last_train_at = selectedHorse.last_train_at,
        appearance = (function()
            local key = selectedHorse.catalog_id
            if not key or key == '' then key = selectedHorse.model end
            local _, cfg = Catalog.Find(key)
            return cfg and cfg.appearance or nil
        end)(),
    })
end)

Core.Callback.Register('bcc-stables:GetMyHorses', function(source, cb)
    local src = source
    local user = Core.getUser(src)

    -- Check if the user exists
    if not user then
        DebugPrint('User not found for source: ' .. tostring(src))
        return cb(false)
    end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    local horses = MySQL.query.await('SELECT * FROM `player_horses` WHERE `charid` = ? AND `identifier` = ? AND `dead` = ?', { charid, identifier, 0 })

    cb(horses)
end)

Core.Callback.Register('bcc-stables:UpdateComponents', function(source, cb, encodedComponents, horseId)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier

    MySQL.query.await('UPDATE `player_horses` SET `components` = ? WHERE `id` = ? AND `charid` = ? AND `identifier` = ?',
    { encodedComponents, horseId, charid, identifier })

    cb(true)
end)

Core.Callback.Register('bcc-stables:SellMyHorse', function(source, cb, data)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local identifier = character.identifier
    local charid = character.charIdentifier
    local horseId = tonumber(data.horseId)
    local horse = HorseUtil.GetOwned(horseId)
    if not HorseUtil.Owns(horse, identifier, charid) then return cb(false) end
    if tonumber(horse.pregnant) == 1 then
        Core.NotifyRightTip(src, 'A pregnant mare cannot be sold.', 4000)
        return cb(false)
    end
    if tonumber(horse.locked) == 1 then
        Core.NotifyRightTip(src, 'That horse is busy.', 4000)
        return cb(false)
    end

    local model = horse.catalog_id ~= '' and horse.catalog_id or horse.model
    local _, colorCfg = Catalog.Find(model)
    if not colorCfg then return cb(false) end

    local captured = tonumber(horse.captured) == 1
    local sellPrice = captured and (Config.tamedSellPrice * colorCfg.cashPrice) or (Config.sellPrice * colorCfg.cashPrice)
    sellPrice = math.ceil(sellPrice)
    local site = data.site
    if site and StableBiz.IsOwned(site) and Config.Ownership.SellBackFromTill then
        local ok = StableBiz.RemoveTill(site, sellPrice)
        if not ok then
            Core.NotifyRightTip(src, 'This stable cannot cover the buy-back right now.', 4000)
            return cb(false)
        end
    end

    MySQL.query.await('DELETE FROM `player_horses` WHERE `id` = ? AND `charid` = ? AND `identifier` = ?',
    { horseId, charid, identifier })
    LogToDiscord(charid, _U('discordHorseSold'))
    character.addCurrency(0, sellPrice)
    Core.NotifyRightTip(src, _U('soldHorse') .. sellPrice, 4000)
    cb(true)
end)

RegisterNetEvent('bcc-stables:SellTamedHorse', function(hash)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local character = user.getUsedCharacter
    local charid = character.charIdentifier
    local sellPriceMultiplier = Config.tamedSellPrice
    local breedCfg, colorCfg = Catalog.FindByHash(hash)
    if colorCfg then
        local sellPrice = math.ceil(sellPriceMultiplier * colorCfg.cashPrice)
        character.addCurrency(0, sellPrice)
        Core.NotifyRightTip(src, _U('soldHorse') .. sellPrice, 4000)
        SetPlayerCooldown('sellTame', charid)
        LogToDiscord(charid, _U('discordTamedSold'))
    end
end)

RegisterNetEvent('bcc-stables:SaveHorseTrade', function(serverId, horseId)
    -- Current Owner
    local src = source
    local curUser = Core.getUser(src)
    if not curUser then return end

    local curOwner = curUser.getUsedCharacter
    local curOwnerId = curOwner.identifier
    local curOwnerCharId = curOwner.charIdentifier
    local curOwnerName = curOwner.firstname .. " " .. curOwner.lastname
    -- New Owner
    local newUser = Core.getUser(serverId)
    if not newUser then return end

    local newOwner = newUser.getUsedCharacter
    local newOwnerId = newOwner.identifier
    local newOwnerCharId = newOwner.charIdentifier
    local newOwnerName = newOwner.firstname .. " " .. newOwner.lastname

    -- Fetch the horse
    local horse = MySQL.query.await('SELECT * FROM `player_horses` WHERE `id` = ? AND `charid` = ? AND `identifier` = ? AND `dead` = ?',
    { horseId, curOwnerCharId, curOwnerId, 0 })

    if horse and #horse > 0 then
        if tonumber(horse[1].pregnant) == 1 or tonumber(horse[1].locked) == 1 then
            Core.NotifyRightTip(src, 'That horse cannot be traded right now.', 4000)
            return
        end
        -- Update the horse ownership
        MySQL.query.await('UPDATE `player_horses` SET `identifier` = ?, `charid` = ?, `selected` = ? WHERE `id` = ?',
        { newOwnerId, newOwnerCharId, 0, horseId })

        -- Notify both parties
        Core.NotifyRightTip(src, _U('youGave') .. newOwnerName .. _U('aHorse'), 4000)
        Core.NotifyRightTip(serverId, curOwnerName .._U('gaveHorse'), 4000)

        LogToDiscord(curOwnerName, _U('discordTraded') .. newOwnerName)
    end
end)

RegisterNetEvent('bcc-stables:RegisterInventory', function(id, model)
    local idStr = 'horse_' .. tostring(id)
    local isRegistered = exports.vorp_inventory:isCustomInventoryRegistered(idStr)

    local _, colorCfg = Catalog.Find(model)
    if colorCfg then
            local data = {
                id = idStr,
                name = _U('horseInv'),
                limit = tonumber(colorCfg.invLimit),
                acceptWeapons = Config.allowWeapons,
                shared = Config.shareInventory,
                ignoreItemStackLimit = Config.ignoreItemStackLimit or true,
                whitelistItems =  Config.useWhiteList or false,
                UsePermissions = Config.usePermissions or false,
                UseBlackList = Config.useBlackList or false,
                whitelistWeapons = Config.whitelistWeapons or false
            }

            if isRegistered then
                exports.vorp_inventory:updateCustomInventoryData(idStr, data)
            else
                exports.vorp_inventory:registerInventory(data)
            end

            if data.UsePermissions then
                for _, permission in ipairs(Config.permissions.allowedJobsTakeFrom) do
                    exports.vorp_inventory:AddPermissionTakeFromCustom(idStr, permission.name, permission.grade)
                end
                for _, permission in ipairs(Config.permissions.allowedJobsMoveTo) do
                    exports.vorp_inventory:AddPermissionMoveToCustom(idStr, permission.name, permission.grade)
                end
            end

            if data.whitelistItems then
                for _, item in ipairs(Config.itemsLimitWhiteList) do
                    exports.vorp_inventory:setCustomInventoryItemLimit(idStr, item.name, item.limit)
                end
            end

            if data.whitelistWeapons then
                for _, weapon in ipairs(Config.weaponsLimitWhiteList) do
                    exports.vorp_inventory:setCustomInventoryWeaponLimit(idStr, weapon.name, weapon.limit)
                end
            end

            if data.UseBlackList then
                for _, item in ipairs(Config.itemsBlackList) do
                    exports.vorp_inventory:BlackListCustomAny(idStr, item)
                end
            end
    end
end)

RegisterNetEvent('bcc-stables:OpenInventory', function(id)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local idStr = 'horse_' .. tostring(id)
    exports.vorp_inventory:openInventory(src, idStr)
end)

-- Iterate over each item in the Config.horseFood array to register them as usable items
for _, item in ipairs(Config.horseFood) do
    exports.vorp_inventory:registerUsableItem(item, function(data)
        local src = data.source
        exports.vorp_inventory:closeInventory(src)

        TriggerClientEvent('bcc-stables:FeedHorse', src, item)
    end)
end

if Config.flamingHooves.active then
    exports.vorp_inventory:registerUsableItem(Config.flamingHooves.item, function(data)
        local src = data.source
        local user = Core.getUser(src)
        if not user then return end

        local item = exports.vorp_inventory:getItem(src, Config.flamingHooves.item)
        exports.vorp_inventory:closeInventory(src)

        if Config.flamingHooves.durability then
            local maxDurability = Config.flamingHooves.maxDurability or 100
            local useDurability = Config.flamingHooves.durabilityPerUse or 1
            local itemMetadata = item.metadata
            local currentDurability = itemMetadata.durability

            -- Initialize durability if it doesn't exist
            if not currentDurability then
                currentDurability = maxDurability
                local newData = {
                    description = _U('flameHooveDesc') .. '</br>' .. _U('durability') .. currentDurability .. '%',
                    durability = currentDurability,
                    id = item.id
                }
                exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
            end

            -- Check if durability is below the usage threshold
            if currentDurability < useDurability then
                exports.vorp_inventory:subItemID(src, item.id)
                Core.NotifyRightTip(src, _U('itemBroke'), 4000)
                return
            end
        end

        TriggerClientEvent('bcc-stables:FlamingHooves', src)
    end)

    RegisterNetEvent('bcc-stables:FlamingHoovesDurability', function()
        local src = source
        local user = Core.getUser(src)
        if not user then return end

        local item = exports.vorp_inventory:getItem(src, Config.flamingHooves.item)
        local useDurability = Config.flamingHooves.durabilityPerUse or 1
        local itemMetadata = item.metadata
        local newDurability = itemMetadata.durability - useDurability

        -- Check if durability is below the usage threshold or update the durability
        if newDurability < useDurability then
            exports.vorp_inventory:subItemID(src, item.id)
            Core.NotifyRightTip(src, _U('itemBroke'), 4000)
        else
            local newData = {
                description = _U('flameHooveDesc') .. '</br>' .. _U('durability') .. newDurability .. '%',
                durability = newDurability,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end
    end)
end

RegisterNetEvent('bcc-stables:RemoveItem', function(item)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    exports.vorp_inventory:subItem(src, item, 1)
end)

exports.vorp_inventory:registerUsableItem(Config.horsebrush.item, function(data)
    local src = data.source
    local user = Core.getUser(src)
    if not user then return end

    local item = exports.vorp_inventory:getItem(src, Config.horsebrush.item)
    exports.vorp_inventory:closeInventory(src)

    if Config.horsebrush.durability then
        local maxDurability = Config.horsebrush.maxDurability or 100
        local useDurability = Config.horsebrush.durabilityPerUse or 1
        local itemMetadata = item.metadata
        local currentDurability = itemMetadata.durability

        -- Initialize durability if it doesn't exist
        if not currentDurability then
            currentDurability = maxDurability
            local newData = {
                description = _U('horsebrushDesc') .. '</br>' .. _U('durability') .. currentDurability .. '%',
                durability = currentDurability,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end

        -- Check if durability is below the usage threshold
        if currentDurability < useDurability then
            exports.vorp_inventory:subItemID(src, item.id)
            Core.NotifyRightTip(src, _U('itemBroke'), 4000)
            return
        end
    end

    TriggerClientEvent('bcc-stables:BrushHorse', src)
end)

RegisterNetEvent('bcc-stables:RequestCare', function(kind)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    kind = tostring(kind or '')
    if kind == 'brush' then
        local item = exports.vorp_inventory:getItem(src, Config.horsebrush.item)
        if not item then
            Core.NotifyRightTip(src, _U('needBrushItem'), 4000)
            TriggerClientEvent('bcc-stables:CareDenied', src)
            return
        end
        if Config.horsebrush.durability then
            local meta = item.metadata or {}
            local current = meta.durability
            local useDurability = Config.horsebrush.durabilityPerUse or 1
            if current and current < useDurability then
                exports.vorp_inventory:subItemID(src, item.id)
                Core.NotifyRightTip(src, _U('itemBroke'), 4000)
                TriggerClientEvent('bcc-stables:CareDenied', src)
                return
            end
        end
        TriggerClientEvent('bcc-stables:BrushHorse', src)
        return
    end

    if kind == 'feed' then
        local found
        for _, name in ipairs(Config.horseFood or {}) do
            local invItem = exports.vorp_inventory:getItem(src, name)
            if invItem then
                found = name
                break
            end
        end
        if not found then
            Core.NotifyRightTip(src, _U('needFeedItem'), 4000)
            TriggerClientEvent('bcc-stables:CareDenied', src)
            return
        end
        TriggerClientEvent('bcc-stables:FeedHorse', src, found)
        return
    end

    TriggerClientEvent('bcc-stables:CareDenied', src)
end)

RegisterNetEvent('bcc-stables:HorseBrushDurability', function()
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local item = exports.vorp_inventory:getItem(src, Config.horsebrush.item)
    local useDurability = Config.horsebrush.durabilityPerUse or 1
    local itemMetadata = item.metadata
    local newDurability = itemMetadata.durability - useDurability

    -- Check if durability is below the usage threshold or update the durability
    if newDurability < useDurability then
        exports.vorp_inventory:subItemID(src, item.id)
        Core.NotifyRightTip(src, _U('itemBroke'), 4000)
    else
        local newData = {
            description = _U('horsebrushDesc') .. '</br>' .. _U('durability') .. newDurability .. '%',
            durability = newDurability,
            id = item.id
        }
        exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
    end
end)

exports.vorp_inventory:registerUsableItem(Config.lantern.item, function(data)
    local src = data.source
    local user = Core.getUser(src)
    if not user then return end

    local item = exports.vorp_inventory:getItem(src, Config.lantern.item)
    exports.vorp_inventory:closeInventory(src)

    if Config.lantern.durability then
        local maxDurability = Config.lantern.maxDurability or 100
        local useDurability = Config.lantern.durabilityPerUse or 1
        local itemMetadata = item.metadata
        local currentDurability = itemMetadata.durability

        -- Initialize durability if it doesn't exist
        if not currentDurability then
            currentDurability = maxDurability
            local newData = {
                description = _U('lanternDesc') .. '</br>' .. _U('durability') .. currentDurability .. '%',
                durability = currentDurability,
                id = item.id
            }
            exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
        end

        -- Check if durability is below the usage threshold
        if currentDurability < useDurability then
            exports.vorp_inventory:subItemID(src, item.id)
            Core.NotifyRightTip(src, _U('itemBroke'), 4000)
            return
        end
    end

    TriggerClientEvent('bcc-stables:UseLantern', src)
end)

RegisterNetEvent('bcc-stables:LanternDurability', function()
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    local item = exports.vorp_inventory:getItem(src, Config.lantern.item)
    local useDurability = Config.lantern.durabilityPerUse or 1
    local itemMetadata = item.metadata
    local newDurability = itemMetadata.durability - useDurability

    -- Check if durability is below the usage threshold or update the durability
    if newDurability < useDurability then
        exports.vorp_inventory:subItemID(src, item.id)
        Core.NotifyRightTip(src, _U('itemBroke'), 4000)
    else
        local newData = {
            description = _U('lanternDesc') .. '</br>' .. _U('durability') .. newDurability .. '%',
            durability = newDurability,
            id = item.id
        }
        exports.vorp_inventory:setItemMetadata(src, item.id, newData, 1)
    end
end)

Core.Callback.Register('bcc-stables:HorseReviveItem', function(source, cb)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local reviveItem = Config.reviver
    local hasItem = exports.vorp_inventory:getItem(src, reviveItem)

    if not hasItem then
        return cb(false)
    end

    exports.vorp_inventory:subItem(src, reviveItem, 1)
    cb(true)
end)

Core.Callback.Register('bcc-stables:CheckPlayerCooldown', function(source, cb, type)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local cooldown = Config.cooldown[type]
    local typeId = type .. tostring(character.charIdentifier)
    local currentTime = os.time()
    local lastTime = CooldownData[typeId]

    if lastTime then
        if os.difftime(currentTime, lastTime) >= cooldown * 60 then
            cb(false) -- Not on Cooldown
        else
            cb(true) -- On Cooldown
        end
    else
        cb(false) -- Not on Cooldown
    end
end)

Core.Callback.Register('bcc-stables:CheckJob', function(source, cb, trainer, site)
    local src = source
    local user = Core.getUser(src)
    if not user then return cb(false) end

    local character = user.getUsedCharacter
    local hasJob = false
    if trainer then
        if HasTrainerJob then
            hasJob = HasTrainerJob(src, character) == true
        else
            for _, job in pairs(Config.trainerJob or {}) do
                if character.job == job.name and tonumber(character.jobGrade) >= tonumber(job.grade or 0) then
                    hasJob = true
                    break
                end
            end
        end
    else
        local jobConfig = (Stables[site] and Stables[site].shop and Stables[site].shop.jobs) or {}
        for _, job in pairs(jobConfig) do
            if (character.job == job.name) and (tonumber(character.jobGrade) >= tonumber(job.grade)) then
                hasJob = true
                break
            end
        end
    end

    cb({hasJob, character.job})
end)

RegisterNetEvent('vorp_core:instanceplayers', function(setRoom)
    local src = source
    local user = Core.getUser(src)
    if not user then return end

    if setRoom == 0 then
        Wait(3000)
        TriggerClientEvent('bcc-stables:UpdateMyHorseEntity', src)
    end
end)

--- Check if properly downloaded
function file_exists(name)
    local f = LoadResourceFile(GetCurrentResourceName(), name)
    return f ~= nil
end

if not file_exists('./ui/index.html') then
    print('^1 INCORRECT DOWNLOAD!  ^0')
    print(
        '^4 Please Download: ^2(bcc-stables.zip) ^4from ^3<https://github.com/BryceCanyonCounty/bcc-stables/releases/latest>^0')
end

BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/BryceCanyonCounty/bcc-stables')
