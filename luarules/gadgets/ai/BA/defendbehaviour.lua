

local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("DefendBehaviour: " .. inStr)
	end
end

local CMD_GUARD = 25
local CMD_PATROL = 15
local CMD_MOVE_STATE = 50
local MOVESTATE_ROAM = 2

-- not does it defend, but is it a dedicated defender
function IsDefender(unit)
	return defenderList[unit:Internal():Name()] or false
end

DefendBehaviour = class(Behaviour)

function DefendBehaviour:Name()
	return "DefendBehaviour"
end

function DefendBehaviour:Init()
	self.moving = {}
	self.unmoved = 0
	self.lastPos = self.unit:Internal():GetPosition()
	self.active = false
	self.id = self.unit:Internal():ID()
	self.name = self.unit:Internal():Name()
	local ut = unitTable[self.name]
	self.tough = battleList[self.name] or breakthroughList[self.name]
	self.isDefender = IsDefender(self.unit)
	self.mtype = unitTable[self.name].mtype
	-- defenders need to be sorted into only one type of weapon
	if ut.groundRange > 0 then
		self.hits = "ground"
	elseif ut.submergedRange > 0 then
		self.hits = "submerged"
	elseif ut.airRange > 0 then
		self.hits = "air"
	end
	for i, name in pairs(raiderList) do
		if name == self.name then
			EchoDebug(self.name .. " is scramble")
			self.scramble = true
			if self.mtype ~= "air" then
				self.ai.defendhandler:AddScramble(self)
			end
			break
		end
	end
	-- keeping track of how many of each type of unit
	EchoDebug("added to unit "..self.name)
end

function DefendBehaviour:OwnerDead()
	-- game:SendToConsole("defender " .. self.name .. " died")
	if self.scramble then
		self.ai.defendhandler:RemoveScramble(self)
		if self.scrambled then
			self.ai.defendhandler:RemoveDefender(self)
		end
	else
		self.ai.defendhandler:RemoveDefender(self)
	end
end

function DefendBehaviour:OwnerIdle()
	self.unit:ElectBehaviour()
end

function DefendBehaviour:Update()
	if self.unit == nil then return end
	local unit = self.unit:Internal()
	if ShardSpringLua and not unit:GetPosition() then
		-- game:SendToConsole(self.ai.id, "undead defend behaviour", unit:ID(), unit:Name())
		self:UnitDead(self.unit)
	end
	if unit == nil then return end
	if self.active then
		local f = game:Frame()
		if f % 60 == 0 then
			if self.target == nil then return end
			local targetPos = self.target.position or BehaviourPosition(self.target.behaviour)
			if targetPos == nil then return end
			targetPos.y = 0
			local guardDistance = self.target.guardDistance
			if not self.tough then guardDistance = guardDistance * 0.33 end
			local guardPos = RandomAway(targetPos, guardDistance, false, self.guardAngle)
			local safe = self.ai.defendhandler:WardSafe(self.target)
			-- if targetPos.y > 100 then game:SendToConsole(targetPos.y .. " " .. type(self.target.behaviour)) end
			local unitPos = unit:GetPosition()
			local dist = Distance(unitPos, guardPos)
			local behaviour = self.target.behaviour
			if self.perpendicular then
				guardPos = RandomAway(guardPos, self.perpDist, false, self.perpendicular)
			end
			if behaviour ~= nil then
				if dist > 500 then
					if self.guarding ~= behaviour.id then
						-- move toward mobile wards that are far away with guard order
						CustomCommand(self.unit:Internal(), CMD_GUARD, {behaviour.id})
						self.guarding = behaviour.id
					end
				elseif not safe then
					if dist > 250 then
						unit:Move(guardPos)
						self.guarding = nil
					end
				elseif dist > 25 then
					unit:Move(guardPos)
					self.guarding = nil
				end
				self.moving = {}
			else
				self.guarding = nil
				local boredNow = self.ai.targethandler:IsSafePosition(unitPos, unit)
				if self.moving.x ~= targetPos.x or self.moving.z ~= targetPos.z or (self.unmoved > 5 and boredNow) or (not self.tough and dist > self.target.guardDistance) then
					unit:Move(guardPos)
					self.moving.x = targetPos.x
					self.moving.z = targetPos.z
				end
			end
			if self.lastPos.x == unitPos.x and self.lastPos.z == unitPos.z then
				self.unmoved = self.unmoved + 1
			else
				self.unmoved = 0
			end
			self.lastPos = api.Position()
			self.lastPos.x, self.lastPos.z = unitPos.x+0, unitPos.z+0
			self.unit:ElectBehaviour()
		end
	end
end

function DefendBehaviour:Assign(ward, angle, dist)
	if ward == nil then
		self.target = nil
	else
		self.target = ward
		self.guardAngle = angle or math.random() * twicePi
		if dist then
			self.perpendicular = AngleAdd(angle, halfPi)
			self.perpDist = dist
		else
			self.perpendicular = nil
			self.perpDist = nil
		end
	end
end

function DefendBehaviour:Scramble()
	EchoDebug(self.name .. " scrambled")
	self.scrambled = true
	self.unit:ElectBehaviour()
end

function DefendBehaviour:Unscramble()
	EchoDebug(self.name .. " unscrambled")
	self.scrambled = false
	self.unit:ElectBehaviour()
end

function DefendBehaviour:Activate()
	EchoDebug("active on "..self.name)
	self.active = true
	self.target = nil
	self.targetPos = nil
	self.guarding = nil
	self.ai.defendhandler:AddDefender(self)
	self:SetMoveState()
end

function DefendBehaviour:Deactivate()
	EchoDebug("inactive on "..self.name)
	self.active = false
	self.target = nil
	self.targetPos = nil
	self.guarding = nil
	self.ai.defendhandler:RemoveDefender(self)
end

function DefendBehaviour:Priority()
	if self.scramble then
		if self.scrambled then
			return 110
		else
			return 0
		end
	else
		return 40
	end
end

-- set all defenders to roam
function DefendBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local floats = api.vectorFloat()
		floats:push_back(MOVESTATE_ROAM)
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
	end
end