--[[
    Coat mixing for breeding. Inspired by real equine layers (base + dilute + one pattern).
    Not a copy of any paid gene table.
]]

Genetics = {}

Config.BreedingGeneWeights = Config.BreedingGeneWeights or {
    Chestnut = 1.0,
    Bay = 1.2,
    Black = 1.0,
    Palomino = 1.0,
    Buckskin = 1.0,
    Cremello = 0.7,
    Perlino = 0.7,
    ['Smoky Black'] = 0.9,
    ['Smoky Cream'] = 0.6,
    Dun = 0.9,
    Champagne = 0.8,
    Grey = 1.0,
    Roan = 1.0,
    Silver = 0.8,
    Solid = 1.0,
    Overo = 1.0,
    Tobiano = 1.0,
    Splash = 0.9,
    Sabino = 0.8,
    Appaloosa = 1.0,
    Tovero = 0.7,
}

local GENE = {
    Palomino = { base = 'Chestnut', cream = 1 },
    Buckskin = { base = 'Bay', cream = 1 },
    Perlino = { base = 'Bay', cream = 2 },
    Cremello = { base = 'Chestnut', cream = 2 },
    ['Smoky Black'] = { base = 'Black', cream = 1 },
    ['Smoky Cream'] = { base = 'Black', cream = 2 },
    Champagne = { base = 'Bay', cream = 1, champagne = true },
    Dun = { base = 'Bay', cream = 0, dun = true },
    Grey = { base = 'Bay', cream = 0, grey = true },
    Roan = { base = 'Bay', cream = 0, roan = true },
    Silver = { base = 'Black', cream = 0, silver = true },
    Chestnut = { base = 'Chestnut', cream = 0 },
    Bay = { base = 'Bay', cream = 0 },
    Black = { base = 'Black', cream = 0 },
}

local function geneOf(colorName)
    return GENE[colorName] or { base = colorName or 'Bay', cream = 0 }
end

local function dilute(base, cream)
    if cream >= 2 then
        if base == 'Chestnut' then return 'Cremello' end
        if base == 'Black' then return 'Smoky Cream' end
        return 'Perlino'
    end
    if cream == 1 then
        if base == 'Chestnut' then return 'Palomino' end
        if base == 'Black' then return 'Smoky Black' end
        return 'Buckskin'
    end
    return base
end

