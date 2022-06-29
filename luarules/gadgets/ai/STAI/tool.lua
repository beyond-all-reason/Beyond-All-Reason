shard_include("astarclass")

Tool = class(Module)

function Tool:Name()
	return "Tool"
end

function Tool:internalName()
	return "tool"
end

sqrt = math.sqrt
random = math.random
pi = math.pi
halfPi = pi / 2
twicePi = pi * 2
cos = math.cos
sin = math.sin
atan2 = math.atan2
floor = math.floor
ceil = math.ceil
abs = math.abs
min = math.min
max = math.max

local mapBuffer = 32

local layerNames = {"ground", "air", "submerged"}
local unitThreatLayers = {}
local whatHurtsUnit = {}
local whatHurtsMtype = {}

local quadX = { -1, 1, -1, 1 }
local quadZ = { -1, -1, 1, 1 }

local output = ''

function Tool:ModuleScheduler(module)
	STAI.fum = STAI.fum or 0
	self.ai[module].uFrame = self.ai[module].uFrame or 0
	local f = game:Frame()
	if f - self.ai[module].uFrame <= self.ModuleScheda[self.ai[module]:Name()] - self.ai.index  then
		return false
	end

	self.ai[module].uFrame = f
	--self.DebugEnabled = true
	if STAI.fum == f then
		print('sameframecallmodule',module, self.ai.id,STAI.fum)
	end
	STAI.fum = f
	--self:EchoDebug('module',module,f)
	--self.DebugEnabled = false
	return true

end

Tool.ModuleScheda = {
	SleepST = 0,
	ArmyHST = 999999,
	MapHST = 999998,
	EcoHST = 0,
	AttackHST = 20,
	BomberHST = 210,
	RaidHST = 60,
	BuildSiteHST = 999994,
	LabBuildHST = 40,
	TurtleHST = 999995,
	LosHST = 50,
	TargetHST = 70,
	DamageHST = 90,
	ScoutHST = 999991,
	DefendHST = 30,
	CleanHST = 999993,
	NanoHST = 999992,
	OverviewHST = 240,
	UnitHST = 0,
	TasksHST = 999997,
	Tool = 999996,

}

function Tool:ConstrainToMap(x, z)
	local mapSize = self.ai.map:MapDimensions()
	local maxElmosX = mapSize.x * 8
	local maxElmosZ = mapSize.z * 8
	x = max(min(x, maxElmosX-mapBuffer), mapBuffer)
	z = max(min(z, maxElmosZ-mapBuffer), mapBuffer)
	return x, z
end

function Tool:RandomAway(pos, dist, opposite, angle)
	if angle == nil then
		angle = random() * twicePi
	end
	local mapSize = self.ai.map:MapDimensions()
	local maxElmosX = mapSize.x * 8
	local maxElmosZ = mapSize.z * 8
	local away = api.Position()
	away.x = pos.x + dist * cos(angle)
	away.z = pos.z - dist * sin(angle)
	away.y = pos.y + 0
	if away.x < 1 then
		away.x = 1
	elseif away.x > maxElmosX - 1 then
		away.x = maxElmosX - 1
	end
	if away.z < 1 then
		away.z = 1
	elseif away.z > maxElmosZ - 1 then
		away.z = maxElmosZ - 1
	end
	if opposite then
		angle = twicePi - angle
		return away, Tool:RandomAway(pos, dist, false, angle)
	else
		return away
	end
end

function Tool:distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local zd = pos1.z-pos2.z
	local yd = pos1.y-pos2.y
	if yd < 0 then
		yd = -yd
	end
	local dist = math.sqrt(xd*xd + zd*zd + yd*yd*yd)
	return dist
end

