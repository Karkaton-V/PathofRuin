local game = POR.game

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)                              -- Nehemiah
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)                  -- T. Nehemiah
local NEHEMIAH_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiah_addon.anm2")         -- Nehemiah's Costume
local NEHEMIAHB_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiahb_addon.anm2")       -- T. Nehemiah's Costume
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
    player:AddTrinket(62, true)     -- 62 is TrinketType: SHINY_ROCK

    local pool = game:GetItemPool()
    pool:RemoveCollectible(NEHEMIAHSHAMMER_ITEM_ID)

end

function POR:TaintedNehemiahInit(player)
    if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE then
        return -- If not Tainted Nehemiah, exits
    end
    local sprite = player:GetSprite()
    local pool = game:GetItemPool()

    sprite:Load("gfx/characters/nehemiahb.anm2", true)
    player:AddNullCostume(NEHEMIAHB_COSTUME)

    player:SetPocketActiveItem(BOOKOFEZRA_ITEM_ID, ActiveSlot.SLOT_POCKET, true)
    pool:RemoveCollectible(BOOKOFEZRA_ITEM_ID)

end

-- Custom implementation of GetAimDirection that doesn't reset between rooms.
-- Also accounts for Marked.
---@param player EntityPlayer
---@return Vector
---@function
function POR:GetAimDirection(player)
	local isMouseEnabled = Options.MouseControl
	local aimVector = Vector.Zero

	if isMouseEnabled and Input.IsMouseBtnPressed(0) and player.ControllerIndex == 0 then -- 0 is left button
		local mousePos = Input.GetMousePosition(true)
		local direction = (mousePos - player.Position):Normalized()
		aimVector = direction
	end

	if not isMouseEnabled and player.ControllerIndex ~= 0 then -- they are using a controller
		local input = player:GetShootingJoystick()
		aimVector = input
	end

	if aimVector:Length() < 1e-3 then
		if player:AreOpposingShootDirectionsPressed() then
			aimVector = player:GetAimDirection()
		else
			aimVector = player:GetShootingJoystick()
		end
	end

	if player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then
		local targetAimVector = POR:TryGetMarkedTargetAimVector(player)
		if targetAimVector then
			aimVector = targetAimVector
		end
	end
	return aimVector
end

---@param player EntityPlayer
---@return Vector
---@function
function POR:GetAttackDirection(player)
	local angle = POR:GetAimDirection(player):GetAngleDegrees()

	if not player:HasCollectible(CollectibleType.COLLECTIBLE_ANALOG_STICK) and not player:HasCollectible(CollectibleType.COLLECTIBLE_MARKED) then
		angle = ((angle + 45) // 90) * 90
	end

	return Vector.FromAngle(angle)
end

---Returns true if player's aim direction vector length is greater than 0
function POR:IsShooting(player)
	if Isaac.GetPlayer():HasCollectible(Isaac.GetItemIdByName("COLLECTIBLE_KIDNEY_STONE")) then
		return true
	end

	return POR:GetAimDirection(player):Length() > 1e-3
end