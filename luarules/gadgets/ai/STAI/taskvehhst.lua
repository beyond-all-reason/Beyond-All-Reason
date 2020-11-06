TaskVehHST = class(Module)

function TaskVehHST:Name()
	return "TaskVehHST"
end

function TaskVehHST:internalName()
	return "taskvehhst"
end

function TaskVehHST:Init()
	self.DebugEnabled = true
end


--LEVEL 1

function TaskVehHST:ConVehicleAmphibious( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cormuskrat"
	else
		unitName = "armbeaver"
	end
	local mtypedLvAmph = self.ai.taskshst:GetMtypedLv(unitName)
	local mtypedLvGround = self.ai.taskshst:GetMtypedLv('armcv')
	local mtypedLv = math.max(mtypedLvAmph, mtypedLvGround) --workaround for get the best counter
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConGroundVehicle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corcv"
	else
		unitName = "armcv"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConVehicle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	-- local amphRank = (((ai.mobCount['shp']) / self.ai.mobilityGridArea ) +  ((#ai.UWMetalSpots) /(#ai.landMetalSpots + #ai.UWMetalSpots)))/ 2
	local amphRank = self.amphRank or 0.5
	if math.random() < amphRank then
		unitName = self:ConVehicleAmphibious()
	else
		unitName = self:ConGroundVehicle()
	end
	return unitName
end

function TaskVehHST:Lvl1VehBreakthrough( taskQueueBehaviour, ai, builder )
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			return self.ai.taskshst:BuildBreakthroughIfNeeded("corlevlr")
		else
			-- armjanus isn't very a very good defense unit by itself
			local output = self.ai.taskshst:BuildSiegeIfNeeded("armjanus")
			if output == self.ai.armyhst.DummyUnitName then
				output = self.ai.taskshst:BuildBreakthroughIfNeeded("armstump")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl1VehArty( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corwolv"
		else
			unitName = "armart"
		end
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskVehHST:AmphibiousRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corgarp"
	else
		unitName = "armpincer"
	end
	return unitName
end

function TaskVehHST:Lvl1VehRaider( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corgator"
		else
			unitName = "armflash"
		end
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehBattle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corraid"
		else
			unitName = "armstump"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehRaiderOutmoded( taskQueueBehaviour, ai, builder )
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			return self.ai.taskshst:BuildRaiderIfNeeded("corgator")
		else
			return self.ai.armyhst.DummyUnitName
		end
	end
end

function TaskVehHST:Lvl1AAVeh( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("cormist")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armsam")
	end
end

function TaskVehHST:ScoutVeh( taskQueueBehaviour, ai, builder )
	local unitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfav"
	else
		unitName = "armfav"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskVehHST:ConAdvVehicle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coracv"
	else
		unitName = "armacv"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskVehHST:Lvl2VehAssist( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.armyhst.DummyUnitName
	else
		unitName = 'armconsul'
		local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
		return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitPerTypeLimit))
	end
end

function TaskVehHST:Lvl2VehBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			return self.ai.taskshst:BuildBreakthroughIfNeeded("corgol")
		else
			-- armmanni isn't very a very good defense unit by itself
			local output = self.ai.taskshst:BuildSiegeIfNeeded("armmanni")
			if output == self.ai.armyhst.DummyUnitName then
				output = self.ai.taskshst:BuildBreakthroughIfNeeded("armbull")
			end
			return output
		end
	end
end

function TaskVehHST:Lvl2VehArty( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "cormart"
		else
			unitName = "armmart"
		end
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

-- because core doesn't have a lvl2 vehicle raider or a lvl3 raider


function TaskVehHST:Lvl2VehRaider( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = ("corseal")
		else
			unitName = ("armlatnk")
		end
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end



function TaskVehHST:AmphibiousBattle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end

	else
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		else
			unitName = "corparrow"
		end

	else
		unitName = "armcroc"
	end
	return unitName
end

function TaskVehHST:AmphibiousBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corparrow"
	else
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskVehHST:Lvl2VehBattle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "correap"
		else
			unitName = "armbull"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2AAVeh( taskQueueBehaviour, ai, builder )
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return self.ai.taskshst:BuildAAIfNeeded("corsent")
	else
		return self.ai.taskshst:BuildAAIfNeeded("armyork")
	end
end

function TaskVehHST:Lvl2VehMerl( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious(self)
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corvroc"
		else
			unitName = "armmerl"
		end
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end
