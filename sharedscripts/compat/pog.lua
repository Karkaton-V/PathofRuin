-- Compat with the POG for Good Items mod, guarded on the Poglite global as in compat/eid.lua; only The Condemned needs registering
if Poglite then
    local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)
    local POG_COSTUME = Isaac.GetCostumeIdByPath("gfx/characters/nehemiahbpog.anm2")

    Poglite:AddPogCostume("PORCondemnedPog", TAINTED_NEHEMIAH_TYPE, POG_COSTUME)
end
