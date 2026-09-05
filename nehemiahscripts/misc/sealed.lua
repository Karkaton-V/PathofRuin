-- Sealed: a custom status effect applying native Slow (0.5x speed, purple tint) plus a 0.5x contact-damage multiplier; re-applying refreshes duration without re-halving

local SEALED = {}
POR.Sealed = SEALED

SEALED.KEY = "POR_Sealed"

local SEAL_COLOR = Color(0.6, 0.25, 0.85, 1, 0, 0, 0) -- purple tint, doubles as the AddSlowing color
local SLOW_MULTIPLIER = 0.5
local DAMAGE_MULTIPLIER = 0.5
local FRAMES_PER_SECOND = 30

---@param npc EntityNPC
---@param source Entity @Credited as the source of the native Slow status
---@param durationSeconds number
function SEALED.Apply(npc, source, durationSeconds)
    if not npc or not npc:Exists() then return end

    local durationFrames = math.floor(durationSeconds * FRAMES_PER_SECOND)
    local data = npc:GetData()

    if not data[SEALED.KEY] then
        data[SEALED.KEY] = { OriginalCollisionDamage = npc.CollisionDamage }
        npc.CollisionDamage = npc.CollisionDamage * DAMAGE_MULTIPLIER
    end

    data[SEALED.KEY].ExpireFrame = Game():GetFrameCount() + durationFrames
    npc:AddSlowing(EntityRef(source), durationFrames, SLOW_MULTIPLIER, SEAL_COLOR)
end

-- Restores the halved contact damage once the Sealed duration elapses (native Slow expires unaided)
function SEALED.OnNpcUpdate(_, npc)
    local sealedData = npc:GetData()[SEALED.KEY]
    if not sealedData then return end

    if Game():GetFrameCount() >= sealedData.ExpireFrame then
        npc.CollisionDamage = sealedData.OriginalCollisionDamage
        npc:GetData()[SEALED.KEY] = nil
    end
end

return SEALED
