

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Respawning",
		desc = "Prevents death and instead respawns elsewhere",
		author = "Xehrath",
		date = "2023-05-12",
		license = "None",
		layer = 49,
		enabled = true
	}
end

if gadgetHandler:IsSyncedCode() then

	local spCreateUnit            = Spring.CreateUnit
	local spDestroyUnit           = Spring.DestroyUnit
	local spGiveOrderToUnit       = Spring.GiveOrderToUnit
	local spSetUnitRulesParam     = Spring.SetUnitRulesParam
	local spGetUnitPosition       = Spring.GetUnitPosition
	local spGetUnitRulesParam = Spring.GetUnitRulesParam
	local spGetUnitHealth 		= Spring.GetUnitHealth
	local spGetUnitTeam 		= Spring.GetUnitTeam
	local spSetUnitHealth = Spring.SetUnitHealth
	local spGetGameSeconds = Spring.GetGameSeconds
	local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy

	local mcSetVelocity         = Spring.MoveCtrl.SetVelocity
	local mcSetPosition         = Spring.MoveCtrl.SetPosition

	local mapsizeX 				  = Game.mapSizeX
	local mapsizeZ 				  = Game.mapSizeZ

	local diag = math.diag


	local GAME_SPEED = Game.gameSpeed
	local TAU = 2 * math.pi
	local PRIVATE = { private = true }
	local CMD_WAIT = CMD.WAIT
	local EMPTY_TABLE = {}

	local respawnMetaList = {}
	local effigyMetaList = {}
	local defCustomParams = {}

	local TIMER_CHECK_FREQUENCY = 30 -- gameframes

	--messages[1] = textColor .. Spring.I18N('ui.raptors.wave1', {waveNumber = raptorEventArgs.waveCount})


	-- SethDGamre, values can be tuned in the unitdef file. Add the section below to the unitdef list in the unitdef file.
	--customparams = {
		--	-- Required:
		-- respawn_condition = "health",   sets the respawn condition. Health is the only option implemented
		
		
		--	-- Optional:
		-- effigy = "unit_name",						--Set this to spawn the effigy unit when the main unit is created.
		-- minimum_respawn_stun = 5,					--respawn stun duration, roughly in seconds. 
		-- distance_stun_multiplier = 1,				--respawn stun duration based on distance from respawn location when dying. (distance * distance_stun_multiplier) 
		-- respawn_pad = true,							--set this to true if you want the effigy to stay where it is when respawning. Use this if the effigy unit is a respawn pad or similar. 
		-- iseffigy = true,								--set this in the unitdef of the effigies that are buildable by the player.

		--	-- Has a default value, as indicated, if not chosen:
		-- respawn_health_threshold = 0,				--The health value when the unit will initiate the respawn sequence.
		-- destructive_respawn = true,					--If this is set to true, the effigy unit will be destroyed when the unit respawns. 


		-- },

	for id, def in pairs(UnitDefs) do
		if def.customParams.respawn_condition or def.customParams.iseffigy then
			defCustomParams[id] = def.customParams
		end
	end

    function ReturnToBase(unitID, friendlyFire)
		local x,y,z = spGetUnitPosition(unitID) -- usefull if you want to spawn explosions or other effects where you were.


		if respawnMetaList[unitID].effigyID then
			local health, maxHealth = spGetUnitHealth(unitID)
			local ex,ey,ez = spGetUnitPosition(respawnMetaList[unitID].effigyID)
			Spring.SetUnitPosition(unitID, ex, ez, true)
			Spring.SpawnCEG("commander-spawn", ex, ey, ez, 0, 0, 0)
			Spring.PlaySoundFile("commanderspawn-mono", 1.0, ex, ey, ez, 0, 0, 0, "sfx")
			GG.ComSpawnDefoliate(ex, ey, ez)

			if respawnMetaList[unitID].respawn_pad == "false" then
				Spring.SetUnitPosition(respawnMetaList[unitID].effigyID, x, z, true)
				Spring.SpawnCEG("commander-spawn", x, y, z, 0, 0, 0)
				Spring.PlaySoundFile("commanderspawn-mono", 1.0, x, y, z, 0, 0, 0, "sfx")
				GG.ComSpawnDefoliate(x, y, z)
			end

			if respawnMetaList[unitID].destructive_respawn then
			    if friendlyFire then
			        spDestroyUnit(respawnMetaList[unitID].effigyID, false, true)
			    else
				    spDestroyUnit(respawnMetaList[unitID].effigyID, false, false)
				end
				spSetUnitRulesParam(unitID, "unit_effigy", nil, PRIVATE)
				respawnMetaList[unitID].effigyID = nil
			end
			local stunDuration = maxHealth + ((maxHealth/30)*respawnMetaList[unitID].minimum_respawn_stun) + (((maxHealth/30)*diag((x-ex), (z-ez))*respawnMetaList[unitID].distance_stun_multiplier)/250)--250 is an arbitrary number that seems to produce desired results.
			spSetUnitHealth(unitID, {health = 1, capture = 0, paralyze = stunDuration,})
			spGiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		end
    end


	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		local udcp = defCustomParams[unitDefID]

		if not udcp then
			return
		end

		if udcp.respawn_condition then
			respawnMetaList[unitID] = {
				respawn_condition = udcp.respawn_condition or "none",
				respawn_health_threshold = tonumber(udcp.respawn_health_threshold) or 0,
				effigy = udcp.effigy or "none",
				effigy_offset = tonumber(udcp.effigy_offset) or 0,
				minimum_respawn_stun = tonumber(udcp.minimum_respawn_stun) or 0,
				distance_stun_multiplier = tonumber(udcp.distance_stun_multiplier) or 0,
				destructive_respawn = udcp.destructive_respawn or true,
				respawn_pad = udcp.respawn_pad or "false",
				respawnTimer = spGetGameSeconds(),
				effigyID = nil,
			}

			if respawnMetaList[unitID].effigy ~= "none" then
				local blockedIncrement = 1
				for i = 1, 500, blockedIncrement do
					local x, y, z = spGetUnitPosition(unitID)
					local blockType, blockID = Spring.GetGroundBlocked(x-i, z-i)
					local groundH = Spring.GetGroundHeight(x-i, z-i)
			
					if respawnMetaList[unitID].effigy_offset == 0 then
						local newUnitID = spCreateUnit(respawnMetaList[unitID].effigy, x, groundH, z, 0, unitTeam)
						spSetUnitRulesParam(unitID, "unit_effigy", newUnitID, PRIVATE)
						if newUnitID then
							respawnMetaList[unitID].effigyID = newUnitID
							return
						end
					elseif not blockType then
						local newUnitID = spCreateUnit(respawnMetaList[unitID].effigy, x-i, groundH, z-i, 0, unitTeam)
						spSetUnitRulesParam(unitID, "unit_effigy", newUnitID, PRIVATE)
						if newUnitID then
							respawnMetaList[unitID].effigyID = newUnitID
							return
						else 
							blockedIncrement = blockedIncrement+50
						end
					end
				end
			end
		end

		if udcp.iseffigy  and builderID then
			if respawnMetaList[builderID] then
				local oldeffigyID = respawnMetaList[builderID].effigyID
				respawnMetaList[builderID].effigyID = unitID
		
				if oldeffigyID then
					local oldEffigyBuildProgress = select(5, spGetUnitHealth(oldeffigyID))
					if oldEffigyBuildProgress == 1 then
						Spring.SetUnitCosts(unitID, {buildTime = 1, metalCost = 1, energyCost = 1})
					end
					spDestroyUnit(oldeffigyID, false, true)
				end
				spSetUnitRulesParam(builderID, "unit_effigy", unitID, PRIVATE)
			else
				for vipID, _ in pairs(respawnMetaList) do
					local team = spGetUnitTeam(vipID)
					if team == unitTeam then
				
						local oldeffigyID = respawnMetaList[vipID].effigyID
						
						respawnMetaList[vipID].effigyID = unitID
		
						if oldeffigyID then
							local oldEffigyBuildProgress = select(5, spGetUnitHealth(oldeffigyID))
							if oldEffigyBuildProgress == 1 then
								Spring.SetUnitCosts(unitID, {buildTime = 1, metalCost = 1, energyCost = 1})
							end
							spDestroyUnit(oldeffigyID, false, true)
						end
						spSetUnitRulesParam(builderID, "unit_effigy", unitID, PRIVATE)
						return
					end
				end
			end
		end
	end

	

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if respawnMetaList[unitID] then
			if respawnMetaList[unitID].respawn_pad == "false" then
				local newID = spGetUnitRulesParam(unitID, "unit_evolved")
                if newID then
					if respawnMetaList[newID].effigyID then
						if respawnMetaList[unitID].effigyID then
							local effigyBuildProgress = select(5, spGetUnitHealth(respawnMetaList[unitID].effigyID))
							if effigyBuildProgress ~= 1 then
								spDestroyUnit(respawnMetaList[newID].effigyID, false, true)
							end
						else
							spDestroyUnit(respawnMetaList[newID].effigyID, false, true)
						end
					end
					if respawnMetaList[unitID].effigyID then
						if respawnMetaList[newID] and respawnMetaList[newID].effigyID then
							local ex,ey,ez = spGetUnitPosition(respawnMetaList[unitID].effigyID)
							if ex then
								Spring.SetUnitPosition(respawnMetaList[newID].effigyID, ex, ez, true)
							else
								spDestroyUnit(respawnMetaList[newID].effigyID, false, true)
							end
							spDestroyUnit(respawnMetaList[unitID].effigyID, false, true)
						elseif respawnMetaList[newID] then
							respawnMetaList[newID].effigyID = respawnMetaList[unitID].effigyID
						else
							spDestroyUnit(respawnMetaList[unitID].effigyID, false, false)
						end
					end
				elseif respawnMetaList[unitID].effigyID then
					spDestroyUnit(respawnMetaList[unitID].effigyID, false, true)
				end
			end
			respawnMetaList[unitID] = nil
		end
	end
	
	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if respawnMetaList[unitID] then
			if respawnMetaList[unitID].respawn_condition == "health" then
				local h, mh = spGetUnitHealth(unitID)
				local currentTime =  spGetGameSeconds()
				if respawnMetaList[unitID].effigyID and (h-damage) <= respawnMetaList[unitID].respawn_health_threshold and (currentTime-respawnMetaList[unitID].respawnTimer) >= 5 then
					local effigyBuildProgress = select(5, spGetUnitHealth(respawnMetaList[unitID].effigyID))
					if effigyBuildProgress == 1 then
						if not attackerTeam then
							attackerTeam = unitTeam -- lava damage team = nil, so set to self team if nil
						end
					    local friendlyFire = Spring.AreTeamsAllied(unitTeam, attackerTeam)
					    local enemyNearby = spGetUnitNearestEnemy(unitID, 1000)
					    if friendlyFire and enemyNearby then
					        friendlyFire = false
					    end
						ReturnToBase(unitID, friendlyFire)
						respawnMetaList[unitID].respawnTimer = spGetGameSeconds()
						return 0, 0
					end
				elseif (currentTime-respawnMetaList[unitID].respawnTimer) <= 5 then
					return 0, 0
				end
			end
		end
	end
	


