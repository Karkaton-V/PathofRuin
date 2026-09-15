---- Path of Ruin ---
-- By Team Ruin

-- Setup
if not REPENTOGON then
    error("This Mod Requires REPENTAGON!!")
end
POR = RegisterMod("Path of Ruin", 1)
POR.game = Game()

-- Includes
-- -- Third-party libraries
-- Must load first: patches the EntityPlayer health methods, so everything else can use them normally.
include("sharedscripts.APIs.customhealthapi.core")

-- -- Base Case
-- -- -- Helpers
-- NOTE: custom_save_compiler must be first; it sets POR.SaveCompiler as a side effect
POR_CustomSaveCompiler  = include("sharedscripts.APIs.custom_save_compiler")
POR.SaveCallbacks       = POR.SaveCompiler.SaveCallbacks
POR_CustomSaveCreator   = include("sharedscripts.APIs.custom_save_creator")
POR_ScrumMaster         = include("sharedscripts.APIs.custom_scrum_master_schedule")
POR_Incrementor         = include("sharedscripts.APIs.custom_incrementor")
POR_UnlockManager       = include("sharedscripts.APIs.unlocks.unlockmanager")
POR_CharacterUnlocks    = include("sharedscripts.APIs.unlocks.character_unlock_handling")
POR_BombBag             = include("sharedscripts.items.bomb_bag")
POR_ChargeBarStacking   = include("sharedscripts.APIs.chargebar_stacking")
POR_OrangeSkin          = include("sharedscripts.APIs.orange_skin")
POR_ShopRaid            = include("sharedscripts.APIs.shop_raid")
POR_Challenges          = include("sharedscripts.APIs.challenges")
POR_Spike               = include("sharedscripts.items.spike")
POR_Orpiment            = include("sharedscripts.items.orpiment")
POR_Ammoniac            = include("sharedscripts.items.ammoniac")
POR_SecretDoor          = include("nehemiahscripts.misc.custom_secret_door")
POR_Sealed              = include("nehemiahscripts.misc.sealed")
POR_BetaTimer           = include("nehemiahscripts.challenges.beta_timer")

-- -- Nehemiah
-- -- -- Characters
-- Must load first: sets globals (NEHEMIAH_TYPE, item IDs, etc.) other scripts depend on
POR_NehemiahCharacter   = include("nehemiahscripts.characters.nehemiah")

-- -- -- Compat
POR_NehemiahCompat      = include("sharedscripts.compat.eid")
POR_PogCompat           = include("sharedscripts.compat.pog")

-- -- -- Entities
POR_MoonlightEntity     = include("nehemiahscripts.entities.ezras_moonlight")
POR_NehemiahRockEntity  = include("nehemiahscripts.entities.nehemiahs_boulder")

-- -- -- Items
POR_BookofEzra          = include("nehemiahscripts.items.book_of_ezra")
POR_BookofNehemiah      = include("nehemiahscripts.items.book_of_nehemiah")
POR_SecretRoomChallenge = include("nehemiahscripts.misc.secret_room_challenge")
POR_HappyHour           = include("nehemiahscripts.items.happy_hour")
POR_GoldenApple         = include("nehemiahscripts.items.golden_apple")
POR_WoolenBlanket       = include("nehemiahscripts.items.woolen_blanket")
POR_NehemiahsHammer     = include("nehemiahscripts.items.nehemiahs_hammer")
POR_Pistanthrophobia    = include("nehemiahscripts.items.pistanthrophobia")
POR_CursedRing          = include("nehemiahscripts.items.cursed_ring")
POR_HolySmokes          = include("nehemiahscripts.items.holy_smokes")
POR_OldBrick            = include("nehemiahscripts.items.old_brick")
POR_GoldBrick           = include("nehemiahscripts.items.gold_brick")
POR_Memoir              = include("nehemiahscripts.items.memoir")
POR_Masons              = include("nehemiahscripts.items.masons")

-- Loaded after the files they hook into, so the bomb tests, raid reward override and raid boss swap attach to tables that already exist
POR_FiendFolioCompat    = include("sharedscripts.compat.fiendfolio")
POR_GodsGambitCompat    = include("sharedscripts.compat.godsgambit")
POR_NehemiahsChisel     = include("nehemiahscripts.compat.nehemiahs_chisel")

-- TEMPORARY: registers the "porcostume" console command used to diagnose the invisible Ammoniac costume, delete this line once that is resolved
POR_CostumeProbe        = include("sharedscripts.debug.costume_probe")

