local NEHEMIAH = Isaac.GetPlayerTypeByName("Nehemiah", false)

POR.ROCKTABLE = {}

-- ROCKTABLE pickup is actually an effect because of all pickup rerolling items (d20 or ace cards)
POR.ROCKTABLE.PICKUP_EFFECT_VARIANT = Isaac.GetEntityVariantByName("Nehemiah ReRoll Rock")
POR.ROCK_VARIANT = POR.ROCKTABLE.PICKUP_EFFECT_VARIANT

-- used for the sprite of the rock that nehemiah is holding up
POR.ROCKTABLE.HOLDING_ROCKTABLE_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Holding Rock")
POR.ROCKTABLE.HOLDING_ROCKTABLE_OFFSET = Vector(0, -20)

POR.ROCKTABLE.TEAR_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Traveling Rock")
POR.ROCK_TEAR_VARIANT = POR.ROCKTABLE.TEAR_VARIANT

-- For Gravity Sections (aka the beast)
local ROCK_FALL_SPEED_BEAST = 8

-- variants for the rock sprites based on which floor nehemiah is on
POR.ROCKTABLE.SPRITE_VARIANTS = {
	Basement = 1,
	Cellar = 2,
	BurningBasement = 3,
	Downpour = 4,
	Dross = 5,
	Caves = 6,
	Catacombs = 7,
	FloodedCaves = 8,
	Mines = 9,
	Ashpit = 10,
	Depths = 11,
	Necropolis = 12,
	DankDepths = 13,
	Mausoleum = 14,
	Gehenna = 15,
	Womb = 16,
	Utero = 17,
	ScarredWomb = 18,
	BlueWomb = 19,
	Corpse = 20,
	Sheol = 21,
	Cathedral = 22,
	Chest = 23,
	DarkRoom = 24,
	Home = 25,
	HomeB = 26,
}

-- No official enums for this, sadly
-- https://wofsauge.github.io/IsaacDocs/rep/Room.html?h=stage#getroomconfigstage
POR.ROCKTABLE.STAGE_TO_VARIANT = {
	[1] = POR.ROCKTABLE.SPRITE_VARIANTS.Basement,
	[2] = POR.ROCKTABLE.SPRITE_VARIANTS.Cellar,
	[3] = POR.ROCKTABLE.SPRITE_VARIANTS.BurningBasement,
	[27] = POR.ROCKTABLE.SPRITE_VARIANTS.Downpour,
	[28] = POR.ROCKTABLE.SPRITE_VARIANTS.Dross,

	[4] = POR.ROCKTABLE.SPRITE_VARIANTS.Caves,
	[5] = POR.ROCKTABLE.SPRITE_VARIANTS.Catacombs,
	[6] = POR.ROCKTABLE.SPRITE_VARIANTS.FloodedCaves,
	[29] = POR.ROCKTABLE.SPRITE_VARIANTS.Mines,
	[30] = POR.ROCKTABLE.SPRITE_VARIANTS.Ashpit,

	[7] = POR.ROCKTABLE.SPRITE_VARIANTS.Depths,
	[8] = POR.ROCKTABLE.SPRITE_VARIANTS.Necropolis,
	[9] = POR.ROCKTABLE.SPRITE_VARIANTS.DankDepths,
	[31] = POR.ROCKTABLE.SPRITE_VARIANTS.Mausoleum,
	[32] = POR.ROCKTABLE.SPRITE_VARIANTS.Gehenna,

	[10] = POR.ROCKTABLE.SPRITE_VARIANTS.Womb,
	[11] = POR.ROCKTABLE.SPRITE_VARIANTS.Utero,
	[12] = POR.ROCKTABLE.SPRITE_VARIANTS.ScarredWomb,
	[33] = POR.ROCKTABLE.SPRITE_VARIANTS.Corpse,

	[13] = POR.ROCKTABLE.SPRITE_VARIANTS.BlueWomb,

	[14] = POR.ROCKTABLE.SPRITE_VARIANTS.Sheol,
	[15] = POR.ROCKTABLE.SPRITE_VARIANTS.Cathedral,

	[16] = POR.ROCKTABLE.SPRITE_VARIANTS.DarkRoom,
	[17] = POR.ROCKTABLE.SPRITE_VARIANTS.Chest,

	-- Shop and Ultra Greed destroy the API lol

	[35] = POR.ROCKTABLE.SPRITE_VARIANTS.Home,
}

