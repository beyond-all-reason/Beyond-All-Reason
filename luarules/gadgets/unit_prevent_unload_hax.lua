function gadget:GetInfo()
  return {
    name      = "Prevent Unload Hax",
    desc      = "removes unit velocity on unload (and prevents firing units across the map with 'stored' impulse)",
    author    = "Bluestone",
    date      = "12/08/2013",
    license   = "horse has fallen over, again",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

local frameMargin = 10

local COMMANDO = UnitDefNames["cormando"].id

local SpSetUnitVelocity = Spring.SetUnitVelocity
local SpGetUnitVelocity = Spring.GetUnitVelocity
local SpGetGroundHeight = Spring.GetGroundHeight
local SpGetUnitPosition = Spring.GetUnitPosition
local SpGetGameFrame = Spring.GetGameFrame
local SpSetUnitPhysics = Spring.SetUnitPhysics
local SpSetUnitDirection = Spring.SetUnitDirection
local SpGetUnitIsDead = Spring.GetUnitIsDead

local unloadedUnits = {}

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	if unitID == nil or unitDefID == nil or transportID == nil then return end
    --FIXME: is this exception for commando this really necessary?
	if (unitDefID == COMMANDO) then		
		local x,y,z = SpGetUnitVelocity(transportID)
		if x > 10 then x = 10 elseif x <- 10 then x = -10 end -- 10 is well above 'normal' air-trans velocity
		if z > 10 then z = 10 elseif z <- 10 then z = -10 end		
        local bx,by,bz = SpGetUnitPosition(unitID)
        if by-SpGetGroundHeight(bx,bz) < 5 then
            x = 0; y = 0; z = 0 --in particular, don't give any velocity if the transport has placed the unit slightly underground (or wierdness...)
        end
		SpSetUnitVelocity(unitID, x, y, z)    
	else
    -- prevent unloaded units from sliding across the map
        local px,py,pz = Spring.GetUnitPosition(unitID)
        local dx,dy,dz = Spring.GetUnitDirection(unitID)
        local frame = SpGetGameFrame() + frameMargin
        unloadedUnits[unitID] = {["px"]=px,["py"]=py,["pz"]=pz,["dx"]=dx,["dy"]=dy,["dz"]=dz,["frame"]=frame}

		SpSetUnitVelocity(unitID, 0,0,0)	
	end
end

function gadget:UnitDestroyed(unitID)
    unloadedUnits[unitID] = nil
end

function gadget:GameFrame(frame)
    -- prevent unloaded units from sliding across the map
    for unitID,data in pairs(unloadedUnits) do
        if data.frame == frame then
            -- reset position
            SpSetUnitPhysics(unitID,data.px,data.py,data.pz,0,0,0,0,0,0,0,0,0)
            SpSetUnitDirection(unitID,data.dx,data.dy,data.dz)
            --Spring.GiveOrderToUnit(unitID,CMD.MOVE,{data.px+10*data.dx,data.py,data.pz+10*data.dz},CMD.OPT_SHIFT)
            data = nil
        end
    end
end
	