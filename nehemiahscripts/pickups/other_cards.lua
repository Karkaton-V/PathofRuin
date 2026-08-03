local game = Game()

local OTHER_CARDS = {}
POR.OtherCards = OTHER_CARDS

-- Card ids, looked up by their "hud" attribute in pocketitems.xml
OTHER_CARDS.MISPRINTED_HIEROPHANT_ID = Isaac.GetCardIdByName("MPHierophant")
OTHER_CARDS.MISPRINTED_JUSTICE_ID    = Isaac.GetCardIdByName("MPJustice")
OTHER_CARDS.SUICIDE_KING_ID          = Isaac.GetCardIdByName("SRSuicideKing")
OTHER_CARDS.KING_OF_CLUBS_ID         = Isaac.GetCardIdByName("SRKingofClubs")
OTHER_CARDS.JACK_OF_DIAMONDS_ID      = Isaac.GetCardIdByName("SRJackofDiamonds")
OTHER_CARDS.GRACEFUL_CHARITY_ID      = Isaac.GetCardIdByName("GracefulCharity")
OTHER_CARDS.DISGRACEFUL_CHARITY_ID   = Isaac.GetCardIdByName("DisgracefulCharity")

-- Re-applies each card's HUD icon from ui_cardfronts.anm2, in case the native hud= link desyncs
local function SetCardFront(cardId, animName)
    if not cardId or cardId == 0 then return end
    local cardConfig = Isaac.GetItemConfig():GetCard(cardId)
    if not cardConfig or not cardConfig.ModdedCardFront then return end
    cardConfig.ModdedCardFront:Load("gfx/ui_cardfronts.anm2", true)
    cardConfig.ModdedCardFront:Play(animName, true)
end

SetCardFront(OTHER_CARDS.MISPRINTED_HIEROPHANT_ID, "MPHierophant")
SetCardFront(OTHER_CARDS.MISPRINTED_JUSTICE_ID, "MPJustice")
SetCardFront(OTHER_CARDS.SUICIDE_KING_ID, "SRSuicideKing")
SetCardFront(OTHER_CARDS.KING_OF_CLUBS_ID, "SRKingofClubs")
SetCardFront(OTHER_CARDS.JACK_OF_DIAMONDS_ID, "SRJackofDiamonds")
SetCardFront(OTHER_CARDS.GRACEFUL_CHARITY_ID, "GracefulCharity")
SetCardFront(OTHER_CARDS.DISGRACEFUL_CHARITY_ID, "DisgracefulCharity")

-- Spawns 2 Cement Hearts below Isaac
function OTHER_CARDS:MisprintedHierophant(player)
    local room = game:GetRoom()

    for i = 1, 2 do
        local offset = Vector((i == 1) and -20 or 20, 0)
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 40) + offset, 40)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, POR.CementHeart.SUBTYPE_SINGLE, pos, Vector.Zero, player)
    end
end
-- Spawns 2-4 chests: mostly Old Chests, sometimes Chests, rarely Haunted
function OTHER_CARDS:MisprintedJustice(player)
    local room = game:GetRoom()
    local count = math.random(2, 4)

    for i = 1, count do
        local variant = PickupVariant.PICKUP_OLDCHEST
        if math.random() < 0.5 then
            variant = PickupVariant.PICKUP_CHEST
            if math.random() < 0.5 then
                variant = PickupVariant.PICKUP_HAUNTEDCHEST
            end
        end

        local angle = (i - 1) * (360 / count) + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 40
        local pos = room:FindFreePickupSpawnPosition(player.Position + offset, 40)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, variant, 0, pos, Vector.Zero, player)
    end
