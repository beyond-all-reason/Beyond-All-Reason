function gadget:GetInfo()
	return {
		name = "Mission API",
		desc = "Mission API functions",
		author = "WTF, wilkubyk",
		date = "2023.02.01",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[Each section use function that can be called to initialize special features for each mission.
Each function will specify beforehead which table is required for it to work correctly.
If you find any bugs or better way for optimization feel free to do so.
]]--
if not gadgetHandler:IsSyncedCode() then
	return
end
local objectiveUnits = {}


--[[ API_GiveOrderToUnit require those tables in designated *.lua files
	for all the features to load properly: 
	objectiveUnits = {} specifiy initial units, position, team, rotation and 
	additional pos for orders. 
]]--
local function giveOrderToUnit(unitID, orders)
	for k , unit in pairs(objectiveUnits) do
		if UnitDefNames[unit.name] then
			unitID = Spring.CreateUnit(unit.name, unit.x, unit.y, unit.z, unit.rot, unit.teamID)

			for i = 1, #unit.queue do
				local order = unit.queue[i]
				order.position = {order.position["px"], order.position["py"], order.position["pz"]}
				Spring.GiveOrderToUnit(unitID, order.cmdID, order.position, CMD.OPT_SHIFT)
			end
		end
	end
end
--[[ API_Triggers require those tables in designated *.lua files
	for all the features to load properly:
	= {}
]]--
function API_Triggers()

end

function gadget:Initialize()
	GG['missionAPI'] = {}
	GG['missionAPI'].GiveOrderToUnit = giveOrderToUnit
end

function gadget:ShutDown()
	GG['missionAPI'] = nil
end