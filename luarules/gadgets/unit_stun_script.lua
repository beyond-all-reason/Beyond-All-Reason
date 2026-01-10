
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Stun Script",
        desc      = "makes unit stun status known to unit scripts",
        author    = "Floris",
        date      = "April 2020",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local stunnedUnits = {}

local hasSetStunned = {}
for udid, ud in pairs(UnitDefs) do
    if ud.customParams.paralyzemultiplier == 0 then
        hasSetStunned[udid] = false
    end
end

local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spCallCOBScript = Spring.CallCOBScript

local spGetCOBScriptID = Spring.GetCOBScriptID
local GetScriptFunc = function (unitID, functionName)
	local env = Spring.UnitScript.GetScriptEnv(unitID)
	if Spring.GetCOBScriptID(unitID, functionName) then
		return (function(uid, functionName, a,b)
		SpCallCOBScript(uid, functionName, a,b)
		end)
	elseif env and env[functionName] then
		return (
			function(uid, functionName, a,b)
				local scriptEnv = Spring.UnitScript.GetScriptEnv(uid)
				Spring.UnitScript.CallAsUnit(uid, scriptEnv[functionName], a,b)
			end
		)
	else
		return false
	end
end

function gadget:GameFrame(n)
    -- check if stunned units have become deparalyzed
    if n % 10 == 3 then
        for unitID, _ in pairs(stunnedUnits) do
            if not select(2, spGetUnitIsStunned(unitID)) then
				stunnedUnits[unitID](unitID, 'SetStunned', 0, false)
                stunnedUnits[unitID] = nil
            end
        end
    end
end

function gadget:Initialize()
    for i, unitID in pairs(Spring.GetAllUnits()) do
        gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
    if hasSetStunned[unitDefID] == nil then
        hasSetStunned[unitDefID] = GetScriptFunc(unitID, 'SetStunned')
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if hasSetStunned[unitDefID] then
        stunnedUnits[unitID] = nil
	end
end

function gadget:UnitDamaged(unitID,unitDefID,unitTeam,damage,paralyzer,weaponDefID,projectileID,attackerID,attackerDefID,attackerTeam)
    if paralyzer and hasSetStunned[unitDefID] then -- hasSetStunned can't be nil, it's either bool false or a function
        if select(2, spGetUnitIsStunned(unitID)) then
            stunnedUnits[unitID] = hasSetStunned[unitDefID] -- at this point hasSetStunned can only be a function
            stunnedUnits[unitID](unitID, 'SetStunned', 0, true)
        end
    end
end
