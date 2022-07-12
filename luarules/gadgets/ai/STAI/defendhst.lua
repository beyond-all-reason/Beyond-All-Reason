
local techLevelPriority = 2
local commanderPriority = 2
local threatenedPriority = 2

local canDefend = {
	air = { air = 1, bot = 1, veh = 1, amp = 1, hov = 1, shp = 1, sub = 1 },
	bot = { bot = 1, veh = 1 },
	veh = { veh = 1, bot = 1 },
	amp = { bot = 1, veh = 1 }, -- theoretically, gimp and pelican could defend amp, shp, sub. not sure how to resolve that
	hov = { hov = 1, bot = 1, veh = 1, shp = 1, sub = 1 },
	shp = { shp = 1, sub = 1 },
	sub = { sub = 1, shp = 1 },
	}

DefendHST = class(Module)

function DefendHST:Name()
	return "DefendHST"
end

function DefendHST:internalName()
	return "defendhst"
end

DebugEnabled = false

function DefendHST:Init()
	self.defenders = {}
	self.wards = {}
	self.scrambles = {}
	self.loiterers = { veh = {}, bot = {}, hov = {}, amp = {}, shp = {}, sub = {} }
	self.totalPriority = { ground = 0, air = 0, submerged = 0 }
	self.lastAssignFrame = { ground = {}, air = {}, submerged = {} }
	self.needAssignment = { ground = {}, air = {}, submerged = {} }
	self.needLoitererAssignment = {}
	for mtype, can in pairs(canDefend) do
		self.lastAssignFrame.ground[mtype] = 0
		self.lastAssignFrame.air[mtype] = 0
		self.lastAssignFrame.submerged[mtype] = 0
	end
	self.wardsByDefenderID = {}
	self.defendersByID = {}
	self.unitGuardDistances = {}
	self.ai.frontPosition = {}
end

function DefendHST:AddWard(behaviour, turtle)
	local priority = { ground = 0, air = 0, submerged = 0 }
	local ward
	if behaviour ~= nil then
		if behaviour.unit == nil then return end
		if behaviour.name == nil then behaviour.name = behaviour.unit:Internal():Name() end
		if behaviour.id == nil then behaviour.id = behaviour.unit:Internal():ID() end
		local un = behaviour.name
		local utable = self.ai.armyhst.unitTable[un]
		priority.air = utable.techLevel * techLevelPriority
		if self.ai.armyhst.commanderList[un] then priority.air = commanderPriority end
		local mtype = behaviour.mtype
		if mtype == "air" then
			-- already zero
		elseif mtype == "sub" or mtype == "shp" then
			priority.submerged = priority.air + 0
		elseif mtype == "amp" then
			priority.submerged = priority.air + 0
			priority.ground = priority.air + 0
		else
			priority.ground = priority.air + 0
		end
		local frontNumber = { ground = 0, air = 0, submerged = 0 }
		ward = { uid = behaviour.id, behaviour = behaviour, priority = priority, frontNumber = frontNumber, threatened = nil, defenders = {}, guardDistance = self:GetGuardDistance(un) }
	elseif turtle ~= nil then
		local f = nil --TODO this because f seem a useless variable and i do not know for what we use maybe game:frame()
		priority.air = turtle.priority
		if turtle.air > 0 then priority.air = priority.air + (turtle.air / 100) end
		ward = { turtle = turtle, position = turtle.position, priority = priority, threatened = f, defenders = {}, guardDistance = turtle.size, scrambleForMe = turtle.priority > 4 }
	end
	if ward ~= nil then
		table.insert(self.wards, ward)
		for GAS, p in pairs(priority) do
			if p > 0 then
				self.totalPriority[GAS] = self.totalPriority[GAS] + p
				self:MarkAllMtypesForAssignment(GAS)
			end
		end
	end
end

