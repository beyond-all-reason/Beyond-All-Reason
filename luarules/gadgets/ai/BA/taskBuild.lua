 DebugEnabled = false

local function EchoDebug(inStr)
	if DebugEnabled then
		game:SendToConsole("taskBuild: " .. inStr)
	end
end

--TORRETTE


function BuildLLT(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = DummyUnitName
		if ai.mySide == CORESideName then
			unitName = "corllt"
		else
			unitName = "armllt"
		end
		local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildSpecialLT(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if IsAANeeded() then
		-- pop-up turrets are protected against bombs
		if ai.mySide == CORESideName then
			unitName = "cormaw"
		else
			unitName = "armclaw"
		end
	else
		if ai.mySide == CORESideName then
			unitName = "hllt"
		else
			unitName = "tawf001"
		end
	end
	local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildSpecialLTOnly(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "hllt"
	else
		unitName = "tawf001"
	end
	local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildFloatHLT(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corfhlt"
	else
		unitName = "armfhlt"
	end
	local unit = self.unit:Internal()
	--return GroundDefenseIfNeeded(unitName, unit)
	return unitName
end

function BuildHLT(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corhlt"
	else
		unitName = "armhlt"
	end
	local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildLvl2PopUp(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corvipe"
	else
		unitName = "armpb"
	end
	local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildTachyon(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cordoom"
	else
		unitName = "armanni"
	end
	local unit = self.unit:Internal()
	return GroundDefenseIfNeeded(unitName, unit)
end

function BuildDepthCharge(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cordl"
	else
		unitName = "armdl"
	end
	return BuildTorpedoIfNeeded(unitName)
end


function BuildLightTorpedo(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cortl"
	else
		unitName = "armtl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

function BuildPopTorpedo(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corptl"
	else
		unitName = "armptl"
	end
	return BuildTorpedoIfNeeded(unitName)
end

function BuildHeavyTorpedo(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "coratl"
	else
		unitName = "armatl"
	end
	return BuildTorpedoIfNeeded(unitName)
end


--TORRI ANTIAEREA


-- build AA in area only if there's not enough of it there already
function BuildLightAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("corrl")
	else
		unitName = BuildAAIfNeeded("armrl")
	end
	return unitName
end

function BuildFloatLightAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("corfrt")
	else
		unitName = BuildAAIfNeeded("armfrt")
	end
	return unitName
end

function BuildMediumAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("madsam")
	else
		unitName = BuildAAIfNeeded("packo")
	end
	return unitName
end

function BuildHeavyishAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("corerad")
	else
		unitName = BuildAAIfNeeded("armcir")
	end
	return unitName
end

function BuildHeavyAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("corflak")
	else
		unitName = BuildAAIfNeeded("armflak")
	end
	return unitName
end

function BuildFloatHeavyAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("corenaa")
	else
		unitName = BuildAAIfNeeded("armfflak")
	end
	return unitName
end

function BuildExtraHeavyAA(self)
	if self.unit == nil then
		return DummyUnitName
	end
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = BuildAAIfNeeded("screamer")
	else
		unitName = BuildAAIfNeeded("mercury")
	end
	return unitName
end



--SONAR-RADAR

function BuildSonar()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corsonar"
	else
		unitName = "armsonar"
	end
	return unitName
end

function BuildAdvancedSonar()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corason"
	else
		unitName = "armason"
	end
	return unitName
end


function BuildRadar()
	local unitName = DummyUnitName
		if ai.mySide == CORESideName then
			unitName = "corrad"
		else
			unitName = "armrad"
		end
	return unitName
end

function BuildFloatRadar()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corfrad"
	else
		unitName = "armfrad"
	end
	return unitName
end

function BuildAdvancedRadar()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corarad"
	else
		unitName = "armarad"
	end
	return unitName
end

function BuildLvl1Jammer()
	if not IsJammerNeeded() then return DummyUnitName end
		if ai.mySide == CORESideName then
			return "corjamt"
		else
			return "armjamt"
		end
end

function BuildLvl2Jammer()
	if not IsJammerNeeded() then return DummyUnitName end
	if ai.mySide == CORESideName then
		return "corshroud"
	else
		return "armveil"
	end
end

--NUKE-PLASMA

function BuildShield()
	if IsShieldNeeded() then
		local unitName = ""
		if ai.mySide == CORESideName then
			unitName = "corgate"
		else
			unitName = "armgate"
		end
		return unitName
	end
	return DummyUnitName
end

function BuildAntinuke()
	if IsAntinukeNeeded() then
		local unitName = ""
		if ai.mySide == CORESideName then
			unitName = "corfmd"
		else
			unitName = "armamd"
		end
		return unitName
	end
	return DummyUnitName
end

function BuildNuke()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corsilo"
	else
		unitName = "armsilo"
	end
	return BuildWithLimitedNumber(unitName, ai.situation.nukeLimit)
end

function BuildNukeIfNeeded()
	if IsNukeNeeded() then
		return BuildNuke()
	end
end

function BuildTacticalNuke()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cortron"
	else
		unitName = "armemp"
	end
	return BuildWithLimitedNumber(unitName, ai.situation.tacticalNukeLimit)
end

function BuildLvl1Plasma()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corpun"
	else
		unitName = "armguard"
	end
	return unitName
end

function BuildLvl2Plasma()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "cortoast"
	else
		unitName = "armamb"
	end
	return unitName
end

function BuildHeavyPlasma()
	local unitName = ""
	if ai.mySide == CORESideName then
		unitName = "corint"
	else
		unitName = "armbrtha"
	end
	return BuildWithLimitedNumber(unitName, ai.situation.heavyPlasmaLimit)
end
