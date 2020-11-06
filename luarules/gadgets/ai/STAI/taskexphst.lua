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
function TaskExpHST:Lvl3Merl( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcat"
	else
		unitName = self.ai.armyhst.DummyUnitName
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Arty( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:lv3Amp( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armmar"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Breakthrough( taskQueueBehaviour, ai, builder )
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

function TaskExpHST:lv3bigamp( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = 'corkorg'
	else
		unitName = 'armbanth'
	end
	return unitName
end

function TaskExpHST:Lvl3Raider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.armyhst.DummyUnitName
	else
		unitName = "armmar"
	end
	self:EchoDebug(unitName)
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskExpHST:Lvl3Battle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corkarg"
	else
		unitName = "armraz"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lvl3Hov( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsok"
	else
		unitName = "armlun"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lv3VehAmp( taskQueueBehaviour, ai, builder )
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


function TaskExpHST:Lv3Special( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corjugg"
	else
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end
