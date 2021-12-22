
local DebugDrawEnabled = false




local maxOrganDistance = 400

local babySize = 200
local outpostSize = 250
local baseSize = 300

local outpostLimbs = 2
local baseLimbs = 3

local layerMod = {
	ground = 1,
	air = 1,
	submerged = 1,
	antinuke = 1000,
	shield = 1000,
	jam = 1000,
	radar = 1000,
	sonar = 1000,
	}

local missingFactoryDefenseDistance = 1500 -- if a turtle with a factory has no defense, subtract this much from self.ai.tool:distance
local modDistance = 1 -- how much Priority modifies self.ai.tool:distance, the higher the number the father builders will travel for the most/least turtled turtle

local factoryPriority = 4 -- added to tech level. above this priority allows two of the same type of defense tower.

local basePriority = factoryPriority + 1
local outpostPriority = 2

local exteriorLayer = { ground = 1, submerged = 1 }
local interiorLayer = { air = 1, antinuke = 1, shield = 1, jam = 1, radar = 1, sonar = 1 }
local hurtyLayer = { ground = 1, submerged = 1, air = 1 }

local unitPriorities = {}

TurtleHST = class(Module)

function TurtleHST:Priority(unitName)
	local army = self.ai.armyhst
	local p = unitPriorities[unitName]
	if p then return p end
	local priority = 0
	local ut = army.unitTable[unitName]
	if army._convs_[unitName] then
		priority = 1 * ut.techLevel
	elseif army._estor_[unitName] then
		priority = 2 * ut.techLevel
	elseif army._mstor_[unitName] then
		priority = 2 * ut.techLevel
	elseif army.antinukes[unitName] then
		priority = 2 * ut.techLevel
	elseif army._shield_[unitName] then
		priority = 2
	else
		if ut.buildOptions then
			priority = priority + factoryPriority + ut.techLevel
		end
		if ut.extractsMetal > 0 then
			priority = priority + (ut.extractsMetal * 1000)
		end
		if ut.totalEnergyOut > 0 then
			priority = priority + (ut.totalEnergyOut / 200)
		end
		if ut.jammerRadius > 0 then
			priority = priority + (ut.jammerRadius / 700)
		end
		if ut.radarRadius > 0 then
			priority = priority + (ut.radarRadius / 3500)
		end
		if ut.sonarRadius > 0 then
			priority = priority + (ut.sonarRadius / 2400)
		end
		priority = priority + (ut.metalCost / 1000)
	end
	unitPriorities[unitName] = p
	return priority
end


function TurtleHST:Name()
	return "TurtleHST"
end

function TurtleHST:internalName()
	return "turtlehst"
end

TurtleHST.DebugEnabled = false

function TurtleHST:Init()
	self.turtles = {} -- zones to protect
	self.shells = {} -- defense buildings, shields, and jamming
	self.planned = {}
	self.turtlesByUnitID = {}
	self.totalPriority = 0
end

function TurtleHST:UnitDead(unit)
	local unitName = unit:Name()
	local ut = self.ai.armyhst.unitTable[unitName]
	local unitID = unit:ID()
	if ut.isBuilding or self.ai.armyhst._nano_[unitName] then
		if ut.isWeapon or self.ai.armyhst._shield_[unitName] then
			self:RemoveShell(unitID)
		else
			self:RemoveOrgan(unitID)
		end
		self.turtlesByUnitID[unitID] = nil
	end
end

-- received from buildsitehst
-- also applies to plans, in which case the plan is the unitID
function TurtleHST:NewUnit(unitName, position, unitID)
	local ut = self.ai.armyhst.unitTable[unitName]
	if ut.isBuilding or self.ai.armyhst._nano_[unitName] then
		if ut.isWeapon and not ut.buildOptions and not self.ai.armyhst.antinukes[unitName] and not self.ai.armyhst.nukeList[unitName] and not self.ai.armyhst.bigPlasmaList[unitName] then
			self:AddDefense(position, unitID, unitName)
		else
			if self.ai.armyhst.antinukes[unitName] then
				self:AddShell(position, unitID, unitName, 1, "antinuke", 72000)
			elseif self.ai.armyhst._shield_[unitName] then
				self:AddShell(position, unitID, unitName, 1, "shield", 450)
			elseif ut.jammerRadius ~= 0 then
				self:AddShell(position, unitID, unitName, 1, "jam", ut.jammerRadius)
			elseif ut.radarRadius ~= 0 then
				self:AddShell(position, unitID, unitName, 1, "radar", ut.radarRadius * 0.67)
			elseif ut.sonarRadius ~= 0 then
				self:AddShell(position, unitID, unitName, 1, "sonar", ut.sonarRadius * 0.67)
			end
			self:AddOrgan(position, unitID, unitName)
		end
	end
