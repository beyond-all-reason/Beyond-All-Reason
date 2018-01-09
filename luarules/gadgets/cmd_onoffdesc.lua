if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
	name 	= "On/Off descriptions",
	desc	= "Replaces On/Off tooggle with description",
	author	= "Doo",
	date	= "09 January 2018",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc   = Spring.FindUnitCmdDesc

VFS.Include("luarules/configs/onoffdescs.lua")
onoffNames = {}

for unitDefID = 1, #UnitDefs do
	local ud = UnitDefs[unitDefID]
	if ud.customParams and ud.customParams.onoffname then
		onoffNames[unitDefID] = ud.customParams and ud.customParams.onoffname
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if onoffNames[unitDefID] then
			local cmdDesc = spFindUnitCmdDesc(unitID, CMD.ONOFF)
			if cmdDesc then
				spEditUnitCmdDesc(unitID, cmdDesc, cmdArray[onoffNames[unitDefID]])
			end
		end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
	end
end