if Spring.GetModOptions().teamcolors_anonymous_mode ~= "disabled" then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Hats",
		desc = "Handles cosmetic-only hat behaviour",
		author = "Beherith",
		date = "2020",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

local DEBUG = false

function gadget:GameID(gameID)
	-- make sure gameID is a string because i'm not actually sure
	cachedGameID = tostring(gameID)
	-- Initialise this madness
	local FakeRandomSeed = ""
	-- because yes
	for i = 1, 1000 do
		-- Check if the next character in the game ID is a number
		if tonumber(string.sub(cachedGameID, i, i)) then
			-- Make sure the number we are creating doesn't grow beyond the 32bit integrer limits
			if (not tonumber(FakeRandomSeed)) or i <= 8 or (i > 8 and tonumber(FakeRandomSeed .. tonumber(string.sub(cachedGameID, i, i))) < 10) then
				-- Add the next character that is for sure a number
				FakeRandomSeed = FakeRandomSeed .. tonumber(string.sub(cachedGameID, i, i))
			else
				-- Oh so we're about to break the 32 bit integrer, let's end it here
				break
			end
		end
	end
	-- Turn this abomination string into an actual number
	FakeRandomSeed = tonumber(FakeRandomSeed)
	-- Use this number as math.random seed
	math.randomseed(FakeRandomSeed)
end

