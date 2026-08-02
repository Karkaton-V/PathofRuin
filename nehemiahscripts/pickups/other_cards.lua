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

-- Empty effect stubs, one per card; fill these in with real behavior later
function OTHER_CARDS:MisprintedHierophant(player) end
-- Spawns 2-4 chests around Isaac; each is Old Chest by default, 50% chance to be a Chest, and 50% of that to be Haunted
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
-- Spawns 4 pedestal items from the room's pool below Isaac; once 2 are taken, removes the rest and triggers Plan C
function OTHER_CARDS:SuicideKing(player)
    local room = game:GetRoom()
    local pool = game:GetItemPool()
    local seed = room:GetSpawnSeed()
    local poolType = pool:GetPoolForRoom(room:GetType(), seed)

    local pedestals = {}
    for i = 1, 4 do
        local itemId = pool:GetCollectible(poolType, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
        local angle = (i - 1) * 90 + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 50
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 60) + offset, 40)
        local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, itemId, pos, Vector.Zero, player)
        table.insert(pedestals, GetPtrHash(pedestal))
    end

    player:GetData().POR_SuicideKingPedestals = pedestals
    player:GetData().POR_SuicideKingRoomIndex = game:GetLevel():GetCurrentRoomDesc().ListIndex
end

-- Watches the Suicide King's pedestals; once 2 are collected, clears the rest and triggers Plan C
function OTHER_CARDS.CheckSuicideKing(player)
    local pData = player:GetData()
    local pedestals = pData.POR_SuicideKingPedestals
    if not pedestals then return end

    -- If the player left the room, the pedestals are unreachable; cancel tracking instead of misreading them as collected
    if game:GetLevel():GetCurrentRoomDesc().ListIndex ~= pData.POR_SuicideKingRoomIndex then
        pData.POR_SuicideKingPedestals = nil
        return
    end

    local existing = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
    local remaining = {}
    local collectedCount = 0

    for _, hash in ipairs(pedestals) do
        local stillExists = false
        for _, ent in ipairs(existing) do
            if GetPtrHash(ent) == hash then
                stillExists = true
                break
            end
        end
        if stillExists then
            table.insert(remaining, hash)
        else
            collectedCount = collectedCount + 1
        end
    end

    if collectedCount >= 2 then
        for _, hash in ipairs(remaining) do
            for _, ent in ipairs(existing) do
                if GetPtrHash(ent) == hash then
                    ent:Remove()
                end
            end
        end
        pData.POR_SuicideKingPedestals = nil
        player:UseActiveItem(CollectibleType.COLLECTIBLE_PLAN_C, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    else
        pData.POR_SuicideKingPedestals = remaining
    end
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
-- Turns every coin in the room (and a Quarter pedestal, if present) into a Nickel, then spawns a Penny below Isaac
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
-- Picks a random collectible currently held by the player
-- Spawns 3 pedestal items from the room's pool below Isaac; once 1 is taken, removes the other 2
function OTHER_CARDS:GracefulCharity(player)
    local room = game:GetRoom()
    local pool = game:GetItemPool()
    local seed = room:GetSpawnSeed()
    local poolType = pool:GetPoolForRoom(room:GetType(), seed)

    local pedestals = {}
    for i = 1, 3 do
        local itemId = pool:GetCollectible(poolType, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
        local angle = (i - 1) * 120 + math.random() * 20 - 10
        local offset = Vector.FromAngle(angle) * 50
        local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 60) + offset, 40)
        local pedestal = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, itemId, pos, Vector.Zero, player)
        table.insert(pedestals, GetPtrHash(pedestal))
    end

    player:GetData().POR_GracefulCharityPedestals = pedestals
    player:GetData().POR_GracefulCharityRoomIndex = game:GetLevel():GetCurrentRoomDesc().ListIndex
end

-- Watches Graceful Charity's pedestals; once 1 is collected, removes the other 2
function OTHER_CARDS.CheckGracefulCharity(player)
    local pData = player:GetData()
    local pedestals = pData.POR_GracefulCharityPedestals
    if not pedestals then return end

    if game:GetLevel():GetCurrentRoomDesc().ListIndex ~= pData.POR_GracefulCharityRoomIndex then
        pData.POR_GracefulCharityPedestals = nil
        return
    end

    local existing = Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE)
    local remaining = {}
    local collectedCount = 0

    for _, hash in ipairs(pedestals) do
        local stillExists = false
        for _, ent in ipairs(existing) do
            if GetPtrHash(ent) == hash then
                stillExists = true
                break
            end
        end
        if stillExists then
            table.insert(remaining, hash)
        else
            collectedCount = collectedCount + 1
        end
    end

    if collectedCount >= 1 then
        for _, hash in ipairs(remaining) do
            for _, ent in ipairs(existing) do
                if GetPtrHash(ent) == hash then
                    ent:Remove()
                end
            end
        end
        pData.POR_GracefulCharityPedestals = nil
    else
        pData.POR_GracefulCharityPedestals = remaining
    end
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

-- Removes Isaac's 2 most recently picked-up items, then spawns 3 pedestal items from the room's pool
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
    local poolType = pool:GetPoolForRoom(room:GetType(), seed)

    for i = 1, 3 do
        local itemId = pool:GetCollectible(poolType, true, seed + i, CollectibleType.COLLECTIBLE_NULL)
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

--#region Callbacks

POR:AddCallback(ModCallbacks.MC_USE_CARD, function(_, card, player)
    OTHER_CARDS.UseCard(card, player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    OTHER_CARDS.CheckSuicideKing(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    OTHER_CARDS.CheckGracefulCharity(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, collectibleType, charge, firstTime, slot, varData, player)
    OTHER_CARDS.TrackRecentItem(collectibleType, player)
end)

--#endregion

return OTHER_CARDS