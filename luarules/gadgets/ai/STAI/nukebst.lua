NukeBST = class(Behaviour)

function NukeBST:Name()
	return "NukeBST"
end

NukeBST.DebugEnabled = false

function NukeBST:Init()
	local uname = self.unit:Internal():Name()
	if uname == "armemp" then
		self.stunning = true
	elseif uname == "cortron" then
		self.tactical = true
	end
	self.stockpileTime = self.ai.armyhst.nukeList[uname]
	self.position = self.unit:Internal():GetPosition()
	self.range = self.ai.armyhst.unitTable[uname].groundRange
    self.lastStockpileFrame = 0
    self.lastLaunchFrame = 0
    self.gotTarget = false
    self.finished = false
end

function NukeBST:OwnerBuilt()
	self.finished = true
	self.unit:Internal():Stockpile()
	self.unit:Internal():Stockpile()
end

function NukeBST:Update()
-- 	 self.uFrame = self.uFrame or 0
--
-- 	if f - self.uFrame < self.ai.behUp['nukebst']  then
-- 		return
-- 	end
-- 	self.uFrame = f
	local f = game:Frame()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'NukeBST' then return end
	if not self.active then return end

	--local f = self.game:Frame()

	if self.finished then
		--if f > self.lastLaunchFrame + 100 then
			self.gotTarget = false
			if self.ai.needNukes and self.ai.canNuke then
				local bestCell
				if self.tactical then
					bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 2500)
				elseif self.stunning then
					bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 3000, true) -- only targets threats
				else
					bestCell = self.ai.self:GetBestNukeCell()
				end
				if bestCell ~= nil then
					local position = bestCell.pos
					local floats = api.vectorFloat()
					-- populate with x, y, z of the position
					floats:push_back(position.x)
					floats:push_back(position.y)
					floats:push_back(position.z)
					self.unit:Internal():AreaAttack(floats,0)
					self.gotTarget = true
					self:EchoDebug("got target")
				end
			end
			self.lastLaunchFrame = f
		--end
		if self.gotTarget then
			if self.lastStockpileFrame == 0 or f > self.lastStockpileFrame + self.stockpileTime then
				self.lastStockpileFrame = f
			end
		end
	end
end

function NukeBST:GetBestNukeCell()
	local best
	local bestValueThreat = 0
	for i, G in pairs(self.ENEMYCELLS) do
		local cell = self.ai.targethst.CELLS[G.x][G.z]
		if cell.pos then
			if CELL.ENEMY > bestValueThreat then
				best = cell
				bestValueThreat = valuethreat
			end
		end
	end
	return best, bestValueThreat
end

function NukeBST:Activate()
	self.active = true
end

function NukeBST:Deactivate()
	self.active = false
end

function NukeBST:Priority()
	return 100
end
