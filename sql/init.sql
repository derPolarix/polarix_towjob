-- Player progression
CREATE TABLE IF NOT EXISTS polarix_towjob_players (
    identifier        VARCHAR(60) PRIMARY KEY,
    name              VARCHAR(50),
    level             INT      DEFAULT 1,
    xp                INT      DEFAULT 0,
    skill_points      INT      DEFAULT 0,
    skills            JSON     DEFAULT ('[]'),
    total_earnings    BIGINT   DEFAULT 0,
    total_deliveries  INT      DEFAULT 0,
    failed_deliveries INT      DEFAULT 0,
    aborted_deliveries INT     DEFAULT 0,
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Area definitions (map-unlockable regions)
CREATE TABLE IF NOT EXISTS polarix_towjob_areas (
    id            VARCHAR(36)  PRIMARY KEY,
    name          VARCHAR(100),
    region        VARCHAR(50),
    points        JSON,           -- polygon vertices in GTA world coords, [{x,y}, ...], min 3 (web/src/lib/gtaMap.ts converts to the Leaflet map)
    unlock_cost   INT      DEFAULT 0,
    level_required INT     DEFAULT 1,
    reward_multiplier DECIMAL(4,2) DEFAULT 1.00,   -- stacks with Settings.GetRewardMultiplier() (missions.lua Complete)
    xp_multiplier DECIMAL(4,2) DEFAULT 1.00,       -- stacks with Settings.GetXpMultiplier() (missions.lua Complete)
    note          VARCHAR(140) DEFAULT NULL,       -- short admin note/tag, e.g. "High traffic" (display-only)
    is_default    TINYINT(1) DEFAULT 0,    -- pre-unlocked for everyone
    is_active     TINYINT(1) DEFAULT 1,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Per-player area unlocks (only rows for non-default areas a player has unlocked)
CREATE TABLE IF NOT EXISTS polarix_towjob_player_areas (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    identifier   VARCHAR(60),
    area_id      VARCHAR(36),
    unlocked_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_player_area (identifier, area_id)
);

-- Mission templates (Admin-UI managed, seeded from config on first boot)
CREATE TABLE IF NOT EXISTS polarix_towjob_missions (
    id                VARCHAR(36) PRIMARY KEY,
    area_id           VARCHAR(36),
    name              VARCHAR(100),
    vehicle_model     VARCHAR(50),
    vehicle_label     VARCHAR(100),
    vehicle_colors    JSON,                  -- { primary = int, secondary = int } for description text
    spawn_points      JSON,           -- hand-placed spawn spots, [{x,y,z,heading}, ...], min 1, max 20 (one is picked per delivery)
    dropoff_x         FLOAT, dropoff_y FLOAT, dropoff_z FLOAT, dropoff_heading FLOAT,
    dropoff_width     FLOAT     DEFAULT 6.0,
    dropoff_length    FLOAT     DEFAULT 10.0,
    reward_base       INT,
    xp_base           INT,
    reward_per_km     INT       DEFAULT 0,   -- added on top of reward_base per km between the picked spawn point and the dropoff
    xp_per_km         INT       DEFAULT 0,
    time_limit_minutes INT      DEFAULT NULL,
    difficulty        ENUM('easy','medium','hard') DEFAULT 'easy',
    level_required    INT       DEFAULT 1,
    is_active         TINYINT(1) DEFAULT 1,
    created_by        VARCHAR(60),
    updated_by        VARCHAR(60),
    created_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Delivery history / active deliveries
CREATE TABLE IF NOT EXISTS polarix_towjob_deliveries (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    mission_id     VARCHAR(36),
    mission_name   VARCHAR(100),  -- snapshot: priority jobs have no template row, and a hard-deleted template would otherwise blank its history
    identifier     VARCHAR(60),
    status         ENUM('active','completed','failed','aborted') DEFAULT 'active',
    reward_paid    INT DEFAULT 0,
    xp_paid        INT DEFAULT 0,
    damage_penalty INT DEFAULT 0,
    used_rental    TINYINT(1) DEFAULT 0,
    is_test        TINYINT(1) DEFAULT 0,  -- admin test run: never paid or counted, row deleted when it ends
    started_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at   TIMESTAMP NULL
);

-- Owned tow trucks (purchase + persistent damage + garage state)
CREATE TABLE IF NOT EXISTS polarix_towjob_vehicles (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    identifier    VARCHAR(60),
    tier_id       VARCHAR(50),               -- key into config VehicleTiers
    plate         VARCHAR(12) UNIQUE,
    body_health   FLOAT     DEFAULT 1000.0,
    engine_health FLOAT     DEFAULT 1000.0,
    state         ENUM('stored','deployed') DEFAULT 'stored',
    purchased_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Runtime-editable admin settings (key/value)
CREATE TABLE IF NOT EXISTS polarix_towjob_settings (
    setting_key   VARCHAR(60) PRIMARY KEY,
    setting_value JSON,
    updated_by    VARCHAR(60),
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Migrations for servers whose tables predate later columns. CREATE TABLE IF NOT EXISTS
-- never adds columns to an existing table, so these run every boot (each is pcall'd
-- individually in server/main.lua's loadSchema and is a no-op once the column exists).
ALTER TABLE polarix_towjob_areas ADD COLUMN IF NOT EXISTS points JSON;
ALTER TABLE polarix_towjob_areas ADD COLUMN IF NOT EXISTS reward_multiplier DECIMAL(4,2) DEFAULT 1.00;
ALTER TABLE polarix_towjob_areas ADD COLUMN IF NOT EXISTS xp_multiplier DECIMAL(4,2) DEFAULT 1.00;
ALTER TABLE polarix_towjob_areas ADD COLUMN IF NOT EXISTS note VARCHAR(140) DEFAULT NULL;
ALTER TABLE polarix_towjob_deliveries ADD COLUMN IF NOT EXISTS mission_name VARCHAR(100);
ALTER TABLE polarix_towjob_missions ADD COLUMN IF NOT EXISTS reward_per_km INT DEFAULT 0;
ALTER TABLE polarix_towjob_missions ADD COLUMN IF NOT EXISTS xp_per_km INT DEFAULT 0;
ALTER TABLE polarix_towjob_deliveries ADD COLUMN IF NOT EXISTS is_test TINYINT(1) DEFAULT 0;