POR.ROCKTABLE.ROOMTYPE_TO_VARIANT = {
	[RoomType.ROOM_DEVIL] = POR.ROCKTABLE.SPRITE_VARIANTS.Sheol,
	[RoomType.ROOM_ANGEL] = POR.ROCKTABLE.SPRITE_VARIANTS.Cathedral,
	[RoomType.ROOM_CHEST] = POR.ROCKTABLE.SPRITE_VARIANTS.Chest,
	[RoomType.ROOM_BLUE] = POR.ROCKTABLE.SPRITE_VARIANTS.BlueWomb,
	[RoomType.ROOM_ISAACS] = POR.ROCKTABLE.SPRITE_VARIANTS.Home,
	[RoomType.ROOM_BARREN] = POR.ROCKTABLE.SPRITE_VARIANTS.Home,
}

---@class RockSpriteModifier
---@field Anm2 string?
---@field ThrownAnm2 string?
---@field Spritesheet string
---@field Priority number

POR.ROCKTABLE.ForbiddenTearFlags =
	TearFlags.TEAR_ABSORB |
	TearFlags.TEAR_SPLIT |
	TearFlags.TEAR_SHIELDED |
	TearFlags.TEAR_STICKY |
	TearFlags.TEAR_BELIAL |
	TearFlags.TEAR_BURSTSPLIT |
	TearFlags.TEAR_ORBIT_ADVANCED

local function cloneSprite(sprite, toClone)
	sprite:Load(toClone:GetFilename(), true)
	sprite.Color = toClone.Color
	sprite.FlipX = toClone.FlipX
	sprite.FlipY = toClone.FlipY
	sprite.Offset = toClone.Offset
	sprite.PlaybackSpeed = toClone.PlaybackSpeed
	sprite.Rotation = toClone.PlaybackSpeed
	sprite.Scale = toClone.Scale
	sprite:SetFrame(toClone:GetAnimation(), toClone:GetFrame())
	sprite:SetOverlayFrame(toClone:GetOverlayAnimation(), toClone:GetOverlayFrame())
end

---@param player EntityPlayer
---@param direction Vector
---@param damage? number
---@param tags? table @An array of "tags" to add to the rock. Tags are just extra data that get stored in the rock's data table under `POR_RockTags`.
---@function
function POR.ROCKTABLE:FireRock(player, direction, damage, tags)
	direction = direction:Normalized()
	damage = damage or (player.Damage * 2)

	local vel = direction * player.ShotSpeed * 10 * 2.5
	vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * 1.1

	local rock = player:FireTear(player.Position, vel, true, false, true, player)
	rock.Position = player.Position -- override the position set by FireTear
	rock:ChangeVariant(POR.ROCK_TEAR_VARIANT)
	rock.CollisionDamage = damage
	rock:ClearTearFlags(POR.ROCKTABLE.ForbiddenTearFlags)

	POR.ROCKTABLE:rockInit(rock, player, player:GetData().POR_HoldingRockSprite, player:GetData()
		.POR_HoldingRockAnm2, player:GetData().POR_HoldingRockDontUpdate)
	rock:GetData().POR_RockTags = {}

	if tags then
		for tag, value in pairs(tags) do
			rock:GetData().POR_RockTags[tag] = value
		end
	end

	POR:FireExtraCallback(POR.ExtraCallbacks.NEHEMIAH_POST_THROW_ROCK, player, rock)

	SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE)
	-- insert custom sound here

	return rock
end

