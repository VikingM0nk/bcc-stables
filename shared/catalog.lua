--[[
    Horse catalog helpers. Vanilla coats keep model-as-key.
    Overlay presets may use a unique id plus cfg.model.
]]

Catalog = {}

local HOT_BREEDS = {
    Arabian = true, Turkoman = true, Thoroughbred = true, Mustang = true,
    Criollo = true, Nokota = true, ['Missouri Fox Trotter'] = true,
}
local COLD_BREEDS = {
    Shire = true, ['Gypsy Cob'] = true, Breton = true, Kladruber = true,
    Ardennes = true, Belgian = true, ['Belgian Draft'] = true, ['Suffolk Punch'] = true,
}

local PATTERN_ORDER = {
    { 'tovero', 'Tovero' },
    { 'overo', 'Overo' },
    { 'tobiano', 'Tobiano' },
    { 'splashed', 'Splash' },
    { 'splash', 'Splash' },
    { 'sabino', 'Sabino' },
    { 'piebald', 'Tobiano' },
    { 'skewbald', 'Tobiano' },
    { 'pinto', 'Tobiano' },
    { 'leopard', 'Appaloosa' },
    { 'blanket', 'Appaloosa' },
    { 'snowflake', 'Appaloosa' },
    { 'few spotted', 'Appaloosa' },
    { 'blagdon', 'Splash' },
}

local COLOR_ORDER = {
    { 'cremello', 'Cremello' },
    { 'perlino', 'Perlino' },
    { 'smoky cream', 'Smoky Cream' },
    { 'palomino', 'Palomino' },
    { 'buckskin', 'Buckskin' },
    { 'champagne', 'Champagne' },
    { 'grullo', 'Dun' },
    { 'grulla', 'Dun' },
    { 'dun', 'Dun' },
    { 'grey', 'Grey' },
    { 'gray', 'Grey' },
    { 'roan', 'Roan' },
    { 'black', 'Black' },
    { 'seal brown', 'Black' },
    { 'chestnut', 'Chestnut' },
    { 'sorrel', 'Chestnut' },
    { 'bay', 'Bay' },
    { 'white', 'Grey' },
    { 'silver', 'Silver' },
    { 'gold', 'Palomino' },
}

local DEFAULT_PERSONALITY = {
    ['Easy-going'] = 25, Social = 15, Playful = 12, Sensitive = 10,
    Aloof = 10, Fearful = 8, Distrustful = 7, Challenging = 6,
    ['Mud Magnet'] = 5, Dangerous = 2,
}

local HOT_PERSONALITY = {
    Challenging = 18, Playful = 16, Social = 14, ['Easy-going'] = 12,
    Sensitive = 10, Distrustful = 10, Fearful = 8, Aloof = 6,
    Dangerous = 4, ['Mud Magnet'] = 2,
}

local COLD_PERSONALITY = {
    ['Easy-going'] = 28, Aloof = 16, Social = 14, Sensitive = 12,
    ['Mud Magnet'] = 10, Playful = 8, Fearful = 5, Distrustful = 4,
    Challenging = 2, Dangerous = 1,
}

local function parseCoat(label)
    local lower = tostring(label or ''):lower()
    local pattern = 'Solid'
    for i = 1, #PATTERN_ORDER do
        if lower:find(PATTERN_ORDER[i][1], 1, true) then
            pattern = PATTERN_ORDER[i][2]
            break
        end
    end
    local color = 'Bay'
    for i = 1, #COLOR_ORDER do
        if lower:find(COLOR_ORDER[i][1], 1, true) then
            color = COLOR_ORDER[i][2]
            break
        end
    end
    local genotype = color
    if pattern ~= 'Solid' then
        genotype = color .. ' + ' .. pattern
    end
    return color, pattern, genotype
end

local function weatherFor(breed)
    if HOT_BREEDS[breed] then return 'hot' end
    if COLD_BREEDS[breed] then return 'cold' end
    return 'mixed'
end

local function oddsFor(breed)
    if HOT_BREEDS[breed] then return HOT_PERSONALITY end
    if COLD_BREEDS[breed] then return COLD_PERSONALITY end
    return DEFAULT_PERSONALITY
end

function Catalog.SpawnModel(idOrCfg, cfg)
    if type(idOrCfg) == 'table' then
        return tostring(idOrCfg.model or idOrCfg.color or '')
    end
    if cfg and cfg.model then
        return tostring(cfg.model)
    end
    return tostring(idOrCfg or '')
end

function Catalog.Find(idOrModel)
    if not idOrModel or not Horses then return nil, nil, nil end
    local key = tostring(idOrModel)
    local keyLower = key:lower()
    for i = 1, #Horses do
        local breedCfg = Horses[i]
        local colors = breedCfg and breedCfg.colors
        if colors then
            if colors[key] then
                return breedCfg, colors[key], key
            end
            for id, cfg in pairs(colors) do
                if type(cfg) == 'table' then
                    if tostring(id):lower() == keyLower then
                        return breedCfg, cfg, id
                    end
                    if cfg.model and tostring(cfg.model):lower() == keyLower then
                        return breedCfg, cfg, id
                    end
                end
            end
        end
    end
end

local function u32(n)
    n = tonumber(n) or 0
    n = n % 4294967296
    if n < 0 then n = n + 4294967296 end
    return n
end

function Catalog.FindByHash(hash)
    hash = tonumber(hash)
    if not hash or hash == 0 or not Horses then return nil, nil, nil end
    local masked = u32(hash)
    for i = 1, #Horses do
        local breedCfg = Horses[i]
        local colors = breedCfg and breedCfg.colors
        if colors then
            for id, cfg in pairs(colors) do
                if type(cfg) == 'table' then
                    local spawn = Catalog.SpawnModel(id, cfg)
                    local modelHash = u32(joaat(spawn))
                    if modelHash == masked then
                        return breedCfg, cfg, id
                    end
                    local idHash = u32(joaat(id))
                    if idHash == masked then
                        return breedCfg, cfg, id
                    end
                end
            end
        end
    end
end

function Catalog.Genes(cfg, breedName, colorKey)
    if not cfg then return 'Bay', 'Solid', 'Bay' end
    local color = cfg.breedingColor
    local pattern = cfg.breedingPattern
    local genotype = cfg.genotype
    if not color or not pattern then
        local inferredColor, inferredPattern, inferredGene = parseCoat(cfg.color or colorKey)
        color = color or inferredColor
        pattern = pattern or inferredPattern
        genotype = genotype or inferredGene
    end
    return color, pattern, genotype or (color .. ((pattern ~= 'Solid' and (' + ' .. pattern)) or ''))
end

function Catalog.IsBreedable(cfg, breedName)
    if cfg and cfg.breedable == false then return false end
    local breed = tostring(breedName or ''):lower()
    local color = tostring(cfg and cfg.color or ''):lower()
    if breed == 'donkey' or color == 'donkey' then return false end
    local model = Catalog.SpawnModel(nil, cfg)
    if model:find('donkey', 1, true) then return false end
    return true
end

function Catalog.RollPersonality(breedName, cfg)
    local odds = (cfg and cfg.personalityOdds) or oddsFor(breedName)
    local total = 0
    for _, w in pairs(odds) do total = total + (tonumber(w) or 0) end
    if total <= 0 then return 'Easy-going' end
    local roll = math.random() * total
    local acc = 0
    local last = 'Easy-going'
    for name, w in pairs(odds) do
        acc = acc + (tonumber(w) or 0)
        last = name
        if roll <= acc then return name end
    end
    return last
end

function Catalog.Matching(color, pattern, preferBreed)
    local list = {}
    local fallback = {}
    color = tostring(color or 'Bay')
    pattern = tostring(pattern or 'Solid')
    for i = 1, #Horses do
        local breedCfg = Horses[i]
        local colors = breedCfg and breedCfg.colors
        if colors then
            for id, cfg in pairs(colors) do
                if type(cfg) == 'table' and Catalog.IsBreedable(cfg, breedCfg.breed) then
                    local c, p = Catalog.Genes(cfg, breedCfg.breed, cfg.color or id)
                    if c == color and p == pattern then
                        local row = { id = id, cfg = cfg, breed = breedCfg.breed }
                        if preferBreed and breedCfg.breed == preferBreed then
                            list[#list + 1] = row
                        else
                            fallback[#fallback + 1] = row
                        end
                    end
                end
            end
        end
    end
    if #list > 0 then return list end
    return fallback
end

function Catalog.Enrich()
    if Catalog._enriched or not Horses then return end
    for i = 1, #Horses do
        local breedCfg = Horses[i]
        local breed = breedCfg.breed
        local colors = breedCfg.colors
        if colors then
            for id, cfg in pairs(colors) do
                if type(cfg) == 'table' then
                    cfg.model = cfg.model or id
                    local color, pattern, genotype = Catalog.Genes(cfg, breed, cfg.color or id)
                    cfg.breedingColor = color
                    cfg.breedingPattern = pattern
                    cfg.genotype = genotype
                    if cfg.breedable == nil then
                        cfg.breedable = Catalog.IsBreedable(cfg, breed)
                    end
                    cfg.weather = cfg.weather or weatherFor(breed)
                    cfg.personalityOdds = cfg.personalityOdds or oddsFor(breed)
                end
            end
        end
    end
    Catalog._enriched = true
end

CreateThread(function()
    Wait(0)
    Catalog.Enrich()
end)
