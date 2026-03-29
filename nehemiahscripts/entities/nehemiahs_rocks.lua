local game = POR.game

local NEHEMIAH = Isaac.GetPlayerTypeByName("Nehemiah", false)
local ROCKTABLE = {}

-- ROCKTABLE pickup is actually an effect because of all pickup rerolling items (d20 or ace cards)
ROCKTABLE.PICKUP_EFFECT_VARIANT = Isaac.GetEntityVariantByName("Nehemiah ReRoll Rock")
local ROCK_VARIANT = ROCKTABLE.PICKUP_EFFECT_VARIANT

-- used for the sprite of the rock that nehemiah is holding up
ROCKTABLE.HOLDING_ROCKTABLE_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Holding Rock")
ROCKTABLE.HOLDING_ROCKTABLE_OFFSET = Vector(0, -20)

ROCKTABLE.TEAR_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Traveling Rock")
local ROCK_TEAR_VARIANT = ROCKTABLE.TEAR_VARIANT

-- For Gravity Sections (aka the beast)
local ROCK_FALL_SPEED = 8

-- variants for the rock sprites based on which floor nehemiah is on
ROCKTABLE.SPRITE_VARIANTS = {
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
ROCKTABLE.STAGE_TO_VARIANT = {
	[1] = ROCKTABLE.SPRITE_VARIANTS.Basement,
	[2] = ROCKTABLE.SPRITE_VARIANTS.Cellar,
	[3] = ROCKTABLE.SPRITE_VARIANTS.BurningBasement,
	[27] = ROCKTABLE.SPRITE_VARIANTS.Downpour,
	[28] = ROCKTABLE.SPRITE_VARIANTS.Dross,

	[4] = ROCKTABLE.SPRITE_VARIANTS.Caves,
	[5] = ROCKTABLE.SPRITE_VARIANTS.Catacombs,
	[6] = ROCKTABLE.SPRITE_VARIANTS.FloodedCaves,
	[29] = ROCKTABLE.SPRITE_VARIANTS.Mines,
	[30] = ROCKTABLE.SPRITE_VARIANTS.Ashpit,

	[7] = ROCKTABLE.SPRITE_VARIANTS.Depths,
	[8] = ROCKTABLE.SPRITE_VARIANTS.Necropolis,
	[9] = ROCKTABLE.SPRITE_VARIANTS.DankDepths,
	[31] = ROCKTABLE.SPRITE_VARIANTS.Mausoleum,
	[32] = ROCKTABLE.SPRITE_VARIANTS.Gehenna,

	[10] = ROCKTABLE.SPRITE_VARIANTS.Womb,
	[11] = ROCKTABLE.SPRITE_VARIANTS.Utero,
	[12] = ROCKTABLE.SPRITE_VARIANTS.ScarredWomb,
	[33] = ROCKTABLE.SPRITE_VARIANTS.Corpse,

	[13] = ROCKTABLE.SPRITE_VARIANTS.BlueWomb,

	[14] = ROCKTABLE.SPRITE_VARIANTS.Sheol,
	[15] = ROCKTABLE.SPRITE_VARIANTS.Cathedral,

	[16] = ROCKTABLE.SPRITE_VARIANTS.DarkRoom,
	[17] = ROCKTABLE.SPRITE_VARIANTS.Chest,

	-- Shop and Ultra Greed destroy the API lol

	[35] = ROCKTABLE.SPRITE_VARIANTS.Home,
}

ROCKTABLE.ROOMTYPE_TO_VARIANT = {
	[RoomType.ROOM_DEVIL] = ROCKTABLE.SPRITE_VARIANTS.Sheol,
	[RoomType.ROOM_ANGEL] = ROCKTABLE.SPRITE_VARIANTS.Cathedral,
	[RoomType.ROOM_CHEST] = ROCKTABLE.SPRITE_VARIANTS.Chest,
	[RoomType.ROOM_BLUE] = ROCKTABLE.SPRITE_VARIANTS.BlueWomb,
	[RoomType.ROOM_ISAACS] = ROCKTABLE.SPRITE_VARIANTS.Home,
	[RoomType.ROOM_BARREN] = ROCKTABLE.SPRITE_VARIANTS.Home,
}

---@class RockSpriteModifier
---@field Anm2 string?
---@field ThrownAnm2 string?
---@field Spritesheet string
---@field Priority number

ROCKTABLE.ForbiddenTearFlags =
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
function ROCKTABLE:FireRock(player, direction, damage, tags)
	direction = direction:Normalized()
	damage = damage or (player.Damage * 2)

	local vel = direction * player.ShotSpeed * 10 * 2.5
	vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * 1.1

	local rock = player:FireTear(player.Position, vel, true, false, true, player)
	rock.Position = player.Position -- override the position set by FireTear
	rock:ChangeVariant(ROCK_TEAR_VARIANT)
	rock.CollisionDamage = damage
	rock:ClearTearFlags(ROCKTABLE.ForbiddenTearFlags)

	ROCKTABLE:rockInit(rock, player, player:GetData().POR_HoldingRockSprite, player:GetData()
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
function ROCKTABLE:GetStageId()
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
function ROCKTABLE:BedSleptCheck(bed, collider)
	-- mom's bed, the enum is wrong
	if bed.SubType == 10 and collider:ToPlayer() then
		local save = POR:RunSave()
		save.MomBedSlept = true
	end
end

POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, ROCKTABLE.BedSleptCheck, PickupVariant.PICKUP_BED)
