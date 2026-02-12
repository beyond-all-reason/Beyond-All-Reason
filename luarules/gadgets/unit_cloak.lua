
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Cloak",	
		desc      = "optionally: decloaks units when they are damged",
		author    = "Google Frog", 
		date      = "Nov 25, 2009", -- changed Jan 6th 2026, by ZainMGit
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local decloakWhenDamaged = false

include("LuaRules/Configs/customcmds.h.lua")

local unitWantCloakCommandDesc = {
	id      = CMD_WANT_CLOAK,
	type    = CMDTYPE.ICON_MODE,
	name    = 'Cloak State',
	action  = 'wantcloak',
	queueing = false,
	tooltip	= 'invisiblility state',
	params 	= {0, 'Decloaked', 'Cloaked'}
}

local alliedTrueTable = {allied = true}

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spAreTeamsAllied = Spring.AreTeamsAllied
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spSetUnitCloak = Spring.SetUnitCloak
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spUseUnitResource = Spring.UseUnitResource
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitStates = Spring.GetUnitStates -- firestate tracking for cloak/decloak
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitCommands = Spring.GetUnitCommands
local spSetUnitTarget = Spring.SetUnitTarget -- clear auto-target when cloaking
local spGetUnitWeaponState = Spring.GetUnitWeaponState
local spSetUnitWeaponState = Spring.SetUnitWeaponState

local CMD_CLOAK = CMD.CLOAK
local CMD_ATTACK = CMD.ATTACK
local CMD_DGUN = CMD.DGUN
local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_FIGHT = CMD.FIGHT
local CMD_REMOVE = CMD.REMOVE
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local FIRE_STATE_HOLD_FIRE = 0
local WEAPON_HOLDFIRE_PAUSE = 100000
local DEFAULT_DECLOAK_TIME = 128
local UPDATE_FREQUENCY = 10
local CLOAK_MOVE_THRESHOLD = math.sqrt(0.2)
local recloakUnit = {}
local recloakFrame = {}
local currentFrame = 0
local fireStateBackup = {} --  firestate saved at cloak toggle
local holdFireUnits = {} -- units currently set to hold fire
local holdFireWeaponBackup = {} -- unit cached reload timers for hold fire pause
local isCommander = {}

local canCloak = {}
for udid, ud in pairs(UnitDefs) do
	if ud.canCloak then
		canCloak[udid] = {
			ud.startCloaked,
			ud.cloakCostMoving,
			ud.cloakCost,
		}
	end
	if ud.customParams and ud.customParams.iscommander then
		isCommander[udid] = true
	end
end

function PokeDecloakUnit(unitID, duration)
	if recloakUnit[unitID] then
		recloakUnit[unitID] = duration or DEFAULT_DECLOAK_TIME
	else
		spSetUnitRulesParam(unitID, 'cannotcloak', 1, alliedTrueTable)
		spSetUnitCloak(unitID, 0)
		recloakUnit[unitID] = duration or DEFAULT_DECLOAK_TIME
	end

end

GG.PokeDecloakUnit = PokeDecloakUnit

if decloakWhenDamaged then
	local noFFWeaponDefs = {}
	for i = 1, #WeaponDefs do
		local wd = WeaponDefs[i]
		if wd.customParams and wd.customParams.nofriendlyfire then
			noFFWeaponDefs[i] = true
		end
	end
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,  weaponID, attackerID, attackerDefID, attackerTeam)
		if damage > 0 and
			not (attackerTeam and
				weaponID and
				noFFWeaponDefs[weaponID] and
				attackerID ~= unitID and
				spAreTeamsAllied(unitTeam, attackerTeam)) then
			PokeDecloakUnit(unitID)
		end
	end
end

