local game = POR.Game()

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)                              -- Nehemiah
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)                  -- T. Nehemiah
local NEHEMIAH_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiah_extra.anm2")         -- Nehemiah's Costume
local NEHEMIAHB_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiahb_extra.anm2")        -- T. Nehemiah's Costume
local NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")                      -- Item Id of Nehemiah's Hammer
local BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra")                                -- Item Id of Book of Ezra

--- @param player EntityPlayer       -- establishes that player references an EntityPlayer
function POR:NehemiahInit(player)
    if player:GetPlayerType() ~= NEHEMIAH_TYPE then
        return -- If not Nehemiah, exits
    end
    player:AddNullCostume(NEHEMIAH_COSTUME)
    -- "KeepinPools?" is bugged, so if set to false, game will always crash when trying to continue a run
    player:SetPocketActiveItem(NEHEMIAHSHAMMER_ITEM_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(NEHEMIAHSHAMMER_ITEM_ID)

end
function POR:TaintedNehemiahInit(player)
   if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE then
      return -- If not Tainted Nehemiah, exits
   end
   player:AddNullCostume(NEHEMIAHB_COSTUME)
    player:SetPocketActiveItem(BOOKOFEZRA_ITEM_ID, ActiveSlot.SLOT_POCKET, true)

    local pool = game:GetItemPool()
    pool:RemoveCollectible(BOOKOFEZRA_ITEM_ID)

end