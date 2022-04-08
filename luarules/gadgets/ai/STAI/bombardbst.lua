BombardBST = class(Behaviour)

function BombardBST:Name()
	return "BombardBST"
end

local CMD_ATTACK = 20
local valueThreatThreshold = 1600 -- any cell above this level of value+threat will be shot at manually

function BombardBST:Init()
	self.DebugEnabled = false
    self.lastFireFrame = 0
    self.targetFrame = 0
    local unit = self.unit:Internal()
    self.position = unit:GetPosition()
    self.range = self.ai.armyhst.unitTable[unit:Name()].groundRange
    self.radsPerFrame = 0.015
end

function BombardBST:Fire()
	if self.target ~= nil then
		self:EchoDebug("firing")
		local floats = api.vectorFloat()
		-- populate with x, y, z of the position
		floats:push_back(self.target.x)
		floats:push_back(self.target.y)
		floats:push_back(self.target.z)
		self.unit:Internal():MoveAndFire(floats) --TEST
		--self.unit:Internal():ExecuteCustomCommand(CMD_ATTACK, floats)
		self.lastFireFrame = self.game:Frame()
	end
end

function BombardBST:CeaseFire()
	self.target = nil
	self.unit:Internal():Stop()
end

function BombardBST:OwnerIdle()
	if self.active then
		self.idle = true
	end
end

function BombardBST:Update()
	if not self.active then
		return
	end
	local f = self.game:Frame()
	if f % 307 ~= 0 then
		return
	end
	self:EchoDebug("retargeting")
	--local bestCell, valueThreat, buildingID = self.ai.targethst:GetBestBombardCell(self.position, self.range, valueThreatThreshold)
	local bestCell, valueThreat, buildingID = self:GetTarget()
	if bestCell then
		local newTarget
		if buildingID then
			local building = self.game:GetUnitByID(buildingID)
			if building then
				newTarget = building:GetPosition()
			end
		end
		if not newTarget then newTarget = bestCell.pos end
		if newTarget ~= self.target then
			local newAngle = self.ai.tool:AngleAtoB(self.position.x, self.position.z, newTarget.x, newTarget.z)
			local ago = f - self.targetFrame
			self:EchoDebug(ago, newAngle, self.targetAngle)
			if self.targetAngle then
				if AngleDist(self.targetAngle, newAngle) > ago * self.radsPerFrame then
					newTarget = nil
				end
			end
			if newTarget then
				self.target = newTarget
				self.targetFrame = f
				self.targetAngle = newAngle
				self:EchoDebug("new high priority target: " .. valueThreat)
				self:Fire()
			end
		end
	else
		self:EchoDebug("no target, ceasing manual controlled fire")
		self:CeaseFire()
	end
end

function BombardBST:GetTarget(unit)
	local bestCell = nil
	local bestValue = 0
	for index,G in pairs(self.ai.targethst.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.gx][G.Gx]
		if self.ai.tool:Distance(self.position,sell.pos) < self.range then
			if cell.ENEMY > bestValue then
				bestCell = cell
				bestValue = cell.ENEMY
			end
		end
	end
	return bestValue
end

function BombardBST:IsBombardPosition(position, unitName) --example: there are more than bertha * 2 metal to bombard around?
	local R = math.floor(self.ai.armyhst.unitTable[unitName].G_R / cellElmos)
	local enemies = self:getCellsFields(position,{'ENEMY'},R)
	return self.ai.armyhst.unitTable[unitName].metalCost * 2 < enemies
end

function BombardBST:Activate()
	self.active = true
end

function BombardBST:Deactivate()
	self.active = false
end

function BombardBST:Priority()
	return 100
end
