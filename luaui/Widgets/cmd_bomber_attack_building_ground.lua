local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name         = "Bomber Attack Building Ground",
      desc         = "Bombers attack ground under buildings instead of snapping on the unit itself (which disappears when out of los)",
      author       = "Floris",
      date         = "May 2021",
	  license      = "GNU GPL, v2 or later",
      layer        = 0,
      enabled      = true
   }
end

local losGraceRadius = 75
local monitorTargets = {}
local CMD_ATTACK = CMD.ATTACK
local CMD_STOP = CMD.STOP
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrder = Spring.GiveOrder
local spGetUnitCommands = Spring.GetUnitCommands
local spIsPosInLos = Spring.IsPosInLos
local spValidUnitID = Spring.ValidUnitID

local isBuilding = {}
local isBomber = {}
local isBomb = {}
for id, wDef in pairs(WeaponDefs) do
	if wDef.type == "AircraftBomb" then
		isBomb[id] = true
	end
end
for udid, ud in pairs(UnitDefs) do
	if ud.isBuilding or string.find(ud.name, "nanotc") then
		isBuilding[udid] = true
	end
	if (ud["weapons"] and ud["weapons"][1] and isBomb[ud["weapons"][1].weaponDef] == true) or (string.find(ud.name, 'armlance') or string.find(ud.name, 'cortitan') or string.find(ud.name, 'legatorpbomber')) then
		isBomber[udid] = true
	end
end
isBomb = nil


function widget:GameFrame(gf)
	if gf % 7 == 1 then
		for unitID, params in pairs(monitorTargets) do
			if not spValidUnitID(unitID) then
				if spIsPosInLos(params[1]-losGraceRadius,params[2],params[3]+losGraceRadius) and		-- check wider area because unit can be marked invalid while just becoming in los
					spIsPosInLos(params[1]-losGraceRadius,params[2],params[3]-losGraceRadius) and
					spIsPosInLos(params[1]+losGraceRadius,params[2],params[3]-losGraceRadius) and
					spIsPosInLos(params[1]+losGraceRadius,params[2],params[3]+losGraceRadius)
				then
					for bomberID, _ in pairs(params[4]) do
						if spValidUnitID(bomberID) then
							local cmds = spGetUnitCommands(bomberID,100)

							-- remove commands
							spGiveOrderToUnit(bomberID, CMD_STOP, {}, 0)

							-- reinsert commands
							for i=1, #cmds do
								local cmd = cmds[i]
								if cmd.id ~= CMD_ATTACK or (cmd.params[1] ~= params[1] and cmd.params[1] ~= params[1] and cmd.params[1] ~= params[1]) then
									spGiveOrderToUnit(bomberID, cmd.id, cmd.params, {"shift"} )
								end
							end
						end
						monitorTargets[unitID] = nil
					end
				end
			end
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if cmdID ~= CMD_ATTACK then
		return false
	end
	-- number of cmdParams should either be
	-- 1 (unitID) or
	-- 3 (map coordinates)
	if #cmdParams ~= 1 then
		return false
	end
	local targetBuildingID = cmdParams[1]
	if not isBuilding[spGetUnitDefID(targetBuildingID)] then
		return false
	end
	local targetBuildingPosX, targetBuildingPosY, targetBuildingPosZ = Spring.GetUnitPosition(targetBuildingID)

	local units = Spring.GetSelectedUnits()
	local hasBomber = false
	for i=1, #units do
		local unitID = units[i]
		if isBomber[spGetUnitDefID(unitID)] then
			spGiveOrder(cmdID, { targetBuildingPosX, targetBuildingPosY, targetBuildingPosZ}, cmdOptions)
			if not monitorTargets[targetBuildingID] then
				monitorTargets[targetBuildingID] = { targetBuildingPosX, targetBuildingPosY, targetBuildingPosZ, {} }
			end
			monitorTargets[targetBuildingID][4][unitID] = true
			hasBomber = true
		end
	end
	return hasBomber
end
