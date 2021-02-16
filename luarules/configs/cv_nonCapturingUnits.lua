--[[
local nonCapturingUnits = {
	"eairengineer",
	"efighter",
	"efighter_up1",
	"efighter_up2",
	"efighter_up3",
	--"escout",
	"egunship2",
	"egunship2_up1",
	"egunship2_up2",
	"egunship2_up3",
	"etransport",
	"etransport_up1",
	"etransport_up2",
	"etransport_up3",
	"edrone",
	"ebomber",
	"ebomber_up1",
	"ebomber_up2",
	"ebomber_up3",
	--"escout",
}
]]
nonCapturingUnits = {
"armdrag",
"cordrag",
"armfort",
"corfort",
"armfdrag",
"corfdrag",
"armeyes",
"coreyes",
"cormine1",
"cormine2",
"cormine3",
"cormine4",
"armmine1",
"armmine2",
"armmine3",
}

for name, uDef in pairs(UnitDefs) do
	if uDef.canFly then
		table.insert(nonCapturingUnits, uDef.name)
	end
end

return nonCapturingUnits
