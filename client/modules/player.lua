LocalPlayerData = nil

RegisterNetEvent("polarix_towjob:playerUpdate", function(data)
    LocalPlayerData = data
end)

RegisterNetEvent("polarix_towjob:levelUp", function(data)
    Framework.Notify(("You reached level %d: %s"):format(data.level, data.title or ""), "success")
end)
