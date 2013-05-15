
function widget:GetInfo()
  return {
    name      = "Specific Unit Reclaimer",
    desc      = "Hold down Alt and give an area reclaim order, centered on a unit of the type to reclaim.",
    author    = "Google Frog",
    date      = "May 12, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local team = Spring.GetMyTeamID()
local allyTeam = Spring.GetMyAllyTeamID()

-- Speedups

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetCommandQueue = Spring.GetCommandQueue
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetModKeyState = Spring.GetModKeyState


local reclaimEnemy = Game.reclaimAllowEnemies

--

function spEcho(text)
  Spring.Echo(text)
end

function widget:CommandNotify(id, params, options)


  if (id == 90) and (#params == 4) then
	local alt,_,_,_ = spGetModKeyState()
	if not alt then 
		return false
	end
    
	local cx, cy, cz = params[1], params[2], params[3]
	
	local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
    local cType,id = spTraceScreenRay(mx,my) 
	
	if (cType == "unit") then 
  
	  local cr = params[4]

	  local selUnits = spGetSelectedUnits()
	  
	  local shift = options.shift
	  
	  if not shift then
	    for i, sid in ipairs(selUnits) do 
		  spGiveOrderToUnit(sid, CMD.STOP, {}, CMD.OPT_RIGHT)
	    end
	  end
	  
	  if reclaimEnemy and spGetUnitAllyTeam(id) ~= allyTeam then
	    
		local areaUnits = spGetUnitsInCylinder(cx ,cz , cr)
		
	    for i, aid in ipairs(areaUnits) do 
		  if spGetUnitAllyTeam(aid) ~= allyTeam then
		    spGiveOrderToUnitArray( selUnits, CMD.RECLAIM, {aid}, CMD.OPT_SHIFT)
		  end
	    end
	  
	  else
	  
	    local areaUnits = spGetUnitsInCylinder(cx ,cz , cr, team)
	    local unitDef = spGetUnitDefID(id)
	  
        for i, aid in ipairs(areaUnits) do 
		  if spGetUnitDefID(aid) == unitDef then
		    spGiveOrderToUnitArray( selUnits, CMD.RECLAIM, {aid}, CMD.OPT_SHIFT)
		  end
	    end
		
	  end
	  
	return true 
	  
	end
	
  end
  
end


