local DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskBuild: " .. inStr)
	end
end

--t1 ground

function BuildLLT(tskqbhvr)
	if tskqbhvr.unit == nil then
		return DummyUnitName
	end
	local unitName = DummyUnitName
		if MyTB.side == CORESideName then
			unitName = "corllt"
		else
			unitName = "armllt"
		end
		local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildSpecialLT(tskqbhvr)
	local unitName = DummyUnitName
	if IsAANeeded() then
		-- pop-up turrets are protected against bombs
		if MyTB.side == CORESideName then
			unitName = "cormaw"
		else
			unitName = "armclaw"
		end
	else
		if MyTB.side == CORESideName then
			unitName = "hllt"
		else
			unitName = "tawf001"
		end
	end
	local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildSpecialLTOnly(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "hllt"
	else
		unitName = "tawf001"
	end
	local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildHLT(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corhlt"
	else
		unitName = "armhlt"
	end
	local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildDepthCharge(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cordl"
	else
		unitName = "armdl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

function BuildFloatHLT(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corfhlt"
	else
		unitName = "armfhlt"
	end
	local unit = tskqbhvr.unit:Internal()
	--return GroundDefenseIfNeeded(unitName)
	return unitName
end

--t2 ground
function BuildLvl2PopUp(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corvipe"
	else
		unitName = "armpb"
	end
	local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildTachyon(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cordoom"
	else
		unitName = "armanni"
	end
	local unit = tskqbhvr.unit:Internal()
	return GroundDefenseIfNeeded(unitName)
end

function BuildLightTorpedo(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cortl"
	else
		unitName = "armtl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

function BuildPopTorpedo(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corptl"
	else
		unitName = "armptl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

function BuildHeavyTorpedo(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "coratl"
	else
		unitName = "armatl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

--AA

-- build AA in area only if there's not enough of it there already
--t1

function BuildLightAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("corrl")
	else
		unitName = BuildAAIfNeeded("armrl")
	end
	return unitName
end

function BuildFloatLightAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("corfrt")
	else
		unitName = BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function BuildMediumAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("madsam")
	else
		unitName = BuildAAIfNeeded("packo")
	end
	return unitName
end

function BuildHeavyishAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("corerad")
	else
		unitName = BuildAAIfNeeded("armcir")
	end
	return unitName
end

--t2

function BuildHeavyAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("corflak")
	else
		unitName = BuildAAIfNeeded("armflak")
	end
	return unitName
end

function BuildFloatHeavyAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("corenaa")
	else
		unitName = BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function BuildExtraHeavyAA(tskqbhvr)
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = BuildAAIfNeeded("screamer")
	else
		unitName = BuildAAIfNeeded("mercury")
	end
	return unitName
end



--SONAR-RADAR

function BuildSonar()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corsonar"
	else
		unitName = "armsonar"
	end
	return unitName
end

function BuildRadar()
	local unitName = DummyUnitName
		if MyTB.side == CORESideName then
			unitName = "corrad"
		else
			unitName = "armrad"
		end
	return unitName
end

function BuildFloatRadar()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corfrad"
	else
		unitName = "armfrad"
	end
	return unitName
end

function BuildLvl1Jammer()
	if not IsJammerNeeded() then return DummyUnitName end
		if MyTB.side == CORESideName then
			return "corjamt"
		else
			return "armjamt"
		end
end

--t1

function BuildAdvancedSonar()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corason"
	else
		unitName = "armason"
	end
	return unitName
end

function BuildAdvancedRadar()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corarad"
	else
		unitName = "armarad"
	end
	return unitName
end

function BuildLvl2Jammer()
	if not IsJammerNeeded() then return DummyUnitName end
	if MyTB.side == CORESideName then
		return "corshroud"
	else
		return "armveil"
	end
end

--Anti Radar/Jammer/Minefield/ScoutSpam Weapon

function BuildAntiRadar()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cjuno"
	else
		unitName = "ajuno"
	end
	return unitName
end

--NUKE

function BuildAntinuke()
	if IsAntinukeNeeded() then
		local unitName = DummyUnitName
		if MyTB.side == CORESideName then
			unitName = "corfmd"
		else
			unitName = "armamd"
		end
		return unitName
	end
	return DummyUnitName
end

function BuildNuke()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corsilo"
	else
		unitName = "armsilo"
	end
	return BuildWithLimitedNumber(unitName, ai.overviewhandler.nukeLimit)
end

function BuildNukeIfNeeded()
	if IsNukeNeeded() then
		return BuildNuke()
	end
end

function BuildTacticalNuke()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cortron"
	else
		unitName = "armemp"
	end
	return BuildWithLimitedNumber(unitName, ai.overviewhandler.tacticalNukeLimit)
end

--PLASMA

function BuildLvl1Plasma()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corpun"
	else
		unitName = "armguard"
	end
	return unitName
end

function BuildLvl2Plasma()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cortoast"
	else
		unitName = "armamb"
	end
	return unitName
end

function BuildHeavyPlasma()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corint"
	else
		unitName = "armbrtha"
	end
	return BuildWithLimitedNumber(unitName, ai.overviewhandler.heavyPlasmaLimit)
end

function BuildLol()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corbuzz"
	else
		unitName = "armvulc"
	end
	return unitName
end

--plasma deflector

function BuildShield()
	if IsShieldNeeded() then
		local unitName = DummyUnitName
		if MyTB.side == CORESideName then
			unitName = "corgate"
		else
			unitName = "armgate"
		end
		return unitName
	end
	return DummyUnitName
end

--anti intrusion 

function BuildAntiIntr()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "corsd"
	else
		unitName = "armsd"
	end
	return unitName
end

--targeting facility

function BuildTargeting()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = "cortarg"
	else
		unitName = "armtarg"
	end
	return unitName
end

--ARM emp launcer

function BuildEmpLauncer()
	local unitName = DummyUnitName
	if MyTB.side == CORESideName then
		unitName = DummyUnitName
	else
		unitName = "armEmp"
	end
	return unitName
end

--Function of function

local function CommanderAA(tskqbhvr)
	local unitName = DummyUnitName
	if IsAANeeded() then
		if ai.maphandler:IsUnderWater(tskqbhvr.unit:Internal():GetPosition()) then
			unitName = BuildFloatLightAA(tskqbhvr)
		else
			unitName = BuildLightAA(tskqbhvr)
		end
	end
	return unitName
end
