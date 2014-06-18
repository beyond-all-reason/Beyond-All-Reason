
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
local armageddonDuration = 12

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

local gaiaTeamID = Spring.GetGaiaTeamID()
 
local spGetUnitDefID 	= Spring.GetUnitDefID
local spValidUnitID		= Spring.ValidUnitID
local spDestroyUnit		= Spring.DestroyUnit 
local spGetGameFrame	= Spring.GetGameFrame

local numX = Game.mapX-1
local numZ = Game.mapY-1
local nSquares = numX*numZ

local meteorDefID = UnitDefNames["meteor"].id
local METEOR_EXPLOSION = WeaponDefNames["meteor_weapon"].id
local nextStrike = armageddonFrame
local meteorStrike = math.max(10,math.sqrt(15*math.floor(numX*numZ))) 
local pStrike = meteorStrike / (armageddonDuration * 30)


local meteorCount = {}
for x=1,numX do
meteorCount[x] = {}
for z=1,numZ do
meteorCount[x][z] = 1 -- start with all at 1, so as not to divide by 0
end
end

function RandomCoordInSquare(sx,sz)
	local x = 512 * sx + math.random(512)
	local z = 512 * sz + math.random(512)
	return x,z
end
 
function FireMeteor()
    -- sample square, with a bias towards squares that haven't been hit much
    local nMost = 0
    local nTotal = 0
    local chanceOfSquare = {}
    for x=1,numX do
    for z=1,numZ do
        if nMost < meteorCount[x][z] then
            nMost = meteorCount[x][z]
        end
    end
    end
    local id = 1
    local N = 0
    for x=1,numX do
    for z=1,numZ do
        chanceOfSquare[id] = {p=nMost+1-meteorCount[x][z], x=x, z=z} 
        N = N + chanceOfSquare[id].p 
        id = id + 1
    end
    end
    local sq = math.random(1,N)
    local c = 1
    for i,v in ipairs(chanceOfSquare) do
        c = c + v.p
        if sq <= c then
            id = i --found the winning square, (distribution v -> v.p/N)
            break
        end
    end
    local sx = chanceOfSquare[id].x
    local sz = chanceOfSquare[id].z
    
    -- fire
    local x,z = RandomCoordInSquare(sx,sz)
    local y = Spring.GetGroundHeight(x,z)
    Spring.CreateUnit(meteorDefID, x, y, z, "north", gaiaTeamID)
end 
 
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
        -- explode immobile units
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
	
    -- meteor shower 
    if n>=armageddonFrame then
        if n==argmageddonFrame then
            FireMeteor()   
        elseif n > armageddonFrame and n <= armageddonFrame + 6*30 then 
            if math.random() < pStrike/4 then
                FireMeteor()
            end
        elseif n > armageddonFrame + 6*30 and  n <= armageddonFrame + 10*30 then
            if math.random() < pStrike/2 then
                FireMeteor()
            end
        elseif n > armageddonFrame + 10*30 and n <= armageddonFrame + 14*30 then
            if math.random() < pStrike then
                FireMeteor()
            end
        elseif n > armageddonFrame + 14*30 and n <= armageddonFrame + 18*30 then
            if math.random() < pStrike/3 then
                FireMeteor()
            end
        end
    end
    
    -- keep firing meteors, slower rate
    if n == nextStrike then
        FireMeteor()
        nextStrike = nextStrike + 5 * math.random(25) --about twice every second
    end
    
	-- kill anything that is created (as instructed by UnitFinished)
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
	if isArmageddon then
        --coms must survive & need protecting until the explosions are over
        if UnitDefs[unitDefID].customParams.iscommander == "1" then 
            local h, mh = Spring.GetUnitHealth(unitID)
            if h <= mh/4 then
                return 0 
            else
                return h/4
            end
        end
        --anything immobile that gets hit by a meteor explodes
        if UnitDefs[unitDefID].isImmobile and weaponDefID == METEOR_EXPLOSION then
            if spValidUnitID(unitID) then
                spDestroyUnit(unitID,true)
            end
        end
    end
end


function gadget:UnitFinished(unitID, unitDefID, teamID, builderID)
	if hadArmageddon and unitDefID~=meteorDefID then
		local n = spGetGameFrame()
		if not toKill[n+1] then toKill[n+1] = {} end
		local k = #(toKill[n+1])+1
		toKill[n+1][k] = unitID --destroying units on the same simframe as they are created is a bad idea 
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    -- make sure meteors die & make sure they don't show up as "proper" units
    if unitDefID==meteorDefID then
        n = spGetGameFrame()
        local m = n+3*30+2
        if not toKill[m] then toKill[m] = {} end
        local k = #(toKill[n+3*30+2])+1
        toKill[n+3*30+2][k] = unitID --just to make sure, although its own explosion should kill it on the frame before
        
        Spring.SetUnitNoDraw(unitID, true)
		Spring.SetUnitStealth(unitID, true)
		Spring.SetUnitSonarStealth(unitID, true)
        Spring.SetUnitNeutral(unitID, true)
    end
end
