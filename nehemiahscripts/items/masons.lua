local game = POR.game

MASONS_ITEM_ID = Isaac.GetItemIdByName("The Masons") -- item id of The Masons
MASONS_VARIANT = Isaac.GetEntityVariantByName("The Masons") -- familiar variant 3564 in entities2.xml

local FOLLOWER_ANM2 = "gfx/masons1.anm2" -- directional float/shoot sheet layout the first three crews share
local ROAMER_ANM2 = "gfx/masons2.anm2" -- single-facing Idle/Shoot loops, already pointed at mason_spike.png

local SHOOT_DIR_THRESHOLD = 0.1 -- matches the threshold in spike.lua for reading the shooting stick as held
local FRAMES_PER_SECOND = 30

local BRICK_TEAR_SCALE = 0.9 -- smaller than the 1.4x tear on Old Brick
local BRICK_FRAGMENTS = 2 -- half of the four shards on Old Brick

local ROAM_SPEED = 4
local BUFF_RANGE = 160 -- radius the Buff crew looks for a target in, roughly two tiles further than the body
local BUFF_COOLDOWN = 3 * FRAMES_PER_SECOND
local BUFF_SPIKE_SCALE = 0.6
local BUFF_SHOT_SPEED = 9

local roomCleared = false -- guards the clear check so one room clear rerolls once, as in unlockmanager.lua

-- Throws the Old Brick lobbed rock tear at reduced size and half the shard count, built by old_brick.lua so both share one implementation
local function fireBrick(familiar, player, direction)
    local tear = familiar:FireProjectile(direction)
    if tear and POR.MakeOldBrickTear then
        POR.MakeOldBrickTear(tear, player, BRICK_TEAR_SCALE, BRICK_FRAGMENTS)
    end
end

-- Throws a nail tear, the only departure for the crew from a plain familiar shot
local function fireNehemiah(familiar, _, direction)
    local tear = familiar:FireProjectile(direction)
    if tear then tear:ChangeVariant(TearVariant.NAIL) end
end

-- Throws a rock tear carrying the split flag, so the variant and the splitting come from the same shot
local function fireOld(familiar, _, direction)
    local tear = familiar:FireProjectile(direction)
    if not tear then return end

    tear:ChangeVariant(TearVariant.ROCK)
    tear:AddTearFlags(TearFlags.TEAR_SPLIT)
end

-- Throws a shrunken Spike ball that bursts into at most one shard, spawned through spike.lua so it keeps the physics from the item
local function fireBuff(familiar, player, direction)
    if not POR.SpawnSpikeBall then return end
    POR.SpawnSpikeBall(player, familiar.Position, direction * BUFF_SHOT_SPEED, BUFF_SPIKE_SCALE, math.random(0, 1))
end

-- The four crews the familiar rotates through; Rate is the fraction of the Isaac tear rate a follower crew fires at
local FORMS = {
    { Anm2 = FOLLOWER_ANM2, Sheet = "gfx/familiars/mason_brick.png",    Rate = 0.5, Fire = fireBrick },
    { Anm2 = FOLLOWER_ANM2, Sheet = "gfx/familiars/mason_nehemiah.png", Rate = 0.8, Fire = fireNehemiah },
    { Anm2 = FOLLOWER_ANM2, Sheet = "gfx/familiars/mason_old.png",      Rate = 0.3, Fire = fireOld },
    { Anm2 = ROAMER_ANM2,   Roams = true, Cooldown = BUFF_COOLDOWN,                 Fire = fireBuff },
}

-- Crew indices live in the run save keyed by player, so which one is out survives both a room change and a continue
local function formTable()
    local run = POR:RunSave()
    if not run then return nil end

    run.POR_MasonForms = run.POR_MasonForms or {}
    return run.POR_MasonForms
end

-- The crew a player currently has out, falling back to the first when the run save is unavailable
local function formIndex(player)
    local forms = formTable()
    if not forms then return 1 end
    return forms[tostring(player:GetPlayerIndex())] or 1
end