end
-- Spawns 4 pedestal items; once 2 are taken, clears the rest and triggers Plan C
function OTHER_CARDS:SuicideKing(player)
    local room = game:GetRoom()
    local pool = game:GetItemPool()
    local seed = room:GetSpawnSeed()

    local pedestals = {}
    local items = {}
    for i = 1, 4 do
        -- See comment above GracefulCharity's pool draw for why POOL_TREASURE is used directly
        local itemId = pool:GetCollectible(ItemPoolType.POOL_TREASURE, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
        local angle = (i - 1) * 90 + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 50
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 60) + offset, 40)
        local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, itemId, pos, Vector.Zero, player)
        table.insert(pedestals, GetPtrHash(pedestal))
        table.insert(items, pedestal.SubType) -- the real, engine-assigned item (itemId may still be rerolled)
    end

    player:GetData().POR_SuicideKingPedestals = pedestals
    player:GetData().POR_SuicideKingItems = items
    player:GetData().POR_SuicideKingCollectedCount = 0
end

-- Clears every pedestal still tracked in `hashes`, best-effort (some may already be gone). Removes it
-- and spawns a poof effect in the same frame, so the puff reads as the moment it disappears.
local function RemoveTrackedPedestals(hashes)
    if not hashes or #hashes == 0 then return end
    local existing = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
    for _, hash in ipairs(hashes) do
        for _, ent in ipairs(existing) do
            if GetPtrHash(ent) == hash then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, ent.Position, Vector.Zero, nil)
                ent:Remove()
            end
        end
    end
end

-- Called from MC_POST_ADD_COLLECTIBLE. Watching for the pedestal entity to disappear turned out to
-- be unreliable (these custom-spawned pedestals don't reliably despawn on pickup), so collection is
-- instead detected the authoritative way: the item actually landing in the player's inventory.
function OTHER_CARDS.OnSuicideKingItemAdded(player, collectibleType)
    local pData = player:GetData()
    local items = pData.POR_SuicideKingItems
    if not items then return end

    for i, itemId in ipairs(items) do
        if itemId == collectibleType then
            table.remove(items, i)
            pData.POR_SuicideKingCollectedCount = (pData.POR_SuicideKingCollectedCount or 0) + 1
            break
        end
    end

    if pData.POR_SuicideKingCollectedCount >= 2 then
        RemoveTrackedPedestals(pData.POR_SuicideKingPedestals)
        pData.POR_SuicideKingPedestals = nil
        pData.POR_SuicideKingItems = nil
        pData.POR_SuicideKingCollectedCount = nil
        player:UseActiveItem(CollectibleType.COLLECTIBLE_PLAN_C, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    end
end

-- Clears Suicide King/Graceful Charity tracking on room or floor change, since their pedestals become unreachable
function OTHER_CARDS.ClearPedestalTracking(player)
    local pData = player:GetData()
    pData.POR_SuicideKingPedestals = nil
    pData.POR_SuicideKingItems = nil
    pData.POR_SuicideKingCollectedCount = nil
    pData.POR_GracefulCharityPedestals = nil
    pData.POR_GracefulCharityItems = nil
end
-- Destroys all pickups in the room; each has a 20% chance to become a live Giga Bomb instead
function OTHER_CARDS:KingOfClubs(player)
    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
        local pos = ent.Position
        ent:Remove()
        if math.random() < 0.2 then
            Isaac.Spawn(4, 17, 0, pos, Vector.Zero, player)
        end
    end
end
-- Turns every coin (and any Quarter pedestal) into a Nickel, then spawns a Penny
function OTHER_CARDS:JackOfDiamonds(player)
    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
        local pickup = ent:ToPickup()
        if pickup then
            if pickup.Variant == PickupVariant.PICKUP_COIN then
                pickup.SubType = CoinSubType.COIN_NICKEL
            elseif pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType == CollectibleType.COLLECTIBLE_QUARTER then
                pickup:Morph(PickupVariant.PICKUP_COIN, CoinSubType.COIN_NICKEL, true, true, true)
            end
        end
    end

    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 40), 40)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, pos, Vector.Zero, player)
