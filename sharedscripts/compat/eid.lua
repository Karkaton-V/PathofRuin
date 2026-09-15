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
    EID:addBirthright(Isaac.GetPlayerTypeByName("Nehemiah", false), "{{CementHeart}} Rock chunks thrown by Nehemiah have a chance to break up into blue spiders", "Nehemiah")
    EID:addBirthright(Isaac.GetPlayerTypeByName("Nehemiah", true), "{{SoulofNehemiah}} Let loose the chains of fate and reclaim your rightful glory", "The Condemned")

    -- Active Items
    EID:addCollectible(Isaac.GetItemIdByName("Happy Hour"), "{{ArrowUp}} All stats up +10%#Isaac is under the influence of a random worm", "Happy Hour")
    EID:addCollectible(Isaac.GetItemIdByName("Nehemiah's Hammer"), "Gives Isaac a one-use melee weapon#Breaking rocks with the hammer dislodges chunks of stone that Isaac can throw at enemies", "Nehemiah's Hammer")
    EID:addCollectible(Isaac.GetItemIdByName("Gold Brick"), "Gives Isaac midas rock tears that cause enemies to drop money", "Gold Brick")
    EID:addCollectible(Isaac.GetItemIdByName("Book of Ezra"), "Summons a ray of light in the current room#{{ArrowUp}} Standing in it grants a fading all stats up", "Book of Ezra")
    EID:addCollectible(Isaac.GetItemIdByName("Book of Nehemiah"), "{{Collectible" .. Isaac.GetItemIdByName("Book of Ezra") .. "}} Book of Ezra + {{Collectible160}} Crack the Sky", "Book of Nehemiah")
    EID:addCollectible(Isaac.GetItemIdByName("Bag O' Bombs"), "Turns {{Bomb}} bombs into {{ThrowBomb}} throwable bombs, and back again", "Bag O' Bombs")

    -- Passive Items
    EID:addCollectible(Isaac.GetItemIdByName("Golden Apple"), "{{Freezing}} Freezes nearby enemies instead of taking fatal damage", "Golden Apple")
    EID:addCollectible(Isaac.GetItemIdByName("Holy Smokes!"), "{{ArrowUp}} Angel room chance +20%#{{Burning}} Isaac gains an aura that burns enemies inside it", "Holy Smokes!")
    EID:addCollectible(Isaac.GetItemIdByName("Woolen Blanket"), "{{HolyMantleSmall}} The first damage taken each floor is reduced to half a heart#Grants an extra long period of invincibility afterwards", "Woolen Blanket")
    EID:addCollectible(Isaac.GetItemIdByName("The Memoir"), "{{ArrowDown}} Damage -0.4#{{ArrowDown}} Tears -0.4#{{ArrowUp}} Range, shot speed and speed +15%#Isaac gains a permanent tear-repelling aura", "The Memoir")
    EID:addCollectible(Isaac.GetItemIdByName("Old Brick"), "{{ArrowDown}} Range -1.5#Isaac has a chance to shoot a compacted rock tear#{{Indent}} Shatters into multiple rocks on impact", "Old Brick")
    EID:addCollectible(Isaac.GetItemIdByName("Cursed Ring"), "Enemies that touch Isaac become {{Sealed}}{{ColorPurple}}Sealed{{ColorText}}#{{Indent}} {{ArrowDown}} All stats down, and inflicts {{Slow}}{{ColorOlive}}Slow{{ColorText}}", "Cursed Ring")
    EID:addCollectible(Isaac.GetItemIdByName("Pistanthrophobia"), "{{ArrowUp}} Damage +0.5 for each enemy in the room#Scales back {{ArrowDown}} down as enemies are killed", "Pistanthrophobia")
    EID:addCollectible(Isaac.GetItemIdByName("Spike"), "Isaac gains a chargebar#When full, fires a spike ball that splits into rocks when it breaks", "Spike")
    EID:addCollectible(Isaac.GetItemIdByName("Ammoniac"), "Isaac gains a slow chargebar#When full, fires 3 plasma projectiles in a spread that deal no damage#{{Indent}} Each enemy hit is evenly likely to be {{Burning}} burned, {{Confusion}} confused or {{Freezing}} frozen", "Ammoniac")
    EID:addCollectible(Isaac.GetItemIdByName("Orpiment"), "{{Poison}} All tears become poison tears, dealing 3x tear damage as poison#Enemies killed by the poison burst into {{Poison}} poison creep#{{Indent}} Deals the same damage to nearby enemies#{{Indent}} 20% chance to poison them too, scaling with luck", "Orpiment")

    -- Familiars
    EID:addCollectible(Isaac.GetItemIdByName("The Masons"), "Gives a familiar that changes between rooms:#{{Indent}} A small Nehemiah that follows Isaac and shoots nail tears#{{Indent}} A lanky mason that follows Isaac and shoots compacted rock tears#{{Indent}} A buff wrecker that bounces around the room and shoots a spike ball#{{Indent}} An old man that shoots splitting rock tears", "The Masons")


    -- Trinkets
    EID:addTrinket(Isaac.GetTrinketIdByName("Windflower"), "Standing still grants a temporary tear-repelling aura#{{Indent}} Works like {{Card57}} The Reverse Magician", "Windflower")
    EID:addTrinket(Isaac.GetTrinketIdByName("Oily Branch"), "{{Charm}} Tears have a 10% chance to charm an enemy, scaling with luck", "Oily Branch")
    EID:addTrinket(Isaac.GetTrinketIdByName("Butterfly Wings"), "Spawned rocks have a 0.2% chance to be a tinted rock, scaling with luck", "Butterfly Wings")

    -- Pickups
    EID:addCard(Isaac.GetCardIdByName("FFool"), "{{RadiantCard}} Uses {{Collectible127}} Forget-Me-Now#{{RadiantCard}} Dispels all curses")
    EID:addCard(Isaac.GetCardIdByName("FMagician"), "{{RadiantCard}} {{ArrowUp}} Range x2#{{RadiantCard}} {{ArrowUp}} Tears x3#{{RadiantCard}} Uses {{Collectible369}} Continuum")
    EID:addCard(Isaac.GetCardIdByName("FHighPriestess"), "{{RadiantCard}} Summons a {{MomBossSmall}} Mom's Hand on Isaac")
    EID:addCard(Isaac.GetCardIdByName("FEmpress"), "{{RadiantCard}} Uses {{Collectible230}}{{ColorBlack}} Abaddon")
    EID:addCard(Isaac.GetCardIdByName("FEmperor"), "{{RadiantCard}} Teleports Isaac to the {{BossRushRoom}} boss challenge, {{ChallengeRoom}} challenge, {{SacrificeRoom}} sacrifice or {{CursedRoom}} cursed room")
    EID:addCard(Isaac.GetCardIdByName("FHierophant"), "{{RadiantCard}} Spawns 2 {{GoldenHeart}}{{ColorYellow}} golden hearts")
    EID:addCard(Isaac.GetCardIdByName("FLovers"), "{{RadiantCard}} Uses {{Collectible45}} Yum Heart#{{RadiantCard}} Spawns {{Collectible15}} <3")
    EID:addCard(Isaac.GetCardIdByName("FChariot"), "{{RadiantCard}} Uses {{Collectible593}} Mars#{{RadiantCard}} Uses {{Collectible302}} Leo")
    EID:addCard(Isaac.GetCardIdByName("FJustice"), "{{RadiantCard}} Spawns a {{Bomb}} double bomb, {{Key}} double key, {{Coin}} double coin and {{Heart}} double heart")
    EID:addCard(Isaac.GetCardIdByName("FHermit"), "{{RadiantCard}} Spawns a trapdoor to the {{Collectible602}} VIP shop")
    EID:addCard(Isaac.GetCardIdByName("FWheelOfFortune"), "{{RadiantCard}} Spawns a {{CraneGame}} crane game")
    EID:addCard(Isaac.GetCardIdByName("FStrength"), "{{RadiantCard}} Uses {{Collectible625}} Mega Mush")
    EID:addCard(Isaac.GetCardIdByName("FHangedMan"), "{{RadiantCard}} Uses {{Collectible719}} Keeper's Box 3 times in quick succession")
    EID:addCard(Isaac.GetCardIdByName("FDeath"), "{{RadiantCard}} Uses {{Collectible237}} Death's Touch#{{RadiantCard}} Uses {{Collectible530}} Death's List")
    EID:addCard(Isaac.GetCardIdByName("FTemperance"), "{{RadiantCard}} Spawns a {{Confessional}} confessional")
    EID:addCard(Isaac.GetCardIdByName("FDevil"), "{{RadiantCard}} Uses {{Collectible712}} Lemegeton 3 times in quick succession")
    EID:addCard(Isaac.GetCardIdByName("FTower"), "{{RadiantCard}} Drops 3 {{Bomb}}{{ColorRed}} giga bombs")
    EID:addCard(Isaac.GetCardIdByName("FMoon"), "{{RadiantCard}} Teleports Isaac to the {{SuperSecretRoom}} super secret room")
    EID:addCard(Isaac.GetCardIdByName("FSun"), "{{RadiantCard}} +2 {{SoulHeart}} soul hearts#{{RadiantCard}} Reveals all marked rooms on the map#{{RadiantCard}} Dispels {{CurseLost}} Curse of the Lost and {{CurseBlind}} Curse of the Blind#{{RadiantCard}} Uses {{Collectible651}} Star of Bethlehem")
    EID:addCard(Isaac.GetCardIdByName("FJudgement"), "{{RadiantCard}} Spawns a {{BatteryBeggar}} battery beggar or a {{RottenBeggar}} rotten beggar")
    EID:addCard(Isaac.GetCardIdByName("FWorld"), "{{RadiantCard}} Opens all doors#{{RadiantCard}} Spawns a {{LadderRoom}} trapdoor")
    EID:addCard(Isaac.GetCardIdByName("MPHierophant"), "{{RadiantCard}} Spawns 2 {{CementHeart}} cement hearts")
    EID:addCard(Isaac.GetCardIdByName("MPJustice"), "{{RadiantCard}} Spawns 2-4 {{DirtyChest}} old, {{Chest}} regular or {{HauntedChest}} haunted chests")
    EID:addCard(Isaac.GetCardIdByName("SRSuicideKing"), "{{RedCard}} Spawns 4 items from the current room's item pool#{{Warning}} Taking 2 makes the others vanish and uses {{Collectible475}}{{ColorRed}} Plan C")
    EID:addCard(Isaac.GetCardIdByName("SRKingofClubs"), "{{RedCard}}{{Warning}} Destroys all pickups in the current room#{{Indent}} Each has a 20% chance to become a {{Bomb}}{{ColorRed}} giga bomb{{ColorText}} instead")
    EID:addCard(Isaac.GetCardIdByName("SRJackofDiamonds"), "{{RedCard}} Spawns a {{Coin}} coin and turns all other coins into nickels")
    EID:addCard(Isaac.GetCardIdByName("GracefulCharity"), "{{YugiohCard}}{{Warning}} Destroys Isaac's 2 most recent items#Spawns 3 items from the current room's item pool")
    EID:addCard(Isaac.GetCardIdByName("DisgracefulCharity"), "{{YugiohCard}} Returns the difference if Isaac has fewer pickups than when he entered the floor")
    EID:addCard(Isaac.GetCardIdByName("SoulOfNehemiah"), "{{SoulofNehemiah}} Breaks all rocks in the room and spawns 3 rock chunks")

    -- Transformation Pointers
    EID:assignTransformation("collectible", Isaac.GetItemIdByName("Book of Ezra"), EID.TRANSFORMATION["BOOKWORM"])




    -- Compat
    if ANDROMEDA then
        EID:addCard(Isaac.GetCardIdByName("FStar"), "{{RadiantCard}} Teleports Isaac to the {{Planetarium}} planetarium#{{Indent}} Redirects to an {{AbPlanetarium}} abandoned planetarium if the item room was already visited")
    else
        EID:addCard(Isaac.GetCardIdByName("FStar"), "{{RadiantCard}} Teleports Isaac to the {{Planetarium}} planetarium")
    end

end