-- Registers the nehemiah_ and nehemiaht_ console commands that toggle completion marks
POR_CompletionCommands  = include("sharedscripts.debug.completion_commands")

POR_DumbLuck            = include("nehemiahscripts.trinkets.dumb_luck")
POR_OilyBranch          = include("nehemiahscripts.trinkets.oily_branch")
POR_ButterflyWings      = include("nehemiahscripts.trinkets.butterfly_wings")

-- -- -- Pickups
POR_RadiantCards        = include("nehemiahscripts.pickups.radiant_cards")
POR_OtherCards          = include("nehemiahscripts.pickups.other_cards")

-- Must load after RadiantCards/OtherCards; reads the card id tables
POR_CardPool            = include("nehemiahscripts.pickups.card_pool")
POR_CementHeart         = include("nehemiahscripts.pickups.cement_heart")
POR_Runes               = include("nehemiahscripts.pickups.runes")

-- Loaded after cement_heart.lua, since it overwrites the clot spritesheet that file registers
POR_SlimeClotsCompat    = include("sharedscripts.compat.slime_clots")

-- TEMPORARY: registers the "porcompat" console command used to check which other mods the compat gates can see, delete once those are confirmed
POR_CompatProbe         = include("sharedscripts.debug.compat_probe")

-------------------------------------------------------------------------------------------------------------------------------
-- Initializes Save Handler
function POR:Init(folder, table)
    for _, string in ipairs(table) do
        include("nehemiahscripts/" .. folder .. "." .. string)
        include("sharedscripts/" .. folder .. "." .. string)
    end
end

POR.SaveCompiler.Init(POR)

-------------------------------------------------------------------------------------------------------------------------------
--[[
function mod:PostRender()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pos = Isaac.WorldToScreen(entity.Position)
        Isaac.RenderText(
            tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType),
            pos.X, pos.Y, 1,1,1,1)
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.PostRender)
]]--

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,  POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,  POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, POR.NehemiahLostSkin)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, POR.NehemiahLostSheet)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.NehemiahHammerUse,  NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.BookofEzraUse,      BOOKOFEZRA_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.BookofNehemiahUse,  BOOKOFNEHEMIAH_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.HappyHourUse,       HAPPYHOUR_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.GoldBrickUse,       GOLDBRICK_ITEM_ID)

-- Rock / Boulder, registered once per kind since Normal/Tinted/Golden are separate variants and the filter matches one at a time
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, POR.ROCKTABLE.BedSleptCheck,      PickupVariant.PICKUP_BED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.PickupUpdate,        POR.ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.PickupUpdate,        POR.ROCK_VARIANT_TINTED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.PickupUpdate,        POR.ROCK_VARIANT_GOLDEN)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.ProjectileUpdate,    POR.ROCK_PROJECTILE_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.ProjectileUpdate,    POR.ROCK_PROJECTILE_VARIANT_TINTED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.ProjectileUpdate,    POR.ROCK_PROJECTILE_VARIANT_GOLDEN)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.ROCKTABLE.PostPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.ROCKTABLE.HideRocksOnTrapdoor)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.ROCKTABLE.RestorePersistentBoulders)
-- Wrapped since RestoreHeldBoulderVisual is colon-defined but ForEachPlayer calls func(player, i) directly.
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        function()
    POR:ForEachPlayer(function(player) POR.ROCKTABLE:RestoreHeldBoulderVisual(player) end)
end)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_RED_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingHideAnim,           CollectibleType.COLLECTIBLE_URN_OF_SOULS)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingHideAnim,           CollectibleType.COLLECTIBLE_NOTCHED_AXE)

-- Ezra's Moonlight
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.EzrasMoonlight.MoonlightUpdate, POR.MOONLIGHT_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.EzrasMoonlight.OnPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.EzrasMoonlight.OnEvaluateCache)

-- Nehemiah's Hammer
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.NehemiahHammerEvaluateCache, CacheFlag.CACHE_WEAPON)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.NehemiahHammerSwapSprite)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.NehemiahHammerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.NehemiahHammerNewRoom)

-- Book of Ezra
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.BookofEzraGreedDeath)
POR:AddCallback(ModCallbacks.MC_PRE_ROOM_ENTITY_SPAWN, POR.BookofEzraGraveEntity)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.BookofEzraNewLevel)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.ShopRaid.OnNewLevel)

