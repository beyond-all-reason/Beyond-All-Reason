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

function NukeBST:SetStock()
	self.stock, self.pile = self.unit:Internal():CurrentStockpile()
	if self.stock + self.pile < 2 then
		self.unit:Internal():Stockpile()
	end
end


function NukeBST:Update()
	if self.ai.schedulerhst.behaviourTeam ~= self.ai.id or self.ai.schedulerhst.behaviourUpdate ~= 'NukeBST' then return end
	local f = game:Frame()
	if not self.active then return end
	self:SetStock()
	if self.stock > 0 and not self.gotTarget then
		self.gotTarget = false

		local bestCell
		if self.tactical then
			bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 2500)
		elseif self.stunning then
			bestCell = self.ai.targethst:GetBestBombardCell(self.position, self.range, 3000, true) -- only targets threats
		else
			bestCell = self:GetBestNukeCell()
		end
		if bestCell then
			self.gotTarget = true
			self.currentTarget = bestCell

			self:EchoDebug("got target")
		end
	elseif self.stock > 0 and self.gotTarget then
		if not self.ai.loshst.ENEMY[self.currentTarget.X] or not self.ai.loshst.ENEMY[self.currentTarget.X][self.currentTarget.Z] then
			self.gotTarget = nil
			self.currentTarget = nil
			return
		end
		self.ai.tool:GiveOrder(self.unit:Internal():ID(),CMD.ATTACK, self.currentTarget.POS, 0,'1-1')
		--self.unit:Internal():AttackPos(self.currentTarget.POS)
		self:EchoDebug('current target:',self.currentTarget.POS.x,self.currentTarget.POS.z)
	end

end

function NukeBST:GetBestNukeCell()
	local best
	local bestValueThreat = 0
	for X, cells in pairs(self.ai.loshst.ENEMY) do
		for Z, cell in pairs(cells) do
			local areaCell = self.ai.maphst:getCellsFields(cell.POS,{'ENEMY'},2,self.ai.loshst.ENEMY)
			if areaCell and areaCell > bestValueThreat then
				best = cell
				bestValueThreat = areaCell
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
