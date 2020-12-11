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
		elseif builder:CanBuild( "armllt" ) then
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
		elseif builder:CanBuild( "armclaw" ) then
			unitName = "armclaw"
		end
	else
		if builder:CanBuild( "corhllt" ) then
			unitName = "corhllt"
		elseif builder:CanBuild( "armbeamer" ) then
			unitName = "armbeamer"
		end
	end
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildSpecialLTOnly(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corhllt" ) then
		unitName = "corhllt"
	elseif builder:CanBuild( "armbeamer" ) then
		unitName = "armbeamer"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corhlt" ) then
		unitName = "corhlt"
	elseif builder:CanBuild( "armhlt" ) then
		unitName = "armhlt"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildDepthCharge(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cordl" ) then
		unitName = "cordl"
	elseif builder:CanBuild( "armdl" ) then
		unitName = "armdl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildFloatHLT(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfhlt" ) then
		unitName = "corfhlt"
	elseif builder:CanBuild( "armfhlt" ) then
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
	elseif builder:CanBuild( "armpb" ) then
		unitName = "armpb"
	end
	local unit = Builder.unit:Internal()
	return self.ai.taskshst:GroundDefenseIfNeeded(unitName)
end

function TaskBuildHST:BuildTachyon(Builder)
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cordoom" ) then
		unitName = "cordoom"
	elseif builder:CanBuild( "armanni" ) then
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
	elseif builder:CanBuild( "armtl" ) then
		unitName = "armtl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildPopTorpedo( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corptl" ) then
		unitName = "corptl"
	elseif builder:CanBuild( "armptl" ) then
		unitName = "armptl"
	end
	return self.ai.taskshst:BuildTorpedoIfNeeded(unitName)
end

function TaskBuildHST:BuildHeavyTorpedo( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "coratl" ) then
		unitName = "coratl"
	elseif builder:CanBuild( "armatl" ) then
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
	elseif builder:CanBuild( "armrl" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armrl")
	end
	return unitName
end

function TaskBuildHST:BuildFloatLightAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfrt" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corfrt")
	elseif builder:CanBuild( "armfrt" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function TaskBuildHST:BuildMediumAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cormadsam" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("cormadsam")
	elseif builder:CanBuild( "armferret" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armferret")
	end
	return unitName
end

function TaskBuildHST:BuildHeavyishAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corerad" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corerad")
	elseif builder:CanBuild( "armcir" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armcir")
	end
	return unitName
end

--t2

function TaskBuildHST:BuildHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corflak")
	elseif builder:CanBuild( "armflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armflak")
	end
	return unitName
end

function TaskBuildHST:BuildFloatHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corenaa" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corenaa")
	elseif builder:CanBuild( "armfflak" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function TaskBuildHST:BuildExtraHeavyAA( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corscreamer" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("corscreamer")
	elseif builder:CanBuild( "armmercury" ) then
		unitName = self.ai.taskshst:BuildAAIfNeeded("armmercury")
	end
	return unitName
end



--SONAR-RADAR

function TaskBuildHST:BuildRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corrad" ) then
		unitName = "corrad"
	elseif builder:CanBuild( "armrad" ) then
		unitName = "armrad"
	end
	return unitName
end

function TaskBuildHST:BuildFloatRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corfrad" ) then
		unitName = "corfrad"
	elseif builder:CanBuild( "armfrad" ) then
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
	elseif builder:CanBuild( "armjamt" ) then
		return "armjamt"
	end
end

--t1

function TaskBuildHST:BuildAdvancedSonar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corason" ) then
		unitName = "corason"
	elseif builder:CanBuild( "armason" ) then
		unitName = "armason"
	end
	return unitName
end

function TaskBuildHST:BuildAdvancedRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corarad" ) then
		unitName = "corarad"
	elseif builder:CanBuild( "armarad" ) then
		unitName = "armarad"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Jammer( taskQueueBehaviour, ai, builder )
	if not self.ai.taskshst:IsJammerNeeded() then return self.ai.armyhst.DummyUnitName end
	if builder:CanBuild( "corshroud" ) then
		return "corshroud"
	elseif builder:CanBuild( "armveil" ) then
		return "armveil"
	end
end

--Anti Radar/Jammer/Minefield/ScoutSpam Weapon

function TaskBuildHST:BuildAntiRadar( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corjuno" ) then
		unitName = "corjuno"
	elseif builder:CanBuild( "armjuno" ) then
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
		elseif builder:CanBuild( "armamd" ) then
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
	elseif builder:CanBuild( "armsilo" ) then
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
	elseif builder:CanBuild( "armemp" ) then
		unitName = "armemp"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.tacticalNukeLimit)
end

--PLASMA

function TaskBuildHST:BuildLvl1Plasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corpun" ) then
		unitName = "corpun"
	elseif builder:CanBuild( "armguard" ) then
		unitName = "armguard"
	end
	return unitName
end

function TaskBuildHST:BuildLvl2Plasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortoast" ) then
		unitName = "cortoast"
	elseif builder:CanBuild( "armamb" ) then
		unitName = "armamb"
	end
	return unitName
end

function TaskBuildHST:BuildHeavyPlasma( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corint" ) then
		unitName = "corint"
	elseif builder:CanBuild( "armbrtha" ) then
		unitName = "armbrtha"
	end
	return self.ai.taskshst:BuildWithLimitedNumber(unitName, self.ai.overviewhst.heavyPlasmaLimit)
end

function TaskBuildHST:BuildLol( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "corbuzz" ) then
		unitName = "corbuzz"
	elseif builder:CanBuild( "armvulc" ) then
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
		elseif builder:CanBuild( "armgate" ) then
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
	elseif builder:CanBuild( "armsd" ) then
		unitName = "armsd"
	end
	return unitName
end

--targeting facility

function TaskBuildHST:BuildTargeting( taskQueueBehaviour, ai, builder )
	local unitName = self.ai.armyhst.DummyUnitName
	if builder:CanBuild( "cortarg" ) then
		unitName = "cortarg"
	elseif builder:CanBuild( "armtarg" ) then
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