POR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,    POR.Challenges.OnGameStarted)
POR:AddCallback(ModCallbacks.MC_POST_RENDER,          POR.BetaTimer.OnRender)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.BetaTimer.OnNewLevel)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.BetaTimer.OnUpdate)
POR:AddCallback(ModCallbacks.MC_POST_COMPLETION_MARK_GET, POR.Challenges.SyncChallengeUnlocks)
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.BookofNehemiahGreedDeath)
POR:AddCallback(ModCallbacks.MC_POST_MODS_LOADED,     POR.BookofNehemiahLoadRooms)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.BookofNehemiahNewRoom)
POR:AddCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER,  POR.BookofNehemiahDoorRender)
POR:AddCallback(ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE, POR.BookofNehemiahDoorUpdate)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.ShopRaid.OnUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.ShopRaid.OnNewRoom)

-- The Masons
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.MasonsEvaluateCache, CacheFlag.CACHE_FAMILIARS)
POR:AddCallback(ModCallbacks.MC_FAMILIAR_INIT,        POR.MasonsFamiliarInit,   MASONS_VARIANT)
POR:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE,      POR.MasonsFamiliarUpdate, MASONS_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, POR.MasonsAddCollectible)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.MasonsUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.MasonsNewRoom)

-- Cursed Ring
POR:AddCallback(ModCallbacks.MC_PRE_NPC_COLLISION,    POR.CursedRingSeal)

-- Gold Brick
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.GoldBrickTearColor, CacheFlag.CACHE_TEARCOLOR)
POR:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,       POR.GoldBrickFireTear)
POR:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION,   POR.GoldBrickTearCollision)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.GoldBrickClearAll)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.GoldBrickClearAll)

-- Golden Apple
POR:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,      POR.GoldenAppleTakeDamage)

-- Happy Hour
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.HappyHourEvaluateCache)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.HappyHourClearAll)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.HappyHourClearAll)

-- Holy Smokes!
POR:AddCallback(ModCallbacks.MC_PRE_DEVIL_APPLY_ITEMS, POR.HolySmokesAngelChance)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.HolySmokesBurnAura)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER,   POR.HolySmokesRenderAura)

-- Old Brick
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.OldBrickEvaluateCache, CacheFlag.CACHE_RANGE)
POR:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,       POR.OldBrickFireTear)
POR:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION,   POR.OldBrickTearCollision)
POR:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE,     POR.OldBrickTearUpdate)

-- Pistanthrophobia
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.PistanthrophobiaEvaluateCache, CacheFlag.CACHE_DAMAGE)
POR:AddCallback(ModCallbacks.MC_POST_NPC_INIT,        POR.RefreshPistanthrophobia)
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.RefreshPistanthrophobia)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER,   POR.PistanthrophobiaRenderAura)

-- Woolen Blanket
POR:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,      POR.WoolenBlanketTakeDamage)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.WoolenBlanketPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.WoolenBlanketEvaluateCache, CacheFlag.CACHE_LUCK)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.WoolenBlanketNewLevel)

-- The Memoir
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.MemoirEvaluateCache, POR.MEMOIR_CACHE_FLAGS)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.MemoirRefreshAura)

-- Trinkets
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.DumbLuckPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,       POR.OilyBranchFireTear)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.ButterflyWingsNewRoom)

-- Card Pool (unlock-gated Tarot/Reverse Tarot/Suit/Special/Rune swaps)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_SELECTION, POR.CardPool.OnPickupSelection)

-- Cement Heart
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,      POR.CementHeart.FixPickupSprite,  PickupVariant.PICKUP_HEART)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE,    POR.CementHeart.OnPickupUpdate,   PickupVariant.PICKUP_HEART)
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,  POR.CementHeart.OnPickupCollide,  PickupVariant.PICKUP_HEART)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_SELECTION, POR.CementHeart.OnHeartSelection)

-- Other Cards (Misprinted Hierophant/Justice, Suicide King, King of Clubs, Jack of Diamonds, Graceful/Disgraceful Charity)
POR:AddCallback(ModCallbacks.MC_USE_CARD,              POR.OtherCards.OnUseCard)
POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE,  POR.OtherCards.OnAddCollectible)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,         POR.OtherCards.OnNewRoom)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,        POR.OtherCards.OnNewLevel)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,      POR.OtherCards.FixPickupSprite, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE,    POR.OtherCards.OnPickupUpdate,  PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,  POR.OtherCards.OnPickupCollide, PickupVariant.PICKUP_TAROTCARD)

-- Radiant Cards (the 22 Fool..World swaps)
POR:AddCallback(ModCallbacks.MC_USE_CARD,              POR.RadiantCards.OnUseCard)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,      POR.RadiantCards.FixPickupSprite, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE,    POR.RadiantCards.OnPickupUpdate,  PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,  POR.RadiantCards.OnPickupCollide, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,        POR.RadiantCards.OnEvaluateCache)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,    POR.RadiantCards.OnPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,         POR.RadiantCards.OnNewRoom)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,        POR.RadiantCards.OnNewLevel)