local function pickWeighted(options)
    local weights = Config.BreedingGeneWeights or {}
    local total = 0
    local bag = {}
    for i = 1, #options do
        local name = options[i]
        local w = tonumber(weights[name]) or 1.0
        total = total + w
        bag[#bag + 1] = { name = name, w = w }
    end
    if total <= 0 or #bag == 0 then return options[1] end
    local roll = math.random() * total
    local acc = 0
    for i = 1, #bag do
        acc = acc + bag[i].w
        if roll <= acc then return bag[i].name end
    end
    return bag[#bag].name
end

local function mixBase(a, b)
    local pool = {}
    -- Bay is treated as heterozygous and a silent red carrier
    local function add(base, n)
        for _ = 1, n do pool[#pool + 1] = base end
    end
    if a == 'Bay' or b == 'Bay' then
        add('Bay', 4)
        add('Black', 2)
        add('Chestnut', 2)
    end
    if a == 'Black' or b == 'Black' then
        add('Black', 3)
        add('Bay', 1)
    end
    if a == 'Chestnut' or b == 'Chestnut' then
        add('Chestnut', 3)
        add('Bay', 1)
    end
    if #pool == 0 then
        add(a or 'Bay', 1)
        add(b or 'Bay', 1)
    end
    return pickWeighted(pool)
end

local PATTERN_RANK = {
    Solid = 0, Dun = 1, Roan = 2, Appaloosa = 3, Splash = 4,
    Sabino = 5, Tobiano = 6, Overo = 7, Tovero = 8,
}

local function mixPattern(a, b)
    a = a or 'Solid'
    b = b or 'Solid'
    if a == 'Solid' and b == 'Solid' then return 'Solid' end
    if math.random() < 0.5 then
        if a ~= 'Solid' and b ~= 'Solid' then
            return ((PATTERN_RANK[a] or 0) >= (PATTERN_RANK[b] or 0)) and a or b
        end
        return (a ~= 'Solid') and a or b
    end
    return 'Solid'
end

function Genetics.Describe(row)
    if not row then return 'Bay', 'Solid', 'Bay', 'Horse' end
    local breedCfg, cfg, id = Catalog.Find(row.catalog_id or row.model)
    local color, pattern, genotype
    if cfg then
        color, pattern, genotype = Catalog.Genes(cfg, breedCfg and breedCfg.breed, cfg.color or id)
    else
        color = row.breeding_color or 'Bay'
        pattern = row.breeding_pattern or 'Solid'
        genotype = row.genotype or color
    end
    return color, pattern, genotype, (breedCfg and breedCfg.breed) or row.breed or 'Horse', cfg, id, breedCfg
end

function Genetics.RollFoal(male, female)
    Catalog.Enrich()
    local mColor, mPattern, _, mBreed = Genetics.Describe(male)
    local fColor, fPattern, _, fBreed = Genetics.Describe(female)

    local mGene = geneOf(mColor)
    local fGene = geneOf(fColor)
    local cream = math.min(2, (mGene.cream or 0) + (fGene.cream or 0))
    if cream > 2 then cream = 2 end
    -- two cream carriers can still produce 1 or 2
    if (mGene.cream or 0) > 0 and (fGene.cream or 0) > 0 then
        cream = (math.random() < 0.5) and 2 or 1
    elseif cream > 0 then
        cream = (math.random() < 0.7) and 1 or cream
    end

    local base = mixBase(mGene.base, fGene.base)
    local color = dilute(base, cream)
    if (mGene.grey or fGene.grey) and math.random() < 0.5 then color = 'Grey' end
    if (mGene.roan or fGene.roan) and math.random() < 0.45 then color = 'Roan' end
    if (mGene.dun or fGene.dun) and math.random() < 0.4 and color ~= 'Grey' then color = 'Dun' end
    if (mGene.champagne or fGene.champagne) and math.random() < 0.35 then color = 'Champagne' end

    local pattern = mixPattern(mPattern, fPattern)
    local prefer = (mBreed == fBreed) and mBreed or nil
    local pool = Catalog.Matching(color, pattern, prefer)
    if #pool == 0 then
        pool = Catalog.Matching(color, 'Solid', prefer)
    end
    if #pool == 0 then
        pool = Catalog.Matching(fColor, fPattern, fBreed)
    end

    local pick = pool[math.random(1, math.max(1, #pool))]
    if not pick then
        local breedCfg, cfg, id = Catalog.Find(female.catalog_id or female.model)
        pick = {
            id = id or female.model,
            cfg = cfg or {},
            breed = (breedCfg and breedCfg.breed) or fBreed or 'Mixed',
        }
    end

    local breed = pick.breed or 'Horse'
    local mixed = mBreed and fBreed and mBreed ~= fBreed
    if mixed then breed = 'Mixed' end

    local cfg = pick.cfg or {}
    local gColor, gPattern, genotype = Catalog.Genes(cfg, pick.breed, cfg.color or pick.id)
    local gender = (math.random(100) <= 50) and 'female' or 'male'

    return {
        catalog_id = pick.id,
        model = Catalog.SpawnModel(pick.id, cfg),
        breed = breed,
        color = cfg.color or gColor,
        gender = gender,
        breeding_color = gColor,
        breeding_pattern = gPattern,
        genotype = genotype,
        personality = Catalog.RollPersonality(pick.breed or breed, cfg),
        weather = cfg.weather or 'mixed',
        invLimit = tonumber(cfg.invLimit) or 200,
        appearance = cfg.appearance,
        purebred = not mixed,
    }
end
