-- keeps track of where enemy units seem to be moving

local DebugEnabled = false
local DebugDrawEnabled = false

TacticalHST = class(Module)

function TacticalHST:EchoDebug(inStr)
	if DebugEnabled then
		self.game:SendToConsole("TacticalHST: " .. inStr)
	end
end

function TacticalHST:PlotDebug(x1, z1, vx, vz, label)
	if DebugDrawEnabled then
		local x2 = x1 + vx * 1200
		local z2 = z1 + vz * 1200
		local pos1, pos2 = api.Position(), api.Position()
		pos1.x, pos1.z = x1, z1
		pos2.x, pos2.z = x2, z2
		self.map:DrawLine(pos1, pos2, {1,0,0}, label, true, 9)
	end
end

function TacticalHST:Name()
	return "TacticalHST"
end

function TacticalHST:internalName()
	return "tacticalhst"
end

function TacticalHST:Init()
	self.lastPositionsFrame = 0
	self.lastAverageFrame = 0
	self.lastPositions = {}
	self.lastKnownPositions = {}
	self.lastKnownVectors = {}
	self.unitSamples = {}
	self.threatLayerNames = { "ground", "air", "submerged" }
	self.ai.incomingThreat = 0
end

function TacticalHST:NewEnemyPositions(positions)
	local f = self.game:Frame()
	local since = f - self.lastPositionsFrame
	local update = {}
	for i, e in pairs(positions) do
		local le = self.lastPositions[e.unitID]
		if le then
			local vx = e.position.x - le.position.x
			local vz = e.position.z - le.position.z
			if abs(vx) > 0 or abs(vz) > 0 then
				vx = vx / since
				vz = vz / since
				if not self.unitSamples[e.unitID] then
					self.unitSamples[e.unitID] = {}
				end
				table.insert(self.unitSamples[e.unitID], { vx = vx, vz = vz })
			end
			self.lastKnownPositions[e.unitID] = e
		end
		update[e.unitID] = e
	end
	self.lastPositions = update
	self.lastPositionsFrame = f
	self:AverageSamples()
end

function TacticalHST:AverageUnitSamples(samples)
	local totalVX = 0
	local totalVZ = 0
	for i, sample in pairs(samples) do
		totalVX = totalVX + sample.vx
		totalVZ = totalVZ + sample.vz
	end
	local vx = totalVX / #samples
	local vz = totalVZ / #samples
	return vx, vz
end

function TacticalHST:AverageSamples()
	local f = self.game:Frame()
	local since = f - self.lastAverageFrame
	if since < 300 then return end
	-- self.ai.turtlehst:ResetThreatForecast()
	if DebugDrawEnabled then
		self.map:EraseAll(9)
	end
	for unitID, samples in pairs(self.unitSamples) do
		local e = self.lastKnownPositions[unitID]
		if e then
			local vx, vz = self:AverageUnitSamples(samples)
			self.lastKnownVectors[unitID] = { vx = vx, vz = vz } -- so that anyone using this unit table as a target will be able to lead a little
			self:PlotDebug(e.position.x, e.position.z, vx, vz)
			-- self.ai.turtlehst:AddThreatVector(e, vx, vz)
		end
	end
	-- self.ai.turtlehst:AlertDangers()
	self.unitSamples = {}
	self.lastAverageFrame = f
end

-- for raider and other targetting export
function TacticalHST:PredictPosition(unitID, frames)
	local vector = self.lastKnownVectors[unitID]
	if vector == nil then return end
	local e = self.lastKnownPositions[unitID]
	if e == nil then return end
	return ApplyVector(e.position.x, e.position.z, vector.vx, vector.vz, frames)
end

-- so our tables don't bloat
function TacticalHST:UnitDead(unit)
	local unitID = unit:ID()
	self.lastKnownPositions[unitID] = nil
	self.lastKnownVectors[unitID] = nil
	self.unitSamples[unitID] = nil
end
