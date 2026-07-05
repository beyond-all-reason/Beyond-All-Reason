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
local Firestates = VFS.Include("modules/firestates.lua")
VFS.Include("luaui/Include/firestate_api.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Speedups
local CMD_WANT_CLOAK    = GameCMD.WANT_CLOAK
local FIRESTATE_HOLDFIRE = CMD.FIRESTATE_HOLDFIRE

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local myTeam = spGetMyTeamID()

local cloakFireState = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canCloak and unitDef.customParams.firestateoncloak and not unitDef.customParams.isscavenger then
		cloakFireState[unitDefID] = tonumber(unitDef.customParams.firestateoncloak) or FIRESTATE_HOLDFIRE
	end
end

local decloakFireState = {} --stores the desired fire state when decloaked of each unitID
local cloakActive = {}

local function onUserFirestateWhileCloaked(unitID, userState)
	if not cloakActive[unitID] then
		return
	end
	if not cloakFireState[Spring.GetUnitDefID(unitID)] then
		return
	end
	if userState == Firestates.HOLD_FIRE then
		return
	end
	decloakFireState[unitID] = userState
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID ~= myTeam then return end

	if cmdID == CMD_WANT_CLOAK and cmdParams[1] ~= nil then -- is cloak command
		if not cloakFireState[unitDefID] then return end

		if cmdParams[1] == 1 then -- store current fire state and cloak
			cloakActive[unitID] = true
			decloakFireState[unitID] = Firestates.resolveUserFirestate(unitID) --store last state
			local cloaktargetstate = cloakFireState[unitDefID]
			local cloakTargetUserState = Firestates.fromEngineFirestate(cloaktargetstate)
			if Firestates.resolveUserFirestate(unitID) ~= cloakTargetUserState then
				WG['firestate'].setState(cloakTargetUserState, { unitID }, { userInitiated = false })
			end
		else -- decloak and restore previous fire state
			local decloaktargetState = decloakFireState[unitID] or Firestates.HOLD_FIRE
			if Firestates.resolveUserFirestate(unitID) ~= decloaktargetState then
				WG['firestate'].setState(decloaktargetState, { unitID }, { userInitiated = false }) --revert to last state
			end
			cloakActive[unitID] = nil
			decloakFireState[unitID] = nil
		end
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitTeam == myTeam then
		decloakFireState[unitID] = Firestates.resolveUserFirestate(unitID)	-- 1=firestate
	else
		decloakFireState[unitID] = nil
		cloakActive[unitID] = nil
	end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	widget:UnitCreated(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if decloakFireState[unitID] then
		decloakFireState[unitID] = nil
	end
	cloakActive[unitID] = nil
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
	local previousOnUserFirestate = WG['firestate'].onUserFirestate
	WG['firestate'].onUserFirestate = function(unitID, userState)
		onUserFirestateWhileCloaked(unitID, userState)
		if previousOnUserFirestate then
			previousOnUserFirestate(unitID, userState)
		end
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function widget:PlayerChanged()
	myTeam = spGetMyTeamID()
	maybeRemoveSelf()
end
