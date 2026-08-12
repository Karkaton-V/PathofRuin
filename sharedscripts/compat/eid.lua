if EID then
    
    EID:setModIndicatorName("Path of Ruin")

    local sprite = Sprite()
    sprite:Load("gfx/ui/ruin_eid.anm2")

    -- "Shortcut" / "Anim Name" / "Frame Number" / "Width" / "Height" / "Offset L" / "Offset Top" / "Sprite"
    EID:addIcon("RuinIcon", "Logo", -1, 31, 11, -1, 0, sprite)
    EID:addIcon("CementHeart", "CementHeart", -1, 16, 16, -1, 0, sprite)
    EID:addIcon("RadiantCard", "Radiant", -1, 16, 16, -1, 0, sprite)
    EID:addIcon("YugiohCard", "Yugioh", -1, 16, 16, -1, 0, sprite)
    EID:addIcon("SoulofNehemiah", "NehemiahSoul", -1, 16, 16, -1, 0, sprite)
    EID:addIcon("Sealed", "AllStatsDown", -1, 16, 16, -1, 0, sprite)
    EID:addIcon("ThrowBomb", "RedBomb", -1, 32, 32, -1, 0, sprite)

    EID:setModIndicatorIcon("RuinIcon")




    -- MetaData
    EID:addCardMetadata(Isaac.GetCardIdByName("FFool"), 0, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FMagician"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FHighPriestess"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FEmpress"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FEmperor"), 3, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FHierophant"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FLovers"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FChariot"), 3, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FJustice"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FHermit"), 3, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FWheelOfFortune"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FStrength"), 4, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FHangedMan"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FDeath"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FTemperance"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FDevil"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FTower"), 6, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FStar"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FMoon"), 3, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FSun"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FJudgement"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("FWorld"), 3, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("MPHierophant"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("MPJustice"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("SRSuicideKing"), 2, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("SRKingofClubs"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("SRJackofDiamonds"), 0, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("GracefulCharity"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("DisgracefulCharity"), 12, true)
    EID:addCardMetadata(Isaac.GetCardIdByName("SoulOfNehemiah"), 6, false)




    -- Birthrights
    EID:addBirthright(Isaac.GetPlayerTypeByName("Nehemiah", false), "{{CementHeart}}Rock Chunks thrown by Nehemiah now have a chance to break up into Blue Spiders", "Nehemiah")
    EID:addBirthright(Isaac.GetPlayerTypeByName("The Condemned", true), "{{SoulofNehemiah}}Let Loose the Chains of Fate and Reclaim Your Rightful Glory", "The Condemned")

    -- Active Items
    EID:addCollectible(Isaac.GetItemIdByName("Happy Hour"), "{{ArrowUp}}All Stats Up +10%          Isaac is Under the Influence of a Random Worm", "Happy Hour")
    EID:addCollectible(Isaac.GetItemIdByName("Nehemiah's Hammer"), "Gives Isaac a One-Use Melee Weapon          Breaking Rocks With the Hammer Dislodges Chunks of Stone From the Ceiling That Isaac Can Throw to Damage Enemies", "Nehemiah's Hammer")
    EID:addCollectible(Isaac.GetItemIdByName("Gold Brick"), "Gives Isaac Midas Rock Tears That Cause Enemies to Drop Money", "Gold Brick")
    EID:addCollectible(Isaac.GetItemIdByName("Book of Ezra"), "Summons a Ray of Light in the Current Room That Gives Isaac a Fading {{ArrowUp}}All Stats Up", "Book of Ezra")
    EID:addCollectible(Isaac.GetItemIdByName("Book of Nehemiah"), "Book of Ezra + Crack the Sky", "Book of Nehemiah")
    EID:addCollectible(Isaac.GetItemIdByName("Bag O' Bombs"), "Allows Isaac to Turn {{Bomb}}Bombs into {{ThrowBomb}}Throwable Bombs, and Vice Versa", "Bag O' Bombs")

    -- Passive Items
    EID:addCollectible(Isaac.GetItemIdByName("Golden Apple"), "When Isaac Would Take Fatal Damage, Instead Freezes Nearby Enemies in Their Tracks", "Golden Apple")
    EID:addCollectible(Isaac.GetItemIdByName("Holy Smokes!"), "{{ArrowUp}}Angel Chance +20%          Isaac Has an Orange Aura That Burns Enemies Inside of It", "Holy Smokes!")
    EID:addCollectible(Isaac.GetItemIdByName("Woolen Blanket"), "{{HolyMantleSmall}}The First Damage Taken on the Current Floor is Reduced to a Half Heart          Afterwards, Isaac Has a Period of Extra Long Invincibility", "Woolen Blanket")
    EID:addCollectible(Isaac.GetItemIdByName("The Memoir"), "{{ArrowDown}}Damage -0.4          {{ArrowDown}}Tears -0.4          {{ArrowUp}}3 Stats +15%          Isaac Gains a Permanent Tear-Repelling Aura", "The Memoir")
    EID:addCollectible(Isaac.GetItemIdByName("Old Brick"), "{{ArrowDown}}Range -1.5          Isaac Has a Chance to Shoot a Compacted Rock Tear That Shatters Into Multiple Rocks on Impact", "Old Brick")
    EID:addCollectible(Isaac.GetItemIdByName("Cursed Ring"), "Enemies That Make Contact With Isaac Gain the Status Effect {{Sealed}}{{ColorPurple}}Sealed{{ColorText}} Which Results In an All Stats Down and Inflicts {{Slow}}{{ColorOlive}}Slow", "Cursed Ring")
    EID:addCollectible(Isaac.GetItemIdByName("Pistanthrophobia"), "For Each Enemy in the Current Room, Isaac Gets a {{ArrowUp}}+0.5 Damage Up, Scaling Back {{ArrowDown}}Down as Enemies are Killed", "Pistanthrophobia")
    EID:addCollectible(Isaac.GetItemIdByName("Spike"), "Isaac Gains a Chargebar Shot for a Spike Ball Projectile That Splits Into Rocks on Death", "Spike")

    -- Familiars
    EID:addCollectible(Isaac.GetItemIdByName("The Masons"), "Gives a Familiar That Changes Between Rooms:          A Small Nehemiah That Follows Isaac and Shoots Nail Tears          A Lanky Mason That Follows Isaac and Shoots Compacted Rock Tears          A Buff Wrecker That Bounces Around the Room and Shoots A Spike Ball          An Old Man That Shoots Splitting Rock Tears", "The Masons")


    -- Trinkets
    EID:addTrinket(Isaac.GetTrinketIdByName("Windflower"), "When Standing Still, Isaac Gains a Temporary Tear-Repelling Aura, similar to {{Card57}} The Reverse Magician", "Windflower")
    EID:addTrinket(Isaac.GetTrinketIdByName("Oily Branch"), "Isaac's Tears Have a 10% Chance to Inflict an Enemy With {{Charm}}Charm, Scaling With Luck", "Oily Branch")
    EID:addTrinket(Isaac.GetTrinketIdByName("Butterfly Wings"), "Spawned Rocks have a 0.2% chance to be a {{SoulHeart}}Tinted Rock, Scaling With Luck", "Butterfly Wings")

    -- Pickups
    EID:addCard(Isaac.GetCardIdByName("FFool"), "{{RadiantCard}}Uses {{Collectible127}} Forget-Me-Now          Dispels All Curses")
    EID:addCard(Isaac.GetCardIdByName("FMagician"), "{{RadiantCard}}{{ArrowUp}}Range x2          {{ArrowUp}}Tears x3          Uses {{Collectible369}}Continuum")
    EID:addCard(Isaac.GetCardIdByName("FHighPriestess"), "{{RadiantCard}}Summons a {{MomBossSmall}}Mom Hand on Isaac")
    EID:addCard(Isaac.GetCardIdByName("FEmpress"), "{{RadiantCard}}Uses {{Collectible230}}{{ColorBlack}}Abaddon")
    EID:addCard(Isaac.GetCardIdByName("FEmperor"), "{{RadiantCard}}Teleports Isaac to either the {{BossRushRoom}}Boss Challenge Room, the {{ChallengeRoom}}Challenge Room, the {{SacrificeRoom}}Sacrifice Room, or the {{CursedRoom}}Cursed Room")
    EID:addCard(Isaac.GetCardIdByName("FHierophant"), "{{RadiantCard}}Spawns 2 {{GoldenHeart}}{{ColorYellow}}Golden Hearts")
    EID:addCard(Isaac.GetCardIdByName("FLovers"), "{{RadiantCard}}Uses {{Collectible45}}Yum Heart          Spawns {{Collectible15}}<3")
    EID:addCard(Isaac.GetCardIdByName("FChariot"), "{{RadiantCard}}Uses {{Collectible593}}Mars          Uses {{Collectible302}}Leo")
    EID:addCard(Isaac.GetCardIdByName("FJustice"), "{{RadiantCard}}Spawns a {{Bomb}}Double Bomb, {{Key}}Double Key, {{Coin}}Double Coin, and {{Heart}}Double Heart ")
    EID:addCard(Isaac.GetCardIdByName("FHermit"), "{{RadiantCard}}Spawns a Trapdoor to the {{Collectible602}}VIP Shop")
    EID:addCard(Isaac.GetCardIdByName("FWheelOfFortune"), "{{RadiantCard}}Spawns a {{CraneGame}}Crane Game")
    EID:addCard(Isaac.GetCardIdByName("FStrength"), "{{RadiantCard}}Uses {{Collectible625}}Mega Mush")
    EID:addCard(Isaac.GetCardIdByName("FHangedMan"), "{{RadiantCard}}Uses {{Collectible719}} Keeper's Box 3 Times in Quick Succession")
    EID:addCard(Isaac.GetCardIdByName("FDeath"), "{{RadiantCard}}Uses {{Collectible237}}Death's Touch          Uses {{Collectible530}}Death's List")
    EID:addCard(Isaac.GetCardIdByName("FTemperance"), "{{RadiantCard}}Spawns a {{Confessional}}Confessional")
    EID:addCard(Isaac.GetCardIdByName("FDevil"), "{{RadiantCard}}Activates {{Collectible712}}Lemegeton 3 Times in Quick Succession")
    EID:addCard(Isaac.GetCardIdByName("FTower"), "{{RadiantCard}}Drops 3 {{Bomb}}{{ColorRed}}Giga Bombs")
    EID:addCard(Isaac.GetCardIdByName("FMoon"), "{{RadiantCard}}Teleports Isaac to the {{SuperSecretRoom}}Super Secret Room")
    EID:addCard(Isaac.GetCardIdByName("FSun"), "{{RadiantCard}}+2 {{SoulHeart}}Soul Hearts          Reveals All Marked Rooms on the Map          Dispels {{CurseLost}}Curse of The Lost and {{CurseBlind}}Curse of The Blind          Uses {{Collectible651}}Star of Bethlehem")
    EID:addCard(Isaac.GetCardIdByName("FJudgement"), "{{RadiantCard}}Spawns a {{BatteryBeggar}}Battery Beggar or a {{RottenBeggar}}Rotten Beggar")
    EID:addCard(Isaac.GetCardIdByName("FWorld"), "{{RadiantCard}}Opens all Doors          Spawns a {{LadderRoom}}Trapdoor")
    EID:addCard(Isaac.GetCardIdByName("MPHierophant"), "{{RadiantCard}}Spawns 2 {{CementHeart}}Cement Hearts")
    EID:addCard(Isaac.GetCardIdByName("MPJustice"), "{{RadiantCard}}Spawns 2-4 {{DirtyChest}}Old Chests, {{Chest}}Regular Chests, or {{HauntedChest}}Haunted Chests")
    EID:addCard(Isaac.GetCardIdByName("SRSuicideKing"), "{{RedCard}}{{Warning}}Spawns 4 Items From the Current Room's Item Pool, Upon Taking 2, the Other 2 Disappear and Uses {{Collectible475}}{{ColorRed}}Plan C")
    EID:addCard(Isaac.GetCardIdByName("SRKingofClubs"), "{{RedCard}}{{Warning}}Destroys All Pickups in the Current Room, and each one has a 20% chance to become a {{Bomb}}{{ColorRed}}Giga Bomb{{ColorText}} Instead")
    EID:addCard(Isaac.GetCardIdByName("SRJackofDiamonds"), "{{RedCard}}Spawns a {{Coin}}Coin and Turns All Other Coins Into Nickels")
    EID:addCard(Isaac.GetCardIdByName("GracefulCharity"), "{{YugiohCard}}{{Warning}}Destroys Isaac's 2 Most Recent Items and Spawns 3 Items From The Current Room's Item Pool")
    EID:addCard(Isaac.GetCardIdByName("DisgracefulCharity"), "{{YugiohCard}}If Isaac Has Less Pickups then When He Entered the Floor, The Difference is Returned to Him")
    EID:addCard(Isaac.GetCardIdByName("SoulOfNehemiah"), "{{SoulofNehemiah}}Breaks All Rocks in the Room and Spawns 3 Rock Chunks")

    -- Transformation Pointers
    EID:assignTransformation("collectible", Isaac.GetItemIdByName("Book of Ezra"), EID.TRANSFORMATION["BOOKWORM"])




    -- Compat
    if ANDROMEDA then
        EID:addCard(Isaac.GetCardIdByName("FStar"), "{{RadiantCard}}Teleports Isaac to the {{Planetarium}}Planetarium, if The Item Room Has Already Been Visited, Redirects to an {{AbPlanetarium}}Abandoned Planetarium")
    else
        EID:addCard(Isaac.GetCardIdByName("FStar"), "{{RadiantCard}}Teleports Isaac to the {{Planetarium}}Planetarium")
    end

end