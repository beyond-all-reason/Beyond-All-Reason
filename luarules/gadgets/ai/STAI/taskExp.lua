local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskExp: " .. inStr)
	end
end

--SOME FUNCTIONS ARE DUPLICATE HERE
function Lvl3Merl(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corcat"
	else
		unitName = DummyUnitName
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl3Arty(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "armshiva"
	else
		unitName = "armvang"
	end
	return BuildSiegeIfNeeded(unitName)
end

function lv3Amp(tskqbhvr)
	local unitName=DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "armshiva"
	else
		unitName = "armmar"
	end
	return BuildSiegeIfNeeded(unitName)
end

function Lvl3Breakthrough(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = BuildWithLimitedNumber("corkrog", 1)
		if unitName == DummyUnitName then
			unitName = BuildWithLimitedNumber("corjugg", 2)
		end
		if unitName == DummyUnitName then
			unitName = "corkarg"
		end
	else
		unitName = BuildWithLimitedNumber("armcyclops", 5)
		if unitName == DummyUnitName then
			unitName = "armraz"
		end
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function lv3bigamp(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = 'corkrog'
	else
		unitName = 'armcyclops'
	end
	return unitName
end

function Lvl3Raider(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = DummyUnitName
	else
		unitName = "armmar"
	end
	EchoDebug(unitName)
	return BuildRaiderIfNeeded(unitName)
end

function Lvl3Battle(tskqbhvr)
	local unitName = ""
	if MyTB.side == CORESideName then
		unitName = "corkarg"
	else
		unitName = "armraz"
	end
	return BuildBattleIfNeeded(unitName)
end

function Lvl3Hov(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corsok"
	else
		unitName = "armlun"
	end
	return BuildBattleIfNeeded(unitName)
end
	
function Lv3VehAmp(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
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
	
	
function Lv3Special(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corjugg"
	else
		unitName = "armvang"
	end
	return BuildBattleIfNeeded(unitName)
end
	