-- Runes (Soul of Nehemiah)
POR:AddCallback(ModCallbacks.MC_USE_CARD,              POR.SoulOfNehemiahUse, Isaac.GetCardIdByName("SoulOfNehemiah"))

-- Secret Door (the Secret/Super Secret Room reveal for Tainted Nehemiah)
POR:AddCallback(ModCallbacks.MC_POST_BOMB_UPDATE,             POR.SecretDoor.OnBombUpdate)
POR:AddCallback(ModCallbacks.MC_PRE_BOMB_GRID_COLLISION,      POR.SecretDoor.OnBombGridCollision)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT,             POR.SecretDoor.OnEffectInit)
POR:AddCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER,  POR.SecretDoor.OnDoorRender)
POR:AddCallback(ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE, POR.SecretDoor.OnDoorUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,               POR.SecretDoor.OnNewLevel)

-- Sealed status effect
POR:AddCallback(ModCallbacks.MC_NPC_UPDATE,           POR.Sealed.OnNpcUpdate)

-- Secret Room Challenge
POR:AddCallback(ModCallbacks.MC_POST_NPC_INIT,        POR.SecretRoomChallenge.OnNpcInit)
POR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,    POR.SecretRoomChallenge.OnGameStarted)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.SecretRoomChallenge.OnNewRoom)
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.SecretRoomChallenge.OnNpcDeath)
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,       POR.SecretRoomChallenge.OnNewLevel)

-- Nehemiah character
POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, POR.OnAddCollectibleBirthrightSwap)

-- Unlock Manager, which reads completion marks, so the achievement sweep runs whenever a mark is earned rather than on a boss death
POR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,    POR.OnGameStartedApplyUnlockGates)
POR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,    POR.SyncUnlockAchievements)
POR:AddCallback(ModCallbacks.MC_POST_COMPLETION_MARK_GET, POR.SyncUnlockAchievements)
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.OnMomDeathRecordHardKill, EntityType.ENTITY_MOM)

POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.CharacterUnlocks.OnGideonDeath, 907) -- Great Gideon

-- Nehemiah's Chisel is only present alongside the Tainted Treasure Rooms mod, so every hook is guarded on the compat table
if POR.NehemiahsChisel then
    POR:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,  POR.NehemiahsChisel.OnGameStarted)
    POR:AddCallback(ModCallbacks.MC_USE_ITEM,           POR.NehemiahsChiselUse, NEHEMIAHSCHISEL_ITEM_ID)
    POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,     POR.NehemiahsChisel.OnEvaluateCache, CacheFlag.CACHE_WEAPON)
    POR:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE,  POR.NehemiahsChisel.OnKnifeUpdate)
    POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,      POR.NehemiahsChisel.OnNewRoom)
end
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.CharacterUnlocks.OnNewRoom)
POR:AddCallback(ModCallbacks.MC_POST_SLOT_INIT,       POR.CharacterUnlocks.OnSlotInit,   SlotVariant.HOME_CLOSET_PLAYER)
POR:AddCallback(ModCallbacks.MC_POST_SLOT_UPDATE,     POR.CharacterUnlocks.OnSlotUpdate, SlotVariant.HOME_CLOSET_PLAYER)

-- Bomb Bag
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.BombBagUse, BOMBBAG_ITEM_ID)

-- Orange Skin
POR:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_ADDED,   POR.OrangeSkinCollectibleChanged)
POR:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, POR.OrangeSkinCollectibleChanged)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,                    POR.OrangeSkinNewRoom)

-- Spike
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.SpikePlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_RENDER,          POR.SpikeBarRender)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.SpikeEffectUpdate, SPIKE_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE,    POR.SpikeBrimstoneRecolor, LaserVariant.THICK_RED)
POR:AddCallback(ModCallbacks.MC_PRE_LASER_COLLISION,  POR.SpikeBrimstonePetrify, LaserVariant.THICK_RED)

-- Ammoniac
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.AmmoniacPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_RENDER,          POR.AmmoniacBarRender)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.AmmoniacEffectUpdate,         PLASMA_VARIANT)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.AmmoniacBrimstoneFireDelay,   CacheFlag.CACHE_FIREDELAY)
POR:AddCallback(ModCallbacks.MC_POST_LASER_UPDATE,    POR.AmmoniacBrimstoneSkin,        LaserVariant.THICK_RED)
POR:AddCallback(ModCallbacks.MC_PRE_LASER_COLLISION,  POR.AmmoniacBrimstoneStatus,      LaserVariant.THICK_RED)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.AmmoniacBrimstoneCostume)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.AmmoniacBrimstoneCostumeNewRoom)

