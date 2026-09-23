local hosts = {} -- [herdIndex] = playerId
local inZone = {} -- [playerId] = { [herdIndex] = true }

local function herdCount()
    return #(Config.Herds or {})
end

local function pushHost(src)
    local mine = {}
    for i = 1, herdCount() do
        if hosts[i] == src then
            mine[#mine + 1] = i
        end
    end
    TriggerClientEvent('bcc-wildhorses:setHost', src, mine)
end

local function elect(index)
    local current = hosts[index]
    if current and inZone[current] and inZone[current][index] and GetPlayerName(current) then
        return
    end
    hosts[index] = nil
    for src, zones in pairs(inZone) do
        if zones[index] and GetPlayerName(src) then
            hosts[index] = src
            break
        end
    end
end

local function refreshAll()
    for i = 1, herdCount() do
        elect(i)
    end
    local seen = {}
    for i = 1, herdCount() do
        local src = hosts[i]
        if src and not seen[src] then
            seen[src] = true
            pushHost(src)
        end
    end
    for src in pairs(inZone) do
        if not seen[src] then
            TriggerClientEvent('bcc-wildhorses:setHost', src, {})
        end
    end
end

RegisterNetEvent('bcc-wildhorses:pulse', function(indexes)
    local src = source
    local map = {}
    for i = 1, #(indexes or {}) do
        local idx = tonumber(indexes[i])
        if idx and idx >= 1 and idx <= herdCount() then
            map[idx] = true
        end
    end
    if next(map) == nil then
        inZone[src] = nil
    else
        inZone[src] = map
    end
end)

AddEventHandler('playerDropped', function()
    inZone[source] = nil
    for i = 1, herdCount() do
        if hosts[i] == source then hosts[i] = nil end
    end
end)

CreateThread(function()
    while true do
        Wait((Config.HostHeartbeat or 4) * 1000)
        if Config.Enabled ~= false then
            refreshAll()
        end
    end
end)
