local game = POR.game

local CHALLENGE = {}
POR.SecretRoomChallenge = CHALLENGE

-- Weighted waves: random count between min and max, each pick weighted by rank; entries are {EntityType, Variant, SubType}
CHALLENGE.WEIGHTED_WAVES = {
    BASEMENT = { min = 1, max = 4, pool = { -- Basement/Cellar/Burning Basement
        {15, 2, 0},   -- I.Blob
        {208, 1, 0},  -- Pale Fatty
        {210, 0, 0},  -- Blubber
        {299, 0, 0},  -- Greed Gaper (id inferred from the Caves/Depths lists -- wasn't given here)
        {248, 0, 0},  -- Psychic Horf
        {16, 2, 0},   -- Mulliboom
        {231, 0, 0},  -- Nerve Ending
        {244, 0, 0},  -- Round Worm
        {220, 0, 0},  -- Squirt
        {249, 0, 0},  -- Full Fly
        {14, 1, 0},   -- Super Pooter
        {61, 0, 0},   -- Sucker
        {80, 0, 0},   -- Moter
        {14, 0, 0},   -- Pooter
        {18, 0, 0},   -- Attack Fly
    }},

    DOWNPOUR = { min = 2, max = 4, pool = { -- Downpour/Dross
        {879, 0, 0},  -- Bloaty
        {817, 1, 0},  -- Mullighoul
        {806, 0, 0},  -- Bubbles
        {244, 1, 0},  -- Tube Worm
        {813, 0, 0},  -- Blurb
        {807, 0, 0},  -- Wraith
        {811, 0, 0},  -- Deep Gaper
        {814, 0, 0},  -- Strider
    }},

    CAVES = { min = 2, max = 5, pool = { -- Caves/Catacombs/Flooded Caves
        {306, 0, 0},  -- Portal
        {303, 0, 0},  -- Blister
        {869, 0, 0},  -- Migraine
        {297, 0, 0},  -- Blue Gaper
        {299, 0, 0},  -- Greed Gaper
        {298, 0, 0},  -- Blue Boil
        {288, 0, 0},  -- Dukie
        {276, 0, 0},  -- Roundy
        {255, 0, 0},  -- Night Crawler
        {258, 0, 0},  -- Fat Bat
        {243, 0, 0},  -- Conjoined Spitty
        {226, 1, 0},  -- Rotty
        {220, 1, 0},  -- Dank Squirt
        {211, 0, 0},  -- Half Sack
        {227, 0, 0},  -- Bony
        {90, 0, 0},   -- Hanger
        {30, 0, 0},   -- Boil
        {30, 1, 0},   -- Gut
        {86, 0, 0},   -- Keeper
        {30, 2, 0},   -- Sack
    }},

    MINES = { min = 3, max = 5, pool = { -- Mines/Ashpit
        {844, 0, 0},  -- Bombgagger
        {830, 0, 0},  -- Big Bony
        {828, 0, 0},  -- Necro
        {25, 4, 0},   -- Bone Fly
        {820, 0, 0},  -- Danny
        {889, 0, 0},  -- Clicket Clack
        {277, 0, 0},  -- Black Bony
        {227, 0, 0},  -- Bony
        {23, 3, 0},   -- Carrion Princess
        {818, 0, 0},  -- Rock Spider
    }},

    DEPTHS = { min = 3, max = 6, pool = { -- Depths/Necropolis/Dank Depths
        {306, 0, 0},  -- Portal
        {869, 0, 0},  -- Migraine
        {303, 0, 0},  -- Blister
        {299, 0, 0},  -- Greed Gaper
        {297, 0, 0},  -- Blue Gaper
        {298, 0, 0},  -- Blue Boil
        {296, 0, 0},  -- Hush Fly
        {280, 0, 0},  -- Black Globin's Body
        {279, 0, 0},  -- Black Globin's Head
        {277, 0, 0},  -- Black Bony
        {252, 0, 0},  -- Nulls
        {226, 1, 0},  -- Rotty
        {227, 0, 0},  -- Bony
        {212, 1, 0},  -- Dank Death's Head
        {90, 0, 0},   -- Hanger
    }},

    MAUSOLEUM = { min = 4, max = 6, pool = { -- Mausoleum/Gehenna
        {24, 3, 0},   -- Cursed Globin
        {212, 2, 0},  -- Cursed Death's Head
        {834, 2, 0},  -- Flagellant
        {841, 1, 0},  -- Quad Revenant
        {306, 1, 0},  -- Lil Portal
        {833, 0, 0},  -- Candler
        {885, 1, 0},  -- Blood Cultist
        {834, 1, 0},  -- Snapper
        {840, 0, 0},  -- Pon
        {246, 1, 0},  -- Rag Man's Ragling
        {834, 0, 0},  -- Whipper
        {227, 0, 0},  -- Bony
        {885, 0, 0},  -- Cultist
    }},

    WOMB = { min = 4, max = 7, pool = { -- Womb/Utero/Scarred Womb
        {857, 0, 0},  -- Cohort
        {835, 0, 0},  -- Peeping Fatty
        {306, 0, 0},  -- Portal
        {303, 0, 0},  -- Blister
        {285, 0, 0},  -- Red Ghost
        {209, 0, 0},  -- Fat Sack
        {210, 0, 0},  -- Blubber
        {211, 0, 0},  -- Half Sack
        {57, 0, 0},   -- MemBrain
        {57, 1, 0},   -- Mama Guts
        {38, 3, 0},   -- Wrinkly Baby
        {60, 0, 0},   -- Eye
        {56, 0, 0},   -- Lump
        {41, 0, 0},   -- Knight
        {226, 1, 0},  -- Rotty
        {227, 0, 0},  -- Bony
    }},

    HUSH = { min = 5, max = 7, pool = { -- Blue Womb
        {257, 1, 0},  -- Blue Conjoined Fatty
        {297, 0, 0},  -- Blue Gaper
        {298, 0, 0},  -- Blue Boil
        {296, 0, 0},  -- Hush Fly
    }},

    CORPSE = { min = 5, max = 7, pool = {
        {10, 3, 0},   -- Rotten Gaper
    }},

    -- "Any boss in the game" is too large a list to hand-enumerate safely; left empty until entries are added
    VOID = { min = 2, max = 2, pool = {} },
}

-- Fixed waves: always spawns exactly this list; entries are {EntityType, Variant, SubType, Count}
CHALLENGE.FIXED_WAVES = {
    CATHEDRAL = {
        {227, 1, 0, 1}, -- Holy Bony
        {60, 2, 0, 2},  -- Holy Eye
        {833, 0, 0, 3}, -- Candler
    },
    SHEOL = {
        {888, 0, 0, 1}, -- Shady
        {306, 0, 0, 2}, -- Portal
    },
}

-- Unseen waves: picks `count` entries not yet fought this run, topped up with seen ones; entries are {EntityType, Variant, SubType}
CHALLENGE.UNSEEN_WAVES = {
    CHEST = { count = 2, pool = {
        {51, 1, 0}, -- Super Envy
        {49, 1, 0}, -- Super Gluttony
        {50, 1, 0}, -- Super Greed
        {47, 1, 0}, -- Super Lust
        {52, 1, 0}, -- Super Pride
        {46, 1, 0}, -- Super Sloth
        {48, 1, 0}, -- Super Wrath
    }},
    DARKROOM = { count = 2, pool = {
        {63, 0, 0}, -- Famine
        {64, 0, 0}, -- Pestilence
        {65, 0, 0}, -- War
        {65, 1, 0}, -- Conquest
        {66, 0, 0}, -- Death
        {82, 0, 0}, -- Headless Horseman
    }},
}

-- Tracks every boss-flagged enemy type seen so far this run, for the UNSEEN_WAVES pools above
local seenBosses = {}

local function bossKey(entType, variant, subType)
    return entType .. "_" .. variant .. "_" .. subType
end

function CHALLENGE.OnNpcInit(_, npc)
    if npc:IsBoss() then
        seenBosses[bossKey(npc.Type, npc.Variant, npc.SubType)] = true
    end
end

-- Resets the seen-boss set for a fresh run (known limitation: a continued run restarts empty rather than restoring pre-save state)
function CHALLENGE.OnGameStarted(_, isContinued)
    if not isContinued then
        seenBosses = {}
    end
end

local roomStates = {} -- keyed by ListIndex -> { wasOpen = {slot -> bool}, enemies = {ptrHash -> true}, cleared }

local function isSecretRoomType(roomType)
    return roomType == RoomType.ROOM_SECRET or roomType == RoomType.ROOM_SUPERSECRET
end

local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

-- True if any Tainted Nehemiah in the run currently owns Book of Ezra or Book of Nehemiah
local function hasBookOwner()
    return POR:ForEachPlayer(function(player)
        if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE then return end
        if player:HasCollectible(BOOKOFEZRA_ITEM_ID) or player:HasCollectible(BOOKOFNEHEMIAH_ITEM_ID) then
            return true
        end
    end) == true
end

local function roomKey()
    return game:GetLevel():GetCurrentRoomDesc().ListIndex
end

-- Resolves the current floor to a CHALLENGE.*_WAVES key, allowing for alt path floors that share a LevelStage with the normal counterpart
local function currentFloorKey()
    local level = game:GetLevel()
    local stage, stageType = level:GetStage(), level:GetStageType()
    local isAltPath = stageType == StageType.STAGETYPE_REPENTANCE or stageType == StageType.STAGETYPE_REPENTANCE_B

    if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 then
        return isAltPath and "DOWNPOUR" or "BASEMENT"
    elseif stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 then
        return isAltPath and "MINES" or "CAVES"
    elseif stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 then
        return isAltPath and "MAUSOLEUM" or "DEPTHS"
    elseif stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 then
        return isAltPath and "CORPSE" or "WOMB"
    elseif stage == LevelStage.STAGE4_3 then
        return "HUSH"
    elseif stage == LevelStage.STAGE5 then
        return stageType == StageType.STAGETYPE_WOTL and "CATHEDRAL" or "SHEOL"
    elseif stage == LevelStage.STAGE6 then
        return stageType == StageType.STAGETYPE_WOTL and "CHEST" or "DARKROOM"
    elseif stage == LevelStage.STAGE7 then
        return "VOID"
    end
    return nil
end

-- Closes every open door, remembering which ones were open so they can be restored later
local function closeAndRecordDoors()
    local room = game:GetRoom()
    local wasOpen = {}
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            wasOpen[slot] = door:IsOpen()
            if door:IsOpen() then
                door:Close(true)
            end
        end
    end
    return wasOpen
end

-- Reopens only the doors that were open before the challenge started
local function restoreDoors(wasOpen)
    local room = game:GetRoom()
    for slot, open in pairs(wasOpen) do
        if open then
            local door = room:GetDoor(slot)
            if door then
                door:Open()
            end
        end
    end
end

-- Weighted pick: the pick chance for an entry is proportional to the 1-based rank (last entry most likely)
local function weightedPick(pool)
    local totalWeight = #pool * (#pool + 1) / 2
    local roll = math.random() * totalWeight
    local cumulative = 0
    for i, entry in ipairs(pool) do
        cumulative = cumulative + i
        if roll <= cumulative then
            return entry
        end
    end
    return pool[#pool]
end

-- Picks up to `def.count` unique pool entries not yet in seenBosses, topping up with already-seen entries when there are not enough unseen ones
local function pickUnseen(def)
    local unseen, seen = {}, {}
    for _, entry in ipairs(def.pool) do
        if seenBosses[bossKey(entry[1], entry[2], entry[3])] then
            table.insert(seen, entry)
        else
            table.insert(unseen, entry)
        end
    end

    local picks = {}
    local function takeRandom(list, count)
        for _ = 1, math.min(count, #list) do
            table.insert(picks, table.remove(list, math.random(#list)))
        end
    end
    takeRandom(unseen, def.count)
    takeRandom(seen, def.count - #picks)

    return picks
end

local function spawnEntry(entType, variant, subType)
    local pos = game:GetRoom():FindFreePickupSpawnPosition(POR:GetRandomRoomTile(), 40)
    local npc = Isaac.Spawn(entType, variant, subType or 0, pos, Vector.Zero, nil)
    return GetPtrHash(npc)
end

-- Builds and spawns the wave for the current floor, returning the ptr hashes for the spawned entities, or nil when nothing is defined or spawnable for this floor
local function spawnFloorWave(key)
    local weighted = CHALLENGE.WEIGHTED_WAVES[key]
    if weighted and #weighted.pool > 0 then
        local enemies = {}
        for _ = 1, math.random(weighted.min, weighted.max) do
            local entry = weightedPick(weighted.pool)
            enemies[spawnEntry(entry[1], entry[2], entry[3])] = true
        end
        return enemies
    end

    local fixed = CHALLENGE.FIXED_WAVES[key]
    if fixed then
        local enemies = {}
        for _, entry in ipairs(fixed) do
            for _ = 1, entry[4] do
                enemies[spawnEntry(entry[1], entry[2], entry[3])] = true
            end
        end
        return enemies
    end

    local unseen = CHALLENGE.UNSEEN_WAVES[key]
    if unseen then
        local picks = pickUnseen(unseen)
        if #picks == 0 then return nil end
        local enemies = {}
        for _, entry in ipairs(picks) do
            enemies[spawnEntry(entry[1], entry[2], entry[3])] = true
        end
        return enemies
    end

    return nil
end

-- Drops a Cracked Key at the center of the room
local function spawnCrackedKey()
    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 40)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TAROTCARD, Card.CARD_CRACKED_KEY, pos, Vector.Zero, nil)
end

-- Starts the challenge the first time a book owner steps into an eligible secret room
function CHALLENGE.OnNewRoom()
    local room = game:GetRoom()
    if not isSecretRoomType(room:GetType()) then return end
    if not room:IsFirstVisit() then return end
    if not hasBookOwner() then return end

    local key = currentFloorKey()
    if not key then return end

    local enemies = spawnFloorWave(key)
    if not enemies or not next(enemies) then return end

    roomStates[roomKey()] = {
        wasOpen = closeAndRecordDoors(),
        enemies = enemies,
        cleared = false,
    }
end

-- Once every spawned enemy is dead, reopens the doors and drops the reward
function CHALLENGE.OnNpcDeath(_, npc)
    local state = roomStates[roomKey()]
    if not state or state.cleared then return end

    state.enemies[GetPtrHash(npc)] = nil
    if next(state.enemies) then return end -- still enemies left alive

    state.cleared = true
    restoreDoors(state.wasOpen)
    spawnCrackedKey()
end

-- Per-room state is only meaningful within the current floor
function CHALLENGE.OnNewLevel()
    roomStates = {}
end

return CHALLENGE