function DefendHST:RemoveWard(behaviour, turtle)
	for i, ward in pairs(self.wards) do
		-- either behaviour or turtle should be nil
		if behaviour == ward.behaviour and turtle == ward.turtle then
			for unitID, checkWard in pairs(self.wardsByDefenderID) do
				if ward == checkWard then
					local dfndbehaviour = self.defendersByID[unitID]
					if dfndbehaviour ~= nil then
						dfndbehaviour:Assign(nil)
						self.needAssignment[dfndbehaviour.hits][dfndbehaviour.mtype] = true
						self.wardsByDefenderID[unitID] = nil
					end
				end
			end
			for GAS, p in pairs(ward.priority) do
				self.totalPriority[GAS] = self.totalPriority[GAS] - p
				self:MarkAllMtypesForAssignment(GAS)
			end
			table.remove(self.wards, i)
			self:EchoDebug("ward removed from table. there are " .. #self.wards .. " wards total")
			break
		end
	end
end

function DefendHST:Update()
 	local f = self.game:Frame()
-- 	if f % 30 == 0 then
		if self.ai.schedulerhst.moduleTeam ~= self.ai.id or self.ai.schedulerhst.moduleUpdate ~= self:Name() then return end
		local scrambleCalls = 0
		for i, ward in pairs(self.wards) do
			if ward.behaviour ~= nil then
				if not ward.behaviour.isScout then
					if ward.threatened then
						if not ward.behaviour.underFire then
							local groundDiff = ward.priority.air - ward.priority.ground
							local submergedDiff = ward.priority.air - ward.priority.submerged
							if groundDiff > 0 then
								self:MarkAllMtypesForAssignment("ground")
								self.totalPriority.ground = self.totalPriority.ground + groundDiff
							end
							if submergedDiff > 0 then
								self:MarkAllMtypesForAssignment("submerged")
								self.totalPriority.submerged = self.totalPriority.submerged + submergedDiff
							end
							ward.threatened = nil
						end
					else
						if ward.behaviour.withinTurtle then
							if ward.prioritySnap == nil then
								ward.prioritySnap = {}
								for GAS, p in pairs(ward.priority) do
									ward.prioritySnap[GAS] = p+0
									self.totalPriority[GAS] = self.totalPriority[GAS] - p
									ward.priority[GAS] = 0
									self:MarkAllMtypesForAssignment(GAS)
								end
							end
						else
							if ward.prioritySnap ~= nil then
								for GAS, p in pairs(ward.prioritySnap) do
									ward.priority[GAS] = p+0
									self.totalPriority[GAS] = self.totalPriority[GAS] + p
									self:MarkAllMtypesForAssignment(GAS)
								end
								ward.prioritySnap = nil
							end
							if ward.behaviour.underFire then
								if ward.behaviour.response then
									for GAS, r in pairs(ward.behaviour.response) do
										if r > 0 then
											ward.priority[GAS] = ward.priority[GAS] + threatenedPriority
											self.totalPriority[GAS] = self.totalPriority[GAS] + threatenedPriority
											self:MarkAllMtypesForAssignment(GAS)
											ward.threatened = f
										end
									end
								end
							end
						end
					end
				end
			elseif ward.turtle ~= nil then
				if ward.threatened ~= nil then
					-- defend threatened turtles for ten seconds after they've stopped being threatened
					if f > ward.threatened + 300 then
						self.totalPriority.ground = self.totalPriority.ground - ward.priority.ground
						self.totalPriority.submerged = self.totalPriority.submerged - ward.priority.submerged
						if ward.priority.ground > 0 then self:MarkAllMtypesForAssignment("ground") end
						if ward.priority.submerged > 0 then self:MarkAllMtypesForAssignment("submerged") end
						ward.priority.ground, ward.priority.submerged = 0, 0
					else
						if ward.scrambleForMe then scrambleCalls = scrambleCalls + 1 end
					end
				end
			end
		end
		if scrambleCalls ~= 0 then
			self:Scramble()
		else
			self:Unscramble()
		end
		if self.frontWardWater ~= self.lastFrontWardWater then self:AssignLoiterers(self.frontWardWater) end
		if self.frontWardLand ~= self.lastFrontWardLand then self:AssignLoiterers(self.frontWardLand) end
		self.lastFrontWardWater = self.frontWardWater
		self.lastFrontWardLand = self.frontWardLand
	--end
	for GAS, mtypes in pairs(self.needAssignment) do
		for mtype, needAssignment in pairs(mtypes) do
			if needAssignment and f > self.lastAssignFrame[GAS][mtype] + 60 then
				-- only reassign every two seconds
				self:AssignAll(GAS, mtype)
				self.lastAssignFrame[GAS][mtype] = f
				self.needAssignment[GAS][mtype] = nil
			end
		end
	end
end

function DefendHST:AssignAll(GAS, mtype) -- Ground Air Submerged (weapon), mobility type
	if #self.wards == 0 then
		-- if nothing to defend, make sure defenders aren't defending ghosts (this causes a crash)
		self:EchoDebug("nothing to defend")
		for di, dfndbehaviour in pairs(self.defenders[GAS][mtype]) do
			dfndbehaviour:Assign(nil)
			self.wardsByDefenderID[dfndbehaviour.id] = nil
		end
		return
	end
	self:EchoDebug("assigning all defenders...")
	-- assign defenders to wards
	local defenders = self.defenders[GAS][mtype]
	local defendersPerPriority = #defenders / self.totalPriority[GAS]
	local defendersToAssign = {}
	local defendersToRemove = {}
	for nothing, dfndbehaviour in pairs(defenders) do
		table.insert(defendersToAssign, dfndbehaviour)
	end
	local notDefended
	local wardsAffected = {}
	for i, ward in pairs(self.wards) do
		local wardMtype
		if ward.behaviour ~= nil then
			wardMtype = ward.behaviour.mtype
		elseif ward.turtle ~= nil then
			if ward.turtle.water then wardMtype = "shp" else wardMtype = "veh" end
		end
		local number = 0
		if canDefend[mtype][wardMtype] then
			number = math.floor(ward.priority[GAS] * defendersPerPriority)
		end
		if number ~= 0 and #defendersToAssign ~= 0 then
			self:FreeDefenders(ward, GAS, mtype)
			table.insert(wardsAffected, ward)
			local wardPos = ward.position
			if wardPos == nil and ward.behaviour ~= nil then
				if ward.behaviour ~= nil then
					if ward.behaviour.unit ~= nil then
						local wardUnit = ward.behaviour.unit:Internal()
						if wardUnit ~= nil then
							wardPos = wardUnit:GetPosition()
						end
					end
				end
			end
			-- put into table to sort by self.ai.tool:distance
			local byselfdistance = {}
			for di = #defendersToAssign, 1, -1 do
				local dfndbehaviour = defendersToAssign[di]
				local okay = true
				for nothing, removedfndbehaviour in pairs(defendersToRemove) do
					if removedfndbehaviour == dfndbehaviour then
						table.remove(defendersToAssign, di)
						okay = false
						break
					end
				end
				if okay then
					if dfndbehaviour == nil then
						okay = false
					elseif dfndbehaviour.unit == nil then
						okay = false
					end
				end
				if okay then
					local defender = dfndbehaviour.unit:Internal()
					local ux, uy, uz = defender:GetPosition()
					if ux then
						if self.ai.maphst:UnitCanGoHere(defender, wardPos) then
							local defenderPos = defender:GetPosition()
							local dist = self.ai.tool:Distance(defenderPos, wardPos)
							byselfdistance[dist] = dfndbehaviour -- the probability of the same self.ai.tool:distance is near zero
						end
					else
						-- game:SendToConsole(self.ai.id, "defender unit nil position", defender:ID(), defender:Name())
					end
				end
			end
			-- add as many as needed, closest first
			local n = 0
			for dist, dfndbehaviour in self.ai.tool:pairsByKeys(byselfdistance) do
				if n < number then
					self.wardsByDefenderID[dfndbehaviour.id] = ward
					table.insert(ward.defenders, dfndbehaviour)
					table.insert(defendersToRemove, dfndbehaviour)
				else
					break
				end
				n = n + 1
			end
		elseif number == 0 then
			notDefended = ward
		end
	end
	if #defendersToAssign ~= 0 then
		local ward = notDefended
		if ward ~= nil then
			while #defendersToAssign > 0 do
				local dfndbehaviour = table.remove(defendersToAssign)
				self.wardsByDefenderID[dfndbehaviour.id] = ward
				table.insert(ward.defenders, dfndbehaviour)
			end
		end
	end
	-- find angles for each defender
	for i, ward in pairs(wardsAffected) do
		local divisor = #ward.defenders
		if divisor > 0 then
			if ward.angle == nil then
				local angleAdd = twicePi / divisor
				local angle = math.random() * twicePi
				for nothing, dfndbehaviour in pairs(ward.defenders) do
					dfndbehaviour:Assign(ward, angle)
					angle = angle + angleAdd
					if angle > twicePi then angle = angle - twicePi end
				end
			else
				local angle = ward.angle
				local d = -ward.guardDistance
				local dAdd = (ward.guardDistance * 2) / divisor
				for nothing, dfndbehaviour in pairs(ward.defenders) do
					dfndbehaviour:Assign(ward, angle, d)
					d = d + dAdd
				end
			end
		end
	end
	self:EchoDebug("all defenders assigned")
end

function DefendHST:AssignLoiterers(ward)
	-- assign siege units to hang around near the front
	if ward == nil then return end
	local mtypes, protection
	if ward.turtle.water then
		mtypes = { "sub", "shp", "hov" }
		protection = ward.turtle.submerged + (#ward.defenders * 200)
	else
		mtypes = { "veh", "bot", "amp", "hov" }
		protection = ward.turtle.ground + (#ward.defenders * 200)
	end
	local totalLoiterers = 0
	for i, mtype in pairs(mtypes) do totalLoiterers = totalLoiterers + #self.loiterers[mtype] end
	if protection > totalLoiterers * 200 then
		for i, mtype in pairs(mtypes) do
			local loiterers = self.loiterers[mtype]
			if #loiterers > 0 then
				local d = -ward.guardDistance * 0.5
				local dAdd = ward.guardDistance / totalLoiterers
				for li = 1, #loiterers do
					local dfndbehaviour = loiterers[li]
					dfndbehaviour:Assign(ward, ward.angle, d)
					self.wardsByDefenderID[dfndbehaviour.id] = ward
					d = d + dAdd
				end
			end
		end
	end
end

function DefendHST:FreeDefenders(ward, GAS, mtype)
	for i = #ward.defenders, 1, -1 do
		local dfndbehaviour = ward.defenders[i]
		if dfndbehaviour.hits == GAS and dfndbehaviour.mtype == mtype then
			table.remove(ward.defenders, i)
		end
	end
end

function DefendHST:MarkAllMtypesForAssignment(GAS)
	if self.defenders[GAS] == nil then return end
	for mtype, defenders in pairs(self.defenders[GAS]) do
		self.needAssignment[GAS][mtype] = true
	end
end

function DefendHST:IsDefendingMe(defenderUnit, wardBehaviour)
	local ward = self.wardsByDefenderID[defenderUnit:ID()]
	if ward ~= nil then
		return ward.behaviour == wardBehaviour
	else
		return false
	end
end

function DefendHST:IsDefender(dfndbehaviour)
	if self.defenders[dfndbehaviour.hits] == nil then
		self.defenders[dfndbehaviour.hits] = {}
	end
	if self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype] == nil then
		self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype] = {}
		return false
	end
	for i, db in pairs(self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype]) do
		if db == dfndbehaviour then
			return true
		end
	end
	return false