end

-- received from buildsitehst
function TurtleHST:PlanCreated(plan, unitID)
	local found = false
	local unitName = plan.unitName
	local ut = self.ai.armyhst.unitTable[unitName]
	if ut.isBuilding or self.ai.armyhst._nano_[unitName] then
		if ut.isWeapon or self.ai.armyhst._shield_[unitName] then
			for si, shell in pairs(self.shells) do
				if shell.unitID == plan then
					shell.unitID = unitID
					found = true
					break
				end
			end
		else
			for ti, turtle in pairs(self.turtles) do
				for oi, organ in pairs(turtle.organs) do
					if organ.unitID == plan then
						organ.unitID = unitID
						found = true
						break
					end
				end
				if found then break end
			end
		end
	end
	return found
end

-- received from buildsitehst
function TurtleHST:PlanCancelled(plan)
	local unitName = plan.unitName
	local ut = self.ai.armyhst.unitTable[unitName]
	if ut.isBuilding or self.ai.armyhst._nano_[unitName] then
		if ut.isWeapon or self.ai.armyhst._shield_[unitName] then
			self:RemoveShell(plan)
		else
			self:RemoveOrgan(plan)
		end
		self.turtlesByUnitID[plan] = nil
	end
end

function TurtleHST:AddOrgan(position, unitID, unitName)
	-- calculate priority
	local priority = self:Priority(unitName)
	local ut = self.ai.armyhst.unitTable[unitName]
	local volume = ut.xsize * ut.zsize * 64
	-- create the organ
	local organ = { priority = priority, position = position, unitID = unitID, volume = volume }
	-- find a turtle to attach to
	local nearestDist = maxOrganDistance
	local nearestTurtle
	for i, turtle in pairs(self.turtles) do
		if turtle.water == ut.needsWater then
			local dist = self.ai.tool:Distance(position, turtle.position)
			if dist < turtle.size then
				if dist < nearestDist then
					nearestDist = dist
					nearestTurtle = turtle
				end
			elseif #turtle.organs == 1 then
				if (turtle.priority + priority >= basePriority and dist < baseSize * 2) or (turtle.priority + priority >= outpostPriority and dist < outpostSize * 2) then
					-- merge into an outpost or base
					nearestDist = dist
					nearestTurtle = turtle
				end
			end
		end
	end
	-- make a new turtle if necessary
	if nearestTurtle == nil then
		nearestTurtle = self:AddTurtle(position, ut.needsWater)
	end
	self:Transplant(nearestTurtle, organ)
	self:PlotAllDebug()
end

function TurtleHST:RemoveOrgan(unitID)
	local foundOrgan = false
	local emptyTurtle = false
	for ti = #self.turtles, 1, -1 do
		local turtle = self.turtles[ti]
		for oi = #turtle.organs, 1, -1 do
			local organ = turtle.organs[oi]
			if organ.unitID == unitID then
				turtle.priority = turtle.priority - organ.priority
				self.totalPriority = self.totalPriority - organ.priority
				turtle.organVolume = turtle.organVolume - organ.volume
				table.remove(turtle.organs, oi)
				if #turtle.organs == 0 then
					emptyTurtle = turtle
					self.ai.defendhst:RemoveWard(nil, turtle)
					table.remove(self.turtles, ti)
				end
				foundOrgan = true
				break
			end
		end
		if foundOrgan then break end
	end
	if emptyTurtle then
		for si, shell in pairs(self.shells) do
			for ti = #shell.attachments, 1, -1 do
				local turtle = shell.attachments[ti]
				if turtle == emptyTurtle then
					table.remove(shell.attachments, ti)
				end
			end
		end
	end
	self.turtlesByUnitID[unitID] = nil
	self:PlotAllDebug()
end

