local Core = exports.vorp_core:GetCore()

local SET_ANIMAL_WILD = 0xAEB97D84CDF3C00B

local hostSet = {}
local herds = {}
local herdPeds = {}
local warned = false

local function requestModel(modelName)
    local hash = joaat(modelName)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function groundAt(coords)
    local found, z = GetGroundZAndNormalFor_3dCoord(coords.x, coords.y, coords.z + 20.0)
    if found then return vector3(coords.x, coords.y, z) end
    return coords
end

local function offset(coords, radius)
    local a = math.random() * math.pi * 2
    local r = math.random() * (radius or 14.0)
    return vector3(coords.x + math.cos(a) * r, coords.y + math.sin(a) * r, coords.z)
end

local function pickModel()
    local pool = Config.Pool or {}
    if #pool == 0 then return 'a_c_horse_morgan_bay' end
    return pool[math.random(1, #pool)]
end

local function isOurHorse(ped)
    return herdPeds[ped] == true
end

local function spawnHorse(spot)
    local modelName = pickModel()
    local hash = requestModel(modelName)
    if not hash then return nil end
    local pos = groundAt(offset(spot.coords, spot.radius or 14.0))
    local ped = CreatePed(hash, pos.x, pos.y, pos.z, math.random(0, 359) + 0.0, true, true, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    Citizen.InvokeNative(SET_ANIMAL_WILD, ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    herdPeds[ped] = true
    pcall(function()
        Entity(ped).state:set('bccWildHerd', true, true)
    end)
    return ped
end

local function inUse(group)
    if not group then return false end
    local playerPed = PlayerPedId()
    local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, playerPed)
    for i = 1, #(group.peds or {}) do
        local ped = group.peds[i]
        if ped and DoesEntityExist(ped) and mount == ped then
            return true
        end
    end
    return false
end

local function despawnHerd(index, force)
    local group = herds[index]
    if not group then return end
    if not force and inUse(group) then return end
    for i = 1, #(group.peds or {}) do
        local ped = group.peds[i]
        if ped and DoesEntityExist(ped) then
            local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, PlayerPedId())
            if mount ~= ped then
                herdPeds[ped] = nil
                DeleteEntity(ped)
            end
        end
    end
    herds[index] = nil
end

local function ensureHerd(index, spot)
    local group = herds[index]
    if group then
        local alive = 0
        for i = 1, #(group.peds or {}) do
            local ped = group.peds[i]
            if ped and DoesEntityExist(ped) and not IsEntityDead(ped) then
                alive = alive + 1
            end
        end
        if alive > 0 then return end
    end
    local sizeCfg = Config.HerdSize or {}
    local count = math.random(sizeCfg.min or 2, sizeCfg.max or 4)
    local peds = {}
    for _ = 1, count do
        local ped = spawnHorse(spot)
        if ped then peds[#peds + 1] = ped end
    end
    herds[index] = { peds = peds }
end

RegisterNetEvent('bcc-wildhorses:setHost', function(indexes)
    local nextSet = {}
    for i = 1, #(indexes or {}) do
        nextSet[indexes[i]] = true
    end
    for index in pairs(hostSet) do
        if not nextSet[index] then
            despawnHerd(index, false)
        end
    end
    hostSet = nextSet
end)

CreateThread(function()
    while true do
        Wait(2500)
        if Config.Enabled == false then goto continue end
        local coords = GetEntityCoords(PlayerPedId())
        local nearby = {}
        for i = 1, #(Config.Herds or {}) do
            local spot = Config.Herds[i]
            local dist = #(coords - spot.coords)
            if dist <= (Config.HerdActivate or 140.0) then
                nearby[#nearby + 1] = i
                if hostSet[i] then
                    ensureHerd(i, spot)
                end
            elseif dist >= (Config.HerdDespawn or 210.0) then
                despawnHerd(i, false)
            end
        end
        TriggerServerEvent('bcc-wildhorses:pulse', nearby)
        ::continue::
    end
end)

CreateThread(function()
    while true do
        Wait(1500)
        local mount = Citizen.InvokeNative(0xE7E11B8DCBED1058, PlayerPedId())
        if mount and mount ~= 0 and isOurHorse(mount) and not warned then
            local wild = Citizen.InvokeNative(0x3B005FF0538ED2A9, mount, Citizen.ResultAsInteger())
            if tonumber(wild) ~= 1 then
                warned = true
                Core.NotifyRightTip('Take the broken horse to a trainer to register or sell it.', 6000)
            end
        end
    end
end)
