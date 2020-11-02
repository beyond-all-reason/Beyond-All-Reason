TaskExpHST = class(Module)

function TaskExpHST:Name()
	return "TaskExpHST"
end
function TaskExpHST:internalName()
	return "taskexphst"
end

function TaskExpHST:Init()
	self.DebugEnabled = false
end

--SOME FUNCTIONS ARE DUPLICATE HERE
function TaskExpHST:Lvl3Merl()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcat"
	else
		unitName = self.ai.armyhst.DummyUnitName
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Arty()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:lv3Amp()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armmar"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Breakthrough()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildWithLimitedNumber("corkorg", 1)
		if unitName == self.ai.armyhst.DummyUnitName then
			unitName = self.ai.taskshst:BuildWithLimitedNumber("corjugg", 2)
		end
		if unitName == self.ai.armyhst.DummyUnitName then
			unitName = "corkarg"
		end
	else
		unitName = self.ai.taskshst:BuildWithLimitedNumber("armbanth", 5)
		if unitName == self.ai.armyhst.DummyUnitName then
			unitName = "armraz"
		end
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskExpHST:lv3bigamp()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'corkorg'
	else
		unitName = 'armbanth'
	end
	return unitName
end

function TaskExpHST:Lvl3Raider()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.armyhst.DummyUnitName
	else
		unitName = "armmar"
	end
	self:EchoDebug(unitName)
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskExpHST:Lvl3Battle()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corkarg"
	else
		unitName = "armraz"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lvl3Hov()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsok"
	else
		unitName = "armlun"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lv3VehAmp()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end
	else
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end


function TaskExpHST:Lv3Special()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corjugg"
	else
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end
