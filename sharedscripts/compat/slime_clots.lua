-- Compat with the Slime Rancher clot replacement, which ships no Lua, so the mod is detected through the metadata REPENTOGON parses rather than a global

local WORKSHOP_ID = "3783134747"
local DIRECTORY_ID = "a slime rancher clots" -- REPENTOGON falls back to the folder name when a mod carries no workshop id
local SLIME_CLOT_SHEET = "gfx/familiars/quicksilver_clot.png"

-- True when the clot replacement is loaded, looked up by both ids since an unsubscribed or indev copy is keyed on the directory instead
local function slimeClotsLoaded()
    if type(XMLData) ~= "table" or type(XMLData.GetModById) ~= "function" then return false end

    for _, id in ipairs({ WORKSHOP_ID, DIRECTORY_ID }) do
        local ok, entry = pcall(XMLData.GetModById, id)
        if ok and type(entry) == "table" and entry.name then return true end
    end
    return false
end

-- Cement Heart clots wear the quicksilver sheet alongside the slimes, since the cement art reads as a blood clot next to them
if POR.CementHeart and slimeClotsLoaded() then
    POR.CementHeart.CLOT_SHEET = SLIME_CLOT_SHEET
end
