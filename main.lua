---- Path of Ruin ---
-- By Team Ruin

-- Setup
if not REPENTOGON then
    error("This Mod Requires REPENTAGON!!")
end
POR = RegisterMod("Path of Ruin", 1)
local game = Game()

-- Includes
-- -- Nehemiah
-- -- -- Characters
local NehemiahCharacter = require("nehemiahscripts.characters.nehemiah")

-- -- -- Compat
local NehemiahCompat = require("nehemiahscripts.compat.eid")

-- -- -- Entities
local MoonlightEntity = require("nehemiahscripts.entities.ezras_moonlight")
local NehemiahRockEntity = require("nehemiahscripts.entities.nehemiahs_rocks")

-- -- -- Items
local BookofEzra = require("nehemiahscripts.items.book_of_ezra")
local NehemiahsHammer = require("nehemiahscripts.items.nehemiahs_hammer")


--  -- Stuff Needed Around

--[[
function mod:PostRender()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pos = Isaac.WorldToScreen(entity.Position)
        Isaac.RenderText(
            tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType),
            pos.X,
            pos.Y,
            1,1,1,1)
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.PostRender)
]]--

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.NehemiahHammerUse, NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.BookofEzraUse, BOOKOFEZRA_ITEM_ID)

-------------------------------------------------------------------------------------------------------------------------------


-- For Reference

--[[
local GOLDEN_DAMAGE = 1
function POR:GoldenAppleCache(player, cacheFlags)
    if cacheFlags & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
        local itemcount = player:GetCollectibleNum(GOLDENAPPLE_ITEM_ID)
        local damagetoAdd = GOLDEN_DAMAGE * itemcount
        player.Damage = player.Damage + damagetoAdd
    end
end


local HS_POISON_CHANCE = 0.4            -- Incrimental damage in Isaac happens at 3 ticks, and then concatonates every 20 ticks, ex: 3 23, 43, 63,...
local HS_POISON_LENGTH = 3
local ONE_INTERVAL_OF_POISON = 20       -- This variable and the one before are here to vizualize the previous comment

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
--]]
