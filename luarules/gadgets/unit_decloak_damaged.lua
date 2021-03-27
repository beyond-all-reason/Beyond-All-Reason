--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Decloak when damaged",
		desc      = "Decloaks units when they are damged",
		author    = "Google Frog",
		date      = "Nov 25, 2009", -- Major rework 12 Feb 2014
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

include("LuaRules/Configs/customcmds.h.lua")

local CMD_CLOAK = CMD.CLOAK

local unitWantCloakCommandDesc = {
	id      = CMD_WANT_CLOAK,
	type    = CMDTYPE.ICON_MODE,
	name    = 'Cloak State',
	action  = 'wantcloak',
	queueing = false,
	tooltip	= 'invisiblility state',
	params 	= {0, 'Decloaked', 'Cloaked'}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if not gadgetHandler:IsSyncedCode() then
  return false  --  silent removal
end

local alliedTrueTable = {allied = true}

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spAreTeamsAllied = Spring.AreTeamsAllied
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spSetUnitCloak = Spring.SetUnitCloak
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitVelocity = Spring.GetUnitVelocity
local spUseUnitResource = Spring.UseUnitResource
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc

local recloakUnit = {}
local recloakFrame = {}

local noFFWeaponDefs = {}
for i = 1, #WeaponDefs do
	local wd = WeaponDefs[i]
	if wd.customParams and wd.customParams.nofriendlyfire then
		noFFWeaponDefs[i] = true
	end
end

local DEFAULT_DECLOAK_TIME = 128
local UPDATE_FREQUENCY = 10
local CLOAK_MOVE_THRESHOLD = math.sqrt(0.2)

local currentFrame = 0

local cloakUnitDefID = {}
for udid, ud in pairs(UnitDefs) do
	if ud.canCloak then
		cloakUnitDefID[udid] = ud.startCloaked and '1' or '0'
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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

--function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,  weaponID, attackerID, attackerDefID, attackerTeam)
	-- if damage > 0 and
		-- not (attackerTeam and
		-- weaponID and
		-- noFFWeaponDefs[weaponID] and
		-- attackerID ~= unitID and
		-- spAreTeamsAllied(unitTeam, attackerTeam)) then
		-- PokeDecloakUnit(unitID)
	-- end
--end


function gadget:GameFrame(n)
	currentFrame = n
	if n%UPDATE_FREQUENCY == 2 then
		for unitID, frames in pairs(recloakUnit) do
			if frames <= UPDATE_FREQUENCY then
				if not ((spGetUnitRulesParam(unitID,'on_fire') == 1) or (spGetUnitRulesParam(unitID,'disarmed') == 1)) then
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

		local i = 1
	end
end

-- Only called with enemyID if an enemy is within decloak radius.
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
	local ud = unitDefID and UnitDefs[unitDefID]
	if not ud then
		return false
	end

	local areaCloaked = (spGetUnitRulesParam(unitID, 'areacloaked') == 1) and ((spGetUnitRulesParam(unitID, 'cloak_shield') or 0) == 0)
	if not areaCloaked then
		local speed = select(4, spGetUnitVelocity(unitID))
		local moving = speed and speed > CLOAK_MOVE_THRESHOLD
		local cost = moving and ud.cloakCostMoving or ud.cloakCost

		if not spUseUnitResource(unitID, "e", cost/2) then -- SlowUpdate happens twice a second.
			return false
		end
	end

	return true
end

function gadget:AllowUnitDecloak(unitID, objectID, weaponID)
	recloakFrame[unitID] = currentFrame + DEFAULT_DECLOAK_TIME
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function SetWantedCloaked(unitID, state)
	if (not unitID) or spGetUnitIsDead(unitID) then
		return
	end

	local wantCloakState = spGetUnitRulesParam(unitID, 'wantcloak')
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_WANT_CLOAK)
	if (cmdDescID) then
		spEditUnitCmdDesc(unitID, cmdDescID, { params = {state, 'Decloaked', 'Cloaked'}})
	end

	if state == 1 and wantCloakState ~= 1 then
		local cannotCloak = spGetUnitRulesParam(unitID, 'cannotcloak')
		local areaCloaked = spGetUnitRulesParam(unitID, 'areacloaked')
		if cannotCloak ~= 1 and areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 1)
		end
		spSetUnitRulesParam(unitID, 'wantcloak', 1, alliedTrueTable)
	elseif state == 0 and wantCloakState == 1 then
		local areaCloaked = spGetUnitRulesParam(unitID, 'areacloaked')
		if areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 0)
		end
		spSetUnitRulesParam(unitID, 'wantcloak', 0, alliedTrueTable)
	end
end

GG.SetWantedCloaked = SetWantedCloaked

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_CLOAK] = true, [CMD_WANT_CLOAK] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD_WANT_CLOAK then
		if cloakUnitDefID[unitDefID] then
			SetWantedCloaked(unitID,cmdParams[1])
		end
		return true
	elseif cmdID == CMD_CLOAK then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID)
	if cloakUnitDefID[unitDefID] then
		local cloakDescID = spFindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			spInsertUnitCmdDesc(unitID, unitWantCloakCommandDesc)
			spRemoveUnitCmdDesc(unitID, cloakDescID)
			spSetUnitRulesParam(unitID, 'wantcloak', 0, alliedTrueTable)
			if cloakUnitDefID[unitDefID] == '1' then
				SetWantedCloaked(unitID, 1)
			end
			return
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
	end
end