function TurtleHST:Transplant(turtle, organ)
	table.insert(turtle.organs, organ)
	turtle.priority = turtle.priority + organ.priority
	turtle.organVolume = turtle.organVolume + organ.volume
	-- game:SendToConsole("organ volume:", organ.volume, "new turtle organ volume:", turtle.organVolume, "max:", turtle.maxOrganVolume)
	if #turtle.organs > 1 then
		if #turtle.limbs < baseLimbs and turtle.priority >= basePriority then
			self:Base(turtle, baseSize, baseLimbs)
		elseif #turtle.limbs < outpostLimbs and turtle.priority >= outpostPriority then
			self:Base(turtle, outpostSize, outpostLimbs)
		end
	end
	self.totalPriority = self.totalPriority + organ.priority
	self.turtlesByUnitID[organ.unitID] = turtle
end

function TurtleHST:Attach(limb, shell)
	local turtle = limb.turtle
	turtle[shell.layer] = turtle[shell.layer] + shell.value
	if turtle.nameCounts[shell.uname] == nil then
		turtle.nameCounts[shell.uname] = 1
	else
		turtle.nameCounts[shell.uname] = turtle.nameCounts[shell.uname] + 1
	end
	limb[shell.layer] = limb[shell.layer] + shell.value
	if limb.nameCounts[shell.uname] == nil then
		limb.nameCounts[shell.uname] = 1
	else
		limb.nameCounts[shell.uname] = limb.nameCounts[shell.uname] + 1
	end
	self.turtlesByUnitID[shell.unitID] = turtle
	table.insert(shell.attachments, limb)
end

function TurtleHST:Detach(limb, shell)
	local turtle = limb.turtle
	turtle[shell.layer] = turtle[shell.layer] - shell.value
	turtle.nameCounts[shell.uname] = turtle.nameCounts[shell.uname] - 1
	limb[shell.layer] = limb[shell.layer] - shell.value
	limb.nameCounts[shell.uname] = limb.nameCounts[shell.uname] - 1
	self.turtlesByUnitID[shell.unitID] = nil
end

function TurtleHST:InitializeInteriorLayers(limb)
	for layer, nothing in pairs(interiorLayer) do
		limb[layer] = 0
	end
end

function TurtleHST:Base(turtle, size, limbs)
	turtle.size = size
	turtle.maxOrganVolume = math.ceil(size * size * math.pi * 0.15) -- less than area to account for building spacing
	for li, limb in pairs(turtle.limbs) do
		if limb ~= turtle.firstLimb then
			self:InitializeInteriorLayers(limb)
			table.insert(turtle.interiorLimbs, limb)
		end
	end
	turtle.limbs = {}
	-- average the turtle's position
	local totalX = 0
	local totalZ = 0
	for oi, organ in pairs(turtle.organs) do
		totalX = totalX + organ.position.x
		totalZ = totalZ + organ.position.z
	end
	local mapSize = self.ai.map:MapDimensions()
	local maxElmosX = mapSize.x * 8
	local maxElmosZ = mapSize.z * 8
	local oldY = turtle.position.y+0
	turtle.position = self.ai.api.Position()
	turtle.position.y = oldY
	turtle.position.x = totalX / #turtle.organs
	turtle.position.z = totalZ / #turtle.organs
	local angleAdd = twicePi / limbs
	local angle = math.random() * twicePi
	for l = 1, limbs do
		local limb = { turtle = turtle, nameCounts = {}, ground = 0, submerged = 0 }
		-- make sure the limb is in an acceptable position (not near the map edge, and not inside another turtle)
		for aroundTheClock = 1, 12 do
			local offMapCheck = self.ai.tool:RandomAway( turtle.position, size * 1.33, false, angle)
			if offMapCheck.x ~= 1 and offMapCheck.x ~= maxElmosX - 1 and offMapCheck.z ~= 1 and offMapCheck.z ~= maxElmosZ - 1 then
				limb.position = self.ai.tool:RandomAway( turtle.position, size, false, angle)
				local inAnotherTurtle = false
				for ti, turt in pairs(self.turtles) do
					if turt ~= turtle then
						local dist = self.ai.tool:Distance(turt.position, limb.position)
						if dist < turt.size then
							inAnotherTurtle = true
							break
						end
					end
				end
				if not inAnotherTurtle then break end
			end
			angle = angle + twicePi / 12
			if angle > twicePi then angle = angle - twicePi end
		end
		if limb.position then
			for i, shell in pairs(self.shells) do
				if exteriorLayer[shell.layer] then
					local dist = self.ai.tool:Distance(limb.position, shell.position)
					if dist < shell.radius then
						self:Attach(limb, shell)
					end
				end
			end
			table.insert(turtle.limbs, limb)
		end
		angle = angle + angleAdd
		if angle > twicePi then angle = angle - twicePi end
	end