function Tool:DistanceSq(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	return xd*xd + yd*yd
end

function Tool:Distance(pos1,pos2)
	local xd = pos1.x-pos2.x
	local yd = pos1.z-pos2.z
	local dist = sqrt(xd*xd + yd*yd)
	return dist
end

function Tool:DistanceXZ(x1, z1, x2, z2)
	local xd = x1 - x2
	local zd = z1 - z2
	return sqrt(xd*xd + zd*zd)
end

function Tool:Distance3d(pos1, pos2)
	local dx = pos2.x - pos1.x
	local dy = pos2.y - pos1.y
	local dz = pos2.z - pos1.z
	return math.sqrt( dx*dx + dy*dy + dz*dz )
end

function Tool:ManhattanDistance(pos1,pos2)
	local xd = math.abs(pos1.x-pos2.x)
	local yd = math.abs(pos1.z-pos2.z)
	local dist = xd + yd
	return dist
end

function Tool:MiddleOfTwo(pos1, pos2)
	local middle = api.Position()
	middle.x, middle.y, middle.z = (pos1.x+pos2.x)/2, (pos1.y+pos2.y)/2,(pos1.z+pos2.z)/2
	return middle
end

function Tool:ApplyVector(x, z, vx, vz, frames)
	if frames == nil then frames = 30 end
	return Tool:ConstrainToMap(x + (vx *frames), z + (vz * frames))
end

function AngleDist(angle1, angle2)
	return abs((angle1 + pi -  angle2) % twicePi - pi)
	-- game:SendToConsole(math.floor(angleDist * 57.29), math.floor(high * 57.29), math.floor(low * 57.29))
end

function Tool:AngleAdd(angle1, angle2)
	return (angle1 + angle2) % twicePi
end

function Tool:AngleAtoB(x1, z1, x2, z2)
	local dx = x2 - x1
	local dz = z2 - z1
	return atan2(-dz, dx)
end

function Tool:AnglePosPos(pos1, pos2)
	return self:AngleAtoB(pos1.x, pos1.z, pos2.x, pos2.z)
end

function Tool:CheckRect(rect)
	local new = {}
	if rect.x1 > rect.x2 then
		new.x1 = rect.x2 * 1
		new.x2 = rect.x1 * 1
	else
		new.x1 = rect.x1 * 1
		new.x2 = rect.x2 * 1
	end
	if rect.z1 > rect.z2 then
		new.z1 = rect.z2 * 1
		new.z2 = rect.z1 * 1
	else
		new.z1 = rect.z1 * 1
		new.z2 = rect.z2 * 1
	end
	rect.x1 = new.x1
	rect.z1 = new.z1
	rect.x2 = new.x2
	rect.z2 = new.z2
end

function Tool:PositionWithinRect(position, rect)
	return position.x > rect.x1 and position.x < rect.x2 and position.z > rect.z1 and position.z < rect.z2
end

function Tool:RectsOverlap(rectA, rectB)
	return rectA.x1 < rectB.x2 and
		rectB.x1 < rectA.x2 and
		rectA.z1 < rectB.z2 and
		rectB.z1 < rectA.z2
end

function Tool:pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then return nil
	else return a[i], t[a[i]]
end
end
return iter
end

function Tool:tableSorting(t)
	local Tkey = {}
	local Tvalue = {}
	for key, value in self.ai.tool:pairsByKeys(t) do
      self:EchoDebug(key, value)
	  table.insert(Tkey,key)
	  table.insert(Tvalue,value)
    end
	return Tkey, Tvalue
end

function Tool:listHasKey( value, list )
	for k,v in pairs(list) do
		if k == value then
			return v
		end
	end
	return false
end

function Tool:listHasValue( list,value )
	for k,v in pairs(list) do
		if v == value then
			return k
		end
	end
	return false
end

function Tool:dictHasKey( value, list )
	if list[value] then
		return true
	end
	return false
end

function Tool:countFinished( nameORid )
	local team = self.game:GetTeamID()
	local counter = 0
	if type(nameORid ) == 'string' then
		nameORid = self.ai.armyhst.unitTable[nameORid].defId
	end
	if type(nameORid ) ~= 'number' then
		self:EchoDebug('type not valid in count finish unit')
	end
	local targetList = self.ai.game:GetTeamUnitsByDefs(self.ai.id, nameORid)
	for index , value in pairs(targetList) do
		if value:internal():IsBeingBuilt() == 1 then
			counter = counter +1
		end
	end
	return counter
end

function Tool:countMyUnit( targets )
	local team = self.game:GetTeamID()
	local counter = 0
	for i,target in pairs(targets) do
		self:EchoDebug('target',target)
		if type(target) == 'number' then
			counter = counter + self.game:GetTeamUnitDefCount(team,target)
		elseif self.ai.armyhst[target] then
			for name,t in pairs(self.ai.armyhst[target]) do
				local id = self.ai.armyhst.unitTable[name].defId
				counter = counter + self.game:GetTeamUnitDefCount(team,id)
			end

		else
			self:EchoDebug('search for spec')
			for name,spec in pairs(self.ai.armyhst.unitTable) do
				self:EchoDebug(name,spec)
				if spec[target] or name == target then
					local id = spec.defId
					counter = counter + self.game:GetTeamUnitDefCount(team,id)
				end
			end
		end
	end
	self:EchoDebug('counter',counter)
	return counter
end

function Tool:mtypedLvCount(tpLv)
	local team = self.game:GetTeamID()
	local counter = 0
	for name,spec in pairs(self.ai.armyhst.unitTable) do
		if spec.mtypedLv and spec.mtypedLv == tpLv then
			local id = spec.defId
			counter = counter + self.game:GetTeamUnitDefCount(team,id)
		end
	end
	return counter
end

-- function Tool:CustomCommand(unit, cmdID, cmdParams)
-- 	local floats = api.vectorFloat()
-- 	for i = 1, #cmdParams do
-- 		floats:push_back(cmdParams[i])
-- 	end
-- 	return unit:ExecuteCustomCommand(cmdID, floats)
-- end

function Tool:UnitNameSanity(unitOrName)--TODO move to tool
	if not unitOrName then
		self.game:Warn('nil unit or name')
		return
	end
	if type(unitOrName) == 'string' then
		if not self.ai.armyhst.unitTable[unitOrName] then
			self.game:Warn('invalid string name',unitOrName)
			return
		else
			return unitOrName
		end
	else
		local uName = unitOrName:Name()
		if uName ~= nil  and self.ai.armyhst.unitTable[uName]then
			return uName
		else
			self.game:Warn('invalid object unit give invalid name',unitOrName)
			return
		end
	end
	self.game:Warn('unknow reason to exit from unit name sanity')
end

function Tool:WhatHurtsUnit(unitName, mtype, position)
	local hurts = whatHurtsMtype[mtype] or whatHurtsUnit[unitName]
	if hurts ~= nil then return hurts else hurts = {} end
	if unitName then
		--game:SendToConsole('testparam',self.ai.armyhst.testparam)
		local ut = self.ai.armyhst.unitTable[unitName]
		if ut then
			mtype = ut.mtype
		end
	end
	if mtype == "veh" or mtype == "bot" or mtype == "amp" or mtype == "hov" or mtype == "shp" then
		hurts["ground"] = true
	end
	if mtype == "air" then
		hurts["air"] = true
	end
	if mtype == "sub" or mtype == "shp" or mtype == "amp" then
		hurts["submerged"] = true
	end
	if unitName then whatHurtsUnit[unitName] = hurts end
	if mtype then whatHurtsMtype[mtype] = hurts end
	if mtype == "amp" and position ~= nil then
		-- special case: amphibious need to check whether underwater or not
		local underwater = position.y < 0
		if underwater then
			return { ground = false, air = false, submerged = true}
		else
			return { ground = true, air = false, submerged = true }
		end
	end
	return hurts
end

function Tool:BehaviourPosition(behaviour)
	if behaviour == nil then return end
	if behaviour.unit == nil then return end
	local unit = behaviour.unit:Internal()
	if unit == nil then return end
	return unit:GetPosition()
end

function Tool:HorizontalLine(grid, x, z, tx, sets, adds)
	for ix = x, tx do
		grid[ix] = grid[ix] or {}
		if type(sets) == 'table' or type(adds) == 'table' then
			grid[ix][z] = grid[ix][z] or {}
			local cell = grid[ix][z]
			if sets then
				for k, v in pairs(sets) do
					cell[k] = v
				end
			end
			if adds then
				for k, v in pairs(adds) do
					cell[k] = (cell[k] or 0) + v
				end
			end
		else
			if sets then
				grid[ix][z] = sets
			end
			if adds then
				grid[ix][z] = (grid[ix][z] or 0) + adds
				if grid[ix][z] == 0 then grid[ix][z] = nil end
			end
		end
	end
	return grid
end

function Tool:Plot4(grid, cx, cz, x, z, sets, adds)
	grid = self:HorizontalLine(grid, cx - x, cz + z, cx + x, sets, adds)
	if x ~= 0 and z ~= 0 then
		grid = self:HorizontalLine(grid, cx - x, cz - z, cx + x, sets, adds)
	end
	return grid
end

function Tool:FillCircle(grid, gridElmos, position, radius, sets, adds)
	local cx = ceil(position.x / gridElmos)
	local cz = ceil(position.z / gridElmos)
	radius = max( 0, radius - (gridElmos/2) )
	local cradius = floor(radius / gridElmos)
	if cradius > 0 then
		local err = -cradius
		local x = cradius
		local z = 0
		while x >= z do
			local lastZ = z
			err = err + z
			z = z + 1
			err = err + z
			grid = self:Plot4(grid, cx, cz, x, lastZ, sets, adds)
			if err >= 0 then
				if x ~= lastZ then grid = self:Plot4(grid, cx, cz, lastZ, x, sets, adds) end
				err = err - x
				x = x - 1
				err = err - x
			end
		end
	end
	return grid
end

function Tool:SimplifyPath(path)
	if #path < 3 then
		return path
	end
	local lastAngle
	local removeIds = {}
	for i = 1, #path-1 do
		local node1 = path[i]
		local node2 = path[i+1]
		local angle = Tool:AngleAtoB(node1.position.x, node1.position.z, node2.position.x, node2.position.z)
		if lastAngle then
			local adist = AngleDist(angle, lastAngle)
			if adist < 0.2 then
				removeIds[node1.id] = true
			end
		end
		lastAngle = angle
	end
	for i = #path-1, 2, -1 do
		local node = path[i]
		if removeIds[node.id] then
			table.remove(path, i)
		end
	end
	return path
end
