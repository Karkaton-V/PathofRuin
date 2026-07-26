local game = POR.game

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)                              -- Nehemiah
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)                  -- T. Nehemiah
local NEHEMIAH_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiah_addon.anm2")         -- Nehemiah's Costume
local NEHEMIAHB_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiahb_addon.anm2")       -- T. Nehemiah's Costume
local NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")                      -- Item Id of Nehemiah's Hammer
local BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra")                                -- Item Id of Book of Ezra
local LargeRooms = {}

-- Character Inits
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

-- Custom GetAimDirection that doesn't reset between rooms and also accounts for Marked
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

	if POR:GetAimDirection(player):Length() == nil then return else return POR:GetAimDirection(player):Length() > 1e-3 end
end


---@function
function POR:GetMaxRocksInRoom()
	local shape = game:GetRoom():GetRoomShape()
	local rockCount = Isaac.CountEntities(nil, EntityType.ENTITY_PLAYER, -1, NEHEMIAH_TYPE)

	if POR:Set({ RoomShape.ROOMSHAPE_2x2, RoomShape.ROOMSHAPE_LBL, RoomShape.ROOMSHAPE_LBR, RoomShape.ROOMSHAPE_LTL, RoomShape.ROOMSHAPE_LTR }) ~= nil then
		LargeRooms = POR:Set({ RoomShape.ROOMSHAPE_2x2, RoomShape.ROOMSHAPE_LBL, RoomShape.ROOMSHAPE_LBR, RoomShape.ROOMSHAPE_LTL, RoomShape.ROOMSHAPE_LTR })
	end
	if LargeRooms[shape] then
		return 9 + 3 * (rockCount - 1)
	else
		return 6 + 2 * (rockCount - 1)
	end
end

---Returns true only for Crawlspaces and The Beast's fight room — the only rooms with gravity
---@function
function POR:RoomHasGravity()
	local roomType = game:GetRoom():GetType()
	local isHomeStage = game:GetLevel():GetStage() == LevelStage.STAGE8
	return roomType == RoomType.ROOM_DUNGEON or isHomeStage
end

---@param pos Vector
---@function
function POR:FindFreeRockPosition(pos)
	local room = game:GetRoom()
	local newPos = room:FindFreePickupSpawnPosition(pos)

	for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, POR.ROCKTABLE.PICKUP_EFFECT_VARIANT)) do
		if effect.Position:Distance(newPos) < 20 then
			return room:FindFreePickupSpawnPosition(pos, 40) -- try again
		end
	end

	POR:ForEachPlayer(function(player)
		if player.Position:Distance(newPos) < 20 then
			return room:FindFreePickupSpawnPosition(pos, 40) -- try again
		end
	end)

	return newPos
end

---Finds a random walkable tile somewhere in the current room
---@function
function POR:GetRandomRoomTile()
	local room = game:GetRoom()
	for _ = 1, 20 do
		local gridIndex = math.random(0, room:GetGridSize() - 1)
		if room:GetGridCollision(gridIndex) == GridCollisionClass.COLLISION_NONE then
			local pos = room:GetGridPosition(gridIndex)
			if room:IsPositionInRoom(pos, 0) then
				return pos
			end
		end
	end
	return room:GetCenterPos() -- fallback if no free tile was found after 20 tries
end

--- Spawn a rock, but not more than the allowed maximum
---@param player EntityPlayer
---@param position? Vector @If given, spawns at this position instead of a random room tile
---@param tag? string What extra data should be attached to the rock?
---@function
function POR:DropRocks(player, position, tag)
	local rockCount = Isaac.CountEntities(nil, EntityType.ENTITY_EFFECT, POR.ROCKTABLE.PICKUP_VARIANT)
	local rocksToSpawn = math.min(2, POR:GetMaxRocksInRoom() - rockCount)
	local room = game:GetRoom()

	if rocksToSpawn == 0 then
		local spawnedRocks = 0
		-- FindByType returns entities sorted by FrameCount
		local rocks = Isaac.FindByType(EntityType.ENTITY_EFFECT, POR.ROCKTABLE.PICKUP_VARIANT)
		POR_Incrementor.inverseiforeach(rocks, function(rock)
			if spawnedRocks == 1 then return end

			rock:Remove()
			Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, rock.Position, Vector.Zero, nil)
			spawnedRocks = spawnedRocks + 1
		end)

		SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE)
		rocksToSpawn = 1
	end

	for _ = 1, rocksToSpawn do
		local pos = position or POR:GetRandomRoomTile()
		pos = POR:FindFreeRockPosition(pos)

		local gravityExists = POR:RoomHasGravity()
		local isBeastFight = game:GetLevel():GetStage() == LevelStage.STAGE8 and gravityExists
		if gravityExists and not isBeastFight then
			local bottomPos = room:GetBottomRightPos().Y
			for y = pos.Y, bottomPos, 15 do -- 15 is how much it moves between each check.
				local collision = room:GetGridCollisionAtPos(Vector(pos.X, y))
				if collision ~= GridCollisionClass.COLLISION_NONE then
					pos = Vector(pos.X, y - 15) -- 15 is an offset to make it look like the rock is on the ground and not in the ground
					break
				end
			end
		elseif isBeastFight then
			pos = Vector(pos.X, room:GetTopLeftPos().Y + 5) -- 5 is an arbitrary offset so that it doesn't spawn in the ceiling
		end

		local rockPickup = Isaac.Spawn(EntityType.ENTITY_EFFECT, POR.ROCKTABLE.PICKUP_VARIANT, 0, pos, Vector.Zero,
			player):ToEffect()
		---@cast rockPickup EntityEffect
		rockPickup:GetData().POR_RockFallingBeast = isBeastFight
		rockPickup:GetData().POR_RockTag = tag

		POR.ROCKTABLE:PickupInit(rockPickup)
	end
end