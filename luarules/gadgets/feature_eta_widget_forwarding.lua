local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Feature ETA Widget Forwarding",
		desc		= "Notifies widgets that a feature reclaim or resurrect action has begun",
		author		= "Saul Goodman, copied from Beherith", -- ty Sprung
		date		= "March 2026",
		license	 	= "GNU GPL, v2 or later",
		layer		= -1,
		enabled		= true
	}
end


if gadgetHandler:IsSyncedCode() then

	local SendToUnsynced = SendToUnsynced
	local spGetGameFrame = Spring.GetGameFrame
	local fps = Game.gameSpeed
	local dayFrames = fps * 24 * 60 * 60
	local noProgressTimeout = 5 * fps -- ETAs will disappear after this many frames without progress
	-- Cached teamID to its allyTeamID
	local teamToAllyTeam = {}
	
	-- Map of featureID to map of allyTeamID to frame of last build step
	local forwardedFeatures = {} -- so we only forward the start event once
	-- Map of featureID to most recent build step frame for any ally team
	local featureLastStepTime = {} -- used to remove ETA's for ally teams that are no longer working on a feature
	
	function gadget:AllowFeatureBuildStep(builderID, builderTeamID, featureID, featureDefID, step)
		
		local currentDayFrames, days = spGetGameFrame()
		local currentFrame = currentDayFrames + (days * dayFrames)
		local builderAllyTeamID = teamToAllyTeam[builderTeamID]
		
		local lastStepFrames = forwardedFeatures[featureID]
		if lastStepFrames == nil then
			lastStepFrames = {}
			forwardedFeatures[featureID] = lastStepFrames
		end
		
		if lastStepFrames[builderAllyTeamID] == nil then
			SendToUnsynced("etaFeatureReclaimStartFrame", featureID, builderAllyTeamID, step)
		end
		lastStepFrames[builderAllyTeamID] = currentFrame
		featureLastStepTime[featureID] = currentFrame
		
		return true
	end
	
	local updateInterval = 6
	local updateCounter = updateInterval
	function gadget:GameFrame(frame)
		if updateCounter > 0 then
			updateCounter = updateCounter - 1
			return
		end
		updateCounter = updateInterval
		
		--Check if there are any ally teams that are no longer reclaiming or resurrecting a feature and
		--send a stop signal
		--There may be two ally teams reclaiming the same feature and we want to remove the ETA when an
		--ally team stops reclaiming
		for featureID, allyTeamFrames in pairs(forwardedFeatures) do
			local mostRecentStepFrame = featureLastStepTime[featureID]
			local stopAllETAs = frame - mostRecentStepFrame >= noProgressTimeout --No progress for any team => remove ETA for all teams
			for allyTeamID, lastStepFrame in pairs(allyTeamFrames) do
				if stopAllETAs or lastStepFrame < mostRecentStepFrame then
					SendToUnsynced("etaFeatureReclaimStartFrame", featureID, allyTeamID, 0)
					allyTeamFrames[allyTeamID] = nil
				end
			end
		end
		
	end

	function gadget:FeatureDestroyed(featureID, allyTeamID)
		forwardedFeatures[featureID] = nil
	end

	function gadget:Initialize()
		for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
			for _, teamID in ipairs(Spring.GetTeamList(allyTeamID)) do
				teamToAllyTeam[teamID] = allyTeamID
			end
		end
	end

else
	
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local _, fullview = Spring.GetSpectatingState()

	function gadget:PlayerChanged(playerID)
		myAllyTeamID = Spring.GetMyAllyTeamID()
		_, fullview = Spring.GetSpectatingState()
	end

	local function etaFeatureReclaimStartFrame(cmd, featureID, allyTeamID, step)
		if (fullview or allyTeamID == myAllyTeamID) and Script.LuaUI("FeatureReclaimStartedETA") then
			Script.LuaUI.FeatureReclaimStartedETA(featureID, step)
		end
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("etaFeatureReclaimStartFrame", etaFeatureReclaimStartFrame)
	end

	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("etaFeatureReclaimStartFrame")
	end
end
