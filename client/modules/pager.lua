local debug = require("shared.debug")
local Locale = require("shared.locale")
local Keybinds = require("client.lib.keybinds")

local offerActive = false
local busy = false

local function resolveOffer(accepted)
    if busy then return end
    busy = true
    offerActive = false
    SendMessage("pagerOfferCleared", nil)

    if accepted then
        local result = Vehicle.AcceptPagerOffer()
        if result and not result.ok then
            local key = result.reason == "insufficient_funds" and "error.rental_insufficient_funds" or "notify.job_no_longer_available"
            Framework.Notify(Locale(key), "error")
        end
    else
        lib.callback.await("polarix_towjob:declinePage", false)
    end

    busy = false
end

RegisterNetEvent("polarix_towjob:pagerOffer", function(offer)
    SendMessage("pagerOffer", offer)
    offerActive = true
end)

RegisterNetEvent("polarix_towjob:pagerOfferCleared", function()
    offerActive = false
    SendMessage("pagerOfferCleared", nil)
end)

-- Focus-less NUI: buttons can't be clicked, so accept/decline use keybinds.
Keybinds.Register("PagerAccept", function()
    if offerActive then resolveOffer(true) end
end)

Keybinds.Register("PagerDecline", function()
    if offerActive then resolveOffer(false) end
end)
