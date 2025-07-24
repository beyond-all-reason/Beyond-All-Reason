

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "AI namer",
		desc	= "Assignes names to AI teams",
		author	= "Floris",
		date	= "May 2018",
		license = "GNU GPL, v2 or later",
		layer	= 999,
		enabled = true,
	}
end



if gadgetHandler:IsSyncedCode() then
	local cachedGameID
	-- gameID seems to be the only fucking thing that is truly random in this space? but it's a random garbage of numbers and letters, and we need to filter it out
	function gadget:GameID(gameID) 
		-- make sure gameID is a string because i'm not actually sure
		cachedGameID = tostring(gameID)

		-- Initialise this madness
		local FakeRandomSeed = ""
		-- because yes
		for i = 1,1000 do
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

		-- Voilà, now it's actually random! Somehow.
		-- Feel free to refactor this with less insanity.

		local DonatorAINames 			= VFS.Include("luarules/configs/ai_namer/donators.lua")
		local ContributorAINames 		= VFS.Include("luarules/configs/ai_namer/contributors.lua")
		local RandomAINames 			= VFS.Include("luarules/configs/ai_namer/random.lua")
		local ArmadaAINames 			= VFS.Include("luarules/configs/ai_namer/armada.lua")
		local CortexAINames 			= VFS.Include("luarules/configs/ai_namer/cortex.lua")
		local LegionAINames 			= VFS.Include("luarules/configs/ai_namer/legion.lua")
		local RaptorAINames 			= {'Raptors'}
		local ScavengerAINames 			= {'Scavengers'}

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
			local confirmedAIName
			repeat
				--if math.random(0, FakeRandomSeed) < FakeRandomSeed*0.001 then
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
					if takenNames[aiName] == nil then
						takenNames[aiName] = teamID
						confirmedAIName = aiName
					end
				--end
			until confirmedAIName ~= nil
			return confirmedAIName
		end

		--function gadget:Initialize()
			local t = Spring.GetTeamList()
			for _,teamID in ipairs(t) do
				if select(4,Spring.GetTeamInfo(teamID,false)) then	-- is AI?
					Spring.SetGameRulesParam('ainame_'..teamID, getName(teamID, string.find(Spring.GetTeamLuaAI(teamID) or '', "Raptors"), string.find(Spring.GetTeamLuaAI(teamID) or '', "Scavenger")))
				end
			end
			gadgetHandler:RemoveGadget(self)
		--end
	end
end