end
-- Spawns 3 pedestal items; once 1 is taken, removes the other 2. Pulls from POOL_TREASURE directly
-- rather than pool:GetPoolForRoom(room:GetType(), seed) -- that call only maps special rooms
-- (Treasure/Shop/Devil/etc) to a pool and returns -1 in a normal room, which made GetCollectible
-- always fail and return CollectibleType.COLLECTIBLE_NULL.
function OTHER_CARDS:GracefulCharity(player)
    local room = game:GetRoom()
    local pool = game:GetItemPool()
    local seed = room:GetSpawnSeed()

    local pedestals = {}
    local items = {}
    for i = 1, 3 do
        local itemId = pool:GetCollectible(ItemPoolType.POOL_TREASURE, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
        local angle = (i - 1) * 120 + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 50
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 60) + offset, 40)
        local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, itemId, pos, Vector.Zero, player)
        table.insert(pedestals, GetPtrHash(pedestal))
        table.insert(items, pedestal.SubType)
    end

    player:GetData().POR_GracefulCharityPedestals = pedestals
    player:GetData().POR_GracefulCharityItems = items
end

-- Called from MC_POST_ADD_COLLECTIBLE; once any Graceful Charity item lands in the inventory, removes the rest
function OTHER_CARDS.OnGracefulCharityItemAdded(player, collectibleType)
    local pData = player:GetData()
    local items = pData.POR_GracefulCharityItems
    if not items then return end

    local matched = false
    for _, itemId in ipairs(items) do
        if itemId == collectibleType then
            matched = true
            break
        end
    end
    if not matched then return end

    RemoveTrackedPedestals(pData.POR_GracefulCharityPedestals)
    pData.POR_GracefulCharityPedestals = nil
    pData.POR_GracefulCharityItems = nil
end
-- Records each newly picked up collectible, keeping only the 2 most recent per player
function OTHER_CARDS.TrackRecentItem(collectibleType, player)
    local pData = player:GetData()
    local recent = pData.POR_RecentItems or {}
    table.insert(recent, collectibleType)
    while #recent > 2 do
        table.remove(recent, 1)
    end
    pData.POR_RecentItems = recent
end

-- Removes Isaac's 2 most recent items, then spawns 3 pedestal items
function OTHER_CARDS:DisgracefulCharity(player)
    local pData = player:GetData()
    local recent = pData.POR_RecentItems or {}
    for _, itemId in ipairs(recent) do
        player:RemoveCollectible(itemId)
    end
    pData.POR_RecentItems = {}

    local room = game:GetRoom()
    local pool = game:GetItemPool()
    local seed = room:GetSpawnSeed()

    for i = 1, 3 do
        -- See SuicideKing for why POOL_TREASURE is used directly instead of GetPoolForRoom
        local itemId = pool:GetCollectible(ItemPoolType.POOL_TREASURE, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
        local angle = (i - 1) * 120 + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 50
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 60) + offset, 40)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, itemId, pos, Vector.Zero, player)
    end
end

-- Maps each card id to its handler function
local CARD_HANDLERS = {
    [OTHER_CARDS.MISPRINTED_HIEROPHANT_ID] = OTHER_CARDS.MisprintedHierophant,
    [OTHER_CARDS.MISPRINTED_JUSTICE_ID]    = OTHER_CARDS.MisprintedJustice,
    [OTHER_CARDS.SUICIDE_KING_ID]          = OTHER_CARDS.SuicideKing,
    [OTHER_CARDS.KING_OF_CLUBS_ID]         = OTHER_CARDS.KingOfClubs,
    [OTHER_CARDS.JACK_OF_DIAMONDS_ID]      = OTHER_CARDS.JackOfDiamonds,
    [OTHER_CARDS.GRACEFUL_CHARITY_ID]      = OTHER_CARDS.GracefulCharity,
    [OTHER_CARDS.DISGRACEFUL_CHARITY_ID]   = OTHER_CARDS.DisgracefulCharity,
}

-- Dispatches to the matching card's effect stub on use
function OTHER_CARDS.UseCard(card, player)
    local handler = CARD_HANDLERS[card]
    if handler then
        handler(OTHER_CARDS, player)
    end