end

function DefendHST:IsLoiterer(dfndbehaviour)
	if self.loiterers[dfndbehaviour.mtype] == nil then
		self.loiterers[dfndbehaviour.mtype] = {}
		return false
	end
	for i, db in pairs(self.loiterers[dfndbehaviour.mtype]) do
		if db == dfndbehaviour then
			return true
		end
	end
	return false
end

function DefendHST:AddDefender(dfndbehaviour)
	if dfndbehaviour.tough or dfndbehaviour.hits == "air" then
		if not self:IsDefender(dfndbehaviour) then
			table.insert(self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype], dfndbehaviour)
			self.needAssignment[dfndbehaviour.hits][dfndbehaviour.mtype] = true
		end
	else
		if not self:IsLoiterer(dfndbehaviour) then
			table.insert(self.loiterers[dfndbehaviour.mtype], dfndbehaviour)
			self.needLoitererAssignment[dfndbehaviour.mtype] = true
		end
	end
end

function DefendHST:RemoveDefender(dfndbehaviour)
	-- Spring.Echo(self.ai.id, "remove defender", dfndbehaviour.hits, dfndbehaviour.mtype, self.defenders[dfndbehaviour.hits])
	if dfndbehaviour.tough or dfndbehaviour.hits == "air" then

		self:EchoDebug(self.defenders,#self.defenders,#self.defenders[dfndbehaviour.hits],#self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype])
		for i = #self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype], 1, -1 do
			local db = self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype][i]
			if db == dfndbehaviour then
				table.remove(self.defenders[dfndbehaviour.hits][dfndbehaviour.mtype], i)
				self.needAssignment[dfndbehaviour.hits][dfndbehaviour.mtype] = true
				-- return
			end
		end
	elseif self.loiterers[dfndbehaviour.mtype] then
		for i = #self.loiterers[dfndbehaviour.mtype], 1, -1 do
			local db = self.loiterers[dfndbehaviour.mtype][i]
			if db == dfndbehaviour then
				table.remove(self.loiterers[dfndbehaviour.mtype], i)
				self.needLoitererAssignment[dfndbehaviour.mtype] = true
				-- return
			end
		end
	end
