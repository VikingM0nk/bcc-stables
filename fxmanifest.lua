fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
author 'BCC Team'

shared_scripts {
    'config/*.lua',
    'locale.lua',
    'languages/*.lua',
    'shared/catalog.lua',
    'shared/genetics.lua',
    'shared/presets.lua',
    'shared/settings.lua'
}

client_scripts {
    'client/dataview.lua',
    'client/main.lua',
    'client/horseinfo.lua',
    'client/menus/*.lua',
    'client/care.lua',
    'client/training.lua',
    'client/stablebiz.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/schema.lua',
    'server/horseutil.lua',
    'server/ownership.lua',
    'server/auction.lua',
    'server/exports.lua',
    'server/training.lua',
    'server/main.lua'
}

ui_page {
    'ui/index.html'
}

files {
    "ui/index.html",
    "ui/js/*.*",
    "ui/css/*.*",
    "ui/fonts/*.*",
    "ui/img/*.*"
}

version '1.7.5'
