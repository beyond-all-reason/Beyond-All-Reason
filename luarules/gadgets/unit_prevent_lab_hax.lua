-- $Id: unit_terraform.lua 3524 2008-12-23 13:21:12Z google frog $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Lab Hax",
    desc      = "Stops enemy units from entering labs",
    author    = "Google Frog/TheFatController",
    date      = "Jul 24, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false  --  no unsynced code
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
  
-- Speedups
local spGetGroundHeight     = Spring.GetGroundHeight
local spGetUnitBuildFacing  = Spring.GetUnitBuildFacing
local spGetUnitAllyTeam  = Spring.GetUnitAllyTeam
local spGetUnitsInBox  = Spring.GetUnitsInBox
local spSetUnitPosition  = Spring.SetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local abs = math.abs
local min = math.min

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local lab = {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function checkLabs()
  for Lid,Lv in pairs(lab) do  
    local units = spGetUnitsInBox(Lv.minx, Lv.miny, Lv.minz, Lv.maxx, Lv.maxy, Lv.maxz)
	
    for i,id in ipairs(units) do 
	  local ud = spGetUnitDefID(id)
	  local fly = UnitDefs[ud].canFly
	  local team = spGetUnitAllyTeam(id)
	  if (team ~= Lv.team) and not fly then
	  
	    local ux, _, uz  = spGetUnitPosition(id)
		
		if (Lv.face == 1) then
		  local l = abs(ux-Lv.minx)
		  local r = abs(ux-Lv.maxx)
		  
		  if (l < r) then
		    spSetUnitPosition(id, Lv.minx, uz)
		  else
		    spSetUnitPosition(id, Lv.maxx, uz)
		  end
		else
		  local t = abs(uz-Lv.minz)
		  local b = abs(uz-Lv.maxz)
		  
		  if (t < b) then
		    spSetUnitPosition(id, ux, Lv.minz)
		  else
		    spSetUnitPosition(id, ux, Lv.maxz)
		  end
		end
		
		spGiveOrderToUnit(id, CMD.STOP, {}, {})
		--[[
		local l = abs(ux-Lv.minx)
		local r = abs(ux-Lv.maxx)
		local t = abs(uz-Lv.minz)
		local b = abs(uz-Lv.maxz)
		
		local side = min(l,r,t,b)
		
		if (side == l) then
		  spSetUnitPosition(id, Lv.minx, uz)
		elseif (side == r) then
		  spSetUnitPosition(id, Lv.maxx, uz)
		elseif (side == t) then
		  spSetUnitPosition(id, ux, Lv.minz)
		else
		  spSetUnitPosition(id, ux, Lv.maxz)
		end
		--]]
	  end
	end
	
  end
end

function gadget:UnitCreated(unitID, unitDefID)
  local ud = UnitDefs[unitDefID]
  local name = ud.name
  if (ud.isFactory == true) and not (name == "armap" or name == "armaap" or name == "corap" or name == "coraap") then
	local ux, uy, uz  = spGetUnitPosition(unitID)
	local face = spGetUnitBuildFacing(unitID)
	local xsize = ud.xsize*4
	local ysize = (ud.ysize or ud.zsize)*4
	local team = spGetUnitAllyTeam(unitID)
	
	if ((face == 0) or(face == 2)) then
	  lab[unitID] = { team = team, face = 0,
	  minx = ux-ysize, minz = uz-xsize, maxx = ux+ysize, maxz = uz+xsize}
	else
	  lab[unitID] = { team = team, face = 1,
	  minx = ux-ysize, minz = uz-xsize, maxx = ux+ysize, maxz = uz+xsize}
	end
	
	lab[unitID].miny = spGetGroundHeight(ux,uz)
	lab[unitID].maxy = lab[unitID].miny+100
	
  end
  
end

function gadget:UnitDestroyed(unitID, unitDefID)
  if (lab[unitID]) then
    lab[unitID] = nil
  end
end

function gadget:UnitGiven(unitID, unitDefID)
  if (lab[unitID]) then
    lab[unitID].team = spGetUnitAllyTeam(unitID)
  end
end

function gadget:GameFrame(n)
  if (n % 6 == 0) then 
	checkLabs()
  end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
