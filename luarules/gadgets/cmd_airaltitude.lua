function gadget:GetInfo()
	return {
		name 	= "Command Low/cruise Altitude",
		desc	= "Enables low/cruise altitude flightmodes for planes",
		author	= "Doo",
		date	= "Sept 19th 2017",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = false,
	}
end
include("LuaRules/Configs/customcmds.h.lua")

if gadgetHandler:IsSyncedCode() then

CMD.ALTITUDE = 39999
CMD_ALTITUDE = 39999

nolowalt = {
	armatlas = true,
	armdfly = true,
	corvalk = true,
	corseah = true,
	}

local CruiseAltDesc = {
	id      = CMD_ALTITUDE,
	type    = CMDTYPE.ICON_MODE,
	name    = 'Altitude',
	action  = 'altitude',
	tooltip = 'Toggle for low altitude flightmode',
	params  = { '0', 'CruiseAlt', 'LowAlt'} ,
}
local LowAltDesc = {
	id      = CMD_ALTITUDE,
	type    = CMDTYPE.ICON_MODE,
	name    = 'Altitude',
	action  = 'altitude',
	tooltip = 'Toggle for low altitude flightmode',
	params  = { '1', 'CruiseAlt', 'LowAlt'} ,
}

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID)
	end
end

function gadget:UnitCreated(unitID)
	if UnitDefs[Spring.GetUnitDefID(unitID)].canFly == true then
		Spring.InsertUnitCmdDesc(unitID, CMD.ALTITUDE, CruiseAltDesc)
		if UnitDefs[Spring.GetUnitDefID(unitID)].hoverAttack == false then
			Spring.MoveCtrl.SetAirMoveTypeData(unitID, "wantedHeight", UnitDefs[Spring.GetUnitDefID(unitID)].wantedHeight)
		else
			Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "wantedHeight", UnitDefs[Spring.GetUnitDefID(unitID)].wantedHeight)
		end
	end
end

function gadget:AllowCommand(unitID,_,_,cmdID,cmdParams)
	if cmdID == CMD.ALTITUDE then
	cmdDescId = Spring.FindUnitCmdDesc(unitID, CMD.ALTITUDE) 
		if cmdParams[1] == 1 then
			Spring.EditUnitCmdDesc(unitID, cmdDescId, LowAltDesc)
			if UnitDefs[Spring.GetUnitDefID(unitID)].hoverAttack == false then
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, "wantedHeight", 30)
			else
				Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "wantedHeight", 30)
			end
		elseif cmdParams[1] == 0 then
			Spring.EditUnitCmdDesc(unitID, cmdDescId, CruiseAltDesc)
			if UnitDefs[Spring.GetUnitDefID(unitID)].hoverAttack == false then
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, "wantedHeight", UnitDefs[Spring.GetUnitDefID(unitID)].wantedHeight)
			else
				Spring.MoveCtrl.SetGunshipMoveTypeData(unitID, "wantedHeight", UnitDefs[Spring.GetUnitDefID(unitID)].wantedHeight)
			end
		end
		return false
	end
	return true
end
end
