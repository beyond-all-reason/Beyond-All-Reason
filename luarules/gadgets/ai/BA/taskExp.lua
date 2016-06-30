 DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskExp: " .. inStr)
	end
end

--SOME FUNCTIONS ARE DUPLICATE HERE
function Lvl3Merl(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "armraven"
	else
		unitName = DummyUnitName
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl3Arty(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "shiva"
	else
		unitName = "armshock"
	end
	return BuildSiegeIfNeeded(unitName)
end

function lv3Amp(self)
	local unitName=DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "shiva"
	else
		unitName = "marauder"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl3Breakthrough(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildWithLimitedNumber("corkrog", 1)
		if unitName == DummyUnitName then
			unitName = BuildWithLimitedNumber("gorg", 2)
		end
		if unitName == DummyUnitName then
			unitName = "corkarg"
		end
	else
		unitName = BuildWithLimitedNumber("armbanth", 5)
		if unitName == DummyUnitName then
			unitName = "armraz"
		end
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function lv3bigamp(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = 'corkrog'
	else
		unitName = 'armbanth'
	end
	return unitName
end

function Lvl3Raider(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = DummyUnitName
	else
		unitName = "marauder"
	end
	EchoDebug(unitName)
	return BuildRaiderIfNeeded(unitName)
end

function Lvl3Battle(self)
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corkarg"
	else
		unitName = "armraz"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl3Hov(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "corsok"
	else
		unitName = "armlun"
	end
	return BuildBattleIfNeeded(unitName)
end
	
function Lv3VehAmp(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		if ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end
	else
		unitName = "armcroc"
	end
	return BuildSiegeIfNeeded(unitName)
end
	
	
function Lv3Special(self)
	local unitName = DummyUnitName
	if ai.mySide == CORESideName then
		unitName = "gorg"
	else
		unitName = "armshock"
	end
	return BuildBattleIfNeeded(unitName)
end
	