-- Returns the stage's id.
-- See ROCK.STAGE_TO_VARIANT for information about what the numbers mean.
-- No enum moment.
---@function
function POR.ROCKTABLE:GetStageId()
	local level = POR.Level()
	local stage = level:GetAbsoluteStage()
	local isAlt = level:IsAltStage()
	local stageType = level:GetStageType()

	if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 or stage == LevelStage.STAGE1_GREED then
		if stageType == StageType.STAGETYPE_REPENTANCE then
			return 27
		elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
			return 28
		else
			if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
				return 3
			elseif stageType == StageType.STAGETYPE_ORIGINAL then
				return 1
			else
				return 2
			end
		end
	end

	if stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 or stage == LevelStage.STAGE2_GREED then
		if stageType == StageType.STAGETYPE_REPENTANCE then
			return 29
		elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
			return 30
		else
			if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
				return 6
			elseif stageType == StageType.STAGETYPE_ORIGINAL then
				return 4
			else
				return 5
			end
		end
	end

	if stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 or stage == LevelStage.STAGE3_GREED then
		if stageType == StageType.STAGETYPE_REPENTANCE then
			return 31
		elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
			return 32
		else
			if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
				return 9
			elseif stageType == StageType.STAGETYPE_ORIGINAL then
				return 7
			else
				return 8
			end
		end
	end

	if stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 or stage == LevelStage.STAGE4_GREED then
		if stageType == StageType.STAGETYPE_REPENTANCE then
			return 33
		else
			if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
				return 12
			elseif stageType == StageType.STAGETYPE_ORIGINAL then
				return 10
			else
				return 11
			end
		end
	end

	if stage == LevelStage.STAGE4_3 then
		return 13
	end

	if stage == LevelStage.STAGE5_GREED then
		return 15
	end

	if stage == LevelStage.STAGE5 then
		if isAlt then
			return 15
		else
			return 14
		end
	end

	if stage == LevelStage.STAGE6 then
		if isAlt then
			return 17
		else
			return 16
		end
	end

	if stage == LevelStage.STAGE6_GREED then
		return 24
	end

	if stage == LevelStage.STAGE7 then
		return 26
	end

	if stage == LevelStage.STAGE7_GREED then
		return 25
	end

	if stage == LevelStage.STAGE8 then
		return 35
	end
end

-- for checkign if the floor is homeb
function POR.ROCKTABLE:BedSleptCheck(bed, collider)
	-- mom's bed, the enum is wrong
	if bed.SubType == 10 and collider:ToPlayer() then
		local save = POR.SaveCompiler.RunSave()
		save.MomBedSlept = true
	end
end

