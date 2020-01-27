-- I have no fucking idea how to make this work plz help
function gadget:GameFrame(n)
	if n == 30 then
		-- get all AI versions
		aiList = VFS.DirList("luarules/gadgets/damgamai/", "")
		aiTeamIDs = {}
		aiVersion = {}
		local teams = Spring.GetTeamList()
		for i = 1,#teams do
			local luaAI = Spring.GetTeamLuaAI(teams[i])
			if luaAI and luaAI ~= "" and string.sub(luaAI, 1,8) == 'DamgamAI' then
				for o = 1, #aiList do
					if string.sub(luaAI, 9) == aiList[o] then
						Spring.Echo("Team "..i.. ":")
						Spring.Echo(aiList[o])
						table.insert(aiVersion, aiList[o])
						table.insert(aiTeamIDs, i)
					end
				end
			end
		end
	end
	
	
	
	if n == 90 then
		Spring.Echo("AIVersions:")
		for i = 1,#aiVersion do
			i = i-1
			Spring.Echo(aiVersion[i])
		end
		Spring.Echo("AITeams:")
		for i = 1,#aiTeamIDs do
			i = i-1
			Spring.Echo(aiTeamIDs[i])
		end
	end
end