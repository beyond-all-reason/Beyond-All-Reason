if BAR.Utilities.Gametype.IsSinglePlayer() then
	return
end

-- if (#Spring.GetTeamList())-1 <= 64 then
-- 	return
-- end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Undo Self Destruction Havoc",
		desc = "Restore selfdestructed units and the ones those killed (only availible to a select few playernames)",
		author = "Floris",
		date = "June 2017",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

-- usage: /luarules undo #teamid #maxSecondsAgo (#receivingteamid)

-- only works when being spectator and you werent a player before
-- only availible to a select few playernames

local cmdname = "undo"

local rememberGameframes = 9000 -- 9000 -> 5 minutes
local enableAlertEchos = false
local nullifyFriendlySelfdDgunDamage = false -- only used for big events

local mathFloor = math.floor

if gadgetHandler:IsSyncedCode() then
	local validation = string.randomString(2)
	_G.validationUndo = validation

	-- Cache prefix bytes: "un"(2) + validation(2) = 4 bytes
	local un1, un2 = string.byte("un", 1, 2) -- 117, 110
	local vb1, vb2 = string.byte(validation, 1, 2)

	local teamSelfdUnits = {}
	local selfdCmdUnits = {}
	local selfdBlastUnits = {}
	local sceduledRestoreHeightmap = {}
	local CMD_SELFD = CMD.SELFD
	local enemyNearbyCacheFrame = {}
	local enemyNearbyCacheValue = {}

	local function HasNoNearbyEnemyCached(unitID, gameFrame)
		if enemyNearbyCacheFrame[unitID] ~= gameFrame then
			enemyNearbyCacheFrame[unitID] = gameFrame
			enemyNearbyCacheValue[unitID] = Spring.GetUnitNearestEnemy(unitID, 1000) == nil
		end
		return enemyNearbyCacheValue[unitID]
	end

	local dgunDef = {}
	for weaponDefID, weaponDef in ipairs(WeaponDefs) do
		if weaponDef.type == "DGun" then
			dgunDef[weaponDefID] = true
		end
	end

	local safeguardedUnits = {}
	local selfDWeaponToUnit = {} -- Cache: weaponDefID -> unitDefID for selfd weapons
	for unitDefID, unitDef in pairs(UnitDefs) do
		local isProtected = false
		if unitDef.customParams then
			local techlevel = tonumber(unitDef.customParams.techlevel)
			if techlevel and techlevel > 1 then
				if unitDef.isBuilding or unitDef.metalMake > 0.5 or unitDef.energyMake > 5 or unitDef.energyUpkeep < 0 or unitDef.windGenerator > 0 or unitDef.customParams.solar or unitDef.tidalGenerator > 0 or unitDef.customParams.energyconv_capacity then
					isProtected = true
				end
			end
		end
		if not isProtected and unitDef.customParams and unitDef.customParams.energyconv_capacity then
			isProtected = true
		end
		if isProtected then
			safeguardedUnits[unitDefID] = true
		end
		if unitDef.selfDExplosion then
			local wDef = WeaponDefNames[unitDef.selfDExplosion]
			if wDef then
				selfDWeaponToUnit[wDef.id] = unitDefID
			end
		end
	end

	function gadget:GameFrame(gameFrame)
		-- cleanup periodically
		if gameFrame % 901 == 1 then
			local oldestGameFrame = gameFrame - rememberGameframes
			for teamID, units in pairs(teamSelfdUnits) do
				local cleanedUnits = {}
				for oldUnitID, params in pairs(units) do
					if params[1] > oldestGameFrame then
						cleanedUnits[oldUnitID] = params
					end
				end
				teamSelfdUnits[teamID] = cleanedUnits
			end
			local cleanedBlast = {}
			for unitID, gameframeVal in pairs(selfdBlastUnits) do
				if gameframeVal > gameFrame - 30 then
					cleanedBlast[unitID] = gameframeVal
				end
			end
			selfdBlastUnits = cleanedBlast
		end

		-- apply sceduled heightmap restoration
		local heightmapJobs = sceduledRestoreHeightmap[gameFrame]
		if heightmapJobs then
			for i = 1, #heightmapJobs do
				local params = heightmapJobs[i]
				Spring.RevertHeightMap(params[1], params[2], params[3], params[4], 1)
			end
			sceduledRestoreHeightmap[gameFrame] = nil
		end
	end

	local function restoreUnits(teamID, seconds, toTeamID, playerID)
		if not Spring.GetTeamInfo(toTeamID, false) then
			Spring.SendMessageToPlayer(playerID, "Invalid receiving teamID: " .. tostring(toTeamID))
			return
		end
		if teamSelfdUnits[teamID] == nil then
			Spring.SendMessageToPlayer(playerID, "There is no self destruct unit history for team " .. teamID)
			return
		end

		local curGameFrame = Spring.GetGameFrame()
		local oldestGameFrame = curGameFrame - (seconds * 30)
		local scheduleHeightmapFrame = curGameFrame + 15
		local numRestoredUnits = 0
		local leftovers = {}

		for oldUnitID, params in pairs(teamSelfdUnits[teamID]) do
			if params[1] > oldestGameFrame then
				local unitDef = UnitDefs[params[2]]
				local unitX, unitZ = params[4], params[6]

				-- destroy old unit wreckage if any
				if unitDef and unitDef.wreckName then
					local featureDef = FeatureDefNames[unitDef.wreckName]
					local wreckDefID = featureDef and featureDef.id
					if wreckDefID then
						local features = Spring.GetFeaturesInCylinder(mathFloor(unitX), mathFloor(unitZ), 70)
						for i = 1, #features do
							if Spring.GetFeatureDefID(features[i]) == wreckDefID then
								Spring.DestroyFeature(features[i], false)
								break
							end
						end
					end
				end

				local restoreTeamID = params[11] or toTeamID
				local unitID = Spring.CreateUnit(params[2], unitX, Spring.GetGroundHeight(unitX, unitZ), unitZ, params[7], restoreTeamID)
				if unitID ~= nil then
					Spring.SetUnitHealth(unitID, params[3])
					Spring.SetUnitDirection(unitID, params[8], params[9], params[10])
					numRestoredUnits = numRestoredUnits + 1

					if unitDef and unitDef.selfDExplosion then
						local wDef = WeaponDefNames[unitDef.selfDExplosion]
						if wDef then
							local radius = WeaponDefs[wDef.id].damageAreaOfEffect
							if radius then
								local jobs = sceduledRestoreHeightmap[scheduleHeightmapFrame]
								if not jobs then
									jobs = {}
									sceduledRestoreHeightmap[scheduleHeightmapFrame] = jobs
								end
								jobs[#jobs + 1] = { unitX - radius, unitZ - radius, unitX + radius, unitZ + radius }
							end
						end
					end
				else
					leftovers[oldUnitID] = params
				end
			else
				leftovers[oldUnitID] = params
			end
		end

		teamSelfdUnits[teamID] = leftovers
		Spring.SendMessageToPlayer(playerID, "Restored: " .. numRestoredUnits .. " units")
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if #msg < 4 then
			return
		end
		local b1, b2, b3, b4 = string.byte(msg, 1, 4)
		if b1 ~= un1 or b2 ~= un2 or b3 ~= vb1 or b4 ~= vb2 then
			return
		end
		local accountID = BAR.Utilities.GetAccountID(playerID)
		if _G.permissions.undo[accountID] then
			local params = string.split(msg, ":")
			restoreUnits(tonumber(params[2]), tonumber(params[3]), tonumber(params[4]), playerID)
			return true
		end
	end

	local function notify(message)
		if not enableAlertEchos then
			return
		end
		for _, playerID in ipairs(Spring.GetPlayerList()) do
			local accountID = BAR.Utilities.GetAccountID(playerID)
			if _G.permissions.undo[accountID] then
				Spring.SendMessageToPlayer(playerID, message)
			end
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
		if safeguardedUnits[unitDefID] and attackerTeam and Spring.AreTeamsAllied(unitTeam, attackerTeam) then
			local isDgun = dgunDef[weaponID]
			local isSelfD = selfDWeaponToUnit[weaponID]
			local hasNoEnemy = (not isDgun and not isSelfD) and HasNoNearbyEnemyCached(unitID, Spring.GetGameFrame())

			if isDgun or isSelfD or hasNoEnemy then
				if enableAlertEchos then
					local _, playerID, _, victimIsAi = Spring.GetTeamInfo(unitTeam, false)
					local victimName = Spring.GetPlayerInfo(playerID, false) or "---"
					if victimIsAi then
						local aiName = Spring.GetGameRulesParam("ainame_" .. unitTeam)
						if aiName then
							victimName = aiName .. " (AI)"
						end
					end

					local _, attackerPlayerID, _, attackerIsAi = Spring.GetTeamInfo(attackerTeam, false)
					local attackerName = Spring.GetPlayerInfo(attackerPlayerID, false) or "---"
					if attackerIsAi then
						local aiName = Spring.GetGameRulesParam("ainame_" .. attackerTeam)
						if aiName then
							attackerName = aiName .. " (AI)"
						end
					end

					local x, _, z = Spring.GetUnitPosition(unitID)
					local unitName = UnitDefs[unitDefID].name
					local atPosition = (x and z) and ("   (pos: " .. mathFloor(mathFloor(x / 100) * 100) .. ", " .. mathFloor(mathFloor(z / 100) * 100) .. ")") or ""

					if isDgun then
						if victimName == attackerName then
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to DGUN their own " .. unitName .. atPosition)
						else
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to DGUN " .. victimName .. "'s " .. unitName .. atPosition)
						end
					elseif isSelfD then
						if victimName == attackerName then
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to damage their own " .. unitName .. " (via a SELFD)" .. atPosition)
						else
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to damage " .. victimName .. "'s " .. unitName .. " (via a SELFD)" .. atPosition)
						end
					else
						if victimName == attackerName then
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to damage their own " .. unitName .. " without nearby enemy" .. atPosition)
						else
							notify("\255\255\100\100 -- ALERT --   " .. attackerName .. " tried to damage " .. victimName .. "'s " .. unitName .. " without nearby enemy" .. atPosition)
						end
					end
				end

				if nullifyFriendlySelfdDgunDamage then
					return 0, 0
				else
					return damage, 1
				end
			end
		end
		return damage, 1
	end

	-- log selfd units and all the deaths they caused
	function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID, weaponDefID)
		enemyNearbyCacheFrame[unitID] = nil
		enemyNearbyCacheValue[unitID] = nil

		local attackerWasSelfd = false
		if attackerID ~= nil then
			attackerWasSelfd = (selfdBlastUnits[attackerID] ~= nil) or ((selfdCmdUnits[attackerID] == true) and (weaponDefID ~= nil and selfDWeaponToUnit[weaponDefID] ~= nil))
		end

		if (attackerID == nil and selfdCmdUnits[unitID] == true) or attackerWasSelfd then -- attackerID == nil -> selfd/reclaim
			local ux, uy, uz = Spring.GetUnitPosition(unitID)
			local health, maxHealth = Spring.GetUnitHealth(unitID)
			local buildFacing = Spring.GetUnitBuildFacing(unitID)
			local dx, dy, dz = Spring.GetUnitDirection(unitID)
			local originalTeamID = teamID -- capture before potential overwrite below
			if attackerID ~= nil then
				teamID = attackerTeamID or Spring.GetUnitTeam(attackerID) or teamID
				health = maxHealth -- health only applicable to actual selfd units
			end
			selfdBlastUnits[unitID] = Spring.GetGameFrame()
			if teamSelfdUnits[teamID] == nil then
				teamSelfdUnits[teamID] = {}
			end
			teamSelfdUnits[teamID][unitID] = { Spring.GetGameFrame(), unitDefID, health, ux, uy, uz, buildFacing, dx, dy, dz, originalTeamID }
		end

		selfdCmdUnits[unitID] = nil
	end

	-- log selfd commands
	function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if cmdID == CMD_SELFD then
			if Spring.GetUnitSelfDTime(unitID) > 0 then
				selfdCmdUnits[unitID] = nil
			else
				selfdCmdUnits[unitID] = true
			end
		else
			-- check for queued selfd (to check if queue gets cancelled)
			-- only check if this unit was previously marked as selfD'ing
			if selfdCmdUnits[unitID] then
				local unitQueue = Spring.GetUnitCommands(unitID, 20)
				if unitQueue and #unitQueue > 0 then
					local foundSelfdCmd = false
					for i = 1, #unitQueue do
						if unitQueue[i].id == CMD_SELFD then
							foundSelfdCmd = true
							break
						end
					end
					if not foundSelfdCmd then
						selfdCmdUnits[unitID] = nil
					end
				else
					selfdCmdUnits[unitID] = nil
				end
			end
		end
	end
else -- UNSYNCED
	local validation = SYNCED.validationUndo

	function gadget:Initialize()
		gadgetHandler:AddChatAction(cmdname, Undo)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(cmdname)
	end

	function Undo(cmd, line, words, playerID)
		if words[1] ~= nil and words[2] ~= nil then
			local targetTeamID = words[1]
			if words[3] ~= nil then
				targetTeamID = words[3]
			end
			Spring.SendLuaRulesMsg("un" .. validation .. ":" .. words[1] .. ":" .. words[2] .. ":" .. targetTeamID)
		end
	end
end
