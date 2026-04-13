---@diagnostic disable: param-type-mismatch, inject-field
local game = Game()

local FOREACHTABLE = {}

---@param ent Entity
function FOREACHTABLE.doCast(ent)
	if ent.Type == EntityType.ENTITY_PLAYER then
		return ent:ToPlayer()
	elseif ent.Type == EntityType.ENTITY_TEAR then
		return ent:ToTear()
	elseif ent.Type == EntityType.ENTITY_FAMILIAR then
		return ent:ToFamiliar()
	elseif ent.Type == EntityType.ENTITY_BOMB then
		return ent:ToBomb()
	elseif ent.Type == EntityType.ENTITY_PICKUP then
		return ent:ToPickup()
	elseif ent.Type == EntityType.ENTITY_SLOT then
		return ent:ToSlot()
	elseif ent.Type == EntityType.ENTITY_LASER then
		return ent:ToLaser()
	elseif ent.Type == EntityType.ENTITY_KNIFE then
		return ent:ToKnife()
	elseif ent.Type == EntityType.ENTITY_PROJECTILE then
		return ent:ToProjectile()
	elseif ent.Type == EntityType.ENTITY_EFFECT then
		return ent:ToEffect()
	else
		return ent:ToNPC()
	end
end

---@class SearchParams
---@field Inverse boolean?
---@field ShouldCache boolean?

---@class DebugSearchParams
---@field NPCOnly boolean?
---@field EntityOnly boolean?

---@class AllowEnemySearchParams: SearchParams
---@field UseEnemySearchParams boolean?
---@field Dead boolean?
---@field Friendly boolean?
---@field NoCollision boolean?
---@field CantShutDoors boolean?
---@field Invincible boolean?

---@param ent Entity?
---@param searchParams AllowEnemySearchParams
function FOREACHTABLE.isValidEnemyTarget(ent, searchParams)
	return ent
	and ent:ToNPC()
	and ent:IsActiveEnemy(searchParams and searchParams.Dead or false)
	and (ent:IsVulnerableEnemy() or searchParams and searchParams.Invincible)
	and (not ent:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) or searchParams and searchParams.Friendly)
	and (ent.EntityCollisionClass ~= EntityCollisionClass.ENTCOLL_NONE or searchParams and searchParams.NoCollision)
	and (ent:ToNPC().CanShutDoors or ent.Type == EntityType.ENTITY_DUMMY or searchParams and searchParams.CantShutDoors)
end

---Executes given function for every player
---Return anything to end the loop early
---@param func fun(player: EntityPlayer, playerNum?: integer): any?
function POR:ForEachPlayer(func)
	if REPENTOGON then
		for i, player in ipairs(PlayerManager.GetPlayers()) do
			if func(player, i) then
				return true
			end
		end
	else
		for i = 0, game:GetNumPlayers() - 1 do
			if func(Isaac.GetPlayer(i), i) then
				return true
			end
		end
	end
end

function FOREACHTABLE.varSubtypeCheck(ent, variant, subtype)
	local entSubtype = ent:ToPlayer() and ent:ToPlayer():GetPlayerType() or ent.SubType
	return (not variant or ent.Variant == variant) and (not subtype or entSubtype == subtype)
end

function FOREACHTABLE.forEach(ent, i, func, searchParams, variant, subtype)
	if FOREACHTABLE.varSubtypeCheck(ent, variant, subtype) then
		local castEnt = searchParams and searchParams.EntityOnly and ent or FOREACHTABLE.doCast(ent)
		if searchParams and searchParams.NPCOnly and not ent:ToNPC() then
			castEnt = nil
		end
		if castEnt and (not searchParams or not searchParams.UseEnemySearchParams or FOREACHTABLE.isValidEnemyTarget(castEnt, searchParams)) then
			local index = REPENTOGON and castEnt:ToPlayer() and castEnt:GetPlayerIndex() or i
			local result = func(castEnt, index)
			if result ~= nil then
				return result
			end
		end
	end
