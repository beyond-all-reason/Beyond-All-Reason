local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Feature ETA Widget Forwarding",
		desc = "Notifies widgets that a feature reclaim or resurrect action has begun",
		author = "Saul Goodman, copied from Beherith", -- ty Sprung
		date = "March 2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	local SendToUnsynced = SendToUnsynced
	local spGetGameFrame = SpringShared.GetGameFrame
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
		if updateCounter > 1 then
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
		for _, allyTeamID in ipairs(SpringShared.GetAllyTeamList()) do
			for _, teamID in ipairs(SpringShared.GetTeamList(allyTeamID)) do
				teamToAllyTeam[teamID] = allyTeamID
			end
		end
	end
else
	local myPlayerID = Spring.GetMyPlayerID()
	local myAllyTeamID = Spring.GetMyAllyTeamID()
	local _, fullview = SpringUnsynced.GetSpectatingState()

	--Map of allyTeamID to set of featureIDs. Used to resend ETAs when player changes ally team
	local featureETATeamCache = {}

	function gadget:PlayerChanged(playerID)
		if playerID == myPlayerID then
			myAllyTeamID = Spring.GetMyAllyTeamID()
			_, fullview = SpringUnsynced.GetSpectatingState()

			--Resend feature ETAs when team changes so that we can see active ETAs of new team and stop seeing ETAs of old team
			local myAllyTeamCache = featureETATeamCache[myAllyTeamID]
			for _, featureIDs in pairs(featureETATeamCache) do
				for featureID, _ in pairs(featureIDs) do
					local step = (fullview or myAllyTeamCache[featureID]) and 0.001 or 0
					Script.LuaUI.FeatureReclaimStartedETA(featureID, step)
				end
			end
		end
	end

	local function etaFeatureReclaimStartFrame(cmd, featureID, allyTeamID, step)
		if (fullview or allyTeamID == myAllyTeamID) and Script.LuaUI("FeatureReclaimStartedETA") then
			Script.LuaUI.FeatureReclaimStartedETA(featureID, step)
		end
		featureETATeamCache[allyTeamID][featureID] = step ~= 0 and true or nil
	end

	function gadget:Initialize()
		for _, allyTeamID in ipairs(SpringShared.GetAllyTeamList()) do
			featureETATeamCache[allyTeamID] = {}
		end
		gadgetHandler:AddSyncAction("etaFeatureReclaimStartFrame", etaFeatureReclaimStartFrame)
	end

	function gadget:ShutDown()
		gadgetHandler:RemoveSyncAction("etaFeatureReclaimStartFrame")
	end
end
