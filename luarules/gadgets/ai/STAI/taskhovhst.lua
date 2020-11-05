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

function TaskHovHST:ConHover()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corch"
	else
		unitName = "armch"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskHovHST:HoverMerl()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormh"
	else
		unitName = "armmh"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskHovHST:HoverRaider()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsh"
	else
		unitName = "armsh"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskHovHST:HoverBattle()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsnap"
	else
		unitName = "armanac"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskHovHST:HoverBreakthrough()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhal"
	else
		unitName = "armanac"
	end
	self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskHovHST:AAHover()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("corah")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armah")
	end
end


