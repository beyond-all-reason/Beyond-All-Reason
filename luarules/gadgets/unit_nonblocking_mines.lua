
function gadget:GetInfo()
	return {
		name      = 'Nonblocking mines',
		desc      = 'For 92.+ mines need to be manually unblocked. But other units cannot be built on them.',
		author    = 'Beherith',
		date      = 'Jan 2013',
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
-- Var
----------------------------------------------------------------
local minedefs ={ 
	[UnitDefNames["armfmine3"].id] = true,
	[UnitDefNames["corfmine3"].id] = true,
	[UnitDefNames["armmine1"].id] = true,
	[UnitDefNames["armmine2"].id] = true,
	[UnitDefNames["armmine3"].id] = true,
	[UnitDefNames["cormine1"].id] = true,
	[UnitDefNames["cormine2"].id] = true,
	[UnitDefNames["cormine3"].id] = true,
	[UnitDefNames["cormine4"].id] = true,
}
local mines={}
local nummines=0
----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local spSetUnitBlocking = Spring.SetUnitBlocking
local spGetUnitPosition = Spring.GetUnitPosition
local spGetMyTeamID = Spring.GetMyTeamID
----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function gadget:UnitCreated(uID, uDefID, uTeam)
    if minedefs[uDefID] then
		--nummines=nummines+1
		--Spring.Echo('its a mine!',#mines,nummines)
		local x,_,z= Spring.GetUnitPosition(uID)
		mines[uID]={x,y,z}
        spSetUnitBlocking(uID,false,false,false)
    end
end
function gadget:UnitDestroyed(uID, uDefID, uTeam)
    if minedefs[uDefID] and mines[uID] then
		--nummines=nummines-1
		mines[uID] = nil
        spSetUnitBlocking(uID,false,false,false)
    end
end
function gadget:AllowUnitCreation(unitDefID, builderID,builderTeam, x, y, z) 
	if x and y and z then
		local footprintx= UnitDefs[unitDefID]['xsize'] * 4+8 --add 8 for the mines size too
		local footprintz= UnitDefs[unitDefID]['zsize'] * 4+8  --size is 2x footprint in engine
		for mine, pos in pairs(mines) do
			if math.abs(x-pos[1])<footprintx and math.abs(z-pos[3])<footprintz then
				-- if builderTeam ~=spGetMyTeamID() then --no getmyteamid in synced code :(
					-- local udef = UnitDefs[builderID]
					-- Spring.Echo( udef.humanName  .. ": Can't build on top of mines!" )
				-- end
				
				return false
			end
		end
	end
		--Spring.Echo('AllowUnitCreation',x,y,z)
	return true
end
