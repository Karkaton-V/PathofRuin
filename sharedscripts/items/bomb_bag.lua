local game = Game()

BOMBBAG_ITEM_ID = Isaac.GetItemIdByName("Bag O' Bombs") -- item id of Bag O' Bombs (name must match items.xml exactly)

local THROWABLE_BOMB_VARIANT = 41 -- EntityType.ENTITY_PICKUP (5), Variant 41 = "Throwable Bomb" pickup (5.41.0)
local HELD_BOMB_TYPE, HELD_BOMB_VARIANT, HELD_BOMB_SUBTYPE = EntityType.ENTITY_BOMB, 13, 0 -- 4.13.0 = the live bomb Isaac is currently carrying overhead
local FIND_RADIUS = 40 -- a held bomb tracks the player position closely, so anything farther away isn't the one being carried

-- SOUND_BAGOFCRAFTING_SUCK does not exist in the SoundEffect enum and resolved to nil, so SOUND_INHALE is used as the closest real constant
local BAG_OF_CRAFTING_GRAB_SOUND = SoundEffect.SOUND_INHALE

-- Finds the live bomb Isaac is currently holding overhead, if any
local function findHeldBomb(player)
    for _, ent in ipairs(Isaac.FindByType(HELD_BOMB_TYPE, HELD_BOMB_VARIANT, HELD_BOMB_SUBTYPE)) do
        if ent.Position:Distance(player.Position) <= FIND_RADIUS then
            return ent
        end
    end
    return nil
end

-- Spawns a Throwable Bomb pickup under Isaac, nudged off the exact hitbox so it doesn't get instantly re-collected the instant it appears
local function spawnThrowableBomb(player)
    local pos = game:GetRoom():FindFreePickupSpawnPosition(player.Position, 40)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, THROWABLE_BOMB_VARIANT, 0, pos, Vector.Zero, player)
end

-- Pockets the live bomb Isaac is holding if he has one; otherwise spends a bomb to spawn a throwable one under him, or does nothing if he has neither
function POR:BombBagUse(_, _, player)
    local held = findHeldBomb(player)
    if held then
        held:Remove()
        if BAG_OF_CRAFTING_GRAB_SOUND then SFXManager():Play(BAG_OF_CRAFTING_GRAB_SOUND) end
        player:AddBombs(1)
        return true
    end

    if player:GetNumBombs() <= 0 then return false end -- not holding a bomb and none to spend; do nothing

    player:AddBombs(-1)
    spawnThrowableBomb(player)
    return true
end