function gadget:GameFrame(n)
	currentFrame = n
	if n%UPDATE_FREQUENCY == 2 then
		for unitID, frames in pairs(recloakUnit) do
			if frames <= UPDATE_FREQUENCY then
				local onFire = spGetUnitRulesParam(unitID,'on_fire')
				local disarmed = spGetUnitRulesParam(unitID,'disarmed')
				if not (onFire == 1 or disarmed == 1) then
					local wantCloakState = spGetUnitRulesParam(unitID, 'wantcloak')
					local areaCloaked = spGetUnitRulesParam(unitID, 'areacloaked')
					spSetUnitRulesParam(unitID, 'cannotcloak', 0, alliedTrueTable)
					if wantCloakState == 1 or areaCloaked == 1 then
						spSetUnitCloak(unitID, 1)
					end
					recloakUnit[unitID] = nil
				end
			else
				recloakUnit[unitID] = frames - UPDATE_FREQUENCY
			end
		end
		--Removable after an engine update
		for unitID in pairs(holdFireUnits) do
			local fireState = select(1, spGetUnitStates(unitID, false))
			if fireState ~= FIRE_STATE_HOLD_FIRE then
				holdFireUnits[unitID] = nil
				-- leaving hold fire: restore any paused commander weapon timers
				local weaponData = holdFireWeaponBackup[unitID]
				if weaponData then
					for weaponID, data in pairs(weaponData) do
						spSetUnitWeaponState(unitID, weaponID, {reloadTime = data.reloadTime, reloadState = currentFrame + data.remaining})
					end
					holdFireWeaponBackup[unitID] = nil
				end
			else
				if not isCommander[spGetUnitDefID(unitID)] then
					holdFireUnits[unitID] = nil
				else
				-- enforce hold fire for commanders, drop targets and remove attack orders repeatedly
				spSetUnitTarget(unitID, nil)
				local cmdID, _, cmdTag = spGetUnitCurrentCommand(unitID)
				if cmdTag and (cmdID == CMD_ATTACK or cmdID == CMD_FIGHT or cmdID == CMD_DGUN) then
					spGiveOrderToUnit(unitID, CMD_REMOVE, {cmdTag}, 0)
				end
				local commands = spGetUnitCommands(unitID, -1)
				if commands then
					for i = 1, #commands do
						local cmd = commands[i]
						if cmd.tag and (cmd.id == CMD_ATTACK or cmd.id == CMD_FIGHT or cmd.id == CMD_DGUN) then
							spGiveOrderToUnit(unitID, CMD_REMOVE, {cmd.tag}, 0)
						end
					end
				end
				if CMD_UNIT_CANCEL_TARGET then
					spGiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET, {}, 0)
				end
				end
			end
		end
	end
end

-- Only called with enemyID if an enemy is within decloak radius
function gadget:AllowUnitCloak(unitID, enemyID)
	if enemyID then
		return false
	end

	if recloakFrame[unitID] then
		if recloakFrame[unitID] > currentFrame then
			return false
		end
		recloakFrame[unitID] = nil
	end

	local stunnedOrInbuild = spGetUnitIsStunned(unitID)
	if stunnedOrInbuild then
		return false
	end

	local unitDefID = unitID and spGetUnitDefID(unitID)
	if not canCloak[unitDefID] then
		return false
	end

	local areaCloaked = (spGetUnitRulesParam(unitID, 'areacloaked') == 1) and ((spGetUnitRulesParam(unitID, 'cloak_shield') or 0) == 0)
	if not areaCloaked then
		local speed = select(4, spGetUnitVelocity(unitID))
		local moving = speed and speed > CLOAK_MOVE_THRESHOLD
		local cost = moving and canCloak[unitDefID][2] or canCloak[unitDefID][3]

		if not spUseUnitResource(unitID, "e", cost/2) then -- SlowUpdate happens twice a second.
			return false
		end
	end

	return true
end

function gadget:AllowUnitDecloak(unitID, objectID, weaponID)
	recloakFrame[unitID] = currentFrame + DEFAULT_DECLOAK_TIME
end

local function SetWantedCloaked(unitID, state)
	if not unitID or spGetUnitIsDead(unitID) then
		return
	end

	local unitDefID = spGetUnitDefID(unitID)
	local wantCloakState = spGetUnitRulesParam(unitID, 'wantcloak')
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_WANT_CLOAK)
	if cmdDescID then
		spEditUnitCmdDesc(unitID, cmdDescID, { params = {state, 'Decloaked', 'Cloaked'}})
	end

	if state == 1 and wantCloakState ~= 1 then
		-- preserve pre-cloak firestate for restore on decloak 
		fireStateBackup[unitID] = select(1, spGetUnitStates(unitID, false))
		local cannotCloak = spGetUnitRulesParam(unitID, 'cannotcloak')
		local areaCloaked = spGetUnitRulesParam(unitID, 'areacloaked')
		if cannotCloak ~= 1 and areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 1)
		end
		spSetUnitRulesParam(unitID, 'wantcloak', 1, alliedTrueTable)
		local cmdID, _, cmdTag = spGetUnitCurrentCommand(unitID)
		if cmdTag and (cmdID == CMD_ATTACK or cmdID == CMD_FIGHT or cmdID == CMD_DGUN) then
			spGiveOrderToUnit(unitID, CMD_REMOVE, {cmdTag}, 0)
		end
		local commands = spGetUnitCommands(unitID, -1)
		if commands then
			for i = 1, #commands do
				local cmd = commands[i]
				if cmd.tag and (cmd.id == CMD_ATTACK or cmd.id == CMD_FIGHT or cmd.id == CMD_DGUN) then
					spGiveOrderToUnit(unitID, CMD_REMOVE, {cmd.tag}, 0)
				end
			end
		end
		-- drop any current auto-target so fire at will cannot keep shooting
		spSetUnitTarget(unitID, nil)
		-- force hold fire while cloaked
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, {FIRE_STATE_HOLD_FIRE}, 0)
		if CMD_UNIT_CANCEL_TARGET then
			spGiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET, {}, 0)
		end
	elseif state == 0 and wantCloakState == 1 then
		-- restore firestate after uncloaking
		local fireState = fireStateBackup[unitID]
		if fireState ~= nil then
			spGiveOrderToUnit(unitID, CMD_FIRE_STATE, {fireState}, 0)
		end
		fireStateBackup[unitID] = nil
		local areaCloaked = spGetUnitRulesParam(unitID, 'areacloaked')
		if areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 0)
		end
		spSetUnitRulesParam(unitID, 'wantcloak', 0, alliedTrueTable)
	end
