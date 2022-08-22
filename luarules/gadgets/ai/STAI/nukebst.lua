NukeBST = class(Behaviour)

function NukeBST:Name()
	return "NukeBST"
end

function NukeBST:Init()
	self.DebugEnabled = false
	local uname = self.unit:Internal():Name()
	if uname == "armemp" then
		self.stunning = true
	elseif uname == "cortron" then
		self.tactical = true
	end
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
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'NukeBST' then return end
	local f = game:Frame()
	if not self.active then return end
	if self.finished then
		self.gotTarget = false
		self.stock, self.pile = self:CurrentStockpile()
		if self.stock + self.pile < 2 then
			self.unit:Internal():Stockpile()
		end
		local bestCell
		if self.tactical then
			bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 2500)
		elseif self.stunning then
			bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 3000, true) -- only targets threats
		else
			bestCell = self.ai.self:GetBestNukeCell()
		end
		if bestCell then
			self.gotTarget = true
			self.unit:Internal():AreaAttack(bestCell.POS,0)
			self:EchoDebug("got target")
		end
	end
end

function NukeBST:GetBestNukeCell()
	local best
	local bestValueThreat = 0
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z, cell in pairs(cells) do
			local areaCell = self.ai.armyhst:areaCells(X,Z,2,self.ai.loshst.ENEMY)
			if areaCell > bestValueThreat then
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
