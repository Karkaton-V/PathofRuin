---- Path of Ruin ---
-- By Team Ruin

-- Setup
if not REPENTANCE then end
local POR = RegisterMod("Path of Ruin", 1)
local game = Game()


-- Named Variables

--  -- Declaring Characters
local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

local NEHEMIAH_BEARD_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiah_beard.anm2")


--  -- Declaring Items
local GOLDENAPPLE_ITEM_ID = Isaac.GetItemIdByName("Golden Apple")
local HOLYSMOKES_ITEM_ID = Isaac.GetItemIdByName("Holy Smokes!")
local NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")
local BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra")

--  -- Stuff Needed Around
local GOLDEN_DAMAGE = 1
local HS_POISON_CHANCE = 0.4            -- Incrimental damage in Isaac happens at 3 ticks, and then concatonates every 20 ticks, ex: 3 23, 43, 63,...
local HS_POISON_LENGTH = 3
local ONE_INTERVAL_OF_POISON = 20       -- This variable and the one before are here to vizualize the previous comment

-------------------------------------------------------------------------------------------------------------------------------
-- Functions

--  -- Characters

--- @param player EntityPlayer       -- establishes that player referencses an EntityPlayer
function POR:NehemiahInit(player)
    if player:GetPlayerType() ~= NEHEMIAH_TYPE then
        return -- If not Nehemiah, exits
    end
    player:AddNullCostume(NEHEMIAH_BEARD_COSTUME)
    -- "KeepinPools?" is bugged, so if set to false, game will always crash when trying to continue a run
    player:SetPocketActiveItem(NEHEMIAHSHAMMER_ITEM_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(NEHEMIAHSHAMMER_ITEM_ID)

end


function POR:TaintedNehemiahInit(player)
   if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE then
      return -- If not Tainted Nehemiah, exits
   end
    player:SetPocketActiveItem(BOOKOFEZRA_ITEM_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(BOOKOFEZRA_ITEM_ID)

end


--  -- Items
function POR:GoldenAppleCache(player, cacheFlags)
    if cacheFlags & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
        local itemcount = player:GetCollectibleNum(GOLDENAPPLE_ITEM_ID)
        local damagetoAdd = GOLDEN_DAMAGE * itemcount
        player.Damage = player.Damage + damagetoAdd
    end
end


function POR:HolySmokesNewRoom()
    local playerCount = game:GetNumPlayers()

    for playerIndex = 0, playerCount - 1 do
        local player = Isaac.GetPlayer(playerIndex)
        local copyCount = player:GetCollectibleNum(HOLYSMOKES_ITEM_ID)

        if copyCount > 0 then 
            local rng = player:GetCollectibleRNG(HOLYSMOKES_ITEM_ID)
            local entities = Isaac.GetRoomEntities()

            for _, entity in ipairs(entities) do
                if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() then
                    if rng:RandomFloat() < HS_POISON_CHANCE then
                        -- source, duration, damage
                        entity:AddPoison(EntityRef(player), HS_POISON_LENGTH + (ONE_INTERVAL_OF_POISON * copyCount), player.Damage)
                    end
                end
            end
        end
    end
end


function POR:NehemiahHammerUse(item)
    local roomEntities = Isaac.GetRoomEntities()
    -- "_" is a placeholder meaning "unused" 
    for _, entity in ipairs(roomEntities) do
        -- First ignores shopkeepers and fires, then ignores invincible enemies, like stoneys
        if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() then
            entity:Kill()
        end
    end
    -- This can be replicated in a simpler way by returning true
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end

function POR:BookofEzraUse(_, _, player)
    local spawnPos = player.Position
    Isaac.GetItemConfig():GetNullItem(CollectibleType.COLLECTIBLE_LUNA)

    return true
end

function POR:PostRender()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pos = Isaac.WorldToScreen(entity.Position)
        Isaac.RenderText(
            tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType),
            pos.X,
            pos.Y,
            1,1,1,1)
    end
end
POR:AddCallback(ModCallbacks.MC_POST_RENDER, POR.PostRender)

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, POR.GoldenAppleCache)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, POR.HolySmokesNewRoom)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.NehemiahHammerUse, NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.BookofEzraUse, BOOKOFEZRA_ITEM_ID)

-------------------------------------------------------------------------------------------------------------------------------
--Compat


