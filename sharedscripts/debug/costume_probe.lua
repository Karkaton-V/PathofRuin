local PROBE = {}

local LOG_PREFIX = "[POR COSTUME] "

-- Writes one line to log.txt and the debug console at once
local function log(text)
    Isaac.DebugString(LOG_PREFIX .. text)
    print(LOG_PREFIX .. text)
end

-- Calls a method that this REPENTOGON build may not expose, reporting the failure inline instead of erroring
local function try(object, method, ...)
    if type(object) ~= "userdata" and type(object) ~= "table" then return "<no object>" end
    if type(object[method]) ~= "function" then return "<no " .. method .. ">" end

    local ok, value = pcall(object[method], object, ...)
    if not ok then return "<error: " .. tostring(value) .. ">" end
    return value
end

-- Reports the view the item config has of the costume on a collectible, which is what the engine builds the sprite from
local function logItemCostume(itemId, label)
    local item = Isaac.GetItemConfig():GetCollectible(itemId)
    if not item then
        log(label .. ": no item config for id " .. tostring(itemId))
        return
    end

    local costume = item.Costume
    if not costume then
        log(label .. ": id=" .. tostring(itemId) .. " has no Costume entry")
        return
    end

    log(label .. ": id=" .. tostring(itemId)
        .. " CostumeID=" .. tostring(costume.ID)
        .. " Anm2Path='" .. tostring(costume.Anm2Path) .. "'"
        .. " HasSkinAlt=" .. tostring(costume.HasSkinAlt)
        .. " Priority=" .. tostring(costume.Priority))
end

-- Dumps every layer of one costume sprite, since an invisible costume usually shows up here as a missing sheet or a hidden layer
local function logSpriteLayers(sprite, indent)
    local layers = try(sprite, "GetAllLayers")
    if type(layers) ~= "userdata" and type(layers) ~= "table" then
        log(indent .. "GetAllLayers -> " .. tostring(layers))
        return
    end

    local count = 0
    for _, layer in ipairs(layers) do
        count = count + 1
        log(indent .. "layer " .. tostring(try(layer, "GetLayerID"))
            .. " name='" .. tostring(try(layer, "GetName")) .. "'"
            .. " visible=" .. tostring(try(layer, "IsVisible"))
            .. " sheet='" .. tostring(try(layer, "GetSpritesheetPath")) .. "'"
            .. " default='" .. tostring(try(layer, "GetDefaultSpritesheetPath")) .. "'")
    end
    log(indent .. "layer count = " .. count)
end

-- Lists every costume the player is currently wearing, so a missing Ammoniac entry can be told apart from one that renders blank
local function logWornCostumes(player)
    local descs = try(player, "GetCostumeSpriteDescs")
    if type(descs) ~= "userdata" and type(descs) ~= "table" then
        log("  GetCostumeSpriteDescs -> " .. tostring(descs))
        return
    end

    local count = 0
    for _, desc in ipairs(descs) do
        count = count + 1
        local config = try(desc, "GetItemConfig")
        local id = (type(config) == "userdata" or type(config) == "table") and config.ID or "?"
        local name = (type(config) == "userdata" or type(config) == "table") and config.Name or "?"
        local sprite = try(desc, "GetSprite")

        log("  worn[" .. count .. "] itemID=" .. tostring(id) .. " name='" .. tostring(name) .. "'"
            .. " anm2='" .. tostring((type(config) == "userdata" or type(config) == "table") and config.Costume and config.Costume.Anm2Path or "?") .. "'")

        if id == AMMONIAC_ITEM_ID or tostring(name):lower():find("ammoniac") then
            logSpriteLayers(sprite, "      ")
        end
    end
    log("  worn costume count = " .. count)
end

-- Reports what the entity config exposes about the costume folder for a character, which decides whether the orange skin rule can drop the hand written character list
local function logCostumeFolder(player)
    if not EntityConfig or not EntityConfig.GetPlayer then
        log("  EntityConfig.GetPlayer unavailable")
        return
    end

    local config = EntityConfig.GetPlayer(player:GetPlayerType())
    if not config then
        log("  EntityConfig.GetPlayer returned nil")
        return
    end

    local members = {}
    local meta = getmetatable(config)
    for key in pairs(meta and meta.__index or config) do
        members[#members + 1] = tostring(key)
    end
    table.sort(members)

    log("  EntityConfigPlayer -> " .. table.concat(members, ", "))
    log("  GetCostumeSuffix=" .. tostring(try(config, "GetCostumeSuffix"))
        .. " GetSkinPath=" .. tostring(try(config, "GetSkinPath"))
        .. " GetName=" .. tostring(try(config, "GetName")))
end

-- Dumps everything that decides whether the Ammoniac costume is drawn for one player
local function probePlayer(player, index)
    local pData = player:GetData()

    log("--- player " .. index
        .. " type=" .. tostring(player:GetPlayerType())
        .. " name='" .. tostring(player:GetName()) .. "'")
    log("  hasAmmoniac=" .. tostring(player:HasCollectible(AMMONIAC_ITEM_ID))
        .. " hasBrimstone=" .. tostring(player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE))
        .. " AmnestoneActive=" .. tostring(pData.POR_AmnestoneCostumeActive)
        .. " OrangeSkin=" .. tostring(pData.POR_OrangeSkin))

    logCostumeFolder(player)
    logItemCostume(AMMONIAC_ITEM_ID, "  ammoniac config")

    if POR.OrangeVariantPath then
        local item = Isaac.GetItemConfig():GetCollectible(AMMONIAC_ITEM_ID)
        local anm2 = item and item.Costume and item.Costume.Anm2Path
        log("  orange redirect would be '" .. tostring(anm2 and POR.OrangeVariantPath(anm2)) .. "'")
    end

    logWornCostumes(player)
end

-- Runs the probe for every player currently in the run
function PROBE.Run()
    log("===== begin =====")
    log("AMMONIAC_ITEM_ID = " .. tostring(AMMONIAC_ITEM_ID))

    for i = 0, Game():GetNumPlayers() - 1 do
        probePlayer(Isaac.GetPlayer(i), i)
    end

    log("===== end =====")
end

-- Runs the probe when "porcostume" is typed into the debug console
function PROBE.OnCommand(_, command)
    if command ~= "porcostume" then return end

    PROBE.Run()
    return "POR costume probe written to log.txt"
end

POR:AddCallback(ModCallbacks.MC_EXECUTE_CMD, PROBE.OnCommand)

return PROBE
