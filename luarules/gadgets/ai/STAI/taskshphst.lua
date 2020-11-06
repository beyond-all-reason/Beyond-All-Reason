TaskShpHST = class(Module)

function TaskShpHST:Name()
	return "TaskShpHST"
end

function TaskShpHST:internalName()
	return "taskshphst"
end


function TaskShpHST:Init()
	self.DebugEnabled = false
end
--LEVEL 1

function TaskShpHST:ConShip( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corcs" ) then
		unitName = "corcs"
	else if builder:CanBuild( "armcs" ) then
		unitName = "armcs"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('correcl') --need count sub too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 5) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:RezSub1( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "correcl" ) then
		unitName = "correcl"
	else if builder:CanBuild( "armrecl" ) then
		unitName = "armrecl"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('armcs') --need count shp too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl1ShipRaider( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corsub" ) then
		unitName = "corsub"
	else if builder:CanBuild( "armsub" ) then
		unitName = "armsub"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl1ShipDestroyerOnly( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corroy" ) then
		unitName = "corroy"
	else if builder:CanBuild( "armroy" ) then
		unitName = "armroy"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('armcs')
	return self.ai.taskshst:BuildWithLimitedNumber(unitName,mtypedLv * 0.7)
end

function TaskShpHST:Lvl1ShipBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if self.ai.Metal.full < 0.5 then
		if builder:CanBuild( "coresupp" ) then
			unitName = "coresupp"
		else if builder:CanBuild( "armdecade" ) then
			unitName = "armdecade"
		end
	else
		if builder:CanBuild( "corroy" ) then
			unitName = "corroy"
		else if builder:CanBuild( "armroy" ) then
			unitName = "armroy"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:ScoutShip( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corpt" ) then
		unitName = "corpt"
	else if builder:CanBuild( "armpt" ) then
		unitName = "armpt"
	end
	local scout = self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
	if scout == self.ai.armyhst.DummyUnitName then
		return self.ai.taskshst:BuildAAIfNeeded(unitName)
	else
		return unitName
	end
end

--LEVEL 2
function TaskShpHST:ConAdvSub( taskQueueBehaviour, ai, builder  taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coracsub" ) then
		unitName = "coracsub"
	else if builder:CanBuild( "armacsub" ) then
		unitName = "armacsub"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('cormls') --need count ship too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipAssist( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormls" ) then
		unitName = "cormls"
	else if builder:CanBuild( "armmls" ) then
		unitName = "armmls"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName) + self.ai.taskshst:GetMtypedLv('coracsub') --need count sub too
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 2, self.ai.conUnitPerTypeLimit))
end

function TaskShpHST:Lvl2ShipBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corbats" ) then
		unitName = "corbats"
	else if builder:CanBuild( "armbats" ) then
		unitName = "armbats"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipMerl( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "cormship" ) then
		unitName = "cormship"
	else if builder:CanBuild( "armmship" ) then
		unitName = "armmship"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskShpHST:MegaShip( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corblackhy" ) then
		unitName = "corblackhy"
	else if builder:CanBuild( "armepoch" ) then
		unitName = "armepoch"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(self.ai.taskshst:BuildWithLimitedNumber(unitName, 1))
end

function TaskShpHST:Lvl2ShipRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corshark" ) then
		unitName = "corshark"
	else if builder:CanBuild( "armsubk" ) then
		unitName = "armsubk"
	end

	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskShpHST:Lvl2SubWar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corssub" ) then
		unitName = "corssub"
	else if builder:CanBuild( "armserp" ) then
		unitName = "armserp"
	end

	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2ShipBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corcrus" ) then
		unitName = "corcrus"
	else if builder:CanBuild( "armcrus" )
		unitName = "armcrus"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskShpHST:Lvl2AAShip( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corarch" ) then
		return self.ai.taskshst:BuildAAIfNeeded("corarch")
	else if builder:CanBuild( "armaas" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armaas")
	end
	return ""
end

