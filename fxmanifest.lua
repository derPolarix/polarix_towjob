fx_version "cerulean"
game "gta5"

author "derPolarix"
description "Tow job resource with dashboard, mission/skill/vehicle progression and admin settings UI (qbox / qb-core / esx)"
version "1.0.0"
lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/debug.lua',
    "config/shared.lua",
    'shared/locale.lua',
    'shared/currency.lua',
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
    "target/ox_target/client.lua",
    "target/qb-target/client.lua",
    "target/sleepless_interact/client.lua",
    "target/none/client.lua",
    "target/client.lua",
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
    'client/lib/*.lua',
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

-- Target systems and framework cores are soft dependencies (GetResourceState-checked): only one framework is active
-- and every target needs a native fallback, so hard-listing them would break other setups.
dependencies {
    'ox_lib',
    'oxmysql',
}
