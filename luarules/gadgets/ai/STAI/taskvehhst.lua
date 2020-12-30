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
	if builder:CanBuild( "cormuskrat" ) then
		unitName = "cormuskrat"
	elseif builder:CanBuild( "armbeaver" ) then
		unitName = "armbeaver"
	end
	if unitName ~= self.ai.armyhst.DummyUnitName then
		return unitName
	end
	local mtypedLvAmph = self.ai.taskshst:GetMtypedLv(unitName)
	local mtypedLvGround = self.ai.taskshst:GetMtypedLv('armcv')
	local mtypedLv = math.max(mtypedLvAmph, mtypedLvGround) --workaround for get the best counter
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 6) + 1, self.ai.conUnitPerTypeLimit))
end

function TaskVehHST:ConGroundVehicle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corcv" ) then
		unitName = "corcv"
	elseif builder:CanBuild( "armcv" ) then
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
		unitName = self:ConVehicleAmphibious( taskQueueBehaviour, ai, builder )
	else
		unitName = self:ConGroundVehicle( taskQueueBehaviour, ai, builder )
	end
	return unitName
end

function TaskVehHST:Lvl1VehBreakthrough( taskQueueBehaviour, ai, builder )
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corlevlr" ) then
			return self.ai.taskshst:BuildBreakthroughIfNeeded("corlevlr")
		elseif builder:CanBuild( "armjanus" ) then
			-- armjanus isn't very a very good defense unit by itself
			local output = self.ai.taskshst:BuildSiegeIfNeeded("armjanus")
			if output == self.ai.armyhst.DummyUnitName and builder:CanBuild( "armstump" ) then
				output = self.ai.taskshst:BuildBreakthroughIfNeeded("armstump")
			end
			return output
		end
	end
	return ""
end

function TaskVehHST:Lvl1VehArty( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corwolv" ) then
			unitName = "corwolv"
		elseif builder:CanBuild( "armart" ) then
			unitName = "armart"
		end
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end

function TaskVehHST:AmphibiousRaider( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corgarp" ) then
		unitName = "corgarp"
	elseif builder:CanBuild( "armpincer" ) then
		unitName = "armpincer"
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end

function TaskVehHST:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	local unitName = ""
	if builder:CanBuild( "corgarp" ) then
		unitName = "corgarp"
	elseif builder:CanBuild( "armpincer" ) then
		unitName = "armpincer"
	end
	return unitName
end

function TaskVehHST:Lvl1VehRaider( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corgator" ) then
			unitName = "corgator"
		elseif builder:CanBuild( "armflash" ) then
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
		if builder:CanBuild( "corraid" ) then
			unitName = "corraid"
		elseif builder:CanBuild( "armstump" ) then
			unitName = "armstump"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl1VehRaiderOutmoded( taskQueueBehaviour, ai, builder )
	if self.AmpOrGroundWeapon then
		return self:Lvl1Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corgator" ) then
			return self.ai.taskshst:BuildRaiderIfNeeded("corgator")
		else
			return self.ai.armyhst.DummyUnitName
		end
	end
end

function TaskVehHST:Lvl1AAVeh( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "cormist" ) then
		return self.ai.taskshst:BuildAAIfNeeded("cormist")
	elseif builder:CanBuild( "armsam" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armsam")
	end
end

function TaskVehHST:ScoutVeh( taskQueueBehaviour, ai, builder )
	local unitName
	if builder:CanBuild( "corfav" ) then
		unitName = "corfav"
	elseif builder:CanBuild( "armfav" ) then
		unitName = "armfav"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
end

--LEVEL 2

function TaskVehHST:ConAdvVehicle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coracv" ) then
		unitName = "coracv"
	elseif builder:CanBuild( "armacv" ) then
		unitName = "armacv"
	end
	local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 10) + 1, self.ai.conUnitAdvPerTypeLimit))
end

function TaskVehHST:Lvl2VehAssist( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "armconsul" ) then
		unitName = 'armconsul'
		local mtypedLv = self.ai.taskshst:GetMtypedLv(unitName)
		return self.ai.taskshst:BuildWithLimitedNumber(unitName, math.min((mtypedLv / 8) + 1, self.ai.conUnitPerTypeLimit))
	end
	return self.ai.armyhst.DummyUnitName
end

function TaskVehHST:Lvl2VehBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corgol" ) then
			return self.ai.taskshst:BuildBreakthroughIfNeeded("corgol")
		elseif builder:CanBuild( "armmanni" ) then
			-- armmanni isn't very a very good defense unit by itself
			local output = self.ai.taskshst:BuildSiegeIfNeeded("armmanni")
			if output == self.ai.armyhst.DummyUnitName and builder:CanBuild( "armbull" ) then
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
		if builder:CanBuild( "cormart" ) then
			unitName = "cormart"
		elseif builder:CanBuild( "armmart" ) then
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
		if builder:CanBuild( "corseal" ) then
			unitName = ("corseal")
		elseif builder:CanBuild( "armlatnk" ) then
			unitName = ("armlatnk")
		end
	end
	return self.ai.taskshst:BuildRaiderIfNeeded(unitName)
end



function TaskVehHST:AmphibiousBattle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corseal" ) then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		elseif builder:CanBuild( "corparrow" ) then
			unitName = "corparrow"
		end
	elseif builder:CanBuild( "armcroc" ) then
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corseal" ) then
		if self.ai.Metal.full < 0.5 then
			unitName = "corseal"
		elseif builder:CanBuild( "corparrow" ) then
			unitName = "corparrow"
		end
	elseif builder:CanBuild( "armcroc" ) then
		unitName = "armcroc"
	end
	return unitName
end

function TaskVehHST:AmphibiousBreakthrough( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corparrow" ) then
		unitName = "corparrow"
	elseif builder:CanBuild( "armcroc" ) then
		unitName = "armcroc"
	end
	return self.ai.taskshst:BuildBreakthroughIfNeeded(unitName)
end

function TaskVehHST:Lvl2VehBattle( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "correap" ) then
			unitName = "correap"
		elseif builder:CanBuild( "armbull" ) then
			unitName = "armbull"
		end
	end
	return self.ai.taskshst:BuildBattleIfNeeded(unitName)
end

function TaskVehHST:Lvl2AAVeh( taskQueueBehaviour, ai, builder )
	if builder:CanBuild( "corsent" ) then
		return self.ai.taskshst:BuildAAIfNeeded("corsent")
	elseif builder:CanBuild( "armyork" ) then
		return self.ai.taskshst:BuildAAIfNeeded("armyork")
	end
end

function TaskVehHST:Lvl2VehMerl( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if self.AmpOrGroundWeapon then
		return self:Lvl2Amphibious( taskQueueBehaviour, ai, builder )
	else
		if builder:CanBuild( "corvroc" ) then
			unitName = "corvroc"
		elseif builder:CanBuild( "armmerl" ) then
			unitName = "armmerl"
		end
	end
	return self.ai.taskshst:BuildSiegeIfNeeded(unitName)
end
