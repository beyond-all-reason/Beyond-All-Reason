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
		if builder:CanBuild( "corllt" ) then
			unitName = "corllt"
		else if builder:CanBuild( "armllt" ) then
			unitName = "armllt"
		end
		local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if self.ai.taskshst:IsAANeeded() then
		-- pop-up turrets are protected against bombs
		if builder:CanBuild( "cormaw" ) then
			unitName = "cormaw"
		else if builder:CanBuild( "armclaw" ) then
			unitName = "armclaw"
		end
	else
		if builder:CanBuild( "corhllt" ) then
			unitName = "corhllt"
		else if builder:CanBuild( "armbeamer" ) then
			unitName = "armbeamer"
		end
	end
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLTOnly(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corhllt" ) then
		unitName = "corhllt"
	else if builder:CanBuild( "armbeamer" ) then
		unitName = "armbeamer"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corhlt" ) then
		unitName = "corhlt"
	else if builder:CanBuild( "armhlt" ) then
		unitName = "armhlt"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildDepthCharge(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cordl" ) then
		unitName = "cordl"
	else if builder:CanBuild( "armdl" ) then
		unitName = "armdl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildFloatHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfhlt" ) then
		unitName = "corfhlt"
	else if builder:CanBuild( "armfhlt" ) then
		unitName = "armfhlt"
	end
	local unit = Builder.unit:Internal()
	--return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
	return unitName
end

--t2 ground
function TaskBuildHST:BuildLvl2PopUp(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corvipe" ) then
		unitName = "corvipe"
	else if builder:CanBuild( "armpb" ) then
		unitName = "armpb"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildTachyon(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cordoom" ) then
		unitName = "cordoom"
	else if builder:CanBuild( "armanni" ) then
		unitName = "armanni"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

-- torpedos

function TaskBuildHST:BuildLightTorpedo( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortl" ) then
		unitName = "cortl"
	else if builder:CanBuild( "armtl" ) then
		unitName = "armtl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildPopTorpedo( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corptl" ) then
		unitName = "corptl"
	else if builder:CanBuild( "armptl" ) then
		unitName = "armptl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildHeavyTorpedo( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coratl" ) then
		unitName = "coratl"
	else if builder:CanBuild( "armatl" ) then
		unitName = "armatl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

--AA

-- build AA in area only if there's not enough of it there already
--t1

function TaskBuildHST:BuildLightAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corrl" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corrl")
	else if builder:CanBuild( "armrl" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armrl")
	end
	return unitName
end

function TaskBuildHST:BuildFloatLightAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfrt" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corfrt")
	else if builder:CanBuild( "armfrt" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function TaskBuildHST:BuildMediumAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormadsam" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("cormadsam")
	else if builder:CanBuild( "armferret" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armferret")
	end
	return unitName
end

function TaskBuildHST:BuildHeavyishAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corerad" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corerad")
	else if builder:CanBuild( "armcir" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armcir")
	end
	return unitName
end

--t2

function TaskBuildHST:BuildHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corflak")
	else if builder:CanBuild( "armflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armflak")
	end
	return unitName
end

function TaskBuildHST:BuildFloatHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corenaa" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corenaa")
	else if builder:CanBuild( "armfflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function TaskBuildHST:BuildExtraHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corscreamer" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corscreamer")
	else if builder:CanBuild( "armmercury" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armmercury")
	end
	return unitName
end



--SONAR-RADAR

function TaskBuildHST:BuildRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corrad" ) then
		unitName = "corrad"
	else if builder:CanBuild( "armrad" ) then
		unitName = "armrad"
	end
	return unitName
end

function TaskBuildHST:BuildFloatRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfrad" ) then
		unitName = "corfrad"
	else if builder:CanBuild( "armfrad" ) then
		unitName = "armfrad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl1Jammer( taskQueueBehaviour, ai, builder )
	if not self.ai.taskshst:IsJammerNeeded() then
		return self.ai.armyhst.DummyUnitName
	end
	if builder:CanBuild( "corjamt" ) then
		return "corjamt"
	else if builder:CanBuild( "armjamt" ) then
		return "armjamt"
	end
end

--t1

function TaskBuildHST:BuildAdvancedSonar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corason" ) then
		unitName = "corason"
	else if builder:CanBuild( "armason" ) then
		unitName = "armason"
	end
	return unitName
end

function TaskBuildHST:BuildAdvancedRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corarad" ) then
		unitName = "corarad"
	else if builder:CanBuild( "armarad" ) then
		unitName = "armarad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Jammer( taskQueueBehaviour, ai, builder )
	if not self.ai.taskshst:IsJammerNeeded() then return self.ai.armyhst.DummyUnitName end
	if builder:CanBuild( "corshroud" ) then
		return "corshroud"
	else if builder:CanBuild( "armveil" ) then
		return "armveil"
	end
end

--Anti Radar/Jammer/Minefield/ScoutSpam Weapon

function TaskBuildHST:BuildAntiRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corjuno" ) then
		unitName = "corjuno"
	else if builder:CanBuild( "armjuno" ) then
		unitName = "armjuno"
	end
	return unitName
end

--NUKE

function TaskBuildHST:BuildAntinuke( taskQueueBehaviour, ai, builder )
	if self.ai.taskshst:IsAntinukeNeeded() then
		local unitName = self.ai.armyhst.DummyUnitName
		if builder:CanBuild( "corfmd" ) then
			unitName = "corfmd"
		else if builder:CanBuild( "armamd" ) then
			unitName = "armamd"
		end
		return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)
	end
	return self.ai.armyhst.DummyUnitName
end

function TaskBuildHST:BuildNuke( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corsilo" ) then
		unitName = "corsilo"
	else if builder:CanBuild( "armsilo" ) then
		unitName = "armsilo"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, 1)--ai.overviewhst.nukeLimit)
end

function TaskBuildHST:BuildNukeIfNeeded( taskQueueBehaviour, ai, builder )
	if self.ai.taskshst:IsNukeNeeded() then
		return self:BuildNuke( taskQueueBehaviour, ai, builder )
	end
end

function TaskBuildHST:BuildTacticalNuke( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortron" ) then
		unitName = "cortron"
	else if builder:CanBuild( "armemp" ) then
		unitName = "armemp"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.tacticalNukeLimit)
end

--PLASMA

function TaskBuildHST:BuildLvl1Plasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corpun" ) then
		unitName = "corpun"
	else if builder:CanBuild( "armguard" ) then
		unitName = "armguard"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Plasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortoast" ) then
		unitName = "cortoast"
	else if builder:CanBuild( "armamb" ) then
		unitName = "armamb"
	end
	return unitName
end

function TaskBuildHST:BuildHeavyPlasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corint" ) then
		unitName = "corint"
	else if builder:CanBuild( "armbrtha" ) then
		unitName = "armbrtha"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.heavyPlasmaLimit)
end

function TaskBuildHST:BuildLol( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corbuzz" ) then
		unitName = "corbuzz"
	else if builder:CanBuild( "armvulc" ) then
		unitName = "armvulc"
	end
	return unitName
end

--plasma deflector

function TaskBuildHST:BuildShield( taskQueueBehaviour, ai, builder )
	if self.ai.taskshst:IsShieldNeeded() then
		local unitName = self.ai.armyhst.DummyUnitName
		if builder:CanBuild( "corgate" ) then
			unitName = "corgate"
		else if builder:CanBuild( "armgate" ) then
			unitName = "armgate"
		end
		return unitName
	end
	return self.ai.armyhst.DummyUnitName
end

--anti intrusion

function TaskBuildHST:BuildAntiIntr( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corsd" ) then
		unitName = "corsd"
	else if builder:CanBuild( "armsd" ) then
		unitName = "armsd"
	end
	return unitName
end

--targeting facility

function TaskBuildHST:BuildTargeting( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortarg" ) then
		unitName = "cortarg"
	else if builder:CanBuild( "armtarg" ) then
		unitName = "armtarg"
	end
	return unitName
end

--ARM emp launcer

function TaskBuildHST:BuildEmpLauncer( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "armEmp" ) then
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
