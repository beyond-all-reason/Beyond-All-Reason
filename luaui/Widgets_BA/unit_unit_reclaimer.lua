
function widget:GetInfo()
  return {
    name      = "Unit Reclaimer",
    desc      = "Reclaim units in an area. Hover over a unit and drag an area-reclaim circle",
    author    = "Google Frog",
    date      = "Dec 16, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

local team = Spring.GetMyTeamID()

-- Speedups

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGiveOrderToUnitArray = Spring.GiveOrderToUnitArray
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spTraceScreenRay = Spring.TraceScreenRay


function widget:CommandNotify(id, params, options)

  if (id == 90) and (#params == 4) then
    
	local cx, cy, cz = params[1], params[2], params[3]
	
	local mx,my,mz = spWorldToScreenCoords(cx, cy, cz)
    local cType = spTraceScreenRay(mx,my) 
	
	if (cType == "unit") then
  
	  local cr = params[4]

	  local areaUnits = spGetUnitsInCylinder(cx ,cz , cr, team)
	  local selUnits = spGetSelectedUnits()
	  
	  local shift = options.shift
	  
	  if not shift then
	    for i, sid in ipairs(selUnits) do 
		  spGiveOrderToUnit(sid, CMD.STOP, {}, CMD.OPT_RIGHT)
	    end
	  end
	  
      for i, aid in ipairs(areaUnits) do 
	  
	    local r = true
		for i, sid in ipairs(selUnits) do 
		  if (aid == sid) then
		    r = false
		  end
	    end
		   
		if r then
		  spGiveOrderToUnitArray( selUnits, CMD.RECLAIM, {aid}, CMD.OPT_SHIFT)
		end
	  end
	  
	return true 
	  
	end
	
  end
  
end


