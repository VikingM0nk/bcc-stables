local Core = exports.vorp_core:GetCore()

local function characterOf(src)
    local user = Core.getUser(src)
    if not user then return nil end
    return user.getUsedCharacter
end

local function yardOf(key)
    for _, yard in ipairs((Config.Auction and Config.Auction.Yards) or {}) do
        if yard.key == key then return yard end
    end
end

local function settle(row)
    if not row or row.status ~= 'open' then return end
    MySQL.update.await('UPDATE bcc_horse_auctions SET status = ? WHERE id = ?', { 'closed', row.id })
    local horse = HorseUtil.GetOwned(row.horse_id)
    if not horse then return end

    if (tonumber(row.bid) or 0) > 0 and row.bidder_identifier and row.bidder_charid then
        MySQL.update.await(
            'UPDATE player_horses SET identifier = ?, charid = ?, selected = 0, locked = 0, lock_reason = ? WHERE id = ?',
            { row.bidder_identifier, row.bidder_charid, '', row.horse_id }
        )
        local cut = math.floor((tonumber(row.bid) or 0) * ((Config.Auction and Config.Auction.HouseCut) or 0.10))
        local sellerPay = (tonumber(row.bid) or 0) - cut
        local seller = nil
        for _, sid in ipairs(GetPlayers()) do
            local ch = characterOf(tonumber(sid))
            if ch and ch.identifier == row.seller_identifier and tonumber(ch.charIdentifier) == tonumber(row.seller_charid) then
                seller = { src = tonumber(sid), ch = ch }
                break
            end
        end
        if seller then
            seller.ch.addCurrency(0, sellerPay)
            Core.NotifyRightTip(seller.src, ('Auction sold %s for $%s'):format(horse.name, sellerPay), 5000)
        elseif row.stable_key and row.stable_key ~= '' then
            StableBiz.AddTill(row.stable_key, sellerPay)
        else
            pcall(function()
                MySQL.update.await(
                    'UPDATE characters SET money = money + ? WHERE identifier = ? AND charidentifier = ?',
                    { sellerPay, row.seller_identifier, row.seller_charid }
                )
            end)
        end
        if cut > 0 and row.stable_key and row.stable_key ~= '' then
            StableBiz.CreditSale(row.stable_key, cut)
        end
        for _, sid in ipairs(GetPlayers()) do
            local ch = characterOf(tonumber(sid))
            if ch and ch.identifier == row.bidder_identifier and tonumber(ch.charIdentifier) == tonumber(row.bidder_charid) then
                Core.NotifyRightTip(tonumber(sid), ('You won %s at auction.'):format(horse.name), 5000)
                break
            end
        end
    else
        MySQL.update.await('UPDATE player_horses SET locked = 0, lock_reason = ? WHERE id = ?', { '', row.horse_id })
    end
end

CreateThread(function()
    Schema.Wait()
    while true do
        Wait(15000)
        local open = MySQL.query.await("SELECT * FROM bcc_horse_auctions WHERE status = 'open' AND ends_at <= ?", { os.time() }) or {}
        for i = 1, #open do
            settle(open[i])
        end
    end
end)

Core.Callback.Register('bcc-stables:ListAuctions', function(source, cb, yard)
    local rows = MySQL.query.await([[
        SELECT a.*, h.name, h.model, h.gender, h.genotype, h.personality
        FROM bcc_horse_auctions a
        LEFT JOIN player_horses h ON h.id = a.horse_id
        WHERE a.status = 'open' AND (? IS NULL OR a.yard = ?)
        ORDER BY a.ends_at ASC
    ]], { yard, yard }) or {}
    cb(rows)
end)

