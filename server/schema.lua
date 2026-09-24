Schema = {}
Schema.Ready = false

local COLUMNS = {
    { 'catalog_id', "VARCHAR(100) NOT NULL DEFAULT ''" },
    { 'breeding_color', "VARCHAR(40) NOT NULL DEFAULT ''" },
    { 'breeding_pattern', "VARCHAR(40) NOT NULL DEFAULT 'Solid'" },
    { 'genotype', "VARCHAR(80) NOT NULL DEFAULT ''" },
    { 'gelded', 'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'care_hunger', 'INT NOT NULL DEFAULT 100' },
    { 'care_thirst', 'INT NOT NULL DEFAULT 100' },
    { 'care_clean', 'INT NOT NULL DEFAULT 100' },
    { 'care_love', 'INT NOT NULL DEFAULT 50' },
    { 'last_care_at', 'BIGINT NOT NULL DEFAULT 0' },
    { 'personality', "VARCHAR(40) NOT NULL DEFAULT ''" },
    { 'age_days', 'INT NOT NULL DEFAULT 0' },
    { 'pregnant', 'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'foal_phase', 'INT NOT NULL DEFAULT -1' },
    { 'locked', 'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'lock_reason', "VARCHAR(40) NOT NULL DEFAULT ''" },
    { 'train_speed', 'INT NOT NULL DEFAULT 0' },
    { 'train_health', 'INT NOT NULL DEFAULT 0' },
    { 'train_stamina', 'INT NOT NULL DEFAULT 0' },
    { 'train_bravery', 'INT NOT NULL DEFAULT 0' },
    { 'train_bond', 'INT NOT NULL DEFAULT 0' },
    { 'last_train_at', 'BIGINT NOT NULL DEFAULT 0' },
}

function Schema.Wait()
    local deadline = GetGameTimer() + 15000
    while not Schema.Ready and GetGameTimer() < deadline do
        Wait(50)
    end
    if not Schema.Ready then
        Schema.Ensure()
    end
end

function Schema.Ensure()
    if Schema.Ready then return end
    -- Tables first so ownership/auction never query a missing table while
    -- player_horses ALTERs are still running.
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcc_stable_owners` (
          `stable_key` VARCHAR(60) NOT NULL,
          `owner_identifier` VARCHAR(80) DEFAULT NULL,
          `owner_charid` INT DEFAULT NULL,
          `owner_name` VARCHAR(80) DEFAULT NULL,
          `till` INT NOT NULL DEFAULT 0,
          `bought_at` BIGINT DEFAULT NULL,
          PRIMARY KEY (`stable_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcc_stables_custom` (
          `stable_key` VARCHAR(60) NOT NULL,
          `label` VARCHAR(80) NOT NULL,
          `npc_x` DOUBLE NOT NULL,
          `npc_y` DOUBLE NOT NULL,
          `npc_z` DOUBLE NOT NULL,
          `npc_h` DOUBLE NOT NULL DEFAULT 0,
          `horse_x` DOUBLE NOT NULL,
          `horse_y` DOUBLE NOT NULL,
          `horse_z` DOUBLE NOT NULL,
          `horse_h` DOUBLE NOT NULL DEFAULT 0,
          `cam_x` DOUBLE NOT NULL,
          `cam_y` DOUBLE NOT NULL,
          `cam_z` DOUBLE NOT NULL,
          `purchase_price` INT NOT NULL DEFAULT 2500,
          `society` VARCHAR(60) NOT NULL DEFAULT '',
          `breeding` TINYINT(1) NOT NULL DEFAULT 0,
          `created_by` VARCHAR(80) NOT NULL DEFAULT '',
          PRIMARY KEY (`stable_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `bcc_horse_auctions` (
          `id` INT NOT NULL AUTO_INCREMENT,
          `horse_id` INT NOT NULL,
          `seller_identifier` VARCHAR(80) NOT NULL,
          `seller_charid` INT NOT NULL,
          `seller_name` VARCHAR(80) NOT NULL DEFAULT '',
          `yard` VARCHAR(40) NOT NULL,
          `stable_key` VARCHAR(60) NOT NULL DEFAULT '',
          `reserve` INT NOT NULL DEFAULT 0,
          `buyout` INT NOT NULL DEFAULT 0,
          `bid` INT NOT NULL DEFAULT 0,
          `bidder_identifier` VARCHAR(80) DEFAULT NULL,
          `bidder_charid` INT DEFAULT NULL,
          `bidder_name` VARCHAR(80) NOT NULL DEFAULT '',
          `ends_at` BIGINT NOT NULL,
          `status` VARCHAR(20) NOT NULL DEFAULT 'open',
          PRIMARY KEY (`id`),
          INDEX `idx_auction_status` (`status`, `ends_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]])

    Schema.Ready = true

    for i = 1, #COLUMNS do
        local col, def = COLUMNS[i][1], COLUMNS[i][2]
        pcall(function()
            MySQL.query.await(('ALTER TABLE `player_horses` ADD COLUMN `%s` %s'):format(col, def))
        end)
    end

    -- TINYINT(1) is treated as boolean by some MySQL drivers (1 => true).
    local trainCols = { 'train_speed', 'train_health', 'train_stamina', 'train_bravery', 'train_bond' }
    for i = 1, #trainCols do
        pcall(function()
            MySQL.query.await(('ALTER TABLE `player_horses` MODIFY COLUMN `%s` INT NOT NULL DEFAULT 0'):format(trainCols[i]))
        end)
    end
end

CreateThread(function()
    local function run()
        if not Schema.Ready then
            Schema.Ensure()
        end
    end
    if MySQL and type(MySQL.ready) == 'function' then
        MySQL.ready(run)
    else
        run()
    end
    Wait(5000)
    run()
end)
