--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Decloak when damaged",
    desc      = "Decloaks units when they are damged",
    author    = "Google Frog",
    date      = "Nov 25, 2009", -- Major rework 12 Feb 2014
    license   = "GNU GPL, v2 or later",
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
	tooltip	= 'Unit cloaking state',
	params 	= {0, 'Decloaked', 'Cloaked'}
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false  --  silent removal
end

local alliedTrueTable = {allied = true}

local Spring = Spring
local spAreTeamsAllied = Spring.AreTeamsAllied

local spSetUnitCloak = Spring.SetUnitCloak
local spGetUnitIsCloaked = Spring.GetUnitIsCloaked
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead

local recloakUnit = {}
local recloakFrame = {}

local noFFWeaponDefs = {}
for i = 1, #WeaponDefs do
	local wd = WeaponDefs[i]
	if wd.customParams and wd.customParams.nofriendlyfire then
		noFFWeaponDefs[i] = true
	end
end

local DEFAULT_DECLOAK_TIME = 100
local UPDATE_FREQUENCY = 10
local CLOAK_MOVE_THRESHOLD = math.sqrt(0.2)

local currentFrame = 0

local cloakUnitDefID = {}
for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	if ud.canCloak and not ud.customParams.dynamic_comm then
		cloakUnitDefID[i] = true
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Water handling

local waterUnitCount = 0
local waterUnitMap = {}
local waterUnits = {}
local waterUnitCloakBlocked = {}

local function AddWaterUnit(unitID)
	if waterUnitMap[unitID] then
		return
	end
	waterUnitCount = waterUnitCount + 1
	waterUnitMap[unitID] = waterUnitCount
	waterUnits[waterUnitCount] = unitID
end

local function RemoveWaterUnit(unitID)
	if not waterUnitMap[unitID] then
		return
	end
	waterUnits[waterUnitMap[unitID]] = waterUnits[waterUnitCount]
	waterUnitMap[waterUnits[waterUnitCount]] = waterUnitMap[unitID]
	waterUnits[waterUnitCount] = nil
	waterUnitMap[unitID] = nil
	waterUnitCount = waterUnitCount - 1
	
	waterUnitCloakBlocked[unitID] = nil
end

function gadget:UnitEnteredWater(unitID)
	AddWaterUnit(unitID)
end

function gadget:UnitLeftWater(unitID)
	RemoveWaterUnit(unitID)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function PokeDecloakUnit(unitID, duration)
	if recloakUnit[unitID] then
		recloakUnit[unitID] = duration or DEFAULT_DECLOAK_TIME
	else
		spSetUnitRulesParam(unitID, "cannotcloak", 1, alliedTrueTable)
		spSetUnitCloak(unitID, 0)
		recloakUnit[unitID] = duration or DEFAULT_DECLOAK_TIME
	end

end

GG.PokeDecloakUnit = PokeDecloakUnit

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, 
                            weaponID, attackerID, attackerDefID, attackerTeam)
	if damage > 0 and
		not (attackerTeam and
		weaponID and
		noFFWeaponDefs[weaponID] and
		attackerID ~= unitID and
		spAreTeamsAllied(unitTeam, attackerTeam)) then
		PokeDecloakUnit(unitID)
	end
end

local function CheckWaterBlockCloak(unitID, pos)
	local radius = Spring.GetUnitRadius(unitID)
	if radius + pos < 0 then
		if not waterUnitCloakBlocked[unitID] then
			PokeDecloakUnit(unitID)
			spSetUnitRulesParam(unitID, "cannotcloak", 1, alliedTrueTable)
			waterUnitCloakBlocked[unitID] = true
		end
		return true
	end
	return false
end

function gadget:GameFrame(n)
	currentFrame = n
	if n%UPDATE_FREQUENCY == 2 then
		for unitID, frames in pairs(recloakUnit) do
			if frames <= UPDATE_FREQUENCY then
				if not ((spGetUnitRulesParam(unitID,"on_fire") == 1) or (spGetUnitRulesParam(unitID,"disarmed") == 1) or waterUnitCloakBlocked[unitID]) then
					local wantCloakState = spGetUnitRulesParam(unitID, "wantcloak")
					local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
					spSetUnitRulesParam(unitID, "cannotcloak", 0, alliedTrueTable)
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
		while i <= waterUnitCount do
			local unitID = waterUnits[i]
			if Spring.ValidUnitID(unitID) then
				local pos = select(5, Spring.GetUnitPosition(unitID, true))
				if pos < 0 then
					if (not CheckWaterBlockCloak(unitID, pos)) and waterUnitCloakBlocked[unitID] then
						spSetUnitRulesParam(unitID, "cannotcloak", 0, alliedTrueTable)
						waterUnitCloakBlocked[unitID] = false
					end
				else
					if waterUnitCloakBlocked[unitID] then
						spSetUnitRulesParam(unitID, "cannotcloak", 0, alliedTrueTable)
						waterUnitCloakBlocked[unitID] = false
					end
				end
				i = i + 1
			else
				RemoveWaterUnit(unitID)
			end
		end
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
	
	local stunnedOrInbuild = Spring.GetUnitIsStunned(unitID)
	if stunnedOrInbuild then
		return false
	end
	
	local unitDefID = unitID and Spring.GetUnitDefID(unitID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if not ud then
		return false
	end
	
	local areaCloaked = (Spring.GetUnitRulesParam(unitID, "areacloaked") == 1) and ((Spring.GetUnitRulesParam(unitID, "cloak_shield") or 0) == 0)
	if not areaCloaked then
		local speed = select(4, Spring.GetUnitVelocity(unitID))
		local moving = speed and speed > CLOAK_MOVE_THRESHOLD
		local cost = moving and ud.cloakCostMoving or ud.cloakCost
		
		if not Spring.UseUnitResource(unitID, "e", cost/2) then -- SlowUpdate happens twice a second.
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
	
	local wantCloakState = spGetUnitRulesParam(unitID, "wantcloak")
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, CMD_WANT_CLOAK)
	if (cmdDescID) then
		Spring.EditUnitCmdDesc(unitID, cmdDescID, { params = {state, 'Decloaked', 'Cloaked'}})
	end
	
	if state == 1 and wantCloakState ~= 1 then
		local cannotCloak = spGetUnitRulesParam(unitID, "cannotcloak")
		local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
		if cannotCloak ~= 1 and areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 1)
		end
		spSetUnitRulesParam(unitID, "wantcloak", 1, alliedTrueTable)
	elseif state == 0 and wantCloakState == 1 then
		local areaCloaked = spGetUnitRulesParam(unitID, "areacloaked")
		if areaCloaked ~= 1 then
			spSetUnitCloak(unitID, 0)
		end
		spSetUnitRulesParam(unitID, "wantcloak", 0, alliedTrueTable)
	end
end

GG.SetWantedCloaked = SetWantedCloaked

function gadget:AllowCommand_GetWantedCommand()	
	return {[CMD_CLOAK] = true, [CMD_WANT_CLOAK] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()	
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_WANT_CLOAK then
		if cloakUnitDefID[unitDefID] then
			SetWantedCloaked(unitID,cmdParams[1])
		end
		return false
	elseif cmdID == CMD_CLOAK then
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:UnitCreated(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if cloakUnitDefID[unitDefID] then
		local cloakDescID = Spring.FindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			Spring.InsertUnitCmdDesc(unitID, unitWantCloakCommandDesc)
			Spring.RemoveUnitCmdDesc(unitID, cloakDescID)
			spSetUnitRulesParam(unitID, "wantcloak", 0, alliedTrueTable)
			if ud.customParams.initcloaked or ud.startCloaked then
				SetWantedCloaked(unitID, 1)
			end
			return
		end
	elseif ud.customParams.dynamic_comm then
		local cloakDescID = Spring.FindUnitCmdDesc(unitID, CMD_CLOAK)
		if cloakDescID then
			Spring.RemoveUnitCmdDesc(unitID, cloakDescID)
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		gadget:UnitCreated(unitID, unitDefID)
		local pos = select(2, Spring.GetUnitPosition(unitID))
		if pos <= 0 then
			gadget:UnitEnteredWater(unitID)
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