end

function TurtleHST:AddTurtle(position, water, priority)
	if priority == nil then priority = 0 end
	local firstLimb = { position = position, nameCounts = {}, ground = 0, submerged = 0 }
	local maxOrganVolume = math.ceil(babySize * babySize * math.pi * 0.15)
	self:InitializeInteriorLayers(firstLimb)
	local turtle = {position = position, size = babySize, maxOrganVolume = maxOrganVolume, organs = {}, organVolume = 0, limbs = { firstLimb }, interiorLimbs = { firstLimb }, firstLimb = firstLimb, water = water, nameCounts = {}, priority = priority, ground = 0, air = 0, submerged = 0, antinuke = 0, shield = 0, jam = 0, radar = 0, sonar = 0}
	firstLimb.turtle = turtle
	for i, shell in pairs(self.shells) do
		local dist = self.ai.tool:Distance(position, shell.position)
		if dist < shell.radius then
			self:Attach(turtle.firstLimb, shell)
		end
	end
	table.insert(self.turtles, turtle)
	self.totalPriority = self.totalPriority + priority
	self.ai.defendhst:AddWard(nil, turtle)
	return turtle
end

function TurtleHST:AddDefense(position, unitID, unitName)
	local ut = self.ai.armyhst.unitTable[unitName]
	-- effective defense ranges are less than actual ranges, because if a building is just inside a weapon range, it's not defended
	local defense = ut.metalCost
	if ut.groundRange ~= 0 then
		self:AddShell(position, unitID, unitName, defense, "ground", ut.groundRange * 0.5)
	end
	if ut.airRange ~= 0 then
		self:AddShell(position, unitID, unitName, defense, "air", ut.airRange * 0.5)
	end
	if ut.submergedRange ~= 0 then
		self:AddShell(position, unitID, unitName, defense, "submerged", ut.submergedRange * 0.5)
	end
end

function TurtleHST:AddShell(position, unitID, uname, value, layer, radius)
	local shell = {position = position, unitID = unitID, uname = uname, value = value, layer = layer, radius = radius, attachments = {}}
	local nearestDist = radius * 3
	local nearestLimb
	local attached = false
	for i, turtle in pairs(self.turtles) do
		local checkThese
		if exteriorLayer[layer] then
			checkThese = turtle.limbs
		else
			checkThese = turtle.interiorLimbs
		end
		for li, limb in pairs(checkThese) do
			local dist = self.ai.tool:Distance(position, limb.position)
			if dist < radius then
				self:Attach(limb, shell)
				attached = true
			end
			if not attached and dist < nearestDist then
				nearestDist = dist
				nearestLimb = limb
			end
		end
	end
	-- if nothing is close enough, attach to the nearest turtle, so that we don't end up building infinite laser towers at the same turtle
	if not attached and nearestTurtle then
		self:Attach(nearestLimb, shell)
	end
	table.insert(self.shells, shell)
	self:PlotAllDebug()
end

function TurtleHST:RemoveShell(unitID)
	for si = #self.shells, 1, -1 do
		local shell = self.shells[si]
		if shell.unitID == unitID then
			for li, limb in pairs(shell.attachments) do
				self:Detach(limb, shell)
			end
			table.remove(self.shells, si)
		end
	end
	self:PlotAllDebug()
end

