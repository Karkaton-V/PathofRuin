local game = Game()

local NEHEMIAH_COSTUME  = Isaac.GetCostumeIdByPath("gfx/characters/nehemiah_addon.anm2")   -- Nehemiah's Costume
local NEHEMIAHB_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiahb_addon.anm2")  -- T. Nehemiah's Costume

NEHEMIAH_TYPE           = Isaac.GetPlayerTypeByName("Nehemiah", false)                     -- Nehemiah
TAINTED_NEHEMIAH_TYPE   = Isaac.GetPlayerTypeByName("The Condemned", true)                  -- T. Nehemiah

NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")                       -- Item Id of Nehemiah's Hammer
BOOKOFEZRA_ITEM_ID      = Isaac.GetItemIdByName("Book of Ezra")                            -- Item Id of Book of Ezra

--- @param player EntityPlayer
function POR:NehemiahInit(player)
    if player:GetPlayerType() ~= NEHEMIAH_TYPE then
        return -- If not Nehemiah, exits
    end
    player:AddNullCostume(NEHEMIAH_COSTUME)
    -- "KeepinPools?" is bugged, so if set to false, game will always crash when trying to continue a run
    player:SetPocketActiveItem(NEHEMIAHSHAMMER_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
    player:AddTrinket(62, true)     -- 62 is TrinketType: SHINY_ROCK

    local pool = game:GetItemPool()
    pool:RemoveCollectible(NEHEMIAHSHAMMER_ITEM_ID)
end

function POR:TaintedNehemiahInit(player)
    if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE then
        return -- If not Tainted Nehemiah, exits
    end
    local sprite = player:GetSprite()
    local pool   = game:GetItemPool()

    sprite:Load("gfx/characters/nehemiahb.anm2", true)
    player:AddNullCostume(NEHEMIAHB_COSTUME)

    player:SetPocketActiveItem(BOOKOFEZRA_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
    pool:RemoveCollectible(BOOKOFEZRA_ITEM_ID)
end