end

function DefendHST:IsScramble(dfndbehaviour)
	for i, db in pairs(self.scrambles) do
		if db == dfndbehaviour then
			return true
		end
	end
	return false
end

function DefendHST:AddScramble(dfndbehaviour)
	if not self:IsScramble(dfndbehaviour) then
		table.insert(self.scrambles, dfndbehaviour)
		if self.scrambling then
			dfndbehaviour.scrambled = true
		end
	end
end

function DefendHST:RemoveScramble(dfndbehaviour)
	for i, db in pairs(self.scrambles) do
		if db == dfndbehaviour then
			table.remove(self.scrambles, i)
			break
		end
	end
end

function DefendHST:Scramble()
	if not self.scrambling then
		for i, db in pairs(self.scrambles) do
			db:Scramble()
		end
		self.scrambling = true
	end
end

function DefendHST:Unscramble()
	if self.scrambling then
		for i, db in pairs(self.scrambles) do
			db:Unscramble()
		end
		self.scrambling = false
	end
end

function DefendHST:FindFronts(troublingCells)
	if not troublingCells then return end
	local number = #troublingCells
	for n = 1, number do
		local tcells = troublingCells[n]
		for GAS, cell in pairs(tcells) do
			if GAS ~= "air" and cell ~= nil then
				local water = GAS == "submerged"
				local nearestMobileDist = 100000
				local nearestMobile
				local nearestTurtleDist = 100000
				local nearestTurtle
				for wardIndex , ward in pairs(self.wards) do
					if ward.behaviour ~= nil then
						local behaviour = ward.behaviour
						if not ward.behaviour.unit or not ward.behaviour.unit:Internal() or not ward.behaviour.unit:Internal():IsAlive() then
							table.remove(self.wards, wardIndex)
						else
							if water == behaviour.water then
								local dist = self.ai.tool:Distance(behaviour.unit:Internal():GetPosition(), cell.pos)
								if dist < nearestMobileDist then
									nearestMobileDist = dist
									nearestMobile = ward
								end
							end
							if ward.frontNumber[GAS] > 0 then self:SetDangerZone(ward, 0, number, GAS) end
						end
					elseif n == 1 and ward.turtle ~= nil then
						local turtle = ward.turtle
						turtle.threatForecastAngle = nil
						turtle.front = nil
						if water == turtle.water then
							if turtle.priority > 1 then
								local dist = self.ai.tool:Distance(turtle.position, cell.pos)
								if dist < nearestTurtleDist then
									nearestTurtleDist = dist
									nearestTurtle = ward
								end
							end
						end
					end
				end
				if n == 1 then
					if nearestTurtle ~= nil then
						local turtle = nearestTurtle.turtle
						turtle.threatForecastAngle = self.ai.tool:AngleAtoB(turtle.position.x, turtle.position.z, cell.pos.x, cell.pos.z)
						turtle.front = true
						self:Danger(nil, turtle, GAS)
						self.ai.incomingThreat = cell.response[GAS]
						self.ai.frontPosition[GAS] = turtle.position
					else
						self.ai.incomingThreat = 0
					end
				end
				if nearestMobile ~= nil then
					self:SetDangerZone(nearestMobile, n, number, GAS)
				end
			end
		end
	end
