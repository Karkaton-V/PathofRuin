local game = POR.Game()

local NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")  -- item id of Nehemiah's Hammer
local HAMMEREFFECT = Isaac.GetEntityTypeByName("Nehemiah's Hammer")         -- effect id of the hammer

function POR:NehemiahHammerUse(item)
    local hammer = Isaac.CreateWeapon(11, Isaac.GetPlayer())

    -- This can be replicated in a simpler way by returning true
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end