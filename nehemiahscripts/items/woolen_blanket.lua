local game = Game()

WOOLENBLANKET_ITEM_ID = Isaac.GetItemIdByName("Woolen Blanket") -- item id of Woolen Blanket
-- Costume is fully automatic: costumes2.xml's <costume id="..." type="passive"> matches items.xml's <passive id="...">

-- Reduces the first hit each floor to exactly half a heart
POR:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, damageFlags, source, countdownFrames)
    local player = entity:ToPlayer()
    if not player then return end
    if not player:HasCollectible(WOOLENBLANKET_ITEM_ID) then return end

    local pData = player:GetData()
    if not pData.POR_WoolenBlanketApplying and not pData.POR_WoolenBlanketUsedThisFloor and amount > 1 then
        pData.POR_WoolenBlanketUsedThisFloor = true
        pData.POR_WoolenBlanketApplying = true
        player:TakeDamage(1, damageFlags, source, countdownFrames)
        pData.POR_WoolenBlanketApplying = false
        return false
    end
end, EntityType.ENTITY_PLAYER)

-- Doubles i-frames from any hit, refreshing the flicker at the midpoint
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if not player:HasCollectible(WOOLENBLANKET_ITEM_ID) then return end

    local pData = player:GetData()
    local cooldown = player:GetDamageCooldown()

    if cooldown > 0 and not pData.POR_WoolenBlanketDoubled then
        pData.POR_WoolenBlanketDoubled = true
        player:SetMinDamageCooldown(cooldown * 2)
        POR.scrum_master_schedule.Schedule(cooldown, function()
            if player and player:Exists() then
                player:SetMinDamageCooldown(cooldown) -- replays the flicker for the second half
            end
        end)
    elseif cooldown <= 0 then
        pData.POR_WoolenBlanketDoubled = false
    end
end)

-- +2 luck
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player)
    if player:HasCollectible(WOOLENBLANKET_ITEM_ID) then
        player.Luck = player.Luck + 2
    end
end, CacheFlag.CACHE_LUCK)

-- The first-hit reduction resets every new floor
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    POR:ForEachPlayer(function(player)
        player:GetData().POR_WoolenBlanketUsedThisFloor = false
    end)
end)