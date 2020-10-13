TaskExpHST = class(Module)

function TaskExpHST:Name()
	return "TaskExpHST"
end
function TaskExpHST:internalName()
	return "TaskExpHST"
end

function TaskExpHST:Init()
	self.DebugEnabled = false
end

--SOME FUNCTIONS ARE DUPLICATE HERE
function TaskExpHST:Lvl3Merl()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corcat"
	else
		unitName = self.ai.UnitiesHST.DummyUnitName
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Arty()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armvang"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:lv3Amp()
	local unitName=self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "armshiva"
	else
		unitName = "armmar"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Breakthrough()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = BuildWithLimitedNumber("corkorg", 1)
		if unitName == self.ai.UnitiesHST.DummyUnitName then
			unitName = BuildWithLimitedNumber("corjugg", 2)
		end
		if unitName == self.ai.UnitiesHST.DummyUnitName then
			unitName = "corkarg"
		end
	else
		unitName = BuildWithLimitedNumber("armbanth", 5)
		if unitName == self.ai.UnitiesHST.DummyUnitName then
			unitName = "armraz"
		end
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function TaskExpHST:lv3bigamp()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = 'corkorg'
	else
		unitName = 'armbanth'
	end
	return unitName
end

function TaskExpHST:Lvl3Raider()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.UnitiesHST.DummyUnitName
	else
		unitName = "armmar"
	end
	EchoDebug(unitName)
	return BuildRaiderIfNeeded(unitName)
end

function TaskExpHST:Lvl3Battle()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corkarg"
	else
		unitName = "armraz"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lvl3Hov()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsok"
	else
		unitName = "armlun"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lv3VehAmp()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end
	else
		unitName = "armcroc"
	end
	return BuildSiegeIfNeeded(unitName)
end


function TaskExpHST:Lv3Special()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corjugg"
	else
		unitName = "armvang"
	end
	return BuildBattleIfNeeded(unitName)
end
