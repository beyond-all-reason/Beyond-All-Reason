BootBST = class(Behaviour)

function BootBST:Name()
	return "BootBST"
end
--[[
local CMD_MOVE_STATE = 50
local MOVESTATE_HOLDPOS = 0]]

function BootBST:Init()
	DebugEnabled = false
	self.id = self.unit:Internal():ID()
	self.name = self.unit:Internal():Name()
	self.mobile = self.ai.armyhst.unitTable[self.name].speed == 0
	self.mtype = self.ai.armyhst.unitTable[self.name].mtype
	self.lastInFactoryCheck = self.game:Frame()
	-- air units don't need to leave the factory
	self.ignoreFactories = self.mtype == "air" or not self.mobile
	self.finished = false
	if not self.ignoreFactories then self:FindMyFactory() end
	self.unit:ElectBehaviour()
end

function BootBST:OwnerBuilt()
	self.finished = true
	if self.active then self.lastOrderFrame = self.game:Frame() end
end

function BootBST:OwnerDead()
	self.factory = nil
end

function BootBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'BootBST' then return end
	local f = self.game:Frame()
	if not self.finished  then return end
	if self.ignoreFactories then return end
	if self.factory then
			local pos = self.ai.tool:UnitPos(self)
			if not self.ai.tool:PositionWithinRect(pos, self.factory.exitRect) then
				self.factory = nil
				self.unit:ElectBehaviour()
			elseif self.active and self.lastOrderFrame and self.lastExitSide then
				-- 4 seconds after the first attempt, try a different side
				-- if there's only one side, try it again
				if f > self.lastOrderFrame + 12 then
					local face, nsew =self.ai.buildingshst:GetFacing(pos)
					self:ExitFactory(face)

				end
			end
	else
		if f > self.lastInFactoryCheck + 300 then
			
			-- units (especially construction units) can still get stuck in factories long after they're built
			self.lastInFactoryCheck = f
			self:FindMyFactory()
			if self.factory then
				self:EchoDebug(self.name .. " is in a factory")
				self.unit:ElectBehaviour()
			end
		end
	end
end

function BootBST:Activate()
	self:EchoDebug("activated on " .. self.name)
	self.active = true
	if self.repairedBy then
		self:SetMoveState()
	elseif self.factory then
		self:ExitFactory()
	end
end

function BootBST:Deactivate()
	self:EchoDebug("deactivated on " .. self.name)
	self.active = false
end

function BootBST:Priority()
	if self.factory or (self.repairedBy and self.mobile) then
		return 120
	else
		return 0
	end
end

-- set to hold position while being repaired after resurrect
function BootBST:SetMoveState()
	local thisUnit = self.unit
	if thisUnit then
		self.ai.tool:GiveOrder(self.id, CMD.MOVE_STATE, 0, 0,'1-1')
		--thisUnit:Internal():HoldPosition()
	end
end

function BootBST:FindMyFactory()
	local pos = self.ai.tool:UnitPos(self)
	for id,lab in pairs(self.ai.labshst.labs) do
		if self.ai.tool:PositionWithinRect(pos, lab.exitRect) then
			self.factory = lab.behaviour
		end
	end
	self.factory = nil
end

function BootBST:ExitFactory(face)
	local pos = self.factory.position
	face = face or self.ai.buildingshst:GetFacing(pos)
	self:EchoDebug(self.name .. " exiting " .. face)
	local outX, outZ
	if face == 0 then
		outX = 0
		outZ = 200
	elseif face == 2 then
		outX = 0
		outZ = -200
	elseif face == 3 then
		outX = -200
		outZ = 0
	elseif face == 1 then
		outX = 200
		outZ = 0
	end
	local u = self.unit:Internal()

	local out = api.Position()
	out.x = pos.x + outX
	out.y = pos.y + 0
	out.z = pos.z + outZ
-- 	local mapSize = self.map:MapDimensions()
-- 	local maxElmosX = mapSize.x * 8
-- 	local maxElmosZ = mapSize.z * 8
	if out.x > self.ai.maphst.elmoMapSizeX - 1 then
		out.x = self.ai.maphst.elmoMapSizeX - 1
	elseif out.x < 1 then
		out.x = 1
	end
	if out.z > self.ai.maphst.elmoMapSizeZ - 1 then
		out.z = self.ai.maphst.elmoMapSizeZ - 1
	elseif out.z < 1 then
		out.z = 1
	end
 	u:Move(out)
	self.ai.tool:GiveOrderToUnit(u, CMD.MOVE, {out.x, out.y, out.z}, 0,'1-1')
	self.lastOrderFrame = self.game:Frame()
	self.lastExitSide = face
end
