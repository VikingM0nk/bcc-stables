local Core = exports.vorp_core:GetCore()

StableBiz = {}

local function characterOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter, user
end

function StableBiz.IsAdmin(src)
    if IsPlayerAceAllowed(src, Config.AdminAce or 'stables.admin') then return true end
    local character = characterOf(src)
    if not character then return false end
    local group = tostring(character.group or ''):lower()
    for _, name in ipairs(Config.AdminGroups or {}) do
        if group == tostring(name):lower() then return true end
    end
    return false
end

function StableBiz.Ensure(key)
    if not key or key == '' then return end
    MySQL.insert.await('INSERT IGNORE INTO bcc_stable_owners (stable_key, till) VALUES (?, 0)', { key })
end

function StableBiz.Get(key)
    StableBiz.Ensure(key)
    return MySQL.single.await('SELECT * FROM bcc_stable_owners WHERE stable_key = ?', { key })
end

function StableBiz.IsOwned(key)
    local row = StableBiz.Get(key)
    return row and row.owner_identifier and row.owner_identifier ~= '' and (tonumber(row.owner_charid) or 0) > 0
end

function StableBiz.IsOwner(src, key)
    local character = characterOf(src)
    if not character then return false end
    local row = StableBiz.Get(key)
    return row
        and row.owner_identifier == character.identifier
        and tonumber(row.owner_charid) == tonumber(character.charIdentifier)
end

function StableBiz.CountOwned(identifier, charid)
    local row = MySQL.single.await(
        'SELECT COUNT(*) AS n FROM bcc_stable_owners WHERE owner_identifier = ? AND owner_charid = ?',
        { identifier, charid }
    )
    return tonumber(row and row.n) or 0
end