end

-- entities2.xml's card entries are disabled (registering out of sync with pocketitems.xml), so the
-- world-pickup sprite is set manually here instead.
local CARD_ANM2 = {}
for _, id in ipairs({ OTHER_CARDS.MISPRINTED_HIEROPHANT_ID, OTHER_CARDS.MISPRINTED_JUSTICE_ID }) do
    CARD_ANM2[id] = "gfx/radiant_cards.anm2"
end
for _, id in ipairs({ OTHER_CARDS.SUICIDE_KING_ID, OTHER_CARDS.KING_OF_CLUBS_ID, OTHER_CARDS.JACK_OF_DIAMONDS_ID }) do
    CARD_ANM2[id] = "gfx/foil_cards.anm2"
end
for _, id in ipairs({ OTHER_CARDS.GRACEFUL_CHARITY_ID, OTHER_CARDS.DISGRACEFUL_CHARITY_ID }) do
    CARD_ANM2[id] = "gfx/yugioh.anm2"
end

-- Loads the sprite, plays the spawn-in animation, and restores collision physics (custom CardType
-- ids are assigned dynamically at runtime, so no entities2.xml entry can ever match them; without
-- one the entity gets zeroed collision -- Size 0 = walk-through -- so it's set here instead).
local function InitCardPickup(pickup, anm2)
    pickup:GetSprite():Load(anm2, true)
    pickup:GetSprite():Play("Appear", true)

    pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
    pickup.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
    pickup:SetSize(12, pickup.SizeMulti, 24)
    pickup.Friction = 1
    pickup.Mass = 3

    pickup:GetData().POR_CardInitialized = true
end

function OTHER_CARDS.FixPickupSprite(_, pickup)
    local anm2 = CARD_ANM2[pickup.SubType]
    if anm2 then
        InitCardPickup(pickup, anm2)
    end
end

-- Falls back to initializing here too (MC_POST_PICKUP_INIT doesn't guarantee SubType is set yet in
-- every spawn path, e.g. dropping a currently-held card), then handles Appear -> looping Idle.
function OTHER_CARDS.OnPickupUpdate(_, pickup)
    local anm2 = CARD_ANM2[pickup.SubType]
    if not anm2 then return end

    if not pickup:GetData().POR_CardInitialized then
        InitCardPickup(pickup, anm2)
        return
    end

    local sprite = pickup:GetSprite()
    if sprite:IsPlaying("Appear") and sprite:IsFinished("Appear") then
        sprite:Play("Idle", true)
    end
end

-- Plays the Collect flourish the moment the player touches the card
function OTHER_CARDS.OnPickupCollide(_, pickup, collider)
    if not CARD_ANM2[pickup.SubType] then return end
    if not collider:ToPlayer() then return end
    if pickup:GetData().POR_CardCollectAnimPlayed then return end

    pickup:GetData().POR_CardCollectAnimPlayed = true
    pickup:GetSprite():Play("Collect", true)
end

--#region Callbacks

POR:AddCallback(ModCallbacks.MC_USE_CARD, function(_, card, player)
    OTHER_CARDS.UseCard(card, player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, OTHER_CARDS.FixPickupSprite, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, OTHER_CARDS.OnPickupUpdate, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, OTHER_CARDS.OnPickupCollide, PickupVariant.PICKUP_TAROTCARD)

POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, collectibleType, charge, firstTime, slot, varData, player)
    OTHER_CARDS.TrackRecentItem(collectibleType, player)
    OTHER_CARDS.OnSuicideKingItemAdded(player, collectibleType)
    OTHER_CARDS.OnGracefulCharityItemAdded(player, collectibleType)
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    POR:ForEachPlayer(OTHER_CARDS.ClearPedestalTracking)
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    POR:ForEachPlayer(OTHER_CARDS.ClearPedestalTracking)
end)

--#endregion

return OTHER_CARDS