PlayerCosmeticList = {
	[439] = { -- Goopy
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[641] = { -- ZLO
		"LegionChampionHat", -- Legion Fight Night winner
	},
	[694] = { -- Raghna
		"VikingHat", -- Omega Series 4 Winner
	},
	[915] = { -- PRO_rANDY
		"SilverMedalNecklace", -- Last Season Top2 Finisher
	},
	[975] = { -- StarDoM
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
	},
	[1172] = { -- PtaQ
		"VikingHat", -- Omega Series 4 Winner
	},
	[1332] = { -- Flash
		"SilverMedalNecklace", -- Last Season Top2 Finisher
	},
	[1830] = { -- TM_Zow
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[2377] = { -- Therxyy
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
	},
	[3778] = { -- PRO_che
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[3913] = { -- [teh]Teddy
		"VikingHat", -- Omega Series 4 Winner
	},
	[5467] = { -- HelsHound
		"VikingHat", -- Omega Series 4 Winner
	},
	[8069] = { -- BRRRRRRRRRRRRRRRRRRR
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},
	[42178] = { -- [pretor]
		"LegionChampionHat", -- Legion Fight Night winner
	},
	[50820] = { -- Emre
		"VikingHat", -- Omega Series 4 Winner
		"GoldMedalNecklace", -- Last Season Top1 Finisher
	},
	[52043] = { -- scag
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},
	[53682] = { -- PROt_Fiddler112
		"BronzeMedalNecklace", -- Last Season Top3 Finisher
	},
	[59340] = { -- TM_MightySheep
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[59916] = { -- Kuchy
		"VikingHat", -- Omega Series 4 Winner
	},
	[64215] = { -- PRO_RevanXFL
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[70311] = { -- PRO_BTCV
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
		"BronzeMedalNecklace", -- Last Season Top3 Finisher
	},
	[82263] = { -- TM_autopilot
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
		"KingCrownHat",
		"BronzeMedalNecklace", -- Last Season Top3 Finisher
	},
	[82811] = { -- TM_SlickLikeVik
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},
	[88808] = { -- Shadowisper
		"PirateHat", -- "give it to shadow he deserves it"
	},
	[116414] = { -- [APM]random_variable
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[119539] = { -- [Stud]Lovish, BM_LegionAbuse[Stud]
		"LegionChampionHat", -- Legion Fight Night winner
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[134481] = { -- [APM]Blxssom
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[139738] = { -- [DmE]FlyingDuck
		"FightNightHat", -- Fight Night 1v1 and Master's League winner
	},
	[139750] = { -- TM_Sashkorin
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},
	[142011] = { -- [BAC]OutlawElite
		"BronzeMedalNecklace", -- Last Season Top3 Finisher
	},
	[144092] = { -- [DmE]Wraxell
		"LegionChampionHat", -- Legion Fight Night winner
	},
	[151863] = { -- Blodir
		"VikingHat", -- Omega Series 4 Winner
		"GoldMedalNecklace", -- Last Season Top1 Finisher
	},
	[168232] = { -- Leohvm
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[252507] = { -- BM_akumar6
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[266170] = { -- HuK
		"ArmadaNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
		"CortexNationWarsUSLeftShoulder", -- Nation Wars 2026 1st Place
	},
	[390411] = { -- vixatry
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},
	[401928] = { -- RAM_Noctis
		"ArmadaNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
		"CortexNationWarsGERLeftShoulder", -- Nation Wars 2026 3rd Place
	},
	[495517] = { -- OKS[MADO]
		"ArmadaNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
		"CortexNationWarsEECLeftShoulder", -- Nation Wars 2026 2nd Place
	},

	[9999999999] = { -- Debug
		"HalloweenHat",
		"FightNightHat",
		"LegionChampionHat",
		"VikingHat",
		"KingCrownHat",
		"ArmadaNationWarsGERLeftShoulder",
		"ArmadaNationWarsEECLeftShoulder",
		"ArmadaNationWarsUSLeftShoulder",
		"CortexNationWarsGERLeftShoulder",
		"CortexNationWarsEECLeftShoulder",
		"CortexNationWarsUSLeftShoulder",
	},
}

-- Cosmetic Defs

--[[
	slot = "hat", "rightshoulder", "leftshoulder", "necklace", "belt"
	implementation = "unit", "baked" - unit uses separate unit attached, baked uses model parts baked into the model
	unitDefID = UnitDefNames.unitdefname and UnitDefNames.unitdefname.id - only for unit implementation
	scriptCall = "ShowCrown" - only for baked implementation
	faction = {arm = true, cor = true, leg = true},
	conflictsWith = {"HatName"}
]]

CosmeticDefinitions = {

	------------------------------------------
	-- Hats
	------------------------------------------

	HalloweenHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_hw and UnitDefNames.cor_hat_hw.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	FightNightHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_fightnight and UnitDefNames.cor_hat_fightnight.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	LegionChampionHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_legfn and UnitDefNames.cor_hat_legfn.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	VikingHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_viking and UnitDefNames.cor_hat_viking.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	PirateHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_pirate and UnitDefNames.cor_hat_pirate.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	GnomeHat = {
		slot = "hat",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_hat_gnome and UnitDefNames.cor_hat_gnome.id,
		faction = { arm = true, cor = true, leg = true },
		conflictsWith = {},
	},

	KingCrownHat = {
		slot = "hat",
		implementation = "baked",
		scriptCall = "ShowCrown",
		faction = { arm = true, cor = true, leg = false }, -- we don't have this for Legion :/
		conflictsWith = {},
	},

	------------------------------------------
	-- Right Shoulder
	------------------------------------------

	------------------------------------------
	-- Left Shoulder
	------------------------------------------

	ArmadaNationWarsGERLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.arm_leftshoulder_nationwars_ger and UnitDefNames.arm_leftshoulder_nationwars_ger.id,
		faction = { arm = true, cor = false, leg = false },
		conflictsWith = {},
	},

	ArmadaNationWarsEECLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.arm_leftshoulder_nationwars_eec and UnitDefNames.arm_leftshoulder_nationwars_eec.id,
		faction = { arm = true, cor = false, leg = false },
		conflictsWith = {},
	},

	ArmadaNationWarsUSLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.arm_leftshoulder_nationwars_us and UnitDefNames.arm_leftshoulder_nationwars_us.id,
		faction = { arm = true, cor = false, leg = false },
		conflictsWith = {},
	},

	CortexNationWarsGERLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_leftshoulder_nationwars_ger and UnitDefNames.cor_leftshoulder_nationwars_ger.id,
		faction = { arm = false, cor = true, leg = false },
		conflictsWith = {},
	},

	CortexNationWarsEECLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_leftshoulder_nationwars_eec and UnitDefNames.cor_leftshoulder_nationwars_eec.id,
		faction = { arm = false, cor = true, leg = false },
		conflictsWith = {},
	},

	CortexNationWarsUSLeftShoulder = {
		slot = "leftshoulder",
		implementation = "unit",
		unitDefID = UnitDefNames.cor_leftshoulder_nationwars_us and UnitDefNames.cor_leftshoulder_nationwars_us.id,
		faction = { arm = false, cor = true, leg = false },
		conflictsWith = {},
	},

	------------------------------------------
	-- Necklaces
	------------------------------------------

	BronzeMedalNecklace = {
		slot = "necklace",
		implementation = "baked",
		scriptCall = "ShowMedalBronze",
		faction = { arm = true, cor = true, leg = false }, -- we don't have this for Legion :/
		conflictsWith = {},
	},

	SilverMedalNecklace = {
		slot = "necklace",
		implementation = "baked",
		scriptCall = "ShowMedalSilver",
		faction = { arm = true, cor = true, leg = false }, -- we don't have this for Legion :/
		conflictsWith = {},
	},

	GoldMedalNecklace = {
		slot = "necklace",
		implementation = "baked",
		scriptCall = "ShowMedalGold",
		faction = { arm = true, cor = true, leg = false }, -- we don't have this for Legion :/
		conflictsWith = {},
	},

	------------------------------------------
	-- Belts
	------------------------------------------
}

CosmeticUnitDefIDToPiece = {}
for _, def in pairs(CosmeticDefinitions) do
	if def.implementation == "unit" then
		CosmeticUnitDefIDToPiece[def.unitDefID] = def.slot .. "cosmeticpoint"
	end
end

-- We need to keep track of all hats unitdefs, and watch what happens to them
-- hats, can be equipped by capturing them -- or by being given one?
--    if a commando captures a hat, it is destroyed
--    if a hat is already present on a commander, then it is destroyed
-- if the wearer dies, detach the hat
-- decoys?
--  if decoys cant wear hats, then it becomes obvious
--  so decoys will be able to wear hats
-- giving:
-- wearer loses hat if given comm with hat
-- hats should not prevent game end! as they arent real units
-- attachunit somehow does not pass the direction, and passes the position of the piece attached to it about 1 frame late
-- consider manually repositioning hats then? could start to get expensive
-- You cant pick up allied hats
-- Hats should not prevent game ending if they are the only unit left.
-- e.g. dying comms should give hats to gaia

-- Notes:
-- hat wearing units must have unitdef holdsteady = true to give the piece orientations
-- hats have nonzero mass and can stop commanders from being able to use T1 transports (see 5c4b8a3)
-- hat pos is 1 frame off :/

if not gadgetHandler:IsSyncedCode() then
	return
end

local unitsWearingHats = {} -- key unitID of wearer, value unitID of hat

local Hats = {} -- key of unitID of hat, value of wearer unitID

local spGetUnitHealth = Spring.GetUnitHealth
local spSetUnitArmored = Spring.SetUnitArmored
local spGetPlayerList = Spring.GetPlayerList
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spCreateUnit = Spring.CreateUnit
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local function spGetUnitScriptEnv(unitID)
	local unitScript = Spring.UnitScript
	if unitScript and unitScript.GetScriptEnv then
		return unitScript.GetScriptEnv(unitID)
	end
	return nil
end
local spCallAsUnit = Spring.UnitScript.CallAsUnit
local spGetCOBScriptID = Spring.GetCOBScriptID
local spCallCOBScript = Spring.CallCOBScript
local spGetGaiaTeamID = Spring.GetGaiaTeamID
local stringSub = string.sub

local unitDefCanWearHats = {
	[UnitDefNames.corcom.id] = true,
	[UnitDefNames.cordecom.id] = true,
	[UnitDefNames.armcom.id] = true,
	[UnitDefNames.armdecom.id] = true,
}

if Spring.GetModOptions().experimentallegionfaction then
	unitDefCanWearHats[UnitDefNames.legcom.id] = true
	unitDefCanWearHats[UnitDefNames.legdecom.id] = true
end

local unitDefHat = {}
for udid, ud in pairs(UnitDefs) do
	--almost all raptors have dying anims
	if ud.customParams.subfolder and ud.customParams.subfolder == "other/hats" then
		unitDefHat[udid] = true
	end
end

--local function MatchPlayer(awardees, name, accountID)
--	if awardees[name] or (accountID and awardees[accountID]) then
--		return true
--	end
--	return false
--end

local spawnWarpInFrame = Game.spawnWarpInFrame
local spawnAwardsProcessed = false

local function UpdateGameFrameCallIn()
	if spawnAwardsProcessed and next(unitsWearingHats) == nil then
		gadgetHandler:RemoveCallIn("GameFrame")
	else
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function CreateAndGiveHat(hatDefID, unitPosX, unitPosY, unitPosZ, teamID)
	local createdHatID = spCreateUnit(hatDefID, unitPosX, unitPosY, unitPosZ, 0, teamID)
	if createdHatID then
		gadget:UnitGiven(createdHatID, hatDefID, teamID)
	end
end

function gadget:GameFrame(gf)
	if gf == spawnWarpInFrame and not spawnAwardsProcessed then
		for _, playerID in ipairs(spGetPlayerList() or {}) do
			local accountID = nil
			local playerName, _, spec, teamID, _, _, _, _, _, _, accountInfo = spGetPlayerInfo(playerID)
			if accountInfo and accountInfo.accountid then
				accountID = tonumber(accountInfo.accountid)
			end

			if DEBUG then
				accountID = 9999999999
			end
			if not spec and PlayerCosmeticList[accountID] then
				-- Process Player
				local playerCosmeticOptions = { hat = {}, rightshoulder = {}, leftshoulder = {}, necklace = {}, belt = {} }
				local playerFaction = ""
				if true then
					local units = spGetTeamUnits(teamID) or {}
					local unitDefID = spGetUnitDefID(units[1])
					playerFaction = stringSub(UnitDefs[unitDefID].name, 1, 3)
				end

				-- Collect all possible cosmetics for this player
				for i = 1, #PlayerCosmeticList[accountID] do
					local cosmetic = PlayerCosmeticList[accountID][i]
					if CosmeticDefinitions[cosmetic] and CosmeticDefinitions[cosmetic].faction[playerFaction] then
						playerCosmeticOptions[CosmeticDefinitions[cosmetic].slot][#playerCosmeticOptions[CosmeticDefinitions[cosmetic].slot] + 1] = CosmeticDefinitions[cosmetic]
					end
				end

				-- Randomly pick the cosmetics from available options
				for _, list in pairs(playerCosmeticOptions) do
					if #list > 0 then
						math.random()
						math.random()
						math.random()
						local pick = math.random(1, #list)

						if list[pick].implementation == "unit" then
							local units = spGetTeamUnits(teamID) or {}
							for k = 1, #units do
								if not unitDefHat[units[k]] then
									local unitPosX, unitPosY, unitPosZ = spGetUnitPosition(units[k])
									CreateAndGiveHat(list[pick].unitDefID, unitPosX, unitPosY, unitPosZ, teamID)
								end
							end
						elseif list[pick].implementation == "baked" then
							local units = spGetTeamUnits(teamID) or {}
							for k = 1, #units do
								local unitID = units[k]
								if not unitDefHat[unitID] then
									local unitDefID = spGetUnitDefID(unitID)
									if stringSub(UnitDefs[unitDefID].name, 1, 3) == "arm" then
										local scriptEnv = spGetUnitScriptEnv(unitID)
										if scriptEnv then
											if scriptEnv[list[pick].scriptCall] then
												spCallAsUnit(unitID, scriptEnv[list[pick].scriptCall], true)
											end
										end
									else
										if spGetCOBScriptID(unitID, list[pick].scriptCall) then
											spCallCOBScript(unitID, list[pick].scriptCall, 0)
										end
									end
								end
							end
						end
					end
				end
			end
		end
		spawnAwardsProcessed = true
		UpdateGameFrameCallIn()
	end

	-- periodically update hat health	(damage gets applied instantly at gadget:UnitDamaged anyway)
	if gf % 61 == 1 and next(unitsWearingHats) ~= nil then
		for unitID, hatUnitID in pairs(unitsWearingHats) do
			local health, maxHealth = spGetUnitHealth(unitID)
			local hatHealth, hatMaxHealth = spGetUnitHealth(hatUnitID)
			if health and maxHealth and hatMaxHealth then
				Spring.SetUnitHealth(hatUnitID, (health / maxHealth) * hatMaxHealth)
			else
				unitsWearingHats[unitID] = nil
			end
		end
		UpdateGameFrameCallIn()
	end
end

--Spring.GetUnitPiecePosDir

--( number unitID, number pieceNum ) -> nil | number posX, number posY, number posZ,
-- number dirX, number dirZ, number dirY

--Returns piece position and direction in world space. The direction (dirX, dirY, dirZ) is not necessarily normalized. The position is defined as the position of the first vertex of the piece and it defines direction as the direction in which the line --from the first vertex to the second vertex points. -> e.g. hats need two null vertices

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	-- for unitID reuse, just in case
	if unitDefHat[unitDefID] then
		if DEBUG then
			Spring.Echo("hat created", unitID, unitDefID, unitTeam, builderID)
		end
		Hats[unitID] = -1
		Spring.SetUnitNeutral(unitID, true)
		spSetUnitArmored(unitID, true, 0)
		Spring.SetUnitBlocking(unitID, false, false, false, false) -- non blocking while dying
		Spring.SetUnitNoMinimap(unitID, true)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if Hats[unitID] ~= nil then
		if DEBUG then
			Spring.Echo("A hat was destroyed", unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		end
		Hats[unitID] = nil
	end
	if unitsWearingHats[unitID] ~= nil then
		local hatID = unitsWearingHats[unitID]
		if DEBUG then
			Spring.Echo("A hat wearing unit was destroyed, freeing hat", unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		end
		unitsWearingHats[unitID] = nil
		if spGetUnitRulesParam(unitID, "remove_decorations") == 1 then
			Spring.DestroyUnit(hatID)
		else
			Spring.UnitDetachFromAir(hatID)
			Spring.UnitDetach(hatID)
			Hats[hatID] = -1
			Spring.SetUnitNoSelect(hatID, false)
			Spring.TransferUnit(hatID, spGetGaiaTeamID()) -- ( number unitID,  numer newTeamID [, boolean given = true ] ) -> nil if given=false, the unit is captured
			local px, py, pz = Spring.GetUnitPosition(unitID)
			if px and pz then
				Spring.SetUnitPosition(hatID, px + 32, pz + 32)
			end
		end
		UpdateGameFrameCallIn()
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		if DEBUG then
			Spring.Echo("A hat wearing unit was given, destroying hat", unitID, unitDefID, unitTeam, unitsWearingHats[unitID])
		end
		Spring.DestroyUnit(unitsWearingHats[unitID])
		unitsWearingHats[unitID] = nil
	end
	if Hats[unitID] then
		local hatID = unitID
		if unitTeam == spGetGaiaTeamID() then
			if DEBUG then
				Spring.Echo("A hat was given back to gaia", hatID, unitDefID, unitTeam, spGetGaiaTeamID())
			end
			return
		end

		if DEBUG then
			Spring.Echo("A hat was given, finding a wearer", hatID, unitDefID, unitTeam)
		end
		-- find nearest commander and attach hat onto him?
		local hx, hy, hz = Spring.GetUnitPosition(hatID)
		if hx then
			for ct, nearunitID in pairs(Spring.GetUnitsInCylinder(hx, hz, 200, unitTeam)) do
				local neardefID = Spring.GetUnitDefID(nearunitID)
				if unitDefCanWearHats[neardefID] then
					if DEBUG then
						Spring.Echo("Found a wearer", nearunitID, hatID, unitDefID, unitTeam)
					end

					local pieceMap = Spring.GetUnitPieceMap(nearunitID)
					local hatPoint = nil
					for pieceName, pieceNum in pairs(pieceMap) do
						if CosmeticUnitDefIDToPiece[unitDefID] and pieceName:find(CosmeticUnitDefIDToPiece[unitDefID], nil, true) then
							hatPoint = pieceNum
							break
						end
					end

					if DEBUG then
						Spring.Echo("Found a point", nearunitID, hatPoint)
					end

					--Spring.MoveCtrl.Enable(unitID)
					if hatPoint then
						Spring.UnitAttach(nearunitID, hatID, hatPoint)
					end
					Spring.SetUnitNoDraw(hatID, false)
					Spring.SetUnitNoSelect(hatID, true)
					--Spring.MoveCtrl.Disable(unitID)
					--Spring.SetUnitLoadingTransport(unitID, nearunitID)
					unitsWearingHats[nearunitID] = hatID
					Hats[hatID] = nearunitID
					UpdateGameFrameCallIn()
					return
				end
			end
		end
		if DEBUG then
			Spring.Echo("Hat was given, but found noone to put it onto, destroying", hatID)
		end
		Spring.DestroyUnit(hatID)
	end
end

-- also damage the hat
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitsWearingHats[unitID] then
		local health, maxHealth = spGetUnitHealth(unitID)
		local hatHealth, hatMaxHealth = spGetUnitHealth(unitsWearingHats[unitID])
		if hatHealth and health and maxHealth and hatMaxHealth then
			Spring.SetUnitHealth(unitsWearingHats[unitID], (health / maxHealth) * hatMaxHealth)
		end
	end
end

-- also cloak hat
function gadget:UnitCloaked(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		Spring.SetUnitCloak(unitsWearingHats[unitID], 1)
	end
end

function gadget:UnitDecloaked(unitID, unitDefID, unitTeam)
	if unitsWearingHats[unitID] then
		Spring.SetUnitCloak(unitsWearingHats[unitID], 0)
	end
end
