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

Tool.COLOURS = {
			red = {1,0,0,1}, --ship
			green = {0,1,0,1}, --kbot
			blue = {0,0,1,1}, -- air

			aqua = {0,1,1,1}, --hov
			yellow = {1,1,0,1}, -- amp
			purple = {1,0,1,1}, -- sub

			white = {1,1,1,1},
			black = {0,0,0,1}, --veh
			}
Tool._TABLES = {}
Tool.tablerez = 0
Tool.tablenew = 0
function Tool:RezTable()
	self:EchoDebug('#RezTable',#self._TABLES,self.tablerez,self.tablenew)
	if self._TABLES[1] then
		self.tablerez = self.tablerez +1
		return table.remove(self._TABLES)
	end
	self.tablenew = self.tablenew + 1
	return {}
end


-- Function to recursively process a table and discard everything that is not a table
function Tool:KillTable(t)
	
	if not t or type(t) ~= 'table' then
		self:EchoDebug("incorrect type in KillTable",t,type(t))    
		return
	end
	--self:EchoDebug("SIT_TABLE: Before clearing", t)
	--if type(t) == 'table' then
		
	
	for key, value in pairs(t) do
		
		if type(value) == 'table' then
			self:KillTable(value)
		end
		t[key] = nil
		if  next(t) == nil then
			table.insert(self._TABLES, t)
			--t = nil
		end
	end
	self:EchoDebug('#KillTable',#self._TABLES)
	return nil
end

function Tool:ResetTable(t)
	self:KillTable(t) 
	return self:RezTable()
end

function Tool:StoreOrder (id,cmd,params,options,method)
	if not id or not cmd or not params or not options or not method then
		self:EchoDebug('storeorder failed :',id,cmd,params,options)
		return
	end
	for i,v in pairs(params) do
		params[i] = tonumber(v) or v
	end
	--self:EchoDebug('storeorder received :',id,cmd,params,opts)
	game.orders = game.orders or game:RezTable()
	game.lastGameFrame = game.lastGameFrame or 0
	
	local new = game:RezTable()
	new.cmd = nil
	new.params = game:RezTable()
	new.options = game:RezTable()
	
	new.cmd = cmd
	new.id = id
	table.insert(new.params, params)
	table.insert(new.options, options)
	game.orders[id]=new
	
	local frame = game:Frame()
	if frame < game.lastGameFrame + 30 then
		
		return
	end
	game.lastGameFrame = frame
end
		

local serialized = ''
function Tool:SerializeOrder(id,cmd,parameters,options,method)
	
	self:EchoDebug('SerializeOrder',id,cmd,parameters,options,method)
	serialized = ''
	local order = ''
	order = order .. '&id:'
	if type(id) == 'number' then
		order = order .. tostring(id)
	else
		order = order .. self:TableToString(id)
	end
	self:EchoDebug('serialized oder id:',order)
	serialized = ''
	order = order .. '&cmd:'
	if type(cmd) == 'number' then
		order = order .. tostring(cmd)
	else
		order = order .. self:TableToString(cmd)
	end
	self:EchoDebug('serialized oder cmd',order)
	serialized = ''
	order = order .. '&parameters:'
	if type(parameters) == 'number' then
		order = order .. tostring(parameters)
	else
		order = order .. self:TableToString(parameters)
	end
	self:EchoDebug('serialized oder params',order)
	serialized = ''
	order = order .. '&options:'
	if type(options) == 'number' then
		order = order .. tostring(options)
	else
		order = order .. self:TableToString(options)
	end
	self:EchoDebug('serialized ordero ptions',order)
	serialized = ''
	order = order .. '&method:'.. method
	self:EchoDebug('Serialized Order complete:',order)
	serialized = ''
	return order
end

function Tool:GiveOrder(id,cmd,parameters,options,method)
	if not id or not cmd or not parameters or not options or not method then
		self:EchoDebug('Serialize Order missing parameters',id,cmd,parameters,options,method)
		return
	end
	--if type(id) ~= ('number' or 'table') or type(cmd) ~= ('number' or 'table') or type(parameters) ~= ('number' or 'table') or type(options) ~= ('number' or 'table') or type(method) ~= 'string' then
	--	self:EchoDebug('Serialize Order wrong arg types',type(id),type(cmd),type(parameters),type(options),type(method))
	--	return
	--end
	local order = self:SerializeOrder(id,cmd,parameters,options,method)
	game:GiveOrder(order)

end

function Tool:DeserializeOrder(str)
	if not str then
		self:EchoDebug('Deserialize Order missing parameters')
		return
	end
	if string.sub(str,1,4) ~= '[ST]' or string.sub(str,-4,-1) ~= '[ST]' then
		self:EchoDebug(string.sub(str,1,4),string.sub(str,-4,-1))
		return
	else
		str = string.sub(str,5,-5)
	end
	local order = {}
	for s in string.gmatch(str, "([^&]+)") do
		local key, value = string.match(s, "(%w+):(.+)")
		if string.find(value,'|') or string.find(value,',') then
			order[key] = self:StringToTable(value)
		else
			order[key] = tonumber(value) or value
		end
	end
	self:EchoDebug('order',order)
	return order
end


function Tool:TableToString(t)
	if not t then
		return
	end
	if t.x  and t.z and not t.y then
		self:Warn('incomplete position in table to string')
		return 
	elseif t.x  and t.z and t.y then
		serialized = serialized ..t.x ..','..t.y ..','..t.z ..','
		if t[1] then
			serialized = serialized .. t[1]
		end
	else
		for k,v in pairs(t) do

			if type(v) == 'number' then
				serialized = serialized ..v ..','
			else
				self:TableToString(v)
				serialized = serialized ..'|'
			end
		end
	end
    self:EchoDebug("Serialized:", serialized)
    return serialized
end

function Tool:TableToStringBackup(t)
	if not t then
		return
	end
	if t.x  and t.z then
		if not t.y then
			return
		end
		table.insert(t,1,t.x)
		table.insert(t,2,t.y)
		table.insert(t,3,t.z)
		table.x = nil
		table.y = nil
		table.z = nil
	end
    for k,v in pairs(t) do

		if type(v) == 'number' then
			serialized = serialized ..v ..','
		else
			self:TableToString(v)
			serialized = serialized ..'|'
		end
	end
	
    self:EchoDebug("Serialized:", serialized)
    return serialized
end



function Tool:StringToTable(str)
	local t = {}
	local i = 1
	if string.find(str,'|') then
		for s in string.gmatch(str, "([^|]+)") do
			
			t[i] = {}
			for value in string.gmatch(s, "([^,]+)") do
			table.insert(t[i],tonumber(value) or value)
			end
			i = i + 1
		end
	else
		for value in string.gmatch(str, "([^,]+)") do
			table.insert(t,tonumber(value) or value)
		end
	end
	self:EchoDebug("Deserialized:", t)
	return t
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

function Tool:RandomAway2(pos, dist, opposite, angle,away)
	if angle == nil then
		angle = random() * twicePi
	end
	away = away or {}
-- 	local mapSize = self.ai.map:MapDimensions()
-- 	local maxElmosX = mapSize.x * 8
-- 	local maxElmosZ = mapSize.z * 8
	away.x, away.y,away.z = 0,0,0
	away.x = pos.x + dist * cos(angle)
	away.z = pos.z - dist * sin(angle)
	away.y = pos.y + 0
	if away.x < 1 then
		away.x = 1
	elseif away.x > self.ai.maphst.elmoMapSizeX - 1 then
		away.x = self.ai.maphst.elmoMapSizeX - 1
	end
	if away.z < 1 then
		away.z = 1
	elseif away.z > self.ai.maphst.elmoMapSizeZ - 1 then
		away.z = self.ai.maphst.elmoMapSizeZ - 1
	end
	if opposite then
		angle = twicePi - angle
		return away, Tool:RandomAway2(pos, dist, false, angle,away)
	else
		return away
	end
end




function Tool:RawDistance(x1,y1,z1,x2,y2,z2)
	local x = x1-x2
	local y = y1-y2
	local z = z1-z2
	return sqrt( (x*x) + (y*y) + (z*z) )
end

function Tool:DISTANCE(POS1,POS2)
	local x = POS2.x - POS1.x
	local y = POS2.y - POS1.y
	local z = POS2.z - POS1.z
	return sqrt( (x*x) + (y*y) + (z*z) )
end

function Tool:distance(POS1,POS2)
	local x = POS2.x - POS1.x
	local z = POS2.z - POS1.z
	return sqrt( (x*x) + (z*z) )
end

function Tool:sumPos(pos1, pos2)
	local pos = api.Position()
	pos.x = pos1.x + pos2.x
	pos.y = pos1.y + pos2.y
	pos.z = pos1.z + pos2.z
	return pos
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
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	local i = 0      -- iterator variable
	local iter = function ()   -- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	return iter
end

function Tool:tableSorting(t)
	local Tkey = {}
	local Tvalue = {}
	for key, value in self:pairsByKeys(t) do
      self:EchoDebug(key, value)
	  table.insert(Tkey,key)
	  table.insert(Tvalue,value)
    end
	return Tkey, Tvalue
end

function Tool:sortByValue(t)
	local sorted = {}
	for k, v in pairs(t) do
		table.insert(sorted,{k,v})
	end
	table.sort(sorted, function(a,b) return a[2] < b[2] end)
	return sorted
end

function Tool:reverseSortByValue(t)
	local sorted = {}
	for k, v in pairs(t) do
		table.insert(sorted,{k,v})
	end
	table.sort(sorted, function(a,b) return a[2] > b[2] end)
	return sorted
end

function Tool:sortByDistance(POS,list)
	local distanceIndex = {}
	local dix={}
	for index,pos in pairs(list) do
		distanceIndex[(self:distance(pos,POS))] = index
		dix[index]=(self:distance(pos,POS))

	end
	table.sort(dix)
	for i,v in pairs(dix) do
		self:EchoDebug(i,v)
		dix[i] = list[distanceIndex[v]]
	end
	return dix
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

function Tool:gcd(a, b)
	return b==0 and a or self:gcd(b,a%b)
end

function Tool:tableConcat(tables)
	if type(tables) ~= 'table' then
		self:Warn('concatenation require a table of tables')
		return
	end
	local T = {}
	for index,t in pairs(tables) do
		for k, value in pairs(t) do
			table.insert(T,-1,value)
		end
	end
	return T
end

function Tool:getTeamUnitsByClass(classes)
	local list = {}
	for i,class in pairs(classes) do

		if not self.ai.armyhst[class] then
			self:EchoDebug(class , 'is not a valid class to searching for a unit')
		else
			for name,data in pairs(self.ai.armyhst[class]) do
				local current = game:GetTeamUnitsByDefs(self.ai.id,self.ai.armyhst.unitTable[name].defId)
				for index,unit in pairs(current) do
					table.insert(list,current)
				end
			end
		end
	end
	return(list)
end

function Tool:countFinished( targets,team )--accept units names, units def number or classes
	local team = team or self.game:GetTeamID()
	local defs = {}
	local counter = 0
	for i,target in pairs(targets) do
		if self.ai.armyhst[target] then
			for name,data in pairs(self.ai.armyhst[target]) do
				local def = self.ai.armyhst.unitTable[name].defId
				table.insert(defs,def)
			end
		elseif self.ai.armyhst.unitTable[target] then
			table.insert(defs,self.ai.armyhst.unitTable[target].defId)

		elseif UnitDefs[target] then
			table.insert(defs,target)
		end
	end
	defs = game:GetTeamUnitsByDefs(team,defs)

	for index,id in pairs(defs) do
		if not game:GetUnitByID(id):IsBeingBuilt() then
			counter = counter + 1
		end
	end
	return counter, defs
end

function Tool:countMyUnit( targets)
	local team = self.game:GetTeamID()
	local counter = 0
	for i,target in pairs(targets) do
		self:EchoDebug('target',target)
		if type(target) == 'number' then
			counter = counter + game:GetTeamUnitDefCount(team,target)
		elseif self.ai.armyhst[target] then
			for name,t in pairs(self.ai.armyhst[target]) do
				local id = self.ai.armyhst.unitTable[name].defId
				counter = counter + game:GetTeamUnitDefCount(team,id)
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

function Tool:UnitPos(UNIT)
	if not UNIT then return end
	if not UNIT.unit then return end
	if not UNIT.unit:Internal() then return end
	return UNIT.unit:Internal():GetPosition()
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


-- function Tool:CustomCommand(unit, cmdID, cmdParams)
-- 	local floats = api.vectorFloat()
-- 	for i = 1, #cmdParams do
-- 		floats:push_back(cmdParams[i])
-- 	end
-- 	return unit:ExecuteCustomCommand(cmdID, floats)
-- end
