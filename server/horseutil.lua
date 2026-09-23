HorseUtil = {}

function HorseUtil.FillFromCatalog(modelOrId)
    Catalog.Enrich()
    local breedCfg, cfg, id = Catalog.Find(modelOrId)
    if not cfg then
        return {
            catalog_id = tostring(modelOrId or ''),
            model = tostring(modelOrId or ''),
            breed = 'Horse',
            breeding_color = 'Bay',
            breeding_pattern = 'Solid',
            genotype = 'Bay',
            personality = 'Easy-going',
            invLimit = 200,
        }
    end
    local color, pattern, genotype = Catalog.Genes(cfg, breedCfg.breed, cfg.color or id)
    return {
        catalog_id = id,
        model = Catalog.SpawnModel(id, cfg),
        breed = breedCfg.breed,
        breeding_color = color,
        breeding_pattern = pattern,
        genotype = genotype,
        personality = Catalog.RollPersonality(breedCfg.breed, cfg),
        invLimit = tonumber(cfg.invLimit) or 200,
        appearance = cfg.appearance,
        cfg = cfg,
        breedCfg = breedCfg,
    }
end

function HorseUtil.InsertOwned(row)
    local meta = HorseUtil.FillFromCatalog(row.catalog_id or row.model)
    return MySQL.insert.await([[
        INSERT INTO `player_horses`
        (identifier, charid, name, model, gender, captured, catalog_id, breeding_color, breeding_pattern,
         genotype, personality, care_hunger, care_thirst, care_clean, care_love, last_care_at, age_days, foal_phase)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 100, 100, 100, 50, ?, ?, ?)
    ]], {
        row.identifier,
        row.charid,
        row.name,
        meta.model,
        row.gender or 'male',
        row.captured or 0,
        meta.catalog_id,
        row.breeding_color or meta.breeding_color,
        row.breeding_pattern or meta.breeding_pattern,
        row.genotype or meta.genotype,
        row.personality or meta.personality,
        os.time(),
        tonumber(row.age_days) or 0,
        tonumber(row.foal_phase) or -1,
    })
end

function HorseUtil.GetOwned(id)
    return MySQL.single.await('SELECT * FROM player_horses WHERE id = ?', { id })
end

function HorseUtil.Owns(row, identifier, charid)
    return row
        and row.identifier == identifier
        and tonumber(row.charid) == tonumber(charid)
        and tonumber(row.dead) ~= 1
end
