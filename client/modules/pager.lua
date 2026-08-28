local debug = require("shared.debug")

-- Pager NUI is focus-less (never grabs the cursor mid-drive), so its buttons can't be
-- clicked — accept/decline run off raw control checks instead.
local ACCEPT_CONTROL = 191  -- INPUT_FRONTEND_ACCEPT (Enter)
local DECLINE_CONTROL = 177 -- INPUT_FRONTEND_CANCEL (Backspace)

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
            Framework.Notify("That job is no longer available.", "error")
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

CreateThread(function()
    while true do
        if offerActive then
            if IsControlJustPressed(0, ACCEPT_CONTROL) then
                resolveOffer(true)
            elseif IsControlJustPressed(0, DECLINE_CONTROL) then
                resolveOffer(false)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)
