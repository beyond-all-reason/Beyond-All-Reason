function widget:GetInfo()
  return {
    name      = "GroupMove",
    desc      = "Expands destination of multiple unit movement (1.0)",
    author    = "TheFatController",
    date      = "16 August, 2010",
    license   = "MIT",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

VFS.Include("LuaRules/Configs/customcmds.h.lua")
local GetSelectedUnits = Spring.GetSelectedUnits
local GiveOrderToUnit  = Spring.GiveOrderToUnit
local GetUnitPosition  = Spring.GetUnitPosition
local myOrder = false

local function getDistance(x1,z1,x2,z2)
	local dx,dz = x1-x2,z1-z2
	return math.sqrt((dx*dx)+(dz*dz))
end

function widget:CommandNotify(id, params, options)
	if options.alt then
		return false
	end

	if (id == CMD.MOVE) and params[3] and (not myOrder) and options.coded then
		local selUnits = GetSelectedUnits()
		if #selUnits > 1 then
			myOrder = true
			local tx = 0
			local tz = 0
			local mx = params[1]
			local mz = params[3]
			local minx = math.huge
			local minz = math.huge
			local maxx = 0
			local maxz = 0
			local unitPos = {}
			local maxOffset = 4 + (math.min(#selUnits*6,300))
			for _,unitID in ipairs(selUnits) do
				local x,_,z = GetUnitPosition(unitID)
				tx = tx + x
				tz = tz + z
				if x < minx then minx = x end
				if x > maxx then maxx = x end
				if z < minz then minz = z end
				if z > maxz then maxz = z end
				unitPos[unitID] = {x=x,z=z}
			end
			tx = (tx / #selUnits)
			tz = (tz / #selUnits)
			local gather = 1
			if (mx < maxx) and (mx > minx) and (mz < maxz) and (mz > minz) then
				gather = 0.666
			end
			for _,unitID in ipairs(selUnits) do
				local targetX = mx+((unitPos[unitID].x-tx) * gather)
				local targetZ = mz+((unitPos[unitID].z-tz) * gather)
				if (getDistance(mx,mz,targetX,targetZ) > maxOffset) then
					local angle = math.atan2((tx-unitPos[unitID].x),(tz-unitPos[unitID].z))
					targetX = mx - (math.sin(angle) * maxOffset)
					targetZ = mz - (math.cos(angle) * maxOffset)
				end	
				GiveOrderToUnit(unitID,CMD.MOVE,{targetX,params[2],targetZ},options.coded)
			end
			myOrder = false
			return true
		end
	end
	return false
end