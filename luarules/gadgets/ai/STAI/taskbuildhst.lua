TaskBuildHST = class(Module)

function TaskBuildHST:Name()
	return "TaskBuildHST"
end

function TaskBuildHST:internalName()
	return "taskbuildhst"
end

function TaskBuildHST:Init()
	self.DebugEnabled = false
end
--t1 ground

function TaskBuildHST:BuildLLT(Builder)
	if Builder.unit == nil then
		return self.ai.armyhst.DummyUnitName
	end
	local unitName = self.ai.armyhst.DummyUnitName
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corllt"
		else
			unitName = "armllt"
		end
		local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.taskshst:IsAANeeded() then
		-- pop-up turrets are protected against bombs
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "cormaw"
		else
			unitName = "armclaw"
		end
	else
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corhllt"
		else
			unitName = "armbeamer"
		end
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLTOnly(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhllt"
	else
		unitName = "armbeamer"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corhlt"
	else
		unitName = "armhlt"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildDepthCharge(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cordl"
	else
		unitName = "armdl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildFloatHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfhlt"
	else
		unitName = "armfhlt"
	end
	local unit = Builder.unit:Internal()
	--return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
	return unitName
end

--t2 ground
function TaskBuildHST:BuildLvl2PopUp(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corvipe"
	else
		unitName = "armpb"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildTachyon(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cordoom"
	else
		unitName = "armanni"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

-- torpedos

function TaskBuildHST:BuildLightTorpedo()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortl"
	else
		unitName = "armtl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildPopTorpedo()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corptl"
	else
		unitName = "armptl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildHeavyTorpedo()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "coratl"
	else
		unitName = "armatl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

--AA

-- build AA in area only if there's not enough of it there already
--t1

function TaskBuildHST:BuildLightAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corrl")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armrl")
	end
	return unitName
end

function TaskBuildHST:BuildFloatLightAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corfrt")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function TaskBuildHST:BuildMediumAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("cormadsam")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armferret")
	end
	return unitName
end

function TaskBuildHST:BuildHeavyishAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corerad")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armcir")
	end
	return unitName
end

--t2

function TaskBuildHST:BuildHeavyAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corflak")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armflak")
	end
	return unitName
end

function TaskBuildHST:BuildFloatHeavyAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corenaa")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function TaskBuildHST:BuildExtraHeavyAA()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corscreamer")
	else
		unitName = self.ai.taskshst:BuildAAIfNeeded("armmercury")
	end
	return unitName
end



--SONAR-RADAR

function TaskBuildHST:BuildRadar()
	local unitName = self.ai.armyhst.DummyUnitName
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corrad"
		else
			unitName = "armrad"
		end
	return unitName
end

function TaskBuildHST:BuildFloatRadar()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corfrad"
	else
		unitName = "armfrad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl1Jammer()
	if not self.ai.taskshst:IsJammerNeeded() then return self.ai.armyhst.DummyUnitName end
		if  self.ai.side == self.ai.armyhst.CORESideName then
			return "corjamt"
		else
			return "armjamt"
		end
end

--t1

function TaskBuildHST:BuildAdvancedSonar()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corason"
	else
		unitName = "armason"
	end
	return unitName
end

function TaskBuildHST:BuildAdvancedRadar()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corarad"
	else
		unitName = "armarad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Jammer()
	if not self.ai.taskshst:IsJammerNeeded() then return self.ai.armyhst.DummyUnitName end
	if  self.ai.side == self.ai.armyhst.CORESideName then
		return "corshroud"
	else
		return "armveil"
	end
end

--Anti Radar/Jammer/Minefield/ScoutSpam Weapon

function TaskBuildHST:BuildAntiRadar()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corjuno"
	else
		unitName = "armjuno"
	end
	return unitName
end

--NUKE

function TaskBuildHST:BuildAntinuke()
	if self.ai.taskshst:IsAntinukeNeeded() then
		local unitName = self.ai.armyhst.DummyUnitName
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corfmd"
		else
			unitName = "armamd"
		end
		return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
	end
	return self.ai.armyhst.DummyUnitName
end

function TaskBuildHST:BuildNuke()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsilo"
	else
		unitName = "armsilo"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)--ai.overviewhst.nukeLimit)
end

function TaskBuildHST:BuildNukeIfNeeded()
	if self.ai.taskshst:IsNukeNeeded() then
		return self:BuildNuke()
	end
end

function TaskBuildHST:BuildTacticalNuke()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortron"
	else
		unitName = "armemp"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.tacticalNukeLimit)
end

--PLASMA

function TaskBuildHST:BuildLvl1Plasma()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corpun"
	else
		unitName = "armguard"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Plasma()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortoast"
	else
		unitName = "armamb"
	end
	return unitName
end

function TaskBuildHST:BuildHeavyPlasma()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corint"
	else
		unitName = "armbrtha"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.heavyPlasmaLimit)
end

function TaskBuildHST:BuildLol()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corbuzz"
	else
		unitName = "armvulc"
	end
	return unitName
end

--plasma deflector

function TaskBuildHST:BuildShield()
	if self.ai.taskshst:IsShieldNeeded() then
		local unitName = self.ai.armyhst.DummyUnitName
		if  self.ai.side == self.ai.armyhst.CORESideName then
			unitName = "corgate"
		else
			unitName = "armgate"
		end
		return unitName
	end
	return self.ai.armyhst.DummyUnitName
end

--anti intrusion

function TaskBuildHST:BuildAntiIntr()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "corsd"
	else
		unitName = "armsd"
	end
	return unitName
end

--targeting facility

function TaskBuildHST:BuildTargeting()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = "cortarg"
	else
		unitName = "armtarg"
	end
	return unitName
end

--ARM emp launcer

function TaskBuildHST:BuildEmpLauncer()
	local unitName = self.ai.armyhst.DummyUnitName
	if  self.ai.side == self.ai.armyhst.CORESideName then
		unitName = self.ai.armyhst.DummyUnitName
	else
		unitName = "armEmp"
	end
	return unitName
end

--Function of function

function TaskBuildHST:CommanderAA(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.taskshst:IsAANeeded() then
		if self.ai.maphst:IsUnderWater(Builder.unit:Internal():GetPosition()) then
			unitName = self:BuildFloatLightAA(Builder)
		else
			unitName = self:BuildLightAA(Builder)
		end
	end
	return unitName
end