---@param entity EntityEffect | EntityTear
---@param sender EntityPlayer
---@param forceSheet string?
---@function
function POR.ROCKTABLE:RockInit(entity, sender, forceSheet, forceAnm2, dontUpdate)
	local variant = POR.GENERIC_RNG:RandomInt(3) + 1
	local save = POR:RunSave()
	local sprite = entity:GetSprite()
	local stage = POR.ROCKTABLE:GetStageId()
	local roomType = POR.Room():GetType()

	-- do a check to see if it's HomeB since there's no stage variant for it
	local homeB = (save.MomBedSlept and stage == 35) and POR.ROCKTABLE.SPRITE_VARIANTS.HomeB
	local stageVariant = POR.ROCKTABLE.ROOMTYPE_TO_VARIANT[roomType] or homeB or POR.ROCKTABLE.STAGE_TO_VARIANT[stage]
		or POR.ROCKTABLE.SPRITE_VARIANTS.Basement
	local tag = entity:GetData().POR_RockTag
	local replaceSheet = POR:FireExtraCallback(POR.ExtraCallbacks.NEHEMIAH_PRE_ROCK_SPRITE_INIT, sender, variant, tag, entity)

	if sender:GetData().POR_EnemyRockSprite then
		cloneSprite(sprite, sender:GetData().POR_EnemyRockSprite)
	end

	local newSheet
	if forceSheet then
		newSheet = forceSheet
	elseif replaceSheet then
		if replaceSheet.Anm2 then
			sprite:Reset()
			sprite:Load(replaceSheet.Anm2, false)
		end

		if replaceSheet.Sprite then
			cloneSprite(sprite, replaceSheet.Sprite)
			entity:GetData().POR_ThrownRockSprite = sprite
		end

		if replaceSheet.ThrownAnm2 then
			entity:GetData().POR_RockAnm2 = replaceSheet.ThrownAnm2
		end

		newSheet = replaceSheet.Spritesheet
		entity:GetData().POR_HoldingRockDontUpdate = replaceSheet.DontUpdate
		entity:GetData().POR_HoldingRockIsSpecial = true -- this means it shouldnt use the stage to determine the frame of the animation
	else
		newSheet = ("gfx/misc/rock_variation_" .. tostring(variant) .. ".png")
	end

	if not entity:GetData().POR_HoldingRockDontUpdate and not dontUpdate then
		if forceAnm2 then
			sprite:Load(forceAnm2, false)
		end

		sprite:ReplaceSpritesheet(0, newSheet)
		sprite:LoadGraphics()
	end

	entity:GetData().POR_RockSheet = newSheet

	if not entity:GetData().POR_HoldingRockDontUpdate and not dontUpdate then
		if entity.Type == EntityType.ENTITY_EFFECT then
			-- play appear anim
			sprite:Play("Appear" .. tostring(stageVariant), true)
		else -- play idle
			sprite:Play("Idle" .. tostring(stageVariant), true)
		end
	end

	if entity:GetData().POR_RockFallingBeast then
		sprite:Stop() -- stop the falling animation for beast
	end

	return newSheet
end

-- The game only allows collision with pickups in their appear animation
-- There are multiple animations on the rock pickup because of the different sprite variants
-- After one of them is done playing, we switch to a still appear animation that has a frame for each variant
---@param rock EntityEffect
---@function
---@scope Epiphany
function POR:ManageRockPickupSprite(rock)
	local sprite = rock:GetSprite()
	local stage = POR.ROCKTABLE:GetStageId()
	local save = POR:RunSave()
	local roomType = POR.Room():GetType()
	-- do a check to see if it's HomeB since there's no stage variant for it
	local homeB = (save.MomBedSlept and stage == 35) and POR.ROCKTABLE.SPRITE_VARIANTS.HomeB
	local stageVariant = POR.ROCKTABLE.ROOMTYPE_TO_VARIANT[roomType] or homeB or POR.ROCKTABLE.STAGE_TO_VARIANT[stage]
		or POR.ROCKTABLE.SPRITE_VARIANTS.Basement

	if not rock:GetData().POR_HoldingRockDontUpdate then
		if not sprite:IsPlaying("Appear" .. tostring(stageVariant)) or rock:GetData().POR_RockFallingBeast then
			sprite:SetFrame("Appear", stageVariant - 1)
		end
	end
end

---@param rock EntityEffect
---@function
---@scope Epiphany
function POR:RockBeastFalling(rock)
	if rock:GetData().POR_RockFallingBeast then
		rock.Position = rock.Position + Vector(0, ROCK_FALL_SPEED_BEAST)

		if rock.Position.Y > POR.Room():GetBottomRightPos().Y then
			rock:Remove() -- remove if out of bounds
		end
	end
end

---Makes the player stop holding a rock if they are holding one
---@param player EntityPlayer
---@param playHideAnim boolean?
---@function
function POR.ROCKTABLE:StopHolding(player, playHideAnim)
	local pData = player:GetData()
	if pData.POR_HoldingRock then
		if playHideAnim then
			player:AnimatePickup(Sprite(), false, "HideItem")
		else
			player:StopExtraAnimation()
		end
		pData.POR_HoldingRock = false
		pData.POR_RockFrameCount = 0
	end
end

---@param player EntityPlayer
---@function
function POR.ROCKTABLE:PostPlayerUpdate(player)
	local pData = player:GetData()
	if not pData.POR_RockFrameCount then
		pData.POR_RockFrameCount = 0
	end
	if pData.POR_HoldingRock then
		if POR:IsShooting(NEHEMIAH) then
			if pData.POR_RockFrameCount > 9 then
				local aimDirection = POR:GetAttackDirection(player)
				POR.ROCKTABLE:FireRock(player, aimDirection)

				player:AnimatePickup(Sprite(), false, "HideItem") -- play HideItem with invisible sprite
				pData.POR_HoldingRock = false
				pData.POR_RockFrameCount = 0
			end
		else
			for _, chest in ipairs(Isaac.FindInRadius(player.Position, 10, EntityPartition.PICKUP)) do
				if chest.Variant == PickupVariant.PICKUP_BIGCHEST then
					pData.POR_HoldingRock = false
				end
			end
			if player:IsExtraAnimationFinished() then
				local stage = POR.ROCKTABLE:GetStageId()
				local stageVariant = pData.POR_HoldingRockIsSpecial and 1 or POR.ROCKTABLE.STAGE_TO_VARIANT[stage]
					or POR.ROCKTABLE.SPRITE_VARIANTS.Basement

				if not pData.POR_HoldingRockDontUpdate then
					local RockSprite = Sprite()
					RockSprite:Load("gfx/misc/rock_pickup.anm2", false)
					RockSprite:ReplaceSpritesheet(0, pData.POR_HoldingRockSprite)
					RockSprite:SetFrame("Appear", stageVariant - 1)
					RockSprite:LoadGraphics()
					player:AnimatePickup(RockSprite, false, "LiftItem")
				else
					if pData.POR_EnemyRockSprite then
						local sprite = Sprite()
						cloneSprite(sprite, pData.POR_EnemyRockSprite)
						player:AnimatePickup(sprite, false, "LiftItem")
					end
				end

				pData.POR_RockFrameCount = 1
			end
		end
		pData.POR_RockFrameCount = pData.POR_RockFrameCount + 1
	end
end

---@param pickup EntityEffect
---@param player EntityPlayer
---@function
function POR.ROCKTABLE:PickupEffectCollision(pickup, player)
	local pData = player:GetData()
	if not pData.POR_HoldingRock then
		if player:GetPlayerType() == NEHEMIAH then
			player:AnimatePickup(pickup:GetSprite(), false, "LiftItem")
			pData.POR_HoldingRock = true
			pData.POR_HoldingRockSprite = pickup:GetData().POR_RockSheet
			pData.POR_HoldingRockAnm2 = pickup:GetData().POR_RockAnm2
			pData.POR_HoldingRockIsSpecial = pickup:GetData().POR_HoldingRockIsSpecial
			pData.POR_HoldingRockDontUpdate = pickup:GetData().POR_HoldingRockDontUpdate

			-- BB
			pData.POR_EnemyRockSprite = pickup:GetData().POR_EnemyRockSprite

			pickup:Remove()
			return true -- indicate that we picked up the rock
		else
			return
		end
	end
end

---Runs pickup collision for rocks
---@function
function POR.ROCKTABLE:OnUpdate()
	POR_Incrementor.iforeach(Isaac.FindByType(EntityType.ENTITY_EFFECT, POR.ROCK_VARIANTT), function(ent)
		local rock = ent:ToEffect() ---@cast rock EntityEffect
		if rock == nil then return end
		-- AppearXY is actual appear animation,
		-- Appear is idle animation
		if rock:GetSprite():GetAnimation():match("Appear.+") then
			return
		end

		local collidingPlayers = Isaac.FindInRadius(rock.Position, rock.Size, EntityPartition.PLAYER)
		for _, entPlayer in ipairs(collidingPlayers) do
			local player = entPlayer:ToPlayer() ---@cast player EntityPlayer
			if player.Variant == 0
				and player:IsExtraAnimationFinished()
				and not player:IsCoopGhost()
			then
				if POR.ROCKTABLE:PickupEffectCollision(rock, player) then
					break
				end
			end
		end
	end)
end

---@param rock EntityTear
---@param player EntityPlayer
---@param hitWall boolean
---@function
function POR.ROCKTABLE:OnRockDeath(rock, player, hitWall)
	SFXManager():Play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND)
	for _ = 1, 5 do
		local pos = rock.Position - rock.Velocity * 1.5

		local velAngle
		if hitWall then
			-- angle small rocks away from the direction Rock was going in, since they'll just hit a wall
			velAngle = (pos - rock.Position):GetAngleDegrees() + POR:RandomFloatRange(180) - 90
		else
			velAngle = POR:RandomFloatRange(360)
		end

		local vel = Vector.FromAngle(velAngle) * (POR:RandomFloatRange(10) + 6)
		local newTear = player:FireTear(pos, vel)

		newTear.CollisionDamage = player.Damage * 0.75
		newTear:ChangeVariant(TearVariant.ROCK)
		newTear.FallingSpeed = -8 * (POR:RandomFloatRange(2) - 0.5)
		newTear.FallingAcceleration = 2 + POR:RandomFloatRange(2)
	end

	if hitWall then
		rock:Die() -- https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExZXBtOWNjanRpNDg0eHBlMm5peXltcTY5bGE4dXBtN3preG9hcTNyZiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/e37rJnOap14aUrqtTB/giphy.gif
		rock.Visible = false
	end
end

---@param tear EntityTear
---@function
function POR.ROCKTABLE:RockUpdate(tear)
	local player = POR:TryGetPlayer(tear.SpawnerEntity)
	local collidingNormally = tear:CollidesWithGrid()
		and not tear:HasTearFlags(TearFlags.TEAR_HYDROBOUNCE | TearFlags.TEAR_BOUNCE)

	local collidingWithWall = not tear:HasTearFlags(TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_BOUNCE_WALLSONLY)
		and tear.Position:Distance(POR.Room():GetClampedPosition(tear.Position, tear.Size)) > 1e-6

	if tear:GetData().POR_RockSheet == nil then
		POR.ROCKTABLE:RockInit(tear, player or Isaac.GetPlayer(0))
	end

	if not player then return end

	if tear:IsDead() or tear:CollidesWithGrid() then
		POR.ROCKTABLE:OnRockDeath(tear, player, collidingNormally or collidingWithWall)
		POR:FireExtraCallback(POR.ExtraCallbacks.NEHEMIAH_ROCK_DEAD, player, tear, nil)
	end
end

---@param tear EntityTear
---@param collider Entity
---@function
function POR.ROCKTABLE:RockCollide(tear, collider)
	local player = POR:TryGetPlayer(tear.SpawnerEntity)

	if player then
		-- check if the Rock is dead on next frame
		POR_ScrumMaster.Schedule(1, function(tearRef)
			local futureTear = tearRef.Entity ---@type Entity
			if futureTear and futureTear:IsDead() then
				POR.ROCKTABLE:OnRockDeath(tear, player, false)
				POR:FireExtraCallback(POR.ExtraCallbacks.NEHEMIAH_ROCK_DEAD, player, tear, collider)
			end
		end, { EntityRef(tear) })
	end
end

-- Handle items that make you hold stuff above your head.

function POR:stopHoldingRock(_, _, _, player)
	POR.ROCKTABLE:StopHolding(player)
end

function POR:stopHoldingHideAnim(_, _, _, player)
	POR.ROCKTABLE:StopHolding(player, true)
end

-- handle trapdoors and co-op
function POR.ROCKTABLE:HideRocksOnTrapdoor()
	local enteringTrapdoor = false

	POR:ForEachPlayer(function(player)
		if (player:GetSprite():IsPlaying("Trapdoor") or player:GetSprite():IsPlaying("LightTravel"))
			and player.ControlsEnabled == false
		then -- entering trapdoor
			enteringTrapdoor = true
		end
	end)

	if enteringTrapdoor then
		POR:ForEachPlayer(function(player)
			POR.ROCKTABLE:StopHolding(player, true)
		end)
	end
end
