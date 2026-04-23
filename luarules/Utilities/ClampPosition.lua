-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local mapWidth = Game.mapSizeX
local mapHeight = Game.mapSizeZ
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetGroundHeight = Spring.GetGroundHeight
local CMD_INSERT = CMD.INSERT

local oddX = {}
local oddZ = {}

for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	oddX[i] = (ud.xsize % 4)*4
	oddZ[i] = (ud.zsize % 4)*4
end

function Spring.Utilities.SnapToBuildGrid(unitDefID, facing, mx, mz)
	local offFacing = (facing == 1 or facing == 3)
	if offFacing then
		mx = math.floor((mx + 8 - oddZ[unitDefID])/16)*16 + oddZ[unitDefID]
		mz = math.floor((mz + 8 - oddX[unitDefID])/16)*16 + oddX[unitDefID]
	else
		mx = math.floor((mx + 8 - oddX[unitDefID])/16)*16 + oddX[unitDefID]
		mz = math.floor((mz + 8 - oddZ[unitDefID])/16)*16 + oddZ[unitDefID]
	end
	return mx, mz
end

function Spring.Utilities.IsValidPosition(x, z)
	return x and z and x >= 1 and z >= 1 and x <= mapWidth-1 and z <= mapHeight-1
end

function Spring.Utilities.GetTeamGroundHeight(teamID, x, z)
	return CallAsTeam(teamID, spGetGroundHeight, x, z)
end

function Spring.Utilities.ClampPosition(x, z)
	if x and z then
		if Spring.Utilities.IsValidPosition(x, z) then
			return x, z
		else
			if x < 1 then
				x = 1
			elseif x > mapWidth-1 then
				x = mapWidth-1
			end
			if z < 1 then
				z = 1
			elseif z > mapHeight-1 then
				z = mapHeight-1
			end
			return x, z
		end
	end
	return 0, 0
end

function Spring.Utilities.GiveClampedOrderToUnit(unitID, cmdID, params, options, doNotGiveOffMap, snapToHeight)
	if doNotGiveOffMap and not Spring.Utilities.IsValidPosition(params[1], params[3]) then
		return false
	end
	if cmdID == CMD_INSERT then
		local x, z = Spring.Utilities.ClampPosition(params[4], params[6])
		local y = params[5]
		if snapToHeight then
			y = Spring.Utilities.GetTeamGroundHeight(Spring.GetUnitTeam(unitID), x, z)
		end
		spGiveOrderToUnit(unitID, cmdID, {params[1], params[2], params[3], x, y, z}, options)
		return x, y, z
	end
	local x, z = Spring.Utilities.ClampPosition(params[1], params[3])
	local y = params[2]
	if snapToHeight then
		y = Spring.Utilities.GetTeamGroundHeight(Spring.GetUnitTeam(unitID), x, z)
	end
	spGiveOrderToUnit(unitID, cmdID, {x, y, z}, options)
	return x, y, z
end

function Spring.Utilities.GiveClampedMoveGoalToUnit(unitID, x, z, speed, raw)
	x, z = Spring.Utilities.ClampPosition(x, z)
	local y = spGetGroundHeight(x,z)
	Spring.SetUnitMoveGoal(unitID, x, y, z, 16, speed, raw) -- The last argument is whether the goal is raw
	return true
end

function Spring.Utilities.GetGroundHeightMinusOffmap(x, z)
	local maxOff = 0
	if x < 0 then
		maxOff = -x
	elseif x > mapWidth then
		maxOff = x - mapWidth
	end
	if z < -maxOff then
		maxOff = -z
	elseif z > mapHeight + maxOff then
		maxOff = z - mapWidth
	end
	return Spring.GetGroundHeight(x, z) - maxOff
end
