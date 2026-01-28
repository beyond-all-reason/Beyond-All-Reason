--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Cloak Fire State",
		desc      = "Sets units to Hold Fire when cloaked, reverts to original state when decloaked",
		author    = "KingRaptor (L.J. Lim)",
		date      = "Feb 14, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = -1,
		enabled   = true
	}
end


-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetMyTeamID

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Speedups
local GiveOrderToUnit   = Spring.GiveOrderToUnit
local GetUnitStates     = Spring.GetUnitStates
local GiveOrder         = Spring.GiveOrder
local CMD_WANT_CLOAK    = GameCMD.WANT_CLOAK
local CMD_OPT_ALT       = CMD.OPT_ALT
local CMD_INSERT        = CMD.INSERT
local CMD_STOP          = CMD.STOP
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local myTeam = spGetMyTeamID()

local exceptionList = { --add exempt units here
	"armmine1",
	"armmine2",
	"armmine3",
	"armfmine3",
	"cormine1",
	"cormine2",
	"cormine3",
	"cormine4",
	"corfmine3",
	"legmine1",
	"legmine2",
	"legmine3",
	"corsktl",
	"armpb",
	"armamb",
	"armferret",
	"armsnipe",
}

local exceptionArray = {}
for _,name in pairs(exceptionList) do
	local ud = UnitDefNames[name]
	if ud then
		exceptionArray[ud.id] = true
	end
end

local function setFireState(unitID, fireState)
	GiveOrderToUnit(unitID, CMD.FIRE_STATE, { fireState }, 0)

	-- if fireState is 0 (hold fire), insert a stop command so we stop firing immediately and can cloak without delay
	if fireState == 0 then
		GiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_STOP, 0}, CMD_OPT_ALT)
	end
end

local decloakFireState = {} --stores the desired fire state when decloaked of each unitID

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID ~= myTeam then return end

	if cmdID == CMD_WANT_CLOAK and cmdParams[1] ~= nil then -- is cloak command
		if exceptionArray[unitDefID] or string.find(UnitDefs[unitDefID].name, "_scav") then return end -- don't do anything for these units

		if cmdParams[1] == 1 then -- store current fire state and cloak
			decloakFireState[unitID] = select(1, GetUnitStates(unitID, false)) --store last state
			if decloakFireState[unitID] ~= 0 then
				setFireState(unitID, 0)
			end
		else -- decloak and restore previous fire state
			if select(1, GetUnitStates(unitID, false)) == 0 then
				local targetState = decloakFireState[unitID] or 0 -- default to hold fire if no cached state is found
				setFireState(unitID, targetState)
			end
			decloakFireState[unitID] = nil
		end
	end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam then
		decloakFireState[unitID] = select(1, GetUnitStates(unitID, false))	-- 1=firestate
	else
		decloakFireState[unitID] = nil
	end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if decloakFireState[unitID] then
		decloakFireState[unitID] = nil
	end
end

------------------------------------------------------------------------------------------------
---------------------------------- SETUP AND TEARDOWN ------------------------------------------
------------------------------------------------------------------------------------------------


local function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0) or Spring.IsReplay() then
		widgetHandler:RemoveWidget()
	end
end

function widget:Initialize()
	myTeam = spGetMyTeamID()
	maybeRemoveSelf()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function widget:PlayerChanged()
	myTeam = spGetMyTeamID()
	maybeRemoveSelf()
end