function TurtleHST:LeastTurtled(builder, unitName, bombard, oneOnly)
	-- if 1 then return end -- ai might actually be more effective without defenses, uncomment to disable all defense emplacements
	if builder == nil then return end
	self:EchoDebug("checking for least turtled from " .. builder:Name() .. " for " .. tostring(unitName) .. " bombard: " .. tostring(bombard))
	if unitName == nil then return end
	local position = builder:GetPosition()
	local ut = self.ai.armyhst.unitTable[unitName]
	local Metal = self.game:GetResourceByName("Metal")
	local priorityFloor = 1
	local layer
	if ut.isWeapon and not self.ai.armyhst.antinukes[unitName] then
		if ut.groundRange ~= 0 then
			layer = "ground"
		elseif ut.airRange ~= 0 then
			layer = "air"
		elseif ut.submergedRange ~= 0 then
			layer = "submerged"
		end
	elseif self.ai.armyhst.antinukes[unitName] then
		layer = "antinuke"
		priorityFloor = 5
	elseif self.ai.armyhst._shield_[unitName] then
		layer = "shield"
		priorityFloor = 5
	elseif ut.jammerRadius ~= 0 then
		layer = "jam"
		priorityFloor = 5
	elseif ut.radarRadius ~= 0 then
		layer = "radar"
	elseif ut.sonarRadius ~= 0 then
		layer = "sonar"
	end
	local bestDist = 100000
	local best
	local byselfdistance = {}
	for i, turtle in pairs(self.turtles) do
		local important = turtle.priority >= priorityFloor -- so that for example we don't build shields where there's just a mex
		local isLocal = true
		if important then
			-- don't build land shells on water turtles or water shells on land turtles
			isLocal = self.ai.armyhst.unitTable[unitName].needsWater == turtle.water
		end
		if isLocal and important then
			local modLimit = 10000
			if hurtyLayer[layer] then
				modLimit = (turtle.priority / self.totalPriority) * Metal.income * 60
				modLimit = math.floor(modLimit)
			end
			local checkThese
			if interiorLayer[layer] then
				if layer == "air" or turtle.ground + turtle.air + turtle.submerged > 0 then
					checkThese = turtle.interiorLimbs
				else
					checkThese = {}
				end
			else
				checkThese = turtle.limbs
			end
			for li, limb in pairs(checkThese) do
				local enough
				if interiorLayer[layer] then
					enough = turtle.nameCounts[unitName] ~= nil and turtle.nameCounts[unitName] ~= 0
				else
					local turtleEnough = false
					if turtle.nameCounts[unitName] ~= nil then
						turtleEnough = turtle.nameCounts[unitName] >= #turtle.limbs
					end
					enough = (limb.nameCounts[unitName] ~= nil and limb.nameCounts[unitName] ~= 0) or turtleEnough
				end
				local okay = false
				if not enough then
					okay = self.ai.maphst:UnitCanGoHere(builder, limb.position)
				end
				if okay and bombard and unitName ~= nil then
					okay = self.ai.targethst:IsBombardPosition(limb.position, unitName)
				end
				if okay then
					local mod
					if interiorLayer[layer] then
						mod = turtle[layer]
					else
						mod = limb[layer]
					end
					mod = mod * layerMod[layer]
					local modDefecit = modLimit - mod
					self:EchoDebug("turtled: " .. mod .. ", limit: " .. tostring(modLimit) .. ", priority: " .. turtle.priority .. ", total priority: " .. self.totalPriority)
					if mod == 0 or mod < ut.metalCost or mod < modLimit then
						local dist = self.ai.tool:Distance(position, limb.position)
						dist = dist - (modDefecit * modDistance)
						if hurtyLayer[layer] and limb[layer] == 0 and turtle.priority > factoryPriority then dist = dist - missingFactoryDefenseDistance end
						self:EchoDebug("self.ai.tool:distance: " .. dist)
						if oneOnly then
							if dist < bestDist then
								self:EchoDebug("best self.ai.tool:distance")
								bestDist = dist
								best = limb.position
							end
						else
							byselfdistance[dist] = limb.position
						end
					end
				end
			end
		end
	end
	if oneOnly then
		if best then
			local newpos = api.Position()
			newpos.x = best.x
			newpos.z = best.z
			newpos.y = best.y
			return newpos
		else
			return nil
		end
	else
		local sorted = {}
		for dist, pos in self.ai.tool:pairsByKeys(byselfdistance) do
			local newpos = api.Position()
			newpos.x = pos.x+0
			newpos.z = pos.z+0
			newpos.y = pos.y+0
			table.insert(sorted, newpos)
		end
		self:EchoDebug("outputting " .. #sorted .. " least turtles")
		return sorted
	end
end

function TurtleHST:GetIsBombardPosition(turtle, unitName)
	turtle.bombardFor = turtle.bombardFor or {}
	turtle.bombardForFrame = turtle.bombardForFrame or {}
	local f = self.game:Frame()
	if not turtle.bombardForFrame[unitName]
	or (turtle.bombardForFrame[unitName] and f > turtle.bombardForFrame[unitName] + 450) then
		turtle.bombardFor[unitName] = self.ai.targethst:IsBombardPosition(turtle.position, unitName)
		turtle.bombardForFrame[unitName] = f
	end
	return turtle.bombardFor[unitName]
end

function TurtleHST:MostTurtled(builder, unitName, bombard, oneOnly, ignoreDistance)
	local modDist = modDistance
	if unitName then modDist = modDist * self:Priority(unitName) end
	if builder == nil then return end
	self:EchoDebug("checking for most turtled from " .. builder:Name() .. ", bombard: " .. tostring(bombard))
	local position = builder:GetPosition()
	local bestDist = 100000
	local best
	local byselfdistance = {}
	for i, turtle in pairs(self.turtles) do
		if (not unitName or turtle.organVolume < turtle.maxOrganVolume)
		and self.ai.maphst:UnitCanGoHere(builder, turtle.position)
		and (not bombard or self:GetIsBombardPosition(turtle, unitName)) then
			local mod = turtle.ground + turtle.air + turtle.submerged + (turtle.shield * layerMod["shield"]) + (turtle.jam * layerMod["jam"])
			self:EchoDebug("turtled: " .. mod .. ", priority: " .. turtle.priority .. ", total priority: " .. self.totalPriority)
			if mod ~= 0 then
				local dist = 0
				if not ignoreDistance then
					dist = self.ai.tool:Distance(position, turtle.position)
				end
				dist = dist - (mod * modDist)
				self:EchoDebug("self.ai.tool:distance: " .. dist)
				if oneOnly then
					if dist < bestDist then
						self:EchoDebug("best self.ai.tool:distance")
						bestDist = dist
						best = turtle.position
					end
				else
					byselfdistance[dist] = turtle.position
				end
			end
		end
	end
	if oneOnly then
		if best then
			local newpos = api.Position()
			newpos.x = best.x+0
			newpos.z = best.z+0
			newpos.y = best.y+0
			return newpos
		else
			return nil
		end
	else
		local sorted = {}
		for dist, pos in self.ai.tool:pairsByKeys(byselfdistance) do
			local newpos = api.Position()
			newpos.x = pos.x+0
			newpos.z = pos.z+0
			newpos.y = pos.y+0
			table.insert(sorted, newpos)
		end
		self:EchoDebug("outputting " .. #sorted .. " most turtles")
		return sorted
	end
end

function TurtleHST:SafeWithinTurtle(position, unitName)
	local gas = self.ai.tool:WhatHurtsUnit(unitName)
	local cost = self.ai.armyhst.unitTable[unitName].metalCost
	for i = 1, #self.turtles do
		local turtle = self.turtles[i]
		local safety = 0
		for GAS, yes in pairs(gas) do safety = safety + turtle[GAS] end
		if safety > cost then
			local dist = self.ai.tool:Distance(position, turtle.position)
			if dist < turtle.size + 100 then
				return true
			end
		end
	end
	return false
end


function TurtleHST:GetTotalPriority()
	return self.totalPriority
end

function TurtleHST:GetUnitTurtle(unitID)
	return self.turtlesByUnitID[unitID]
end

function TurtleHST:PlotAllDebug()
	if DebugDrawEnabled then
		self.map:EraseAll(2)
		for i, turtle in pairs(self.turtles) do
			local tcolor = {0,1,0}
			if turtle.front then
				tcolor = {1,0,0}
			end
			local label = string.format("%.1f", tostring(turtle.priority)) .. "\n" .. turtle.organVolume .. "/" .. turtle.maxOrganVolume
			self.map:DrawCircle(turtle.position, turtle.size, tcolor, label, false, 2)
			for li, limb in pairs(turtle.limbs) do
				self.map:DrawPoint(limb.position, {1,1,0,1}, "L", 2)
			end
		end
	end
end