function StableBiz.AddTill(key, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 or not key then return StableBiz.Get(key) end
    StableBiz.Ensure(key)
    MySQL.update.await('UPDATE bcc_stable_owners SET till = GREATEST(0, till + ?) WHERE stable_key = ?', { amount, key })
    local site = Stables[key]
    local society = site and site.society
    if society and amount > 0 and GetResourceState('viking_banking') == 'started' then
        pcall(function()
            exports.viking_banking:AddSocietyMoney(society, amount, 'stable_sale', 'money')
        end)
    end
    return StableBiz.Get(key)
end

function StableBiz.RemoveTill(key, amount)
    amount = math.floor(tonumber(amount) or 0)
    local row = StableBiz.Get(key)
    local till = math.floor(tonumber(row and row.till) or 0)
    if amount <= 0 then return true, till end
    if till < amount then return false, till end
    MySQL.update.await('UPDATE bcc_stable_owners SET till = till - ? WHERE stable_key = ?', { amount, key })
    local site = Stables[key]
    if site and site.society and GetResourceState('viking_banking') == 'started' then
        pcall(function()
            exports.viking_banking:RemoveSocietyMoney(site.society, amount, 'stable_payout', 'money')
        end)
    end
    return true, till - amount
end

function StableBiz.CreditSale(key, price)
    if not key or not StableBiz.IsOwned(key) then return end
    local cut = tonumber(Config.Ownership and Config.Ownership.OwnerCut) or 1.0
    local credit = math.floor((tonumber(price) or 0) * cut)
    if credit > 0 then StableBiz.AddTill(key, credit) end
end

local function sitePayload(key)
    local cfg = Stables[key]
    if not cfg then return nil end
    local row = StableBiz.Get(key)
    return {
        key = key,
        name = cfg.shop and cfg.shop.name or key,
        purchasable = cfg.purchasable ~= false,
        price = tonumber(cfg.purchasePrice) or (Config.Ownership and Config.Ownership.DefaultPrice) or 2500,
        owned = StableBiz.IsOwned(key),
        ownerName = row and row.owner_name or '',
        till = tonumber(row and row.till) or 0,
        breeding = cfg.breeding == true,
    }
end

Core.Callback.Register('bcc-stables:GetStableBiz', function(source, cb, key)
    local src = source
    if not Stables[key] then return cb(false) end
    local data = sitePayload(key)
    data.isOwner = StableBiz.IsOwner(src, key)
    data.isAdmin = StableBiz.IsAdmin(src)
    data.ownedCount = 0
    local character = characterOf(src)
    if character then
        data.ownedCount = StableBiz.CountOwned(character.identifier, character.charIdentifier)
    end
    cb(data)
end)

Core.Callback.Register('bcc-stables:BuyStable', function(source, cb, key)
    local src = source
    local character = characterOf(src)
    if not character or not Stables[key] then return cb(false) end
    local cfg = Stables[key]
    if cfg.purchasable == false then
        Core.NotifyRightTip(src, 'This stable cannot be purchased.', 4000)
        return cb(false)
    end
    if StableBiz.IsOwned(key) then
        Core.NotifyRightTip(src, 'This stable is already owned.', 4000)
        return cb(false)
    end
    local maxOwn = tonumber(Config.MaxOwnedStables) or 1
    if StableBiz.CountOwned(character.identifier, character.charIdentifier) >= maxOwn then
        Core.NotifyRightTip(src, 'You already own a stable.', 4000)
        return cb(false)
    end
    local price = tonumber(cfg.purchasePrice) or Config.Ownership.DefaultPrice
    if character.money < price then
        Core.NotifyRightTip(src, _U('shortCash'), 4000)
        return cb(false)
    end
    character.removeCurrency(0, price)
    local name = (character.firstname or '') .. ' ' .. (character.lastname or '')
    StableBiz.Ensure(key)
    MySQL.update.await(
        'UPDATE bcc_stable_owners SET owner_identifier = ?, owner_charid = ?, owner_name = ?, bought_at = ? WHERE stable_key = ?',
        { character.identifier, character.charIdentifier, name, os.time(), key }
    )
    Core.NotifyRightTip(src, ('You bought %s for $%s'):format(cfg.shop.name, price), 5000)
    cb(true)
end)

Core.Callback.Register('bcc-stables:SellStable', function(source, cb, key)
    local src = source
    if not StableBiz.IsOwner(src, key) then return cb(false) end
    local character = characterOf(src)
    local cfg = Stables[key]
    local price = tonumber(cfg and cfg.purchasePrice) or Config.Ownership.DefaultPrice
    local refund = math.floor(price * ((Config.Ownership and Config.Ownership.ResalePercent) or 0.5))
    local row = StableBiz.Get(key)
    local till = math.floor(tonumber(row and row.till) or 0)
    MySQL.update.await(
        'UPDATE bcc_stable_owners SET owner_identifier = NULL, owner_charid = NULL, owner_name = NULL, bought_at = NULL, till = 0 WHERE stable_key = ?',
        { key }
    )
    character.addCurrency(0, refund + till)
    Core.NotifyRightTip(src, ('You sold the stable for $%s (till $%s included).'):format(refund, till), 5000)
    cb(true)
end)

Core.Callback.Register('bcc-stables:WithdrawTill', function(source, cb, key, amount)
    local src = source
    if not StableBiz.IsOwner(src, key) then return cb(false) end
    amount = math.floor(tonumber(amount) or 0)
    local ok, left = StableBiz.RemoveTill(key, amount)
    if not ok then
        Core.NotifyRightTip(src, 'Not enough in the till.', 4000)
        return cb(false)
    end
    local character = characterOf(src)
    character.addCurrency(0, amount)
    Core.NotifyRightTip(src, ('Withdrew $%s. Till: $%s'):format(amount, left), 4000)
    cb(true)
end)

local function toStableCfg(row)
    local npc = vector3(row.npc_x, row.npc_y, row.npc_z)
    local horse = vector3(row.horse_x, row.horse_y, row.horse_z)
    local cam = vector3(row.cam_x, row.cam_y, row.cam_z)
    return {
        shop = {
            name = row.label,
            prompt = row.label,
            distance = 2.0,
            jobsEnabled = false,
            jobs = {},
            hours = { active = false, open = 7, close = 21 },
        },
        blip = {
            show = true, showClosed = true, name = row.label, sprite = 1938782895,
            color = { open = 'WHITE', closed = 'RED', job = 'YELLOW_ORANGE' },
        },
        npc = {
            active = true, model = 'u_m_m_bwmstablehand_01',
            coords = npc, heading = row.npc_h, distance = 100.0,
        },
        horse = { coords = horse, heading = row.horse_h, camera = cam },
        trainerBuy = false,
        purchasable = true,
        purchasePrice = tonumber(row.purchase_price) or Config.Ownership.DefaultPrice,
        society = (row.society ~= '' and row.society) or ('stable_' .. row.stable_key),
        breeding = tonumber(row.breeding) == 1,
        custom = true,
    }
end

function StableBiz.LoadCustom()
    Schema.Wait()
    local rows = MySQL.query.await('SELECT * FROM bcc_stables_custom') or {}
    for i = 1, #rows do
        local row = rows[i]
        Stables[row.stable_key] = toStableCfg(row)
        StableBiz.Ensure(row.stable_key)
    end
    return rows
end

function StableBiz.CustomPayload()
    Schema.Wait()
    local rows = MySQL.query.await('SELECT * FROM bcc_stables_custom') or {}
    local list = {}
    for i = 1, #rows do
        list[#list + 1] = { key = rows[i].stable_key, cfg = toStableCfg(rows[i]) }
    end
    return list
end

CreateThread(function()
    Schema.Wait()
    StableBiz.LoadCustom()
    TriggerClientEvent('bcc-stables:client:customStables', -1, StableBiz.CustomPayload())
end)

RegisterNetEvent('bcc-stables:requestCustomStables', function()
    local src = source
    TriggerClientEvent('bcc-stables:client:customStables', src, StableBiz.CustomPayload())
end)

Core.Callback.Register('bcc-stables:PlaceStable', function(source, cb, data)
    local src = source
    if not StableBiz.IsAdmin(src) then
        Core.NotifyRightTip(src, 'No permission.', 4000)
        return cb(false)
    end
    data = data or {}
    local key = tostring(data.key or ''):gsub('[^%w_]', ''):lower()
    if key == '' or Stables[key] then
        Core.NotifyRightTip(src, 'Invalid or duplicate stable key.', 4000)
        return cb(false)
    end
    local npc, horse, cam = data.npc, data.horse, data.camera
    if not npc or not horse or not cam then return cb(false) end
    local label = tostring(data.label or key)
    local price = tonumber(data.price) or Config.Ownership.DefaultPrice
    MySQL.insert.await([[
        INSERT INTO bcc_stables_custom
        (stable_key, label, npc_x, npc_y, npc_z, npc_h, horse_x, horse_y, horse_z, horse_h, cam_x, cam_y, cam_z, purchase_price, society, breeding, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        key, label,
        npc.x, npc.y, npc.z, npc.w or npc.heading or 0.0,
        horse.x, horse.y, horse.z, horse.w or horse.heading or 0.0,
        cam.x, cam.y, cam.z,
        price, 'stable_' .. key, data.breeding and 1 or 0,
        GetPlayerName(src) or '',
    })
    StableBiz.LoadCustom()
    TriggerClientEvent('bcc-stables:client:customStables', -1, StableBiz.CustomPayload())
    Core.NotifyRightTip(src, 'Stable placed: ' .. key, 4000)
    cb(true)
end)

Core.Callback.Register('bcc-stables:RemoveStable', function(source, cb, key)
    local src = source
    if not StableBiz.IsAdmin(src) then return cb(false) end
    key = tostring(key or '')
    local row = MySQL.single.await('SELECT stable_key FROM bcc_stables_custom WHERE stable_key = ?', { key })
    if not row then
        Core.NotifyRightTip(src, 'Only custom stables can be removed.', 4000)
        return cb(false)
    end
    MySQL.update.await('DELETE FROM bcc_stables_custom WHERE stable_key = ?', { key })
    Stables[key] = nil
    TriggerClientEvent('bcc-stables:client:customStables', -1, StableBiz.CustomPayload())
    cb(true)
end)