else


	local spSelectUnitArray = Spring.SelectUnitArray
	local spGetSelectedUnits = Spring.GetSelectedUnits
	local spGetGameSeconds = Spring.GetGameSeconds

	local announcementStart = 0
	local announcementEnabled = false
	local announcement = nil
	local announcementSize = 18.5

	local displayList

	local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
	local vsx, vsy = Spring.GetViewGeometry()
	local fontfileScale = (0.5 + (vsx * vsy / 6200000))
	local fontfileSize = 50
	local fontfileOutlineSize = 10
	local fontfileOutlineStrength = 1.4
	local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)


	local function Draw(newAnnouncement, newAnnouncementSize)
		vsx, vsy = Spring.GetViewGeometry()
		local uiScale = (0.7 + (vsx * vsy / 6500000))
		displayList = gl.CreateList(function()
			font:Begin()
			font:SetTextColor(1, 1, 1)
			font:Print(newAnnouncement, vsx * 0.5, vsy * 0.67, newAnnouncementSize * uiScale, "co")
			font:End()
		end)

		gl.CallList(displayList)
	end

	local function UnitRespawned(cmd, newAnnouncement, newAnnouncementSize)
		if newAnnouncement then
			announcement = newAnnouncement
			announcementSize = newAnnouncementSize
			announcementEnabled = true
			announcementStart = spGetGameSeconds()
		end
		--Spring.PlaySoundFile("commanderspawn", 0.6, 'ui')
	end

	function gadget:DrawScreen()
		if Spring.IsGUIHidden() then
			return
		end
		if announcementEnabled then
			local currentTime = spGetGameSeconds()
			if currentTime-announcementStart < 3 then
				Draw(announcement, announcementSize)
			else
				announcementEnabled = false
				announcement = nil
				announcementSize = 18.5
			end
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("unit_respawned", UnitRespawned)
		local w = 300
		local h = 210
		displayList = gl.CreateList(function()
			gl.Blending(true)
			gl.Color(1, 1, 1, 1)
			gl.Texture(1, "LuaUI/images/gradient_alpha_2.png")
			gl.TexRect(0, 0, w, h)
		end)

	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("unit_respawned")
		gl.DeleteList(displayList)
	end

end
