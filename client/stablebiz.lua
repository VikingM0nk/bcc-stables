local Core = exports.vorp_core:GetCore()

local function vec4(coords, heading)
    return { x = coords.x, y = coords.y, z = coords.z, heading = heading or GetEntityHeading(PlayerPedId()) }
end

local function asVec(v)
    if not v then return vector3(0.0, 0.0, 0.0) end
    if type(v) == 'vector3' then return v end
    return vector3(tonumber(v.x or v[1]) or 0.0, tonumber(v.y or v[2]) or 0.0, tonumber(v.z or v[3]) or 0.0)
end

RegisterNetEvent('bcc-stables:client:customStables', function(list)
    list = list or {}
    for _, row in pairs(list) do
        if type(row) == 'table' and row.key and type(row.cfg) == 'table' then
            if Stables[row.key] and not Stables[row.key].custom then
                goto continue
            end
            local cfg = row.cfg
            cfg.npc = cfg.npc or {}
            cfg.horse = cfg.horse or {}
            cfg.shop = cfg.shop or { name = row.key, prompt = row.key, distance = 2.0, jobsEnabled = false, jobs = {}, hours = { active = false, open = 7, close = 21 } }
            cfg.shop.hours = cfg.shop.hours or { active = false, open = 7, close = 21 }
            cfg.npc.coords = asVec(cfg.npc.coords)
            cfg.npc.distance = tonumber(cfg.npc.distance) or 100.0
            cfg.npc.model = cfg.npc.model or 'u_m_m_bwmstablehand_01'
            if cfg.npc.active == nil then cfg.npc.active = true end
            cfg.horse.coords = asVec(cfg.horse.coords)
            cfg.horse.camera = asVec(cfg.horse.camera)
            cfg.custom = true
            Stables[row.key] = cfg
        end
        ::continue::
    end
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('bcc-stables:requestCustomStables')
end)

local function openOwnerMenu(site)
    local data = Core.Callback.TriggerAwait('bcc-stables:GetStableBiz', site)
    if not data then return end
    local menu = FeatherMenu:RegisterMenu('bcc-stables:biz', {
        top = '12%', left = '3%', ['1080width'] = '440px',
        contentslot = { style = { ['min-height'] = '240px' } },
        canclose = true, draggable = true,
    })
    local page = menu:RegisterPage('biz:home')
    page:RegisterElement('header', { value = data.name, slot = 'header' })
    page:RegisterElement('textdisplay', {
        value = data.owned and ('Owner: %s\nTill: $%s'):format(data.ownerName, data.till) or ('For sale: $%s'):format(data.price)
    })
    if not data.owned and data.purchasable then
        page:RegisterElement('button', { label = 'Buy this stable $' .. data.price }, function()
            Core.Callback.TriggerAwait('bcc-stables:BuyStable', site)
            menu:Close()
        end)
    end
    if data.isOwner then
        page:RegisterElement('button', { label = 'Withdraw till' }, function()
            AddTextEntry('FMMC_MPM_NA', 'Amount')
            DisplayOnscreenKeyboard(1, 'FMMC_MPM_NA', '', tostring(data.till), '', '', '', 8)
            while UpdateOnscreenKeyboard() == 0 do Wait(0) end
            local amt = tonumber(GetOnscreenKeyboardResult() or '') or 0
            if amt > 0 then Core.Callback.TriggerAwait('bcc-stables:WithdrawTill', site, amt) end
            menu:Close()
        end)
        page:RegisterElement('button', { label = 'Sell stable' }, function()
            Core.Callback.TriggerAwait('bcc-stables:SellStable', site)
            menu:Close()
        end)
        page:RegisterElement('button', { label = 'Geld / spay selected horse $' .. (Config.GeldCost or 75) }, function()
            local horse = Core.Callback.TriggerAwait('bcc-stables:GetHorseData')
            if horse and horse.id then
                Core.Callback.TriggerAwait('bcc-stables:GeldHorse', horse.id)
            end
            menu:Close()
        end)
    end
    menu:Open({ startupPage = page })
end

RegisterCommand('stablebiz', function()
    local site = Site
    if not site then
        local coords = GetEntityCoords(PlayerPedId())
        local best, bestDist = nil, 4.0
        for key, cfg in pairs(Stables or {}) do
            if cfg.npc and cfg.npc.coords then
                local dist = #(coords - asVec(cfg.npc.coords))
                if dist < bestDist then
                    best, bestDist = key, dist
                end
            end
        end
        site = best
    end
    if not site then
        return Core.NotifyRightTip('Stand at a stable to manage it.', 4000)
    end
    openOwnerMenu(site)
end, false)

RegisterKeyMapping('stablebiz', 'Manage stable business', 'KEYBOARD', 'H')

local placing = nil

RegisterCommand('placestable', function(_, args)
    local key = tostring(args[1] or '')
    if key == '' then
        return print('Usage: /placestable [key]')
    end
    placing = { key = key, step = 1 }
    Core.NotifyRightTip('Stand at the NPC prompt and press G to save that spot.', 6000)
end, false)

CreateThread(function()
    while true do
        Wait(0)
        if not placing then
            Wait(400)
        elseif IsControlJustReleased(0, Config.keys.shop) then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            if placing.step == 1 then
                placing.npc = vec4(coords, heading)
                placing.step = 2
                Core.NotifyRightTip('Stand where the horse should preview and press G.', 5000)
            elseif placing.step == 2 then
                placing.horse = vec4(coords, heading)
                placing.step = 3
                Core.NotifyRightTip('Stand at the camera view and press G.', 5000)
            elseif placing.step == 3 then
                placing.camera = { x = coords.x, y = coords.y, z = coords.z }
                local ok = Core.Callback.TriggerAwait('bcc-stables:PlaceStable', {
                    key = placing.key,
                    label = placing.key:gsub('_', ' '),
                    npc = placing.npc,
                    horse = placing.horse,
                    camera = placing.camera,
                    price = Config.Ownership.DefaultPrice,
                    breeding = false,
                })
                if ok then Core.NotifyRightTip('Custom stable saved.', 4000) end
                placing = nil
            end
        end
    end
end)