-- Moves a player onto a different crew, deliberately never landing on the one already out so every reroll is visible
local function rerollForm(player)
    local forms = formTable()
    if not forms then return end

    local key = tostring(player:GetPlayerIndex())
    local current = forms[key]
    if current then
        forms[key] = (current + math.random(#FORMS - 1) - 1) % #FORMS + 1
    else
        forms[key] = math.random(#FORMS)
    end
end

-- Rebuilds a familiar as the crew the owner currently has, swapping the anm2 outright since the roaming crew has neither the sheet layout nor the animations of the other three
local function applyForm(familiar, index)
    local form = FORMS[index]
    if not form then return end

    local sprite = familiar:GetSprite()
    sprite:Load(form.Anm2, true)
    if form.Sheet then sprite:ReplaceSpritesheet(0, form.Sheet, true) end
    sprite:Play(form.Roams and "IdleDown" or "FloatDown", true)

    familiar.IsFollower = not form.Roams
    if form.Roams then
        familiar:RemoveFromFollowers()
    else
        familiar:AddToFollowers()
    end

    local data = familiar:GetData()
    data.POR_MasonForm = index
    data.POR_MasonCooldown = 0
end

-- Rounds up a fraction of the tear rate for Isaac into frames between shots, since MaxFireDelay counts the gap and rounding down would let a crew outpace the share
local function fireCooldown(player, rate)
    return math.max(1, math.ceil((player.MaxFireDelay + 1) / rate))
end

-- Plays the float or shoot loop matching a facing, since masons1.anm2 carries a separate frame set for each of the three
local function playFloatAnim(familiar, direction, shooting)
    local sprite = familiar:GetSprite()
    local facing = "Down"
    if math.abs(direction.X) > math.abs(direction.Y) then
        facing = "Side"
    elseif direction.Y < 0 then
        facing = "Up"
    end

    local animation = (shooting and "FloatShoot" or "Float") .. facing
    if not sprite:IsPlaying(animation) then sprite:Play(animation, true) end
    sprite.FlipX = facing == "Side" and direction.X < 0
end

-- Trails the player and fires the tear for the crew on the shooting input, gated by the share of the Isaac fire rate that crew works at
local function updateFollower(familiar, player, form, data)
    familiar:FollowParent()

    local input = player:GetShootingInput()
    local shooting = input:Length() > SHOOT_DIR_THRESHOLD
    local aim = shooting and input:Normalized() or familiar.Velocity

    if shooting and data.POR_MasonCooldown <= 0 then
        form.Fire(familiar, player, aim)
        data.POR_MasonCooldown = fireCooldown(player, form.Rate)
    end

    playFloatAnim(familiar, aim, shooting)
end

-- Nearest live enemy within a radius, or nil when nothing is close enough to be worth a throw
local function nearestEnemy(position, radius)
    local best, bestDistance = nil, radius
    for _, entity in ipairs(Isaac.FindInRadius(position, radius, EntityPartition.ENEMY)) do
        if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() then
            local distance = entity.Position:Distance(position)
            if distance < bestDistance then best, bestDistance = entity, distance end
        end
    end
    return best
end

-- Drifts the crew member around the room at a fixed speed, reflecting per axis the way the Spike ball does rather than following anyone
local function roam(familiar, data)
    local room = game:GetRoom()
    local velocity = data.POR_MasonRoam or Vector.FromAngle(math.random() * 360):Resized(ROAM_SPEED)
    local position = familiar.Position

    if room:GetGridCollisionAtPos(Vector(position.X + velocity.X, position.Y), true) ~= GridCollisionClass.COLLISION_NONE then
        velocity = Vector(-velocity.X, velocity.Y)
    end
    if room:GetGridCollisionAtPos(Vector(position.X, position.Y + velocity.Y), true) ~= GridCollisionClass.COLLISION_NONE then
        velocity = Vector(velocity.X, -velocity.Y)
    end

    data.POR_MasonRoam = velocity
    familiar.Velocity = velocity
end

-- Bounces around the room and lobs at the closest enemy in range on a separate long cooldown, ignoring where the player is aiming
local function updateRoamer(familiar, player, form, data)
    roam(familiar, data)

    local target = nearestEnemy(familiar.Position, BUFF_RANGE)
    local sprite = familiar:GetSprite()
    local animation = target and "ShootDown" or "IdleDown"
    if not sprite:IsPlaying(animation) then sprite:Play(animation, true) end

    if target and data.POR_MasonCooldown <= 0 then
        form.Fire(familiar, player, (target.Position - familiar.Position):Normalized())
        data.POR_MasonCooldown = form.Cooldown
    end
end

-- Keeps one crew member per copy of the item in the follower chain
function POR.MasonsEvaluateCache(_, player, cacheFlag)
    if cacheFlag ~= CacheFlag.CACHE_FAMILIARS then return end

    local count = player:GetCollectibleNum(MASONS_ITEM_ID) + player:GetEffects():GetCollectibleEffectNum(MASONS_ITEM_ID)
    player:CheckFamiliar(MASONS_VARIANT, count, player:GetCollectibleRNG(MASONS_ITEM_ID), Isaac.GetItemConfig():GetCollectible(MASONS_ITEM_ID))
end

-- Puts a newly spawned crew member into the follower chain, which the first update replaces with whichever crew the owner actually has
function POR.MasonsFamiliarInit(_, familiar)
    familiar.IsFollower = true
    familiar:AddToFollowers()
end

-- Rebuilds the familiar whenever the crew for the owner no longer matches the one on screen, then hands it to the follower or roaming behaviour
function POR.MasonsFamiliarUpdate(_, familiar)
    local player = familiar.Player
    if not player then return end

    local index = formIndex(player)
    local form = FORMS[index]
    if not form then return end

    local data = familiar:GetData()
    if data.POR_MasonForm ~= index then applyForm(familiar, index) end
    data.POR_MasonCooldown = math.max(0, (data.POR_MasonCooldown or 0) - 1)

    if form.Roams then
        updateRoamer(familiar, player, form, data)
    else
        updateFollower(familiar, player, form, data)
    end
end

-- Rerolls the crew the moment the item is picked up, so a fresh copy never arrives as whichever one was already out
function POR.MasonsAddCollectible(_, itemId, _, _, _, _, player)
    if itemId ~= MASONS_ITEM_ID or not player then return end

    rerollForm(player)
end

-- Rerolls the crew for every holder the moment the room is cleared, read as a transition so one clear counts once
function POR.MasonsUpdate()
    local room = game:GetRoom()
    if not room:IsClear() then
        roomCleared = false
        return
    end
    if roomCleared then return end

    roomCleared = true
    POR:ForEachPlayer(function(player)
        if player:HasCollectible(MASONS_ITEM_ID) then rerollForm(player) end
    end)
end

-- Seeds the clear watcher on entering a room, so walking back into an already cleared room does not read as a fresh clear
function POR.MasonsNewRoom()
    roomCleared = game:GetRoom():IsClear()
end
