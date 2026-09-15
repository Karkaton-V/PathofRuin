-- TEMPORARY: registers the "porcompat" console command that reports which other mods this one can currently see, delete once the compat gates are confirmed

local PROBE = {}
POR.CompatProbe = PROBE

local LOG_PREFIX = "[POR COMPAT] "

-- Globals each compat file gates on, so a nil here explains a gate that never fires
local GLOBALS = { "FiendFolio", "GodsGambit", "TaintedTreasure", "EID", "Poglite", "StageAPI", "CustomHealthAPI" }

-- Ids the Slime Rancher clot replacement can be registered under, matching compat/slime_clots.lua
local SLIME_IDS = { "3783134747", "a slime rancher clots" }

local function log(line)
    Isaac.DebugString(LOG_PREFIX .. line)
    print(LOG_PREFIX .. line)
end

-- Reports whether each gated global is present, which is what every compat file in this mod keys on
local function probeGlobals()
    for _, name in ipairs(GLOBALS) do
        local value = _G[name]
        log(name .. " = " .. (value and type(value) or "nil"))
    end
end

-- Reports whether REPENTOGON can see the resource-only slime clot mod, which has no global to test
local function probeSlimeClots()
    if type(XMLData) ~= "table" or type(XMLData.GetModById) ~= "function" then
        log("XMLData.GetModById unavailable, so the slime clot mod cannot be detected")
        return
    end

    for _, id in ipairs(SLIME_IDS) do
        local ok, entry = pcall(XMLData.GetModById, id)
        local name = (ok and type(entry) == "table") and entry.name or nil
        log("GetModById(\"" .. id .. "\") = " .. tostring(name))
    end
end

-- Reports the spritesheet each boulder kind resolves to right now, calling the same picker the spawn path uses
local function probeBoulderSheets()
    local rocks = POR.ROCKTABLE
    if not rocks or not rocks.KindSheet or not rocks.KIND_DATA then
        log("boulder tables unavailable")
        return
    end

    for kind, kindData in pairs(rocks.KIND_DATA) do
        log("boulder " .. tostring(kind) .. " -> " .. tostring(rocks.KindSheet(kindData)))
    end
end

-- Reports which Cement Heart clot sheet is currently selected, which compat/slime_clots.lua may have swapped
local function probeClotSheet()
    if not POR.CementHeart then
        log("cement heart table unavailable")
        return
    end
    log("clot sheet -> " .. tostring(POR.CementHeart.CLOT_SHEET))
end

-- Runs every probe when "porcompat" is typed into the debug console
function PROBE.OnCommand(_, command)
    if string.lower(command or "") ~= "porcompat" then return end

    log("===== begin =====")
    probeGlobals()
    probeSlimeClots()
    probeBoulderSheets()
    probeClotSheet()
    log("===== end =====")

    return "POR compat probe written to the console and log.txt"
end

POR:AddCallback(ModCallbacks.MC_EXECUTE_CMD, PROBE.OnCommand)

return PROBE