-- Orpiment
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.OrpimentEvaluateCache, CacheFlag.CACHE_TEARFLAG)
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE,       POR.OrpimentEvaluateCache, CacheFlag.CACHE_TEARCOLOR)
POR:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION,   POR.OrpimentTearCollision)
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,       POR.OrpimentNpcDeath)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.OrpimentClearPoisonedOnNewRoom)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.OrpimentUpdateGasClouds)

-- Save Creator
POR:AddPriorityCallback(ModCallbacks.MC_POST_NEW_LEVEL, CallbackPriority.LATE, POR.OnNewLevelApplyCacheFlags)

-- Scrum Master Schedule
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.scrum_master_schedule.OnUpdate)
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,        POR.scrum_master_schedule.OnNewRoom)
POR:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,        POR.scrum_master_schedule.OnGameExit)

-------------------------------------------------------------------------------------------------------------------------------
-- Custom Callbacks

---@class ExtraCallback
---@field func fun(...: any)
---@field priority ExtraCallbackPriority
---@field limiters any

---@class ExtraCallbacks
---@field Name string
---@field Functions ExtraCallback[]
---@field Handler fun(functions: ExtraCallback[], ...: any): ...
---@display POR.ExtraCallbacks
POR.ExtraCallbacks = {
    -- Called when a rock has died; args: player, tear, collider
    NEHEMIAH_ROCK_DEAD = {
        Name = "NEHEMIAH_ROCK_DEAD",
        Functions = {},
        Handler = function(callbacks, player, tear, collider)
            for i = 1, #callbacks do callbacks[i].func(player, tear, collider) end
        end,
    },

    -- Called before the Nehemiah hitbox is generated; return {Hitbox, Direction} array + optional true to suppress original
    NEHEMIAH_PRE_HITBOX_GENERATE = {
        Name = "NEHEMIAH_PRE_HITBOX_GENERATE",
        Functions = {},
        Handler = function(callbacks, player, hitbox, incubus)
            local hitboxes, shouldUseOriginal = {}, true
            for i = 1, #callbacks do
                local val, deleteOriginal = callbacks[i].func(player, hitbox, incubus)
                if val and type(val) == "table" then
                    for _, v in ipairs(val) do table.insert(hitboxes, v) end
                end
                if deleteOriginal == true then shouldUseOriginal = false end
            end
            return hitboxes, shouldUseOriginal
        end,
    },

    -- Called after Nehemiah throws a rock; args: player, rock
    NEHEMIAH_POST_THROW_ROCK = {
        Name = "NEHEMIAH_POST_THROW_ROCK",
        Functions = {},
        Handler = function(callbacks, player, tear)
            for i = 1, #callbacks do callbacks[i].func(player, tear) end
        end,
    },

    -- Called after PRE_HITBOX_GENERATE for each hitbox; optionally return modified hitbox
    NEHEMIAH_POST_HITBOX_GENERATE = {
        Name = "NEHEMIAH_POST_HITBOX_GENERATE",
        Functions = {},
        Handler = function(callbacks, player, incubus, hitbox)
            for i = 1, #callbacks do hitbox = callbacks[i].func(player, incubus, hitbox) or hitbox end
            return hitbox
        end
    },

    -- Called before a rock sprite is initialized; return a RockSpriteModifier or nil for default
    NEHEMIAH_PRE_ROCK_SPRITE_INIT = {
        Name = "NEHEMIAH_PRE_ROCK_SPRITE_INIT",
        Functions = {},
        Handler = function(callbacks, player, variant, tag, entity)
            local highestPriority, highestModifier = 0, nil
            for i = 1, #callbacks do
                local result = callbacks[i].func(player, variant, tag, entity)
                if result and result.Priority > highestPriority then
                    highestPriority, highestModifier = result.Priority, result
                end
            end
            return highestModifier
        end
    },
}

---@enum ExtraCallbackPriority
POR.ExtraCallbackPriority = {
    EARLIEST = 0,
    EARLY    = 1,
    NORMAL   = 2,
    LATE     = 3,
    LATEST   = 4,
}

-- Returns a set table with keys equal to the values in the given list, all set to true
---@param list any[]
---@return {[any]: boolean?}
---@function
function POR:Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end