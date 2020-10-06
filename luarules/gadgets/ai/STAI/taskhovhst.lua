TaskHovHST = class(Module)

function TaskHovHST:Name()
	return "TaskShpHST"
end

function TaskHovHST:Init()
	self.DebugEnabled = false
end

function TaskHovHSTConHover()
	if self.side == UnitiesHST.CORESideName then
		unitName = "corch"
	else
		unitName = "armch"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskHovHSTHoverMerl()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "cormh"
	else
		unitName = "armmh"
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskHovHSTHoverRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsh"
	else
		unitName = "armsh"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskHovHSTHoverBattle()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corsnap"
	else
		unitName = "armanac"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskHovHSTHoverBreakthrough()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corhal"
	else
		unitName = "armanac"
	end
	BuildBreakthroughIfNeeded(unitName)
end

function TaskHovHSTAAHover()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("corah")
	else
		return BuildAAIfNeeded("armah")
	end
end


