-- Set the FX version and game type
fx_version "cerulean"
game "gta5"

-- Resource metadata
author "derPolarix"
description ""
version "0.0.0"
lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/debug.lua',
    "config/shared.lua"
}

client_scripts {
    "client/*.lua",
    "client/modules/*.lua",
    "client/nui/*.lua",
    "config/client.lua"
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
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

-- ui_page "http://localhost:5050"

ox_libs {
    'locale',
    'math',
    'table',
}
