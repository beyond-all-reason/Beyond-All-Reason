TaskVehHST = class(Module)

function TaskVehHST:Name()
	return "TaskVehHST"
end

function TaskVehHST:internalName()
	return "TaskVehHST"
end

function TaskVehHST:Init()
	self.DebugEnabled = false
end


--LEVEL 1

function TaskVehHST:ConVehicleAmphibious()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cormuskrat"
	else
		unitName = "armbeaver"
	end
	local mtypedLvAmph = self.ai.TasksHST:GetMtypedLv(unitName)
	local mtypedLvGround = self.ai.TasksHST:GetMtypedLv('armcv')
	local mtypedLv = math.max(mtypedLvAmph, mtypedLvGround) --workaround for get the best counter
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConGroundVehicle()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corcv"
	else
		unitName = "armcv"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName)
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConVehicle()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	-- local amphRank = (((ai.mobCount['shp']) / ai.mobilityGridArea ) +  ((#ai.UWMetalSpots) /(#ai.landMetalSpots + #ai.UWMetalSpots)))/ 2
	local amphRank = self.amphRank or 0.5
	if math.random() < amphRank then
		unitName = self:ConVehicleAmphibious()
	else
		unitName = self:ConGroundVehicle()
	end
	return unitName
end

function TaskVehHST:Lvl1VehBreakthrough()
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			return self.ai.TasksHST:BuildBreakthroughIfNeeded("corlevlr")
		else
			-- armjanus isn't very a very good defense unit by itself
			local output = self.ai.TasksHST:BuildSiegeIfNeeded("armjanus")
			if output == self.ai.UnitiesHST.DummyUnitName then
				output = self.ai.TasksHST:BuildBreakthroughIfNeeded("armstump")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl1VehArty()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corwolv"
		else
			unitName = "armart"
		end
	end
	return self.ai.TasksHST:BuildSiegeIfNeeded(unitName)
end

function TaskVehHST:AmphibiousRaider()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1Amphibious()
	local unitName = ""
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return unitName
end

function TaskVehHST:Lvl1VehRaider()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corgator"
		else
			unitName = "armflash"
		end
	end
	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehBattle()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corraid"
		else
			unitName = "armstump"
		end
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehRaiderOutmoded()
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			return self.ai.TasksHST:BuildRaiderIfNeeded("corgator")
		else
			return self.ai.UnitiesHST.DummyUnitName
		end
	end
end

function TaskVehHST:Lvl1AAVeh()
	if self.side == self.ai.UnitiesHST.CORESideName then
		return self.ai.TasksHST:BuildAAIfNeeded("cormist")
	else
		return self.ai.TasksHST:BuildAAIfNeeded("armsam")
	end
end

function TaskVehHST:ScoutVeh()
	local unitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corfav"
	else
		unitName = "armfav"
	end
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskVehHST:ConAdvVehicle()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "coracv"
	else
		unitName = "armacv"
	end
	local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName)
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, ai.conUnitAdvPerTypeLimit))
end

function TaskVehHST:Lvl2VehAssist()
	if self.side == self.ai.UnitiesHST.CORESideName then
		return self.ai.UnitiesHST.DummyUnitName
	else
		unitName = 'armconsul'
		local mtypedLv = self.ai.TasksHST:GetMtypedLv(unitName)
		return self.ai.TasksHST:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
	end
end

function TaskVehHST:Lvl2VehBreakthrough()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			return self.ai.TasksHST:BuildBreakthroughIfNeeded("corgol")
		else
			-- armmanni isn't very a very good defense unit by itself
			local output = self.ai.TasksHST:BuildSiegeIfNeeded("armmanni")
			if output == self.ai.UnitiesHST.DummyUnitName then
				output = self.ai.TasksHST:BuildBreakthroughIfNeeded("armbull")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl2VehArty()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "cormart"
		else
			unitName = "armmart"
		end
	end
	return self.ai.TasksHST:BuildSiegeIfNeeded(unitName)
end

-- because core doesn't have a lvl2 vehicle raider or a lvl3 raider


function TaskVehHST:Lvl2VehRaider()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = ("corseal")
		else
			unitName = ("armlatnk")
		end
	end
	return self.ai.TasksHST:BuildRaiderIfNeeded(unitName)
end



function TaskVehHST:AmphibiousBattle()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		if ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end

	else
		unitName = "armcroc"
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2Amphibious()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		if ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end

	else
		unitName = "armcroc"
	end
	return unitName
end

function TaskVehHST:AmphibiousBreakthrough(worker)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corparrow"
	else
		unitName = "armcroc"
	end
	return self.ai.TasksHST:BuildBreakthroughIfNeeded(unitName)
end

function TaskVehHST:Lvl2VehBattle(worker)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "correap"
		else
			unitName = "armbull"
		end
	end
	return self.ai.TasksHST:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2AAVeh()
	if self.side == self.ai.UnitiesHST.CORESideName then
		return self.ai.TasksHST:BuildAAIfNeeded("corsent")
	else
		return self.ai.TasksHST:BuildAAIfNeeded("armyork")
	end
end

function TaskVehHST:Lvl2VehMerl(worker)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corvroc"
		else
			unitName = "armmerl"
		end
	end
	return self.ai.TasksHST:BuildSiegeIfNeeded(unitName)
end