end

function DefendHST:SetDangerZone(ward, n, number, GAS)
	local setPriority = ward.priority.air + 1 + (number - n)
	local priorityDiff = setPriority - ward.priority[GAS]
	if priorityDiff > 0 then
		ward.priority[GAS] = setPriority
		self.totalPriority[GAS] = self.totalPriority[GAS] + priorityDiff
		self:MarkAllMtypesForAssignment(GAS)
	end
	ward.frontNumber[GAS] = n
end

-- receive a signal that a building is threatened or a turtle is on the front
function DefendHST:Danger(behaviour, turtle, GAS)
	local f = self.game:Frame()
	if turtle == nil and behaviour ~= nil then turtle = self.ai.turtlehst:GetUnitTurtle(behaviour.id) end
	if turtle ~= nil then
		for i, ward in pairs(self.wards) do
			if ward.turtle == turtle then
				ward.threatened = f
				if ward.priority[GAS] == 0 then
					if turtle.front then
						ward.priority[GAS] = self.totalPriority[GAS]+0
						ward.angle = turtle.threatForecastAngle
						ward.scrambleForMe = turtle.priority > 4
						self.totalPriority[GAS] = self.totalPriority[GAS] + self.totalPriority[GAS]
						if GAS == "ground" then
							self.frontWardLand = ward
						elseif GAS == "submerged" then
							self.frontWardWater = ward
						end
					else
						local priority = turtle.priority
						ward.priority[GAS] = priority
						ward.scrambleForMe = turtle.priority > 4
						self.totalPriority[GAS] = self.totalPriority[GAS] + priority
					end
					self:MarkAllMtypesForAssignment(GAS)
				end
				return
			end
		end
	end
end

function DefendHST:WardSafe(ward)
	local f = self.game:Frame()
	local behaviour = ward.behaviour
	local threatened = ward.threatened
	if behaviour ~= nil then
		return not behaviour.underFire
	elseif threatened ~= nil then
		return f > threatened + 300
	end
	return true
end

function DefendHST:GetGuardDistance(unitName)
	local dist = self.unitGuardDistances[unitName]
	if dist ~= nil then return dist end
	local utable = self.ai.armyhst.unitTable[unitName]
	dist = (math.max(utable.xsize, utable.zsize) * 4) + 100
	self.unitGuardDistances[unitName] = dist
	return dist
end