end

GG.SetWantedCloaked = SetWantedCloaked

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_CLOAK] = true, [CMD_WANT_CLOAK] = true, [CMD_FIRE_STATE] = true, [CMD_MANUALFIRE] = true, [CMD_DGUN] = true, [CMD_ATTACK] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_WANT_CLOAK then
		if canCloak[unitDefID] then
			SetWantedCloaked(unitID, cmdParams[1])
		end
		return true
	elseif cmdID == CMD_ATTACK then
		-- manual attack should decloak so the command can fire immediately (commanders only)
		if isCommander[unitDefID] and spGetUnitRulesParam(unitID, 'wantcloak') == 1 then
			SetWantedCloaked(unitID, 0)
		end
		return true
	elseif cmdID == CMD_MANUALFIRE or cmdID == CMD_DGUN then
		-- manual fire should always decloak so the shot can happen (commanders only)
		if isCommander[unitDefID] and spGetUnitRulesParam(unitID, 'wantcloak') == 1 then
			SetWantedCloaked(unitID, 0)
		end
		return true
	elseif cmdID == CMD_FIRE_STATE then
		if cmdParams[1] == FIRE_STATE_HOLD_FIRE and isCommander[unitDefID] then
			holdFireUnits[unitID] = true
			-- hold fire should immediately drop any auto/priority target for commanders
			spSetUnitTarget(unitID, nil)
			if isCommander[unitDefID] and not holdFireWeaponBackup[unitID] then
				-- pause commander weapons so ongoing shots stop immediately
				local weapons = UnitDefs[unitDefID].weapons
				if weapons and #weapons > 0 then
					local weaponData = {}
					for i = 1, #weapons do
						local reloadState = spGetUnitWeaponState(unitID, i, 'reloadState')
						if reloadState then
							local reloadTime = spGetUnitWeaponState(unitID, i, 'reloadTime')
							local remaining = reloadState - currentFrame
							if remaining < 0 then
								remaining = 0
							end
							weaponData[i] = {
								remaining = remaining,
								reloadTime = reloadTime,
							}
							spSetUnitWeaponState(unitID, i, {reloadTime = WEAPON_HOLDFIRE_PAUSE, reloadState = currentFrame + WEAPON_HOLDFIRE_PAUSE})
						end
					end
					if next(weaponData) then
						holdFireWeaponBackup[unitID] = weaponData
					end
				end
			end
			local cmdIDCurrent, _, cmdTag = spGetUnitCurrentCommand(unitID)
			if cmdTag and (cmdIDCurrent == CMD_ATTACK or cmdIDCurrent == CMD_FIGHT or cmdIDCurrent == CMD_DGUN) then
				spGiveOrderToUnit(unitID, CMD_REMOVE, {cmdTag}, 0)
			end
			local commands = spGetUnitCommands(unitID, -1)
			if commands then
				for i = 1, #commands do
					local cmd = commands[i]
					if cmd.tag and (cmd.id == CMD_ATTACK or cmd.id == CMD_FIGHT or cmd.id == CMD_DGUN) then
						spGiveOrderToUnit(unitID, CMD_REMOVE, {cmd.tag}, 0)
					end
				end
			end
			if CMD_UNIT_CANCEL_TARGET then
				spGiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET, {}, 0)
			end
		else
			holdFireUnits[unitID] = nil
			local weaponData = holdFireWeaponBackup[unitID]
			if weaponData then
				for weaponID, data in pairs(weaponData) do
					spSetUnitWeaponState(unitID, weaponID, {reloadTime = data.reloadTime, reloadState = currentFrame + data.remaining})
				end
				holdFireWeaponBackup[unitID] = nil
			end
		end
		return true
	else -- cmdID == CMD_CLOAK
		return false
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if canCloak[unitDefID] then
		local cloakDescID = spFindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			spInsertUnitCmdDesc(unitID, unitWantCloakCommandDesc)
			spRemoveUnitCmdDesc(unitID, cloakDescID)
			spSetUnitRulesParam(unitID, 'wantcloak', 0, alliedTrueTable)
			if canCloak[unitDefID][1] then
				SetWantedCloaked(unitID, 1)
			end
			return
		end
	end
end

function gadget:UnitDestroyed(unitID)
	fireStateBackup[unitID] = nil
	holdFireUnits[unitID] = nil
	holdFireWeaponBackup[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_CLOAK)
	gadgetHandler:RegisterAllowCommand(CMD_WANT_CLOAK)
	gadgetHandler:RegisterAllowCommand(CMD_FIRE_STATE)
	gadgetHandler:RegisterAllowCommand(CMD_MANUALFIRE)
	gadgetHandler:RegisterAllowCommand(CMD_DGUN)
	gadgetHandler:RegisterAllowCommand(CMD_ATTACK)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end
