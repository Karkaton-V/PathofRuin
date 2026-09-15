-- Swaps skin-alt costume sheets for the _orange recolor while the flag is set; trinkets and type="none" costumes have no equivalent API
local ORANGE_SKIN_FOLDER = "gfx/characters/costumes/skins_orange/"

-- Set of base names the folder actually holds, consulted before any swap because a missing sheet blanks the sprite rather than raising an error
local ORANGE_SHEETS = include("sharedscripts.APIs.orange_skin_manifest")

-- Suffixes for the costumes_<name> folders this mod ships; anything unlisted uses the shared folder
local COSTUME_SUFFIXES = {
    [PlayerType.PLAYER_APOLLYON] = "_apollyon",
    [PlayerType.PLAYER_THEFORGOTTEN] = "_forgotten",
    [PlayerType.PLAYER_KEEPER] = "_keeper",
    [PlayerType.PLAYER_BLACKJUDAS] = "_shadow",
}

-- Returns the costume folder suffix for a character, empty meaning the shared folder
function POR.CostumeFolderSuffix(playerType)
    if EntityConfig and EntityConfig.GetPlayer then
        local config = EntityConfig.GetPlayer(playerType)
        if config and config.GetCostumeSuffix then
            local ok, suffix = pcall(config.GetCostumeSuffix, config)
            if ok and suffix then return suffix end
        end
    end

    return COSTUME_SUFFIXES[playerType] or ""
end

-- True when a character takes the costumes from the shared "costumes" folder rather than a dedicated one
local function usesSharedCostumes(playerType)
    return POR.CostumeFolderSuffix(playerType) == ""
end

-- True for a sheet living in a character specific "costumes_<name>" folder, which has no counterpart in skins_orange
local function isAlternateCostumeFolder(path)
    return path:find("/costumes_") ~= nil or path:find("\\costumes_") ~= nil
end

-- SkinColor-style suffixes stripped from a base filename before appending "_orange", so colored and plain names resolve to the same lookup
local COLOR_SUFFIXES = { "_pink", "_white", "_black", "_blue", "_red", "_green", "_grey", "_gray", "_shadow" }

-- Per-item cache of resolved orange paths so the manifest lookup runs once; false means checked with no variant found, and is not retried
local orangePathCache = {}

-- Strips a known color suffix (case-insensitive) off a bare filename (no extension/folder), if present.
local function stripColorSuffix(baseName)
    local lower = baseName:lower()
    for _, suffix in ipairs(COLOR_SUFFIXES) do
        if lower:sub(-#suffix) == suffix then
            return baseName:sub(1, #baseName - #suffix)
        end
    end
    return baseName
end

-- Maps a sheet path to the orange variant, nil when the folder has no such sheet so callers keep the original
function POR.OrangeVariantPath(path)
    if isAlternateCostumeFolder(path) then return nil end

    local fileName = path:match("([^/\\]+)%.[Aa][Nn][Mm]2$") or path:match("([^/\\]+)%.[Pp][Nn][Gg]$")
    if not fileName then return nil end

    local baseName = stripColorSuffix(fileName)
    if not ORANGE_SHEETS[baseName] then return nil end

    return ORANGE_SKIN_FOLDER .. baseName .. "_orange.png"
end

local orangeVariantPath = POR.OrangeVariantPath

-- Resolves and caches the orange-variant path for an item, storing false for items the manifest has no sheet for so the lookup runs once per item
local function resolveOrangePath(item)
    local cached = orangePathCache[item.ID]
    if cached ~= nil then return cached end

    orangePathCache[item.ID] = orangeVariantPath(item.Costume.Anm2Path) or false
    return orangePathCache[item.ID]
end

-- True for the two layers that carry the skin; the rest of a character sprite has no orange art
local function isSkinLayer(layer)
    local name = layer:GetName():lower()
    return name:sub(1, 4) == "body" or name:sub(1, 4) == "head"
end

-- Repaints the skin layers orange, remembering the sheet each one already wore so the swap can be undone exactly
local function applyOrangeLayers(sprite, originals)
    local changed = false

    for _, layer in ipairs(sprite:GetAllLayers()) do
        if isSkinLayer(layer) then
            local current = layer:GetSpritesheetPath()
            local sheet = orangeVariantPath(current)

            if sheet and current ~= sheet then
                local id = layer:GetLayerID()
                originals[id] = originals[id] or current
                sprite:ReplaceSpritesheet(id, sheet)
                changed = true
            end
        end
    end
    return changed
end

-- Puts back the exact sheets recorded at swap time, which the anm2 default cannot supply since a character's skin is applied over it at runtime
local function restoreOrangeLayers(sprite, originals)
    local changed = false

    for id, path in pairs(originals) do
        sprite:ReplaceSpritesheet(id, path)
        changed = true
    end
    return changed
end

-- Repaints the head and body layers on the player, doing nothing at all when there is no recorded swap to undo
local function refreshPlayerSkin(player, orange)
    local sprite = player:GetSprite()
    local pData = player:GetData()
    local changed = false

    if orange then
        local originals = pData.POR_OrangeSkinOriginals or {}
        changed = applyOrangeLayers(sprite, originals)
        pData.POR_OrangeSkinOriginals = originals
    elseif pData.POR_OrangeSkinOriginals then
        changed = restoreOrangeLayers(sprite, pData.POR_OrangeSkinOriginals)
        pData.POR_OrangeSkinOriginals = nil
    end

    if changed then
        sprite:LoadGraphics()
    end
end

-- Redirects each held skin-alt costume to the orange variant, or strips it so the engine restores the original
local function refreshOrangeSkin(player)
    local orange = POR.HasOrangeSkin(player)
    local itemConfig = Isaac.GetItemConfig()

    refreshPlayerSkin(player, orange)

    for id in pairs(player:GetCollectiblesList()) do
        local item = itemConfig:GetCollectible(id)
        if item and item.Costume and item.Costume.Anm2Path ~= "" and item.Costume.HasSkinAlt then
            if orange then
                local orangePath = resolveOrangePath(item)
                if orangePath then
                    player:ReplaceCostumeSprite(item, orangePath, item.ID)
                end
            elseif orangePathCache[id] then
                player:TryRemoveCollectibleCostume(id, false)
            end
        end
    end
end

-- Refreshes only on a real change, so callers may invoke this every frame; excluded characters are forced off
function POR.SetOrangeSkin(player, enabled)
    enabled = enabled or false
    if not usesSharedCostumes(player:GetPlayerType()) then enabled = false end

    local pData = player:GetData()
    if pData.POR_OrangeSkin == enabled then return end

    pData.POR_OrangeSkin = enabled
    refreshOrangeSkin(player)
end

function POR.HasOrangeSkin(player)
    return player:GetData().POR_OrangeSkin == true
end

-- A changed collectible may carry a costume or shift a transformation, so that player is re-swept
function POR.OrangeSkinCollectibleChanged(_, player)
    if not POR.HasOrangeSkin(player) then return end
    refreshOrangeSkin(player)
end

-- Costumes get rebuilt by the engine on room transitions, which would otherwise revert the redirects.
function POR.OrangeSkinNewRoom()
    POR:ForEachPlayer(function(player)
        if POR.HasOrangeSkin(player) then
            refreshOrangeSkin(player)
        end
    end)
end
