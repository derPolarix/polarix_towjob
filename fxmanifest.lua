-- Set the FX version and game type
fx_version "cerulean"
game "gta5"

-- Resource metadata
author "derPolarix"
description "Tow job resource with dashboard, mission/skill/vehicle progression and admin settings UI (qbox / qb-core / esx)"
version "1.0.0"
lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/debug.lua',
    "config/shared.lua",
    "framework/qbox/shared.lua",
    "framework/qb-core/shared.lua",
    "framework/esx/shared.lua",
    "framework/shared.lua"
}

client_scripts {
    "framework/qbox/client.lua",
    "framework/qb-core/client.lua",
    "framework/esx/client.lua",
    "framework/client.lua",
    "client/*.lua",
    "client/modules/*.lua",
    "client/nui/*.lua",
    "config/client.lua"
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    "framework/qbox/server.lua",
    "framework/qb-core/server.lua",
    "framework/esx/server.lua",
    "framework/server.lua",
    "server/*.lua",
    "server/modules/*.lua",
    "config/server.lua"
}

files {
    'locales/*.json',
    "sql/init.sql",
    "html/*",
    "html/assets/*",
    "html/img/*",
    "html/index.html"
}

ui_page "html/index.html"

ox_libs {
    'locale',
    'math',
    'table',
}

-- ox_target is deliberately NOT listed here — ground rule 5 requires a native-fallback path
-- whenever it isn't running, so it must stay a soft, GetResourceState()-checked dependency.
-- Framework core (qbx_core / qb-core / es_extended) and the per-framework vehicle-keys
-- resources are the same story: only one is ever active per config/shared.lua's Framework
-- value, and every reference to them is already runtime-guarded (see framework/**, ground
-- rule 1, Phase 0.3) — listing one as a hard dependency would break resource start on servers
-- running either of the other two frameworks.
dependencies {
    'ox_lib',
    'oxmysql',
}
