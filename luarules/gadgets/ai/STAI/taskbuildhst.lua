TaskBuildHST = class(Module)

function TaskBuildHST:Name()
	return "TaskBuildHST"
end

function TaskBuildHST:internalName()
	return "TaskBuildHST"
end

function TaskBuildHST:Init()
	self.DebugEnabled = false
end
--t1 ground

function TaskBuildHST:BuildLLT(Builder)
	if Builder.unit == nil then
		return self.ai.UnitiesHST.DummyUnitName
	end
	local unitName = self.ai.UnitiesHST.DummyUnitName
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corllt"
		else
			unitName = "armllt"
		end
		local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLT(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.ai.TasksHST:IsAANeeded() then
		-- pop-up turrets are protected against bombs
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "cormaw"
		else
			unitName = "armclaw"
		end
	else
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corhllt"
		else
			unitName = "armbeamer"
		end
	end
	local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLTOnly(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corhllt"
	else
		unitName = "armbeamer"
	end
	local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildHLT(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corhlt"
	else
		unitName = "armhlt"
	end
	local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildDepthCharge(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cordl"
	else
		unitName = "armdl"
	end
	return self.ai.TasksHST:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildFloatHLT(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corfhlt"
	else
		unitName = "armfhlt"
	end
	local unit = Builder.unit:Internal()
	--return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
	return unitName
end

--t2 ground
function TaskBuildHST:BuildLvl2PopUp(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corvipe"
	else
		unitName = "armpb"
	end
	local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildTachyon(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cordoom"
	else
		unitName = "armanni"
	end
	local unit = Builder.unit:Internal()
	return self.ai.TasksHST:GroundDefenseIfNeeded(unitName)
end

-- torpedos

function TaskBuildHST:BuildLightTorpedo()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cortl"
	else
		unitName = "armtl"
	end
	return self.ai.TasksHST:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildPopTorpedo()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corptl"
	else
		unitName = "armptl"
	end
	return self.ai.TasksHST:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildHeavyTorpedo()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "coratl"
	else
		unitName = "armatl"
	end
	return self.ai.TasksHST:BuildTorpedoIfNeeded(unitName)
end

--AA

-- build AA in area only if there's not enough of it there already
--t1

function TaskBuildHST:BuildLightAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corrl")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armrl")
	end
	return unitName
end

function TaskBuildHST:BuildFloatLightAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corfrt")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function TaskBuildHST:BuildMediumAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("cormadsam")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armferret")
	end
	return unitName
end

function TaskBuildHST:BuildHeavyishAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corerad")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armcir")
	end
	return unitName
end

--t2

function TaskBuildHST:BuildHeavyAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corflak")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armflak")
	end
	return unitName
end

function TaskBuildHST:BuildFloatHeavyAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corenaa")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function TaskBuildHST:BuildExtraHeavyAA()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.TasksHST:BuildAAIfNeeded("corscreamer")
	else
		unitName = self.ai.TasksHST:BuildAAIfNeeded("armmercury")
	end
	return unitName
end



--SONAR-RADAR

function TaskBuildHST:BuildRadar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corrad"
		else
			unitName = "armrad"
		end
	return unitName
end

function TaskBuildHST:BuildFloatRadar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corfrad"
	else
		unitName = "armfrad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl1Jammer()
	if not self.ai.TasksHST:IsJammerNeeded() then return self.ai.UnitiesHST.DummyUnitName end
		if self.side == self.ai.UnitiesHST.CORESideName then
			return "corjamt"
		else
			return "armjamt"
		end
end

--t1

function TaskBuildHST:BuildAdvancedSonar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corason"
	else
		unitName = "armason"
	end
	return unitName
end

function TaskBuildHST:BuildAdvancedRadar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corarad"
	else
		unitName = "armarad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Jammer()
	if not self.ai.TasksHST:IsJammerNeeded() then return self.ai.UnitiesHST.DummyUnitName end
	if self.side == self.ai.UnitiesHST.CORESideName then
		return "corshroud"
	else
		return "armveil"
	end
end

--Anti Radar/Jammer/Minefield/ScoutSpam Weapon

function TaskBuildHST:BuildAntiRadar()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corjuno"
	else
		unitName = "armjuno"
	end
	return unitName
end

--NUKE

function TaskBuildHST:BuildAntinuke()
	if self.ai.TasksHST:IsAntinukeNeeded() then
		local unitName = self.ai.UnitiesHST.DummyUnitName
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corfmd"
		else
			unitName = "armamd"
		end
		return self.ai.TasksHST:BuildWithLimitedNumber(unitName, 1)
	end
	return self.ai.UnitiesHST.DummyUnitName
end

function TaskBuildHST:BuildNuke()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsilo"
	else
		unitName = "armsilo"
	end
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, 1)--ai.overviewhst.nukeLimit)
end

function TaskBuildHST:BuildNukeIfNeeded()
	if self.ai.TasksHST:IsNukeNeeded() then
		return self:BuildNuke()
	end
end

function TaskBuildHST:BuildTacticalNuke()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cortron"
	else
		unitName = "armemp"
	end
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, ai.overviewhst.tacticalNukeLimit)
end

--PLASMA

function TaskBuildHST:BuildLvl1Plasma()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corpun"
	else
		unitName = "armguard"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Plasma()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cortoast"
	else
		unitName = "armamb"
	end
	return unitName
end

function TaskBuildHST:BuildHeavyPlasma()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corint"
	else
		unitName = "armbrtha"
	end
	return self.ai.TasksHST:BuildWithLimitedNumber(unitName, ai.overviewhst.heavyPlasmaLimit)
end

function TaskBuildHST:BuildLol()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corbuzz"
	else
		unitName = "armvulc"
	end
	return unitName
end

--plasma deflector

function TaskBuildHST:BuildShield()
	if self.ai.TasksHST:IsShieldNeeded() then
		local unitName = self.ai.UnitiesHST.DummyUnitName
		if self.side == self.ai.UnitiesHST.CORESideName then
			unitName = "corgate"
		else
			unitName = "armgate"
		end
		return unitName
	end
	return self.ai.UnitiesHST.DummyUnitName
end

--anti intrusion

function TaskBuildHST:BuildAntiIntr()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "corsd"
	else
		unitName = "armsd"
	end
	return unitName
end

--targeting facility

function TaskBuildHST:BuildTargeting()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = "cortarg"
	else
		unitName = "armtarg"
	end
	return unitName
end

--ARM emp launcer

function TaskBuildHST:BuildEmpLauncer()
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.side == self.ai.UnitiesHST.CORESideName then
		unitName = self.ai.UnitiesHST.DummyUnitName
	else
		unitName = "armEmp"
	end
	return unitName
end

--Function of function

function TaskBuildHST:CommanderAA(Builder)
	local unitName = self.ai.UnitiesHST.DummyUnitName
	if self.ai.TasksHST:IsAANeeded() then
		if ai.maphst:IsUnderWater(Builder.unit:Internal():GetPosition()) then
			unitName = self:BuildFloatLightAA(Builder)
		else
			unitName = self:BuildLightAA(Builder)
		end
	end
	return unitName
end
