TaskHovHST = class(Module)

function TaskHovHST:Name()
	return "TaskHovHST"
end
function TaskHovHST:internalName()
	return "TaskHovHST"
end

function TaskHovHST:Init()
	self.DebugEnabled = false
end

function TaskHovHSTConHover()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corch"
	else
		unitName = "armch"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskHovHSTHoverMerl()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormh"
	else
		unitName = "armmh"
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskHovHSTHoverRaider()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsh"
	else
		unitName = "armsh"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskHovHSTHoverBattle()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsnap"
	else
		unitName = "armanac"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskHovHSTHoverBreakthrough()
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhal"
	else
		unitName = "armanac"
	end
	self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskHovHSTAAHover()
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("corah")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armah")
	end
end


