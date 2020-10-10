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
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "cormuskrat"
	else
		unitName = "armbeaver"
	end
	local mtypedLvAmph = GetMtypedLv(unitName)
	local mtypedLvGround = GetMtypedLv('armcv')
	local mtypedLv = math.max(mtypedLvAmph, mtypedLvGround) --workaround for get the best counter
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConGroundVehicle()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corcv"
	else
		unitName = "armcv"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConVehicle()
	local unitName = UnitiesHST.DummyUnitName
	-- local amphRank = (((ai.mobCount['shp']) / ai.mobilityGridArea ) +  ((#ai.UWMetalSpots) /(#ai.landMetalSpots + #ai.UWMetalSpots)))/ 2
	local amphRank = self.amphRank or 0.5
	if math.random() < amphRank then
		unitName = ConVehicleAmphibious()
	else
		unitName = ConGroundVehicle()
	end
	return unitName
end

function TaskVehHST:Lvl1VehBreakthrough()
	if self.AmpOrGroundWeapon then
		return Lvl1Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			return BuildBreakthroughIfNeeded("corlevlr")
		else
			-- armjanus isn't very a very good defense unit by itself
			local output = BuildSiegeIfNeeded("armjanus")
			if output == UnitiesHST.DummyUnitName then
				output = BuildBreakthroughIfNeeded("armstump")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl1VehArty()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl1Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corwolv"
		else
			unitName = "armart"
		end
	end
	return BuildSiegeIfNeeded(unitName)
end

function TaskVehHST:AmphibiousRaider()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1Amphibious()
	local unitName = ""
	if self.side == UnitiesHST.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return unitName
end

function TaskVehHST:Lvl1VehRaider()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl1Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corgator"
		else
			unitName = "armflash"
		end
	end
	return BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehBattle()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl1Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corraid"
		else
			unitName = "armstump"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehRaiderOutmoded()
	if self.AmpOrGroundWeapon then
		return Lvl1Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			return BuildRaiderIfNeeded("corgator")
		else
			return UnitiesHST.DummyUnitName
		end
	end
end

function TaskVehHST:Lvl1AAVeh()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("cormist")
	else
		return BuildAAIfNeeded("armsam")
	end
end

function TaskVehHST:ScoutVeh()
	local unitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corfav"
	else
		unitName = "armfav"
	end
	return BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskVehHST:ConAdvVehicle()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "coracv"
	else
		unitName = "armacv"
	end
	local mtypedLv = GetMtypedLv(unitName)
	return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, ai.conUnitAdvPerTypeLimit))
end

function TaskVehHST:Lvl2VehAssist()
	if self.side == UnitiesHST.CORESideName then
		return UnitiesHST.DummyUnitName
	else
		unitName = 'armconsul'
		local mtypedLv = GetMtypedLv(unitName)
		return BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, ai.conUnitPerTypeLimit))
	end
end

function TaskVehHST:Lvl2VehBreakthrough()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl2Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			return BuildBreakthroughIfNeeded("corgol")
		else
			-- armmanni isn't very a very good defense unit by itself
			local output = BuildSiegeIfNeeded("armmanni")
			if output == UnitiesHST.DummyUnitName then
				output = BuildBreakthroughIfNeeded("armbull")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl2VehArty()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl2Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "cormart"
		else
			unitName = "armmart"
		end
	end
	return BuildSiegeIfNeeded(unitName)
end

-- because core doesn't have a lvl2 vehicle raider or a lvl3 raider


function TaskVehHST:Lvl2VehRaider()
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl2Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = ("corseal")
		else
			unitName = ("armlatnk")
		end
	end
	return BuildRaiderIfNeeded(unitName)
end



function TaskVehHST:AmphibiousBattle()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		if ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end

	else
		unitName = "armcroc"
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2Amphibious()
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
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

function TaskVehHST:AmphibiousBreakthrough(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if self.side == UnitiesHST.CORESideName then
		unitName = "corparrow"
	else
		unitName = "armcroc"
	end
	return BuildBreakthroughIfNeeded(unitName)
end

function TaskVehHST:Lvl2VehBattle(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl2Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "correap"
		else
			unitName = "armbull"
		end
	end
	return BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2AAVeh()
	if self.side == UnitiesHST.CORESideName then
		return BuildAAIfNeeded("corsent")
	else
		return BuildAAIfNeeded("armyork")
	end
end

function TaskVehHST:Lvl2VehMerl(tskqbhvr)
	local unitName = UnitiesHST.DummyUnitName
	if self.AmpOrGroundWeapon then
		return Lvl2Amphibious(self)
	else
		if self.side == UnitiesHST.CORESideName then
			unitName = "corvroc"
		else
			unitName = "armmerl"
		end
	end
	return BuildSiegeIfNeeded(unitName)
end




