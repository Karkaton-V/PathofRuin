-- Compat with Fiend Folio, guarded on the FiendFolio global so the file no-ops when that mod is absent, same pattern as compat/eid.lua
if FiendFolio then
    local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)

    -- Copper Bombs break the secret doors for The Condemned in one blast, matching the giga bomb test already registered in custom_secret_door.lua
    table.insert(POR.SecretDoor.OneShotBombTests, function(bomb)
        return FiendFolio.CopperBombVariants[bomb.Variant] == true
    end)

    -- True if either trinket slot holds one of the Golem rock trinkets, using the Fiend Folio definition of the set
    local function holdsRockTrinket(player)
        for slot = 0, 1 do
            if FiendFolio.IsRockTrinket(player:GetTrinket(slot)) then return true end
        end
        return false
    end

    -- True once Fiend Folio has built the subway map, which the spawn call indexes unconditionally
    local function subwayMapExists()
        if not FiendFolio.ShouldSpawnGolemSubway() then return false end

        local defaultMap = StageAPI.GetDefaultLevelMap()
        local subwayRoomData = defaultMap and defaultMap:GetRoomDataFromRoomID("GolemSubway")
        local subwayRoom = subwayRoomData and defaultMap:GetRoom(subwayRoomData)
        return subwayRoom ~= nil and subwayRoom.PersistentData ~= nil and subwayRoom.PersistentData.Connections ~= nil
    end

    -- Registered ahead of the Member Card reward, so a rock trinket sends The Condemned to Golem's Subway rather than the Gideon crawl space or the shop
    table.insert(POR.RaidRewardOverrides, function(player)
        if player:GetPlayerType() ~= TAINTED_NEHEMIAH_TYPE or not holdsRockTrinket(player) then return false end
        if not subwayMapExists() then return false end

        POR.ShopRaid.ClearTrapdoors()
        FiendFolio:TrySpawnGolemSubwayTrapdoor(true)
        return true
    end)
end
