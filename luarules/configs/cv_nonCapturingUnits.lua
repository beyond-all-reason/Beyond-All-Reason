local nonCapturingUnits = {
"armdrag",
"cordrag",
"armfort",
"corfort",
"armfdrag",
"corfdrag",
"legfdrag",
"armeyes",
"coreyes",
"cormine1",
"cormine2",
"cormine3",
"cormine4",
"legmine1",
"legmine2",
"legmine3",
"armmine1",
"armmine2",
"armmine3",
}

-- for name, uDef in pairs(UnitDefs) do
-- 	if uDef.canFly then
-- 		table.insert(nonCapturingUnits, uDef.name)
-- 	end
-- end

return nonCapturingUnits
