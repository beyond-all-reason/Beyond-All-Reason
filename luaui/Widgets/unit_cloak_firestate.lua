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
local CMD_WANT_CLOAK    = GameCMD.WANT_CLOAK
local FIRESTATE_HOLDFIRE = CMD.FIRESTATE_HOLDFIRE

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local myTeam = spGetMyTeamID()

local cloakFireState = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canCloak and unitDef.customParams.firestateoncloak and not string.find(unitDef.name, "_scav") then
		cloakFireState[unitDefID] = tonumber(unitDef.customParams.firestateoncloak) or FIRESTATE_HOLDFIRE
	end
end

local decloakFireState = {} --stores the desired fire state when decloaked of each unitID

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID ~= myTeam then return end

	if cmdID == CMD_WANT_CLOAK and cmdParams[1] ~= nil then -- is cloak command
		if not cloakFireState[unitDefID] then return end 

		if cmdParams[1] == 1 then -- store current fire state and cloak
			decloakFireState[unitID] = select(1, GetUnitStates(unitID, false)) --store last state
			local cloaktargetstate = cloakFireState[unitDefID]
			if decloakFireState[unitID] ~= cloaktargetstate then
				GiveOrderToUnit(unitID, CMD.FIRE_STATE, { cloaktargetstate }, 0)
			end
		else -- decloak and restore previous fire state
			local decloaktargetState = decloakFireState[unitID] or FIRESTATE_HOLDFIRE
			if select(1, GetUnitStates(unitID, false)) ~= decloaktargetState then
				GiveOrderToUnit(unitID, CMD.FIRE_STATE, { decloaktargetState }, 0) --revert to last state
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
