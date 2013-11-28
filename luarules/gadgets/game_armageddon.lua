
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
local toKill = {} 

local isArmageddon = false
local hadArmageddon = false 
 
local spGetUnitDefID 	= Spring.GetUnitDefID
local spValidUnitID		= Spring.ValidUnitID
local spDestroyUnit		= Spring.DestroyUnit 
local spGetGameFrame	= Spring.GetGameFrame
 
 
function gadget:GameFrame(n)

	-- cause the armageddon; kill everything immobile
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
	
	-- kill anything that is created
	if toKill[n] then
		for i=1,#(toKill[n]) do
			if spValidUnitID(toKill[n][i]) then
				spDestroyUnit(toKill[n][i],true)
			end
		end
		toKill[n] = nil
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


function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
	if hadArmageddon then
		local n = spGetGameFrame()
		if not toKill[n+1] then toKill[n+1] = {} end
		local k = #(toKill[n+1])+1
		toKill[n+1][k] = unitID --destroying units on the same simframe as they are created is a bad idea 
	end
end
