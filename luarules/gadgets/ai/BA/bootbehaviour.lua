-- Sends units out of factories and holds units in place who are being repaired after resurrection
BootBehaviour = class(Behaviour)

function BootBehaviour:Name()
	return "BootBehaviour"
end

local DebugEnabled = false


local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("BootBehaviour: " .. inStr)
	end
end

local CMD_MOVE_STATE = 50
local MOVESTATE_HOLDPOS = 0

function BootBehaviour:Init()
	self.id = self.unit:Internal():ID()
	self.name = self.unit:Internal():Name()
	self.mobile = not unitTable[self.name].isBuilding
	self.mtype = unitTable[self.name].mtype
	self.lastInFactoryCheck = game:Frame()
	self.repairedBy = self.ai.buildsitehandler:ResurrectionRepairedBy(self.id)
	-- air units don't need to leave the factory
	self.ignoreFactories = self.mtype == "air" or not self.mobile
	self.finished = false
	if not self.ignoreFactories then self:FindMyFactory() end
	self.unit:ElectBehaviour()
end

function BootBehaviour:OwnerBuilt()
	self.finished = true
	if self.active then self.lastOrderFrame = game:Frame() end
end

function BootBehaviour:OwnerDead()
	self.factory = nil
	if self.repairedBy then self.repairedBy:ResurrectionComplete() end
	self.ai.buildsitehandler:RemoveResurrectionRepairedBy(self.id)
	self.repairedBy = nil
end

function BootBehaviour:Update()
	if not self.finished then return end

	local f = game:Frame()

	if self.repairedBy then
		if f % 30 == 0 then
			if self.unit:Internal():GetHealth() == self.unit:Internal():GetMaxHealth() then
				self.repairedBy:ResurrectionComplete()
				self.repairedBy = nil
				self.unit:ElectBehaviour()
			end
		end
		return
	end

	if self.ignoreFactories then return end

	if self.factory then
		if f % 30 == 0 then
			local u = self.unit:Internal()
			local pos = u:GetPosition()
			-- EchoDebug(pos.x .. " " .. pos.z .. " " .. self.factory.exitRect.x1 .. " " .. self.factory.exitRect.z1 .. " " .. self.factory.exitRect.x2 .. " " .. self.factory.exitRect.z2)
			if not PositionWithinRect(pos, self.factory.exitRect) then
				self.factory = nil
				self.unit:ElectBehaviour()
			elseif self.active and self.lastOrderFrame and self.lastExitSide then
				-- twelve seconds after the first attempt, try a different side
				-- if there's only one side, try it again
				if f > self.lastOrderFrame + 360 then
					if self.factory.sides == 1 then
						self:ExitFactory("south")
					elseif self.factory.sides == 2 then
						if self.lastExitSide == "south" then
							self:ExitFactory("north")
						elseif self.lastExitSide == "north" then
							self:ExitFactory("south")
						end
					elseif self.factory.sides == 3 then
						if self.lastExitSide == "south" then
							self:ExitFactory("east")
						elseif self.lastExitSide == "east" then
							self:ExitFactory("west")
						elseif self.lastExitSide == "west" then
							self:ExitFactory("south")
						end
					elseif self.factory.sides == 4 then
						if self.lastExitSide == "south" then
							self:ExitFactory("north")
						elseif self.lastExitSide == "north" then
							self:ExitFactory("east")
						elseif self.lastExitSide == "east" then
							self:ExitFactory("west")
						elseif self.lastExitSide == "west" then
							self:ExitFactory("south")
						end
					end
				end
			end
		end
	else
		if f > self.lastInFactoryCheck + 300 then
			-- units (especially construction units) can still get stuck in factories long after they're built
			self.lastInFactoryCheck = f
			self:FindMyFactory()
			if self.factory then
				EchoDebug(self.name .. " is in a factory")
				self.unit:ElectBehaviour()
			end
		end
	end
end

function BootBehaviour:Activate()
	EchoDebug("activated on " .. self.name)
	self.active = true
	if self.repairedBy then
		self:SetMoveState()
	elseif self.factory then
		self:ExitFactory("south")
	end
end

function BootBehaviour:Deactivate()
	EchoDebug("deactivated on " .. self.name)
	self.active = false
end

function BootBehaviour:Priority()
	if self.factory or (self.repairedBy and self.mobile) then
		return 120
	else
		return 0
	end
end

-- set to hold position while being repaired after resurrect
function BootBehaviour:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		local floats = api.vectorFloat()
		floats:push_back(MOVESTATE_HOLDPOS)
		thisUnit:Internal():ExecuteCustomCommand(CMD_MOVE_STATE, floats)
	end
end

function BootBehaviour:FindMyFactory()
	local pos = self.unit:Internal():GetPosition()
	for level, factories in pairs(self.ai.factoriesAtLevel) do
		for i, factory in pairs(factories) do
			if PositionWithinRect(pos, factory.exitRect) then
				self.factory = factory
				return
			end
		end
	end
	self.factory = nil
end

function BootBehaviour:ExitFactory(side)
		EchoDebug(self.name .. " exiting " .. side)
		local outX, outZ
		if side == "south" then
			outX = 0
			outZ = 200
		elseif side == "north" then
			outX = 0
			outZ = -200
		elseif side == "east" then
			outX = 200
			outZ = 0
		elseif side == "west" then
			outX = -200
			outZ = 0
		end
		local u = self.unit:Internal()
		local pos = self.factory.position
		local out = api.Position()
		out.x = pos.x + 0
		out.y = pos.y + outX
		out.z = pos.z + outZ
		if out.x > self.ai.maxElmosX - 1 then
			out.x = self.ai.maxElmosX - 1
		elseif out.x < 1 then
			out.x = 1
		end
		if out.z > self.ai.maxElmosZ - 1 then
			out.z = self.ai.maxElmosZ - 1
		elseif out.z < 1 then
			out.z = 1
		end
		u:Move(out)
		self.lastOrderFrame = game:Frame()
		self.lastExitSide = side
end