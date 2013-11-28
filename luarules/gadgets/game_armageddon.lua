
function gadget:GetInfo()
    return {
        name      = 'Armageddon',
        desc      = 'Implements armageddon modoption',
        author    = 'Niobium, Bluestone',
        version   = 'v1.0',
        date      = '11/2013',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
    return false
end

----------------------------------------------------------------
-- Load?
----------------------------------------------------------------
local armageddonFrame = 60 * 30 * (tonumber((Spring.GetModOptions() or {}).mo_armageddontime) or 0) --mo_armageddontime is in minutes
local armageddonDuration = 5 --in seconds

if armageddonFrame <= 0 then
    return false
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

local toKillUnits = {}
local toKillFrame = {}
local isArmageddon = false
local hadArmageddon = false 
 
local spGetUnitDefID 	= Spring.GetUnitDefID
local spValidUnitID	= Spring.ValidUnitID
local spDestroyUnit		= Spring.DestroyUnit 
 
function gadget:GameFrame(n)
    if n == armageddonFrame - 1 then
		isArmageddon = true
		hadArmageddon = true
        local allUnits = Spring.GetAllUnits()
        local unitID,unitDefID
		for i = 1, #allUnits do
			unitID = allUnits[i]
			unitDefID = spGetUnitDefID(unitID)
			if UnitDefs[unitDefID].isImmobile then
				toKillUnits[#toKillUnits+1] = unitID
				toKillFrame[#toKillFrame+1] = armageddonFrame + math.floor(armageddonDuration * 30 * math.random())
			end
        end
    elseif n >= armageddonFrame and n <= armageddonFrame + armageddonDuration * 30 + 1 then
		for i = 1, #toKillUnits do
			if n == toKillFrame[i] then
				if spValidUnitID(toKillUnits[i]) then
					spDestroyUnit(toKillUnits[i],true) --boom!
				end
			end
        end
	elseif n == armageddonFrame + (armageddonDuration + 1) * 30 then
		isArmageddon = false
	end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if isArmageddon and UnitDefs[unitDefID].customParams.iscommander == "1" then 
		local h, mh = Spring.GetUnitHealth(unitID)
		if h <= mh/4 then
			return 0 --coms survive & need protecting until the explosions are over
		else
			return h/4
		end
	end
end


function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if hadArmageddon then
		spDestroyUnit(unitID,true) --lol
	end
end