Core.Callback.Register('bcc-stables:CreateAuction', function(source, cb, data)
    local src = source
    local character = characterOf(src)
    if not character then return cb(false) end
    data = data or {}
    local yard = yardOf(data.yard)
    if not yard then return cb(false) end
    local horseId = tonumber(data.horseId)
    local horse = HorseUtil.GetOwned(horseId)
    if not HorseUtil.Owns(horse, character.identifier, character.charIdentifier) then
        Core.NotifyRightTip(src, 'That is not your horse.', 4000)
        return cb(false)
    end
    if tonumber(horse.pregnant) == 1 then
        Core.NotifyRightTip(src, 'A pregnant mare cannot be auctioned.', 4000)
        return cb(false)
    end
    if tonumber(horse.locked) == 1 then
        Core.NotifyRightTip(src, 'That horse is busy.', 4000)
        return cb(false)
    end
    local minutes = tonumber(data.minutes) or Config.Auction.DefaultMinutes
    minutes = math.max(Config.Auction.MinMinutes, math.min(Config.Auction.MaxMinutes, minutes))
    local reserve = math.max(0, math.floor(tonumber(data.reserve) or 0))
    local buyout = math.max(0, math.floor(tonumber(data.buyout) or 0))
    local name = (character.firstname or '') .. ' ' .. (character.lastname or '')
    MySQL.update.await('UPDATE player_horses SET locked = 1, lock_reason = ?, selected = 0 WHERE id = ?', { 'auction', horseId })
    MySQL.insert.await([[
        INSERT INTO bcc_horse_auctions
        (horse_id, seller_identifier, seller_charid, seller_name, yard, stable_key, reserve, buyout, bid, ends_at, status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, 'open')
    ]], {
        horseId, character.identifier, character.charIdentifier, name,
        yard.key, yard.stable or '', reserve, buyout, os.time() + (minutes * 60),
    })
    Core.NotifyRightTip(src, 'Horse listed at auction.', 4000)
    cb(true)
end)

Core.Callback.Register('bcc-stables:BidAuction', function(source, cb, auctionId, amount)
    local src = source
    local character = characterOf(src)
    if not character then return cb(false) end
    local row = MySQL.single.await("SELECT * FROM bcc_horse_auctions WHERE id = ? AND status = 'open'", { tonumber(auctionId) })
    if not row then return cb(false) end
    if os.time() >= tonumber(row.ends_at) then
        settle(row)
        return cb(false)
    end
    if row.seller_identifier == character.identifier and tonumber(row.seller_charid) == tonumber(character.charIdentifier) then
        Core.NotifyRightTip(src, 'You cannot bid on your own horse.', 4000)
        return cb(false)
    end
    amount = math.floor(tonumber(amount) or 0)
    local minBid = math.max(tonumber(row.reserve) or 0, (tonumber(row.bid) or 0) + (Config.Auction.MinIncrement or 5))
    if amount < minBid then
        Core.NotifyRightTip(src, ('Bid at least $%s'):format(minBid), 4000)
        return cb(false)
    end
    if character.money < amount then
        Core.NotifyRightTip(src, _U('shortCash'), 4000)
        return cb(false)
    end

    if row.bidder_identifier and (tonumber(row.bid) or 0) > 0 then
        local refunded = false
        for _, sid in ipairs(GetPlayers()) do
            local ch = characterOf(tonumber(sid))
            if ch and ch.identifier == row.bidder_identifier and tonumber(ch.charIdentifier) == tonumber(row.bidder_charid) then
                ch.addCurrency(0, tonumber(row.bid))
                Core.NotifyRightTip(tonumber(sid), 'You were outbid. Your money was returned.', 4000)
                refunded = true
                break
            end
        end
        if not refunded then
            pcall(function()
                MySQL.update.await(
                    'UPDATE characters SET money = money + ? WHERE identifier = ? AND charidentifier = ?',
                    { tonumber(row.bid), row.bidder_identifier, row.bidder_charid }
                )
            end)
        end
    end

    character.removeCurrency(0, amount)
    local name = (character.firstname or '') .. ' ' .. (character.lastname or '')
    MySQL.update.await(
        'UPDATE bcc_horse_auctions SET bid = ?, bidder_identifier = ?, bidder_charid = ?, bidder_name = ? WHERE id = ?',
        { amount, character.identifier, character.charIdentifier, name, row.id }
    )

    if (tonumber(row.buyout) or 0) > 0 and amount >= tonumber(row.buyout) then
        local fresh = MySQL.single.await('SELECT * FROM bcc_horse_auctions WHERE id = ?', { row.id })
        settle(fresh)
        Core.NotifyRightTip(src, 'Buyout accepted.', 4000)
        return cb(true)
    end

    Core.NotifyRightTip(src, ('Bid $%s placed.'):format(amount), 4000)
    cb(true)
end)
