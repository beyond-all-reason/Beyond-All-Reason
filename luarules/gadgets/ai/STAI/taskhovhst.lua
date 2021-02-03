TaskHovHST = class(Module)

function TaskHovHST:Name()
	return "TaskHovHST"
end
function TaskHovHST:internalName()
	return "taskhovhst"
end

function TaskHovHST:Init()
	self.DebugEnabled = false
end

function TaskHovHST:ConHover( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corch" ) then
		unitName = "corch"
	elseif builder:CanBuild( "armch" ) then
		unitName = "armch"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskHovHST:HoverMerl( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "cormh" ) then
		unitName = "cormh"
	elseif builder:CanBuild( "armmh" ) then
		unitName = "armmh"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskHovHST:HoverRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corsh" ) then
		unitName = "corsh"
	elseif builder:CanBuild( "armsh" ) then
		unitName = "armsh"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskHovHST:HoverBattle( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corsnap" ) then
		unitName = "corsnap"
	elseif builder:CanBuild( "armanac" ) then
		unitName = "armanac"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskHovHST:HoverBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corhal" ) then
		unitName = "corhal"
	elseif builder:CanBuild( "armanac" ) then
		unitName = "armanac"
	end
	self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskHovHST:AAHover( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corah" ) then
		return self.ai.taskshst:BuildAAIfNeeded("corah")
	elseif builder:CanBuild( "armah" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armah")
	end
	return ""
end


