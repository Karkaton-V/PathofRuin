-- Compat with God's Gambit, guarded on the GodsGambit global so the file no-ops when that mod is absent, same pattern as compat/eid.lua
if GodsGambit then
    local CHARITY_TYPE = Isaac.GetEntityTypeByName("Charity")
    local CHARITY_VARIANT = Isaac.GetEntityVariantByName("Charity")
    local SUPER_CHARITY_VARIANT = Isaac.GetEntityVariantByName("Super Charity")

    -- Charity stands in for Greed on shop raids, looked up by name rather than by literal id since the mod packs fifty unrelated bosses into the same entity type
    if CHARITY_TYPE > 0 and CHARITY_VARIANT >= 0 and SUPER_CHARITY_VARIANT >= 0 then
        POR.ShopRaid.Boss = {
            Type = CHARITY_TYPE,
            Variant = CHARITY_VARIANT,
            SuperVariant = SUPER_CHARITY_VARIANT,
        }
    end
end
