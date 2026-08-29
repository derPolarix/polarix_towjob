local Locale = require("shared.locale")

LocalPlayerData = nil

RegisterNetEvent("polarix_towjob:playerUpdate", function(data)
    LocalPlayerData = data
end)

RegisterNetEvent("polarix_towjob:levelUp", function(data)
    Framework.Notify(Locale("notify.level_up"):format(data.level, data.title or ""), "success")
end)
