local game = Game()

DUMBLUCK_TRINKET_ID = Isaac.GetTrinketIdByName("Windflower")

local STANDSTILL_FRAMES = 150
local MOVE_THRESHOLD = 0.15

-- Triggers the real Telekinesis effect once, after standing still long enough; won't re-trigger until Isaac moves and stands still again
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    if not player:HasTrinket(DUMBLUCK_TRINKET_ID) then return end

    local pData = player:GetData()
    local isMoving = player.Velocity:Length() > MOVE_THRESHOLD

    if isMoving then
        pData.POR_DumbLuckStillFrames = 0
        pData.POR_DumbLuckActive = false
        return
    end

    pData.POR_DumbLuckStillFrames = (pData.POR_DumbLuckStillFrames or 0) + 1

    if pData.POR_DumbLuckStillFrames >= STANDSTILL_FRAMES and not pData.POR_DumbLuckActive then
        pData.POR_DumbLuckActive = true
        player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEKINESIS, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    end
end)