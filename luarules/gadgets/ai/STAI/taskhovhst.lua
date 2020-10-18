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
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corch"
	else
		unitName = "armch"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName)
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskHovHSTHoverMerl()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cormh"
	else
		unitName = "armmh"
	end
	return self.ai.TasksHST:BuildSiegeIfNeeded(unitName)
end

function TaskHovHSTHoverRaider()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsh"
	else
		unitName = "armsh"
	end
	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end

function TaskHovHSTHoverBattle()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsnap"
	else
		unitName = "armanac"
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskHovHSTHoverBreakthrough()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corhal"
	else
		unitName = "armanac"
	end
	self.ai.TasksHST:BuildBreakthroughIfNeeded(unitName)
end

function TaskHovHSTAAHover()
	if self.side == self.ai.UnitiesHST.CORESideName then
		return self.ai.TasksHST:BuildAAIfNeeded("corah")
	else
		return self.ai.TasksHST:BuildAAIfNeeded("armah")
	end
end