end

function FOREACHTABLE.inverseiforeach(loopTable, func, searchParams, variant, subtype)
	for i = #loopTable, 1, -1 do
		local ent = loopTable[i]
		local result = FOREACHTABLE.forEach(ent, i, func, searchParams, variant, subtype)
		if result ~= nil then
			return result
		end
	end
end

function FOREACHTABLE.iforeach(loopTable, func, searchParams, variant, subtype)
	for i, ent in ipairs(loopTable) do
		local result = FOREACHTABLE.forEach(ent, i, func, searchParams, variant, subtype)
		if result ~= nil then
			return result
		end
	end
end

---@param func fun(ent: Entity, index: integer): any
---@param entType? EntityType
---@param variant? integer @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams | AllowEnemySearchParams | DebugSearchParams
function FOREACHTABLE.startForEachType(func, entType, variant, subtype, searchParams)
	local loopTable
	if REPENTOGON and entType == EntityType.ENTITY_PLAYER then
		loopTable = PlayerManager.GetPlayers()
	elseif entType then
		loopTable = Isaac.FindByType(entType, variant, subtype, searchParams and searchParams.ShouldCache or false, searchParams and searchParams.Friendly or false)
	else
		loopTable = Isaac.GetRoomEntities()
	end

	if searchParams and searchParams.Inverse then
		return FOREACHTABLE.inverseiforeach(loopTable, func, searchParams)
	else
		return FOREACHTABLE.iforeach(loopTable, func, searchParams)
	end
end

