

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "AI namer",
		desc	= "Assignes names to AI teams",
		author	= "Floris",
		date	= "May 2018",
		license = "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end


if gadgetHandler:IsSyncedCode() then

	local DonatorAINames 			= VFS.Include("luarules/configs/ai_namer/donators.lua")
	local ContributorAINames 		= VFS.Include("luarules/configs/ai_namer/contributors.lua")
	local RandomAINames 			= VFS.Include("luarules/configs/ai_namer/random.lua")
	local ArmadaAINames 			= VFS.Include("luarules/configs/ai_namer/armada.lua")
	local CortexAINames 			= VFS.Include("luarules/configs/ai_namer/cortex.lua")
	local LegionAINames 			= VFS.Include("luarules/configs/ai_namer/legion.lua")
	local RaptorAINames 			= {'Raptors Hive Mind'}
	local ScavengerAINames 			= {'Scavengers Collective Consciousness'}

	-- Sorting Helper
	--[[
	Spring.Echo("--- Donator Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(DonatorAINames)
	for i = 1,#DonatorAINames do
		Spring.Echo(DonatorAINames[i])
	end

	Spring.Echo("--- Contributor Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(ContributorAINames)
	for i = 1,#ContributorAINames do
		Spring.Echo(ContributorAINames[i])
	end

	Spring.Echo("--- Random Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(RandomAINames)
	for i = 1,#RandomAINames do
		Spring.Echo(RandomAINames[i])
	end

	Spring.Echo("--- Armada Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(ArmadaAINames)
	for i = 1,#ArmadaAINames do
		Spring.Echo(ArmadaAINames[i])
	end

	Spring.Echo("--- Cortex Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(CortexAINames)
	for i = 1,#CortexAINames do
		Spring.Echo(CortexAINames[i])
	end

	Spring.Echo("--- Legion Names ---------------------------------------------------------------------------------------------------------------------")
	table.sort(LegionAINames)
	for i = 1,#LegionAINames do
		Spring.Echo(LegionAINames[i])
	end
	]]

	local takenNames = {}

	function getName(teamID, raptor, scavenger)
		local aiName
		if raptor then
			aiName = RaptorAINames[math.random(1,#RaptorAINames)]
		elseif scavenger then
			aiName = ScavengerAINames[math.random(1,#ScavengerAINames)]
		else
			if math.random() <= 0.9 then --90% chance to get a human name
				local humanrandom = math.random()
				if humanrandom <= 0.6 then 		-- 60.0% chance for donator name
					aiName = DonatorAINames[math.random(1,#DonatorAINames)]
				elseif humanrandom <= 0.95 then -- 35% chance for contributor name
					aiName = ContributorAINames[math.random(1,#ContributorAINames)]
				else							-- 5% chance for random AI name
					aiName = RandomAINames[math.random(1,#RandomAINames)]
				end
			else -- 10% chance to get generic unit name
				local factionrandom = math.random(1,3)
				if factionrandom == 1 then 		-- Armada
					aiName = ArmadaAINames[math.random(1,#ArmadaAINames)]
				elseif factionrandom == 2 then 	-- Cortex
					aiName = CortexAINames[math.random(1,#CortexAINames)]
				else 							-- Legion
					aiName = LegionAINames[math.random(1,#LegionAINames)]
				end
			end
		end
		if raptor then
			return aiName
		elseif scavenger then
			return aiName
		elseif takenNames[aiName] == nil then
			takenNames[aiName] = teamID
			return aiName
		else
			return getName(teamID, raptor, scavenger)
		end
	end

	function gadget:Initialize()
		local t = Spring.GetTeamList()
		for _,teamID in ipairs(t) do
			if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
				Spring.SetGameRulesParam('ainame_'..teamID, getName(teamID, string.find(Spring.GetTeamLuaAI(teamID) or '', "Raptors"), string.find(Spring.GetTeamLuaAI(teamID) or '', "Scavenger")))
			end
		end
		gadgetHandler:RemoveGadget(self)
	end
end
