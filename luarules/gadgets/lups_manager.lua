function gadget:GetInfo()
	return {
		name = "Lups Manager",
		desc = "Draws energy balls for fusions and some other selective units",
		author = "Floris",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = 1500,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then

	local Lups, LupsAddFX

	local function MergeTable(table1, table2)
		local result = {}
		for i, v in pairs(table2) do
			if type(v) == 'table' then
				result[i] = MergeTable(v, {})
			else
				result[i] = v
			end
		end
		for i, v in pairs(table1) do
			if result[i] == nil then
				if type(v) == 'table' then
					if type(result[i]) ~= 'table' then
						result[i] = {}
					end
					result[i] = MergeTable(v, result[i])
				else
					result[i] = v
				end
			end
		end
		return result
	end


	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local corafusShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 60, 0 },
		size = 32,
		light = 3.25,
		--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
		--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
		repeatEffect = true
	}

	local armafusShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 60, 0 },
		size = 28,
		light = 3.5,
		--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
		--colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
		repeatEffect = true
	}

	local corfusShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 51, 0 },
		size = 23,
		light = 2.75,
		--colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
		--colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
		repeatEffect = true
	}

	local corgateShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 42, 0 },
		size = 11,
		light = 2.5,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
		repeatEffect = true
	}

	local armjunoShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 72, 0 },
		size = 13,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
		repeatEffect = true
	}

	local corjunoShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 72, 0 },
		size = 13,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
		repeatEffect = true
	}

	local armgateShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 23.5, -5 },
		size = 14.5,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
		repeatEffect = true
	}
	local corgateShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 42, 0 },
		size = 11,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
		repeatEffect = true
	}

	local armjunoShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 72, 0 },
		size = 13,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
		repeatEffect = true
	}

	local corjunoShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 72, 0 },
		size = 13,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.8, 0.2, 0.2, 0.4 }, { 0.8, 0.2, 0.2, 0.45 }, { 0.9, 0.2, 0.2, 0.45 }, { 0.9, 0.1, 0.2, 0.4 } },
		repeatEffect = true
	}

	local armgateShieldSphere = {
		layer = -35,
		life = 20,
		pos = { 0, 23.5, -5 },
		size = 14.5,
		light = 2,
		colormap1 = { { 0.9, 0.9, 1, 0.75 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 1.0 }, { 0.9, 0.9, 1, 0.75 } },
		colormap2 = { { 0.2, 0.6, 0.2, 0.4 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.45 }, { 0.2, 0.6, 0.2, 0.4 } },
		repeatEffect = true
	}

	local UnitEffects = {

		["armjuno"] = {
			{ class = 'ShieldSphere', options = armjunoShieldSphere },
			{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
		},
		["corjuno"] = {
			{ class = 'ShieldSphere', options = corjunoShieldSphere },
			{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 72, 0 }, size = 14, precision = 22, repeatEffect = true } },
		},

		--// FUSIONS //--------------------------
		["corafus"] = {
			{ class = 'ShieldSphere', options = corafusShieldSphere },
			{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 32.5, precision = 22, repeatEffect = true } },
		},
		["corfus"] = {
			{ class = 'ShieldSphere', options = corfusShieldSphere },
			{ class = 'ShieldJitter', options = { life = math.huge, pos = { 0, 50, 0 }, size = 23.5, precision = 22, repeatEffect = true } },
		},
		["armafus"] = {
			{ class = 'ShieldSphere', options = armafusShieldSphere },
			{ class = 'ShieldJitter', options = { layer = -16, life = math.huge, pos = { 0, 60, 0 }, size = 28.5, precision = 22, repeatEffect = true } },
		},
		["corgate"] = {
			{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
			{ class = 'ShieldSphere', options = corgateShieldSphere },
			--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
			--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
		},
		["corfgate"] = {
			{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 42, 0 }, size = 12, precision = 22, repeatEffect = true } },
			{ class = 'ShieldSphere', options = corgateShieldSphere },
			--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,42,0.0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
			--{class='ShieldJitter',options={life=math.huge, pos={0,42,0}, size=20, precision=2, repeatEffect=true}},
		},
		["armgate"] = {
			{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 23.5, -5 }, size = 15, precision = 22, repeatEffect = true } },
			{ class = 'ShieldSphere', options = armgateShieldSphere },
			--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,23.5,-5}, size=555, precision=0, strength=0.001, repeatEffect=true}},
		},
		["armfgate"] = {
			{ class = 'ShieldJitter', options = { delay = 0, life = math.huge, pos = { 0, 25, 0 }, size = 15, precision = 22, repeatEffect = true } },
			{ class = 'ShieldSphere', options = MergeTable(armgateShieldSphere, { pos = { 0, 25, 0 } }) },
			--{class='ShieldJitter', options={delay=0,life=math.huge, pos={0,25,0}, size=555, precision=0, strength= 0.001, repeatEffect=true}},
		},

	}

	local scavEffects = {}
	if UnitDefNames['armcom_scav'] then
		for k, effect in pairs(UnitEffects) do
			scavEffects[k .. '_scav'] = effect
			if scavEffects[k .. '_scav'].options then
				if scavEffects[k .. '_scav'].options.color then
					scavEffects[k .. '_scav'].options.color = { 0.92, 0.32, 1.0 }
				end
				if scavEffects[k .. '_scav'].options.colormap then
					scavEffects[k .. '_scav'].options.colormap = { { 0.92, 0.32, 1.0 } }
				end
				if scavEffects[k .. '_scav'].options.colormap1 then
					scavEffects[k .. '_scav'].options.colormap1 = { { 0.92, 0.32, 1.0 } }
				end
				if scavEffects[k .. '_scav'].options.colormap2 then
					scavEffects[k .. '_scav'].options.colormap2 = { { 0.92, 0.32, 1.0 } }
				end
			end
		end
		for k, effect in pairs(scavEffects) do
			UnitEffects[k] = effect
		end
		scavEffects = nil
	end

	local newEffects = {}
	for unitname, effect in pairs(UnitEffects) do
		newEffects[UnitDefNames[unitname].id] = effect
	end
	UnitEffects = newEffects
	newEffects = nil

	local myTeamID = Spring.GetMyTeamID()
	local mySpec, fullview = Spring.GetSpectatingState()

	local abs = math.abs
	local spGetSpectatingState = Spring.GetSpectatingState
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitRulesParam = Spring.GetUnitRulesParam
	local spGetUnitIsActive = Spring.GetUnitIsActive
	local IsUnitInLos = Spring.IsUnitInLos

	local particleIDs = {}

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function ClearFxs(unitID)
		if particleIDs[unitID] then
			for _, fxID in ipairs(particleIDs[unitID]) do
				Lups.RemoveParticles(fxID)
			end
			particleIDs[unitID] = nil
		end
	end

	local function ClearFx(unitID, fxIDtoDel)
		if particleIDs[unitID] then
			local newTable = {}
			for _, fxID in ipairs(particleIDs[unitID]) do
				if fxID == fxIDtoDel then
					Lups.RemoveParticles(fxID)
				else
					newTable[#newTable + 1] = fxID
				end
			end
			if #newTable == 0 then
				particleIDs[unitID] = nil
			else
				particleIDs[unitID] = newTable
			end
		end
	end

	local function AddFxs(unitID, fxID)
		if not particleIDs[unitID] then
			particleIDs[unitID] = {}
		end

		local unitFXs = particleIDs[unitID]
		unitFXs[#unitFXs + 1] = fxID
	end
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	function gadget:UnitFinished(unitID, unitDefID, unitTeam)
		if not fullview and not CallAsTeam(myTeamID, IsUnitInLos, unitID) then
			return
		end

		local effects = UnitEffects[unitDefID]
		if effects then
			for _, fx in ipairs(effects) do
				if (not fx.options) then
					Spring.Echo("LUPS DEBUG ", UnitDefs[unitDefID].name, fx and fx.class)
					return
				end

				if (fx.class == "GroundFlash") then
					fx.options.pos = { Spring.GetUnitBasePosition(unitID) }
				end
				fx.options.unit = unitID
				AddFxs(unitID, LupsAddFX(fx.class, fx.options))
				fx.options.unit = nil
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID)
		ClearFxs(unitID)
	end

	function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)

		if fullview then return end
		if not fullview and CallAsTeam(myTeamID, IsUnitInLos, unitID) then return end

		local unitDefID = spGetUnitDefID(unitID)
		local effects = UnitEffects[unitDefID]
		if effects then
			for _, fx in ipairs(effects) do
				if fx.options.onActive == true and spGetUnitIsActive(unitID) == nil then
					break
				else
					if (fx.class == "GroundFlash") then
						fx.options.pos = { Spring.GetUnitBasePosition(unitID) }
					end
					fx.options.unit = unitID
					fx.options.under_construction = spGetUnitRulesParam(unitID, "under_construction")
					AddFxs(unitID, LupsAddFX(fx.class, fx.options))
					fx.options.unit = nil
				end
			end
		end

	end

	function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
		if mySpec and fullview then
			return
		end

		if not fullview and CallAsTeam(myTeamID, IsUnitInLos, unitID) then
			return
		end

		ClearFxs(unitID)
	end

	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------

	local function CheckForExistingUnits()
		--// initialize effects for existing units
		local allUnits = Spring.GetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			local unitDefID = Spring.GetUnitDefID(unitID)
			if spGetUnitRulesParam(unitID, "under_construction") ~= 1 then
				local _, _, inBuild = Spring.GetUnitIsStunned(unitID)
				if not inBuild then
					gadget:UnitFinished(unitID, unitDefID)
				end
			end
		end

		--gadgetHandler:RemoveGadgetCallIn("Update",gadget)
	end

	function gadget:PlayerChanged(playerID)
		myTeamID = Spring.GetMyTeamID()
		mySpec, fullview = Spring.GetSpectatingState()

		if playerID == Spring.GetMyPlayerID() then
			--// clear all FXs
			for _, unitFxIDs in pairs(particleIDs) do
				for _, fxID in ipairs(unitFxIDs) do
					Lups.RemoveParticles(fxID)
				end
			end
			particleIDs = {}
			CheckForExistingUnits()
			--gadgetHandler:UpdateGadgetCallIn("Update",gadget)
		end
	end

	function gadget:Initialize()
		if not Lups then
			Lups = GG['Lups']
			LupsAddFX = Lups.AddParticles
			CheckForExistingUnits()
		end
	end

	function gadget:Shutdown()

		for _, unitFxIDs in pairs(particleIDs) do
			for _, fxID in ipairs(unitFxIDs) do
				Lups.RemoveParticles(fxID)
			end
		end
		particleIDs = {}

		Spring.SendLuaRulesMsg("lups shutdown", "allies")
	end


end
