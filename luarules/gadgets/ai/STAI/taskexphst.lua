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
	if builder:CanBuild( "corcat" ) then
		unitName = "corcat"
	else
		unitName = self.ai.armyhst.DummyUnitName
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Arty( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "armshiva" ) then
		unitName = "armshiva"
	else if builder:CanBuild( "armvang" ) then
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:lv3Amp( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "armshiva" ) then
		unitName = "armshiva"
	else if builder:CanBuild( "armmar" ) then
		unitName = "armmar"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskExpHST:Lvl3Breakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corkorg" ) then
		unitName = self.ai.taskshst:BuildWithLimitedNumber("corkorg", 1)
		if unitName == self.ai.armyhst.DummyUnitName and builder:CanBuild( "corjugg" ) then
			unitName = self.ai.taskshst:BuildWithLimitedNumber("corjugg", 2)
		end
		if unitName == self.ai.armyhst.DummyUnitName and builder:CanBuild( "corkorg" ) then
			unitName = "corkarg"
		end
	else
		if builder:CanBuild( "armbanth" ) then
			unitName = self.ai.taskshst:BuildWithLimitedNumber("armbanth", 5)
			if unitName == self.ai.armyhst.DummyUnitName then
				if builder:CanBuild( "armraz" ) then
					unitName = "armraz"
				end
			end
		end
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskExpHST:lv3bigamp( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corkorg" ) then
		unitName = 'corkorg'
	else if builder:CanBuild( "armbanth" ) then
		unitName = 'armbanth'
	end
	return unitName
end

function TaskExpHST:Lvl3Raider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "armmar" ) then
		unitName = "armmar"
	else
		unitName = self.ai.armyhst.DummyUnitName
	end
	self:EchoDebug(unitName)
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskExpHST:Lvl3Battle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corkarg" ) then
		unitName = "corkarg"
	else if builder:CanBuild( "armraz" ) then
		unitName = "armraz"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lvl3Hov( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corsok" ) then
		unitName = "corsok"
	else if builder:CanBuild( "armlun" ) then
		unitName = "armlun"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskExpHST:Lv3VehAmp( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		if self.ai.Metal.full < 0.5 and builder:CanBuild( "corseal" ) then
			unitName = "corseal"
		else if builder:CanBuild( "corparrow" ) then
			unitName = "corparrow"
		end
	else if builder:CanBuild( "armcroc" ) then
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end


function TaskExpHST:Lv3Special( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corjugg" ) then
		unitName = "corjugg"
	else if builder:CanBuild( "armvang" ) then
		unitName = "armvang"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end
