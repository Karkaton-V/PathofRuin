-- HAAAAAAAAAAAAHAHAHAHAHAHAHAAA     I AM THE WEAPONS MASTER
local game = Game()

NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")  -- item id of Nehemiah's Hammer
HAMMEREFFECT = Isaac.GetEntityTypeByName("Nehemiah's Hammer")         -- effect id of the hammer

function POR:NehemiahHammerUse(item)
    -- Creates a New Weapon
    local curPlayer = Isaac.GetPlayer()
    local hammer = Isaac.CreateWeapon(11, curPlayer)
    curPlayer:SetWeapon(hammer, 0)
    
    
    

    -- This can be replicated in a simpler way by returning true
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end