---@param func fun(ent: Entity, index: integer): any
---@param partition? EntityPartition | EntityType
---@param pos Vector | Entity
---@param radius number
---@param variant? integer @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams | AllowEnemySearchParams | DebugSearchParams
---@param noPartition? boolean @default: `false`
function FOREACHTABLE.startForEachPartition(func, partition, pos, radius, variant, subtype, searchParams, noPartition)
	local loopTable
	local isVector = getmetatable(pos).__type == "Vector"
	if not isVector then
		pos = pos.Position
	end
	if not partition then
		loopTable = Isaac.GetRoomEntities()
	elseif not noPartition then
		--Automatically accounts for collision spheres
		---@cast partition EntityPartition
		---@cast pos Vector
		loopTable = Isaac.FindInRadius(pos, radius, partition)
	else
		---@cast partition EntityType
		loopTable = {}
		local posCompare
		if isVector then
			posCompare = 0
		else
			posCompare = pos.Size
		end
		local byType = Isaac.FindByType(partition, variant, subtype, true, searchParams and searchParams.Friendly or false)
		for _, ent in ipairs(byType) do
			if ent.Position:DistanceSquared(pos) <= (ent.Size + posCompare) ^ 2 then
				loopTable[#loopTable + 1] = ent
			end
		end
	end

	if searchParams and searchParams.Inverse then
		return FOREACHTABLE.inverseiforeach(loopTable, func, searchParams, variant, subtype)
	else
		return FOREACHTABLE.iforeach(loopTable, func, searchParams, variant, subtype)
	end
end

---@generic V
---@param func fun(player: EntityPlayer, index: integer): V? --With REPENTOGON enabled, `index` is specifically obtained from `EntityPlayer:GetPlayerIndex()` rather than the table's index
---@param variant? PlayerVariant @default: `-1`
---@param playerType? PlayerType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Player(func, variant, playerType, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_PLAYER, variant, playerType, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(player: EntityPlayer, index: integer): V? --With REPENTOGON enabled, `index` is specifically obtained from `EntityPlayer:GetPlayerIndex()` rather than the table's index
---@param variant? PlayerVariant @default: `-1`
---@param playerType? PlayerType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.PlayerInRadius(pos, radius, func, variant, playerType, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.PLAYER, pos, radius, variant, playerType, searchParams)
end

---@generic V
---@param func fun(tear: EntityTear, index: integer): V?
---@param variant? TearVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Tear(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_TEAR, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(tear: EntityTear, index: integer): V?
---@param variant? TearVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.TearInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.TEAR, pos, radius, variant, subtype, searchParams)
end

---@generic V
---@param func fun(familiar: EntityFamiliar, index: integer): V?
---@param variant? FamiliarVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Familiar(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_FAMILIAR, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(familiar: EntityFamiliar, index: integer): V?
---@param variant? FamiliarVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.FamiliarInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.FAMILIAR, pos, radius, variant, subtype, searchParams)
end

---@generic V
---@param func fun(bomb: EntityBomb, index: integer): V?
---@param variant? BombVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Bomb(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_BOMB, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector | Entity @As Bombs lack an EntityPartition, provide an entity to account for collision spheres intersecting
---@param radius number
---@param func fun(bomb: EntityBomb, index: integer): V?
---@param variant? BombVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.BombInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityType.ENTITY_BOMB, pos, radius, variant, subtype, searchParams, true)
end

---@generic V
---@param func fun(pickup: EntityPickup, index: integer): V?
---@param variant? PickupVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Pickup(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_PICKUP, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(pickup: EntityPickup, index: integer): V?
---@param variant? PickupVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.PickupInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.PICKUP, pos, radius, variant, subtype, searchParams)
end

---@generic V
---@param func fun(slot: EntitySlot, index: integer): V?
---@param variant? SlotVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Slot(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_SLOT, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector | Entity @As Slots lack an EntityPartition, provide an entity to account for collision spheres intersecting
---@param radius number
---@param func fun(slot: EntitySlot, index: integer): V?
---@param variant? SlotVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.SlotInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityType.ENTITY_SLOT, pos, radius, variant, subtype, searchParams, true)
end

---@generic V
---@param func fun(laser: EntityLaser, index: integer): V?
---@param variant? LaserVariant @default: `-1`
---@param subtype? LaserSubType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Laser(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_LASER, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector | Entity @As Lasers lack an EntityPartition, provide an entity to account for collision spheres intersecting
---@param radius number
---@param func fun(laser: EntityLaser, index: integer): V?
---@param variant? LaserVariant @default: `-1`
---@param subtype? LaserSubType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.LaserInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityType.ENTITY_LASER, pos, radius, variant, subtype, searchParams, true)
end

---@generic V
---@param func fun(knife: EntityKnife, index: integer): V?
---@param variant? KnifeVariant @default: `-1`
---@param subtype? KnifeSubType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Knife(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_KNIFE, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector | Entity @As Knifes lack an EntityPartition, provide an entity to account for collision spheres intersecting
---@param radius number
---@param func fun(knife: EntityKnife, index: integer): V?
---@param variant? KnifeVariant @default: `-1`
---@param subtype? KnifeSubType @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.KnifeInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityType.ENTITY_KNIFE, pos, radius, variant, subtype, searchParams, true)
end

---@generic V
---@param func fun(projectile: EntityProjectile, index: integer): V?
---@param variant? ProjectileVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Projectile(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_PROJECTILE, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(projectile: EntityProjectile, index: integer): V?
---@param variant? ProjectileVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.ProjectileInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.BULLET, pos, radius, variant, subtype, searchParams)
end

---@generic V
---@param func fun(npc: EntityNPC, index: integer): V?
---@param entType? EntityType @default: `-1`
---@param variant? integer @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? AllowEnemySearchParams @Extended list of search parameters catered towards enemies. If given a table, will go through the default list of requirements for a valid enemy target. Use the table's parameters to adjust the specifics of the search
---@return V?
function FOREACHTABLE.NPC(func, entType, variant, subtype, searchParams)
	searchParams = searchParams or {}
	searchParams.NPCOnly = true
	return FOREACHTABLE.startForEachType(func, entType, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(npc: EntityNPC, index: integer): V?
---@param variant? integer @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? AllowEnemySearchParams @Extended list of search parameters catered towards enemies. If given a table, will go through the default list of requirements for a valid enemy target. Use the table's parameters to adjust the specifics of the search
---@return V?
function FOREACHTABLE.NPCInRadius(pos, radius, func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachPartition(func, EntityPartition.ENEMY, pos, radius, variant, subtype, searchParams)
end

---@generic V
---@param func fun(effect: EntityEffect, index: integer): V?
---@param variant? EffectVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Effect(func, variant, subtype, searchParams)
	return FOREACHTABLE.startForEachType(func, EntityType.ENTITY_EFFECT, variant, subtype, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(effect: EntityEffect, index: integer): V?
---@param variant? EffectVariant @default: `-1`
---@param subtype? integer @default: `-1`
---@param searchParams? SearchParams
---@param collisionOnly? boolean @By  default, effects don't inherently don't have collision, but REPENTOGON fixes Isaac.FindInRadius's EntityPartition.EFFECT by allowing it to show if it has a set collision type. Set to true to use this, otherwise it'll use the manual FindByType + DistanceSquared method
---@return V?
function FOREACHTABLE.EffectInRadius(pos, radius, func, variant, subtype, searchParams, collisionOnly)
	return FOREACHTABLE.startForEachPartition(func, REPENTOGON and collisionOnly and EntityPartition.EFFECT or EntityType.ENTITY_EFFECT, pos, radius, variant, subtype, searchParams, not REPENTOGON or not collisionOnly)
end

---@generic V
---@param func fun(gridEnt: GridEntity, gridIndex: integer): V?
---@param gridType? GridEntityType
---@param gridVariant? integer
---@return V?
function FOREACHTABLE.Grid(func, gridType, gridVariant)
	local room = game:GetRoom()
	for i = 0, room:GetGridSize() - 1 do
		local grid = room:GetGridEntity(i)
		if grid
			and (not gridType or grid:GetType() == gridType)
			and (not gridVariant or grid:GetVariant() == gridVariant)
		then
			local result = func(grid, i)
			if result ~= nil then
				return result
			end
		end
	end
end

---@generic V
---@param func fun(door: GridEntityDoor, doorSlot: DoorSlot): V?
---@return V?
function FOREACHTABLE.Door(func)
	local room = game:GetRoom()
	for i = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
		local door = room:GetDoor(i)
		if door then
			local result = func(door, i)
			if result ~= nil then
				return result
			end
		end
	end
end

---@generic V
---@param func fun(entity: Entity, index: integer): V?
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.Entity(func, searchParams)
	searchParams = searchParams or {}
	searchParams.EntityOnly = true
	return FOREACHTABLE.startForEachType(func, nil, nil, nil, searchParams)
end

---@generic V
---@param pos Vector
---@param radius number
---@param func fun(entity: Entity, index: integer): V?
---@param searchParams? SearchParams
---@return V?
function FOREACHTABLE.EntityInRadius(pos, radius, func, searchParams)
	searchParams = searchParams or {}
	searchParams.EntityOnly = true
	return FOREACHTABLE.startForEachPartition(func, nil, pos, radius, nil, nil, searchParams)
end

--Will move DOWN the chain from the provided entity. Provide the parent if you want to loop through the whole line of enemies
---@param npc Entity
---@param func fun(npc: Entity)
function FOREACHTABLE.Segment(npc, func)
	local entitiesSearch = {}
	local curHash = GetPtrHash(npc)
	entitiesSearch[curHash] = true
	local currentEnt = npc.Child
	if currentEnt.Parent
		and currentEnt.Parent:ToNPC()
		and currentEnt.Parent.Child
		and GetPtrHash(currentEnt) == GetPtrHash(currentEnt.Parent.Child)
		and not entitiesSearch[curHash]
	then
		entitiesSearch[curHash] = true
		func(npc)
		currentEnt = currentEnt.Child
		curHash = GetPtrHash(currentEnt)
	end
end

return FOREACHTABLE