RegisterCommand('removestable', function(_, args)
    Core.Callback.TriggerAwait('bcc-stables:RemoveStable', args[1])
end, false)

local function loadModel(name)
    local hash = joaat(name)
    if not IsModelValid(hash) then return nil end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local timeout = GetGameTimer() + 8000
        while not HasModelLoaded(hash) do
            if GetGameTimer() > timeout then return nil end
            Wait(10)
        end
    end
    return hash
end

local function spawnClerk(spot, scenario)
    if spot.ped and DoesEntityExist(spot.ped) then return end
    local hash = loadModel(spot.model or 'a_m_m_valtownfolk_01')
    if not hash then return end
    local c = spot.coords
    local ped = CreatePed(hash, c.x, c.y, c.z - 1.0, spot.heading or 0.0, false, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return end
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    pcall(function()
        TaskStartScenarioInPlace(ped, scenario or `WORLD_HUMAN_WAITING_IMPATIENT`, -1, true)
    end)
    Wait(200)
    FreezeEntityPosition(ped, true)
    spot.ped = ped
end

local function despawnClerk(spot)
    if spot.ped and DoesEntityExist(spot.ped) then
        DeleteEntity(spot.ped)
    end
    spot.ped = nil
end

local AuctionGroup = GetRandomIntInRange(0, 0xffffff)
local OpenAuction

CreateThread(function()
    OpenAuction = UiPromptRegisterBegin()
    UiPromptSetControlAction(OpenAuction, Config.keys.shop)
    UiPromptSetText(OpenAuction, CreateVarString(10, 'LITERAL_STRING', 'Horse Auction'))
    UiPromptSetVisible(OpenAuction, true)
    UiPromptSetStandardMode(OpenAuction, true)
    UiPromptSetGroup(OpenAuction, AuctionGroup, 0)
    UiPromptRegisterEnd(OpenAuction)

    for _, yard in ipairs((Config.Auction and Config.Auction.Yards) or {}) do
        if yard.blip then
            local blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300, yard.coords)
            SetBlipSprite(blip, -1103135225, true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, yard.label)
        end
    end

    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        for _, yard in ipairs((Config.Auction and Config.Auction.Yards) or {}) do
            local dist = #(playerCoords - yard.coords)
            if dist <= (yard.npcDistance or 80.0) then
                spawnClerk(yard, `WORLD_HUMAN_WRITE_NOTEBOOK`)
            else
                despawnClerk(yard)
            end
            if dist < 2.5 then
                sleep = 0
                UiPromptSetActiveGroupThisFrame(AuctionGroup, CreateVarString(10, 'LITERAL_STRING', yard.label), 1, 0, 0, 0)
                if UiPromptHasStandardModeCompleted(OpenAuction, 0) then
                    HorseAuctionMenu(yard)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, yard in ipairs((Config.Auction and Config.Auction.Yards) or {}) do
        despawnClerk(yard)
    end
end)

function HorseAuctionMenu(yard)
    local listings = Core.Callback.TriggerAwait('bcc-stables:ListAuctions', yard.key) or {}
    local menu = FeatherMenu:RegisterMenu('bcc-stables:auction', {
        top = '8%', left = '3%', ['1080width'] = '480px',
        contentslot = { style = { ['min-height'] = '320px' } },
        canclose = true, draggable = true,
    })
    local page = menu:RegisterPage('auc:home')
    page:RegisterElement('header', { value = yard.label, slot = 'header' })
    page:RegisterElement('button', { label = 'List my selected horse' }, function()
        local horse = Core.Callback.TriggerAwait('bcc-stables:GetHorseData')
        if not horse or not horse.id then
            Core.NotifyRightTip(_U('noSelectedHorse'), 4000)
            return
        end
        AddTextEntry('FMMC_MPM_NA', 'Reserve $')
        DisplayOnscreenKeyboard(1, 'FMMC_MPM_NA', '', '50', '', '', '', 8)
        while UpdateOnscreenKeyboard() == 0 do Wait(0) end
        local reserve = tonumber(GetOnscreenKeyboardResult() or '') or 0
        Core.Callback.TriggerAwait('bcc-stables:CreateAuction', {
            yard = yard.key, horseId = horse.id, reserve = reserve, buyout = reserve * 3,
            minutes = Config.Auction.DefaultMinutes,
        })
        menu:Close()
    end)
    for i = 1, #listings do
        local row = listings[i]
        local left = math.max(0, (tonumber(row.ends_at) or 0) - os.time())
        page:RegisterElement('button', {
            label = ('%s  bid $%s  %sm left'):format(row.name or 'Horse', row.bid or 0, math.floor(left / 60)),
        }, function()
            AddTextEntry('FMMC_MPM_NA', 'Your bid $')
            DisplayOnscreenKeyboard(1, 'FMMC_MPM_NA', '', tostring((tonumber(row.bid) or 0) + 5), '', '', '', 8)
            while UpdateOnscreenKeyboard() == 0 do Wait(0) end
            local amount = tonumber(GetOnscreenKeyboardResult() or '') or 0
            Core.Callback.TriggerAwait('bcc-stables:BidAuction', row.id, amount)
            menu:Close()
        end)
    end
    if #listings == 0 then
        page:RegisterElement('textdisplay', { value = 'No horses listed right now.' })
    end
    menu:Open({ startupPage = page })
end
