-- HAAAAAAAAAAAAHAHAHAHAHAHAHAAA     I AM THE WEAPONS MASTER
local game = POR.Game()

NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")  -- item id of Nehemiah's Hammer
HAMMEREFFECT = Isaac.GetEntityTypeByName("Nehemiah's Hammer")         -- effect id of the hammer
local curPlayer = Isaac.GetPlayer()

function POR:NehemiahHammerUse(item)
    -- Creates a New Weapon
    local hammer = Isaac.CreateWeapon(11, curPlayer)

    -- New Weapon is Secondary, Unless playing as Nehemiah
    if curPlayer == Isaac.GetPlayerTypeByName("Nehemiah", false)
    then 
        Isaac.GetPlayer().SetWeapon(EntityPlayer, hammer, 1)
    else 
        Isaac.GetPlayer().SetWeapon(EntityPlayer, hammer, 2)
    end
    

    -- This can be replicated in a simpler way by returning true
    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end