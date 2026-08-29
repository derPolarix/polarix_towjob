-- Locale loader (SSOT: locales/*.json). Usage: local Locale = require("shared.locale")
-- Keys are semantic (e.g. "notify.vehicle_stored"); en.json is the source of truth,
-- every other locale file translates the same keys. Loaded on both client and server.
-- Only user-facing text goes through here — error/debug prints stay English in code.

local SharedConfig = require("config.shared")

local cache = {}

local function loadPhrases(lang)
    if cache[lang] then return cache[lang] end

    local raw = LoadResourceFile(GetCurrentResourceName(), ("locales/%s.json"):format(lang))
    local decoded = raw and json.decode(raw) or {}
    cache[lang] = decoded
    return decoded
end

return function(key, ...)
    local lang = SharedConfig.Language or "en"
    local phrase = loadPhrases(lang)[key]

    if phrase == nil and lang ~= "en" then
        phrase = loadPhrases("en")[key]
    end
    phrase = phrase or key

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, phrase, ...)
        if ok then return formatted end
    end

    return phrase
end
