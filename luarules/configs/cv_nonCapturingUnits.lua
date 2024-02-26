local nonCapturingUnits = {
"armada_dragonsteeth",
"cortex_dragonsteeth",
"armada_fortificationwall",
"cortex_fortificationwall",
"armada_sharksteeth",
"cortex_sharksteeth",
"armada_beholder",
"cortex_beholder",
"cortex_lightmine",
"cortex_mediummine",
"cortex_heavymine",
"cortex_mediumminecommando",
"armada_lightmine",
"armada_mediummine",
"armada_heavymine",
}

-- for name, uDef in pairs(UnitDefs) do
-- 	if uDef.canFly then
-- 		table.insert(nonCapturingUnits, uDef.name)
-- 	end
-- end

return nonCapturingUnits
