 DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("RaiderBehaviour: " .. inStr)
	end
end

local CMD_IDLEMODE = 145
local CMD_MOVE_STATE = 50
local MOVESTATE_ROAM = 2

function IsRaider(unit)
	for i,name in ipairs(raiderList) do
		if name == unit:Internal():Name() then
			return true
		end
	end
	return false
end

RaiderBehaviour = class(Behaviour)

function RaiderBehaviour:Init()
	local mtype, network = self.ai.maphandler:MobilityOfUnit(self.unit:Internal())
	self.mtype = mtype
	self.name = self.unit:Internal():Name()
	local utable = unitTable[self.name]
	if self.mtype == "sub" then
		self.range = utable.submergedRange
	else
		self.range = utable.groundRange
	end
	self.id = self.unit:Internal():ID()
	self.disarmer = raiderDisarms[self.name]
	if self.ai.raiderCount[mtype] == nil then
		self.ai.raiderCount[mtype] = 1
	else
		self.ai.raiderCount[mtype] = self.ai.raiderCount[mtype] + 1
	end
end

function RaiderBehaviour:UnitDead(unit)
	if unit.engineID == self.unit.engineID then
		-- game:SendToConsole("raider " .. self.name .. " died")
		if self.target then
			self.ai.targethandler:AddBadPosition(self.target, self.mtype)
		end
		self.ai.raidhandler:NeedLess(self.mtype)
		self.ai.raiderCount[self.mtype] = self.ai.raiderCount[self.mtype] - 1
	end
end

function RaiderBehaviour:UnitIdle(unit)
	if unit.engineID == self.unit.engineID then
		self.target = nil
		self.evading = false
		-- keep planes from landing (i'd rather set land state, but how?)
		if self.mtype == "air" then
			self.moveNextUpdate = RandomAway(unit:Internal():GetPosition(), 500)
		end
		self.unit:ElectBehaviour()
	end
end

function RaiderBehaviour:RaidCell(cell)
	EchoDebug(self.name .. " raiding cell...")
	if self.unit == nil then
		EchoDebug("no raider unit to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	elseif self.unit:Internal() == nil then 
		EchoDebug("no raider unit internal to raid cell with!")
		-- self.ai.raidhandler:RemoveRecruit(self)
	else
		if self.buildingIDs ~= nil then
			self.ai.raidhandler:IDsWeAreNotRaiding(self.buildingIDs)
		end
		self.ai.raidhandler:IDsWeAreRaiding(cell.buildingIDs, self.mtype)
		self.buildingIDs = cell.buildingIDs
		self.target = RandomAway(cell.pos, self.range * 0.5)
		if self.mtype == "air" then
			if self.disarmer then
				self.unitTarget = cell.disarmTarget
			else
				self.unitTarget = cell.targets.air.ground
			end
			EchoDebug("air raid target: " .. tostring(self.unitTarget.unitName))
		end
		if self.active then
			if self.mtype == "air" then
				if self.unitTarget ~= nil then
					CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
				end
			else
				self.unit:Internal():Move(self.target)
			end
		end
		self.unit:ElectBehaviour()
	end
end

function RaiderBehaviour:Priority()
	if not self.target then
		-- revert to scouting
		return 0
	else
		return 100
	end
end

function RaiderBehaviour:Activate()
	EchoDebug(self.name .. " active")
	self.active = true
	if self.target then
		if self.mtype == "air" then
			if self.unitTarget ~= nil then
				CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
			end
		else
			self.unit:Internal():Move(self.target)
		end
	end
end

function RaiderBehaviour:Deactivate()
	EchoDebug(self.name .. " inactive")
	self.active = false
	self.target = nil
end

function RaiderBehaviour:Update()
	local f = game:Frame()

	if not self.active then
		if f % 89 == 0 then
			local unit = self.unit:Internal()
			local bestCell = self.ai.targethandler:GetBestRaidCell(unit)
			self.ai.targethandler:RaiderHere(self)
			EchoDebug(self.name .. " targetting...")
			if bestCell then
				EchoDebug(self.name .. " got target")
				self:RaidCell(bestCell)
			else
				self.target = nil
				self.unit:ElectBehaviour()
				-- revert to scouting
			end
		end
	else
		if self.moveNextUpdate then
			self.unit:Internal():Move(self.moveNextUpdate)
			self.moveNextUpdate = nil
		elseif f % 29 == 0 then
			-- attack nearby vulnerables immediately
			local unit = self.unit:Internal()
			local attackTarget
			if self.ai.targethandler:IsSafePosition(unit:GetPosition(), unit, 1) then
				attackTarget = self.ai.targethandler:NearbyVulnerable(unit)
			end
			if attackTarget then
				CustomCommand(unit, CMD_ATTACK, {attackTarget.unitID})
			else
				-- evade enemies on the way to the target, if possible
				if self.target ~= nil then
					local newPos, arrived = self.ai.targethandler:BestAdjacentPosition(unit, self.target)
					self.ai.targethandler:RaiderHere(self)
					if newPos then
						EchoDebug(self.name .. " evading")
						unit:Move(newPos)
						self.evading = true
					elseif arrived then
						EchoDebug(self.name .. " arrived")
						-- if we're at the target
						self.evading = false
					elseif self.evading then
						EchoDebug(self.name .. " setting course to taget")
						-- return to course to target after evading
						if self.mtype == "air" then
							if self.unitTarget ~= nil then
								CustomCommand(self.unit:Internal(), CMD_ATTACK, {self.unitTarget.unitID})
							end
						else
							self.unit:Internal():Move(self.target)
						end
						self.evading = false
					end
				end
			end
		end
	end
end

-- set all raiders to roam
function RaiderBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local floats = api.vectorFloat()
		floats:push_back(MOVESTATE_ROAM)
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
		if self.mtype == "air" then
			local floats = api.vectorFloat()
			floats:push_back(1)
			thisUnit:Internal():ExecuteCustomCommand(CMD_IDLEMODE, floats)
		end
	end
end