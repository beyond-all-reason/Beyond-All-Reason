local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Shard AI Loader",
		desc = "Shard by AF for Spring Lua",
		author = "eronoobos, based on gadget by raaar, and original AI by AF",
		date = "April 2020",
		license = "GPL",
		layer = 999999,
		enabled = true,
	}
end

local teamList = Spring.GetTeamList()
for i = 1, #teamList do
	local luaAI = Spring.GetTeamLuaAI(teamList[i])
	if luaAI ~= "" then
		if type(luaAI) == "string" and (VFS.FileExists("luarules/gadgets/ai/" .. luaAI .. "/boot.lua")) then
			shardEnabled = true
		end
	end
end

if not shardEnabled then
	Spring.Echo("[AI Loader] ShardLua bot Deactivated!")
	return false
end

Spring.Echo("[AI Loader] ShardLua bot Activated!")

-- globals
ShardSpringLua = true

-- this is the AI Boot gadget, so we're in Spring Lua
VFS.Include("luarules/gadgets/ai/shard_runtime/spring_lua/boot.lua")

-- Shard object
Shard = VFS.Include("luarules/gadgets/ai/shard_runtime/spring_lua/shard.lua")
Shard.AIs = {}
Shard.AIsByTeamID = {}

-- fake os object
--os = shard_include("spring_lua/fakeos")

-- missing math function
--function math.mod(number1, number2)
--	return number1 % number2
--end
--math.fmod = math.mod

-- localization
local spEcho = Spring.Echo
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetGaiaTeamID = Spring.GetGaiaTeamID()


if gadgetHandler:IsSyncedCode() then

	function gadget:Initialize()
		--GG.AiHelpers.Start()
	end
	--[[	function gadget:RecvLuaMsg(msg, playerID)
		--msg = 'StGiveOrderToSync'..';'..id..';'..cmd..';'..pos..';'..opts..';'..timeout..';'..uname..';'.'StEndGOTS'
		

		local datas = string.split(msg,';')

		if datas[1] ~= 'StGiveOrderToSync' or datas[7] ~= 'StEndGOTS' then
			Spring.Echo('ST RECEIVEDGOTS INCOMPLETE GOTS ',#datas,msg)
			return
		end

		if #datas ~= 7 then
			Spring.Echo('ST RECEIVEDGOTS INCOMPLETE GOTS ',#datas,msg)
			return
		end

		local id = datas[2]
		if string.split(id,',') then
			id = string.split(id,',')
			Spring.Echo('id',id,#id,id[1],type(id[1]),datas[6])

		end
		for i = 1, #id do
			id[i] = tonumber(id[i])
			if not Spring.ValidUnitID(id[i]) then
				spEcho('order error in STAI unsync to sync: unitID is invalid')
				table.remove(id,i)
			end
		end
		if #id == 0 then
			spEcho('order error in STAI unsync to sync: no valid ids')
			return
		end
		local cmd = datas[3]
		local pos = datas[4]
		local opts = datas[5]
		--local timeout = datas[6]
		local unit = datas[6]

		pos = string.split(pos,',')
		if not pos or not pos[1] or pos[1] == '' then
			Spring.Echo(pos)
			spEcho('warn! invalid POS argument in STAI gotu luarules message')
			return
		end
		if opts ~= 0 then
			opts = string.split(opts,',')
			if not opts or not opts[1] or opts[1] == '' then
				Spring.Echo(opts)
				spEcho('warn! invalid OPTS argument in STAI gotu luarules message')
				return
			end
		end
-- 		Spring.Echo('GOTS ORDER ISSUES',id,cmd,pos,opts)
		
		--Spring.GiveOrderToUnitArray ( table unitArray = { [1] = number unitID, etc... }, number cmdID, table params = {number, etc...}, table options = {"alt", "ctrl", "shift", "right"} )
		--return: nil | bool true
		--local order = Spring.GiveOrderToUnit(id,cmd,pos,opts)
		local order = Spring.GiveOrderToUnitArray(id,cmd,pos,opts)
		if not order  then
			spEcho('order error in STAI unsync to sync give order to unit',msg)
			spEcho('order', order,id,cmd,pos,opts,unit)
-- 		else
-- 			spEcho('STAI give order to unit OK')
		end
	end
]]--
	function gadget:RecvLuaMsg(msg, playerID)
		--msg = 'StGiveOrderToSync'..';'..id..';'..cmd..';'..pos..';'..opts..';'..timeout..';'..uname..';'.'StEndGOTS'
		if string.sub(msg,1,17) ~= 'StGiveOrderToSync' then
			return
		end
		local datas = string.split(msg,';')

		if datas[1] ~= 'StGiveOrderToSync' or datas[7] ~= 'StEndGOTS' then
			Spring.Echo('ST RECEIVEDGOTS INCOMPLETE GOTS ',#datas,msg)
			return
		end

		if #datas ~= 7 then
			Spring.Echo('ST RECEIVEDGOTS INCOMPLETE GOTS ',#datas,msg)
			return
		end

		local id = datas[2]
		local cmd = datas[3]
		local pos = datas[4]
		local opts = datas[5]
		--local timeout = datas[6]
		local unit = datas[6]

		pos = string.split(pos,',')
		if not pos or not pos[1] or pos[1] == '' then
			Spring.Echo(pos)
			spEcho('warn! invalid POS argument in STAI gotu luarules message')
			return
		end
		if opts ~= 0 then
			opts = string.split(opts,',')
			if not opts or not opts[1] or opts[1] == '' then
				Spring.Echo(opts)
				spEcho('warn! invalid OPTS argument in STAI gotu luarules message')
				return
			end
		end
-- 		Spring.Echo('GOTS ORDER ISSUES',id,cmd,pos,opts)
		if Spring.ValidUnitID(id) then
			local order = Spring.GiveOrderToUnit(id,cmd,pos,opts)
			if order ~= true then
				spEcho('order error in STAI unsync to sync give order to unit',msg)
				spEcho('order', order,id,cmd,pos,opts)
	-- 		else
	-- 			spEcho('STAI give order to unit OK')
			end
		else
			spEcho('order error in STAI unsync to sync: unitID is invalid')
		end
	end


else	-- UNSYNCED CODE


	function gadget:Initialize()
		spEcho("Looking for AIs")
		for i = 1, #teamList do
			local id = teamList[i]
			local _, _, _, isAI, side, allyId = spGetTeamInfo(id, false)
			if isAI then
				local thisAI = self:SetupAI(id)
				if thisAI ~= nil then
					Shard.AIsByTeamID[id] = thisAI
					Shard.AIs[#Shard.AIs + 1] = thisAI
					thisAI.index = #Shard.AIs
				end
			end
		end
		-- catch up to started game
		if Spring.GetGameFrame() > 1 then
			self:GameStart()
			-- catch up to current units
			for _, uId in ipairs(spGetAllUnits()) do
				self:UnitCreated(uId, Spring.GetUnitDefID(uId), Spring.GetUnitTeam(uId))
				self:UnitFinished(uId, Spring.GetUnitDefID(uId), Spring.GetUnitTeam(uId))
			end
		end
		collectgarbage('collect')
	end

	function gadget:SetupAI(id)
		local aiInfo = spGetTeamLuaAI(id)
		if type(aiInfo) == "string" then
			spEcho("AI Player " .. id .. " is a " .. aiInfo)
		else
			return nil
		end
		if not VFS.FileExists("luarules/gadgets/ai/" .. aiInfo .. "/boot.lua") then
			spEcho("AI Player " .. id .. " is an unsupported AI type! (" .. aiInfo .. ")")
			return nil
		end

		shard_include = shard_generate_include_func(
			"luarules/gadgets/ai/shard_runtime",
			"luarules/gadgets/ai/" .. aiInfo
		)

		local thisAI = VFS.Include("luarules/gadgets/ai/" .. aiInfo .. "/boot.lua")
		thisAI.loaded = false
		thisAI.id = id
		local _, _, _, isAI, side, allyId = spGetTeamInfo(id, false)
		thisAI.allyId = allyId
		thisAI.fullname = aiInfo

		local alliedTeamIds = {}
		local enemyTeamIds = {}
		for i = 1, #teamList do
			if (spAreTeamsAllied(thisAI.id, teamList[i])) then
				alliedTeamIds[teamList[i]] = true
			else
				enemyTeamIds[teamList[i]] = true
			end
		end
		thisAI.api = VFS.Include("luarules/gadgets/ai/shard_runtime/api.lua")
		thisAI.api.shard_include = shard_include
		thisAI.alliedTeamIds = alliedTeamIds
		thisAI.enemyTeamIds = enemyTeamIds
		thisAI.ownUnitIds = thisAI.ownUnitIds or {}
		thisAI.friendlyUnitIds = thisAI.friendlyUnitIds or {}
		thisAI.alliedUnitIds = thisAI.alliedUnitIds or {}
		thisAI.enemyUnitIds = thisAI.enemyUnitIds or {}
		thisAI.neutralUnitIds = thisAI.neutralUnitIds or {}
		return thisAI
	end

	local basememlimit = 200000
	local pershardmemlimit = 50000
	local garbagelimit = basememlimit -- in kilobytes, will adjust upwards as needed
	local numShards = 0

	function gadget:GameStart()
		-- Initialise AIs
		for _, thisAI in ipairs(Shard.AIs) do
			local _, _, _, isAI, side = spGetTeamInfo(thisAI.id, false)
			thisAI.side = side
			local x, y, z = spGetTeamStartPosition(thisAI.id)
			thisAI.startPos = { x, y, z }
			thisAI:Prepare()
			--thisAI:Init()
			garbagelimit = math.min(1000000,garbagelimit + pershardmemlimit)
			Spring.Echo(string.format("AI %d (%s) using %d MB RAM, adjusting limit to %d MB", thisAI.id, thisAI.fullname, basememlimit/1000, garbagelimit/1000))
			numShards = numShards + 1

		end
	end

	function gadget:GameFrame(n)
		-- for each AI...

		for i, thisAI in ipairs(Shard.AIs) do
			--local RAM = gcinfo()
			-- update sets of unit ids : own, friendlies, enemies
			--1 run AI game frame update handlers
			thisAI:Prepare()
			thisAI:Update()

			if i == 1 and n % 121 == 0 then
				local ramuse = gcinfo()
				--Spring.Echo("STAI use",ramuse .. ' kb of RAM of ' .. garbagelimit, 'available' )
				if ramuse > garbagelimit then
					collectgarbage("collect")
					local notgarbagemem = gcinfo()
					local newgarbagelimit = math.min(1000000, notgarbagemem + basememlimit + pershardmemlimit * numShards) -- peak 1 GB
					Spring.Echo(string.format("%d STAIs using %d MB RAM > %d MB limit, performing garbage collection and adjusting limit to %d MB",
						numShards, math.floor(ramuse/1000), math.floor(garbagelimit/1000), math.floor(newgarbagelimit/1000) ) )
					garbagelimit = newgarbagelimit
				end
			end
			--RAM = gcinfo() - RAM
			--if RAM > 1000 then
			--	print ('AIloader',RAM/1000)
			--end
		end
	end

	function gadget:UnitCreated(unitId, unitDefId, teamId, builderId)
		-- for each AI...
		local unit = Shard:shardify_unit(unitId)
		for _, thisAI in ipairs(Shard.AIs) do
			if spGetUnitTeam(unitId) == thisAI.id then
				thisAI.ownUnitIds[unitId] = true
				thisAI.friendlyUnitIds[unitId] = true
			elseif thisAI.alliedTeamIds[spGetUnitTeam(unitId)] or spGetUnitTeam(unitId) == thisAI.id then
				thisAI.alliedUnitIds[unitId] = true
				thisAI.friendlyUnitIds[unitId] = true
			elseif spGetUnitAllyTeam(unitId) == spGetGaiaTeamID then
				thisAI.neutralUnitIds[unitId] = true
			else
				thisAI.enemyUnitIds[unitId] = true

			end

			if Spring.GetUnitTeam(unitId) == thisAI.id then
				thisAI:Prepare()
				thisAI:UnitCreated(unit, unitDefId, teamId, builderId)
			end
			-- thisAI:UnitCreated(unitId, unitDefId, teamId, builderId)
		end
	end

	function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
		-- for each AI...
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitDead(unit,unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)

				thisAI.ownUnitIds[unitId] = nil
				thisAI.friendlyUnitIds[unitId] = nil
				thisAI.alliedUnitIds[unitId] = nil
				thisAI.enemyUnitIds[unitId] = nil
				thisAI.neutralUnitIds[unitId] = nil
				-- thisAI:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
			end
-- 			Shard:unshardify_unit(self.engineUnit)
		end
	end

	function gadget:UnitDamaged(unitId, unitDefId, unitTeamId, damage, paralyzer, weaponDefId, projectileId, attackerId, attackerDefId, attackerTeamId)
		-- for each AI...
		local unit = Shard:shardify_unit(unitId)
		if unit then
			local attackerUnit = Shard:shardify_unit(attackerId)
			local damageObj = Shard:shardify_damage(damage, weaponDefId, paralyzer)
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitDamaged(unit, attackerUnit, damageObj)
				-- thisAI:UnitDamaged(unitId, unitDefId, unitTeamId, attackerId, attackerDefId, attackerTeamId)
			end
		end
	end

	function gadget:UnitIdle(unitId, unitDefId, teamId)
		-- for each AI...
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitIdle(unit,unitDefId, teamId)
				-- thisAI:UnitIdle(unitId, unitDefId, teamId)
			end
		end
	end

	function gadget:UnitFinished(unitId, unitDefId, teamId)
		-- for each AI...
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				-- thisAI:UnitFinished(unitId, unitDefId, teamId)
				thisAI:Prepare()
				thisAI:UnitBuilt(unit,unitDefId,teamId)
			end
		end
	end

	function gadget:UnitTaken(unitId, unitDefId, teamId, newTeamId)
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				-- thisAI:UnitTaken(unitId, unitDefId, teamId, newTeamId)
				thisAI:UnitDead(unit, unitDefId, teamId, newTeamId)
			end
		end
	end

	function gadget:UnitGiven(unitId, unitDefId, teamId, oldTeamId)
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				-- thisAI:UnitCreated(unitId, unitDefId, teamId, oldTeamId)
				thisAI:UnitCreated(unit, unitDefId, teamId, oldTeamId)
			end
		end
	end

	function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
-- 		local RAM = gcinfo()
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
-- 		Spring.Echo('uelram',gcinfo()-RAM)
	end
	function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
-- 	local RAM = gcinfo()
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
-- 		Spring.Echo('ullram',gcinfo()-RAM)
	end
	function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
-- 	local RAM = gcinfo()
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
-- 		Spring.Echo('uerram',gcinfo()-RAM)
	end
	function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
-- 		local RAM = gcinfo()
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
-- 		Spring.Echo('ulrram',gcinfo()-RAM)
	end

-- 	function gadget:UnitMoved(a,b,c,d)
-- 		print('unit moved',a,b,c,d)
-- 	end

-- 	function gadget:UnitMoveFailed(a,b,c,d)
-- 		print('unit move failed',a,b,c,d)
-- 	end
	function gadget:FeatureDestroyed(featureID)
		Shard:unshardify_feature(featureID)
	end

	function gadget:GameID(gameID)
		if Shard then
			Shard.gameID = gameID
			local rseed = 0
			local unpacked = VFS.UnpackU8(gameID, 1, string.len(gameID))
			for i, part in ipairs(unpacked) do
				-- local mult = 256 ^ (#unpacked-i)
				-- rseed = rseed + (part*mult)
				rseed = rseed + part
			end
			-- Spring.Echo("randomseed", rseed)
			Shard.randomseed = rseed
		end
	end



	--UNSYNCED CODE
--else
	--[[
	local function sdAddRectangle(_, x1, z1, x2, z2, r, g, b, a, label, filled, teamID, channel)
		if (Script.LuaUI('ShardDrawAddRectangle')) then
			Script.LuaUI.ShardDrawAddRectangle(x1, z1, x2, z2, { r, g, b, a }, label, filled, teamID, channel)
		end
	end

	local function sdEraseRectangle(_, x1, z1, x2, z2, r, g, b, a, label, filled, teamID, channel)
		if (Script.LuaUI('ShardDrawEraseRectangle')) then
			Script.LuaUI.ShardDrawEraseRectangle(x1, z1, x2, z2, { r, g, b, a }, label, filled, teamID, channel)
		end
	end

	local function sdAddCircle(_, x, z, radius, r, g, b, a, label, filled, teamID, channel)
		if (Script.LuaUI('ShardDrawAddCircle')) then
			Script.LuaUI.ShardDrawAddCircle(x, z, radius, { r, g, b, a }, label, filled, teamID, channel)
		end
	end

	local function sdEraseCircle(_, x, z, radius, r, g, b, a, label, filled, teamID, channel)
		if (Script.LuaUI('ShardDrawEraseCircle')) then
			Script.LuaUI.ShardDrawEraseCircle(x, z, radius, { r, g, b, a }, label, filled, teamID, channel)
		end
	end

	local function sdAddLine(_, x1, z1, x2, z2, r, g, b, a, label, arrow, teamID, channel)
		if (Script.LuaUI('ShardDrawAddLine')) then
			Script.LuaUI.ShardDrawAddLine(x1, z1, x2, z2, { r, g, b, a }, label, arrow, teamID, channel)
		end
	end

	local function sdEraseLine(_, x1, z1, x2, z2, r, g, b, a, label, arrow, teamID, channel)
		if (Script.LuaUI('ShardDrawEraseLine')) then
			Script.LuaUI.ShardDrawEraseLine(x1, z1, x2, z2, { r, g, b, a }, label, arrow, teamID, channel)
		end
	end

	local function sdAddPoint(_, x, z, r, g, b, a, label, teamID, channel)
		if (Script.LuaUI('ShardDrawAddPoint')) then
			Script.LuaUI.ShardDrawAddPoint(x, z, { r, g, b, a }, label, teamID, channel)
		end
	end

	local function sdErasePoint(_, x, z, r, g, b, a, label, teamID, channel)
		if (Script.LuaUI('ShardDrawErasePoint')) then
			Script.LuaUI.ShardDrawErasePoint(x, z, { r, g, b, a }, label, teamID, channel)
		end
	end

	local function sdAddUnit(_, unitID, r, g, b, a, label, teamID, channel)
		if (Script.LuaUI('ShardDrawAddUnit')) then
			Script.LuaUI.ShardDrawAddUnit(unitID, { r, g, b, a }, label, teamID, channel)
		end
	end

	local function sdEraseUnit(_, unitID, r, g, b, a, label, teamID, channel)
		if (Script.LuaUI('ShardDrawEraseUnit')) then
			Script.LuaUI.ShardDrawEraseUnit(unitID, { r, g, b, a }, label, teamID, channel)
		end
	end

	local function sdClearShapes(_, teamID, channel)
		if (Script.LuaUI('ShardDrawClearShapes')) then
			Script.LuaUI.ShardDrawClearShapes(teamID, channel)
		end
	end

	local function sdDisplay(_, onOff)
		if (Script.LuaUI('ShardDrawDisplay')) then
			Script.LuaUI.ShardDrawDisplay(onOff)
		end
	end

	local function sStartTimer(_, name)
		if (Script.LuaUI('ShardStartTimer')) then
			Script.LuaUI.ShardStartTimer(name)
		end
	end

	local function sStopTimer(_, name)
		if (Script.LuaUI('ShardStopTimer')) then
			Script.LuaUI.ShardStopTimer(name)
		end
	end

	local function sSaveTable(_, tableinput, tablename, filename)
		if (Script.LuaUI('ShardSaveTable')) then
			Script.LuaUI.ShardSaveTable(tableinput, tablename, filename)
		end
	end]]

-- 	function gadget:stBuildingCommand(order)
-- 		print('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa')
-- 		print(order)
-- 		return order
-- -- 		if (Script.LuaUI('BuildingCommand')) then
-- -- 			Script.LuaUI.BuildingCommand(i,order)
-- -- 			print('stBuildingCommand',i,order)
-- -- 		end
--
--
-- 	end



--[[	function gadget:Initialize()
		Spring.Echo("Shard AI unsync gadget init")
		gadgetHandler:AddSyncAction("shard_debug_position", handleShardDebugPosEvent)
		gadgetHandler:AddSyncAction('ShardDrawAddRectangle', sdAddRectangle)
		gadgetHandler:AddSyncAction('ShardDrawEraseRectangle', sdEraseRectangle)
		gadgetHandler:AddSyncAction('ShardDrawAddCircle', sdAddCircle)
		gadgetHandler:AddSyncAction('ShardDrawEraseCircle', sdEraseCircle)
		gadgetHandler:AddSyncAction('ShardDrawAddLine', sdAddLine)
		gadgetHandler:AddSyncAction('ShardDrawEraseLine', sdEraseLine)
		gadgetHandler:AddSyncAction('ShardDrawAddPoint', sdAddPoint)
		gadgetHandler:AddSyncAction('ShardDrawErasePoint', sdErasePoint)
		gadgetHandler:AddSyncAction('ShardDrawAddUnit', sdAddUnit)
		gadgetHandler:AddSyncAction('ShardDrawEraseUnit', sdEraseUnit)
		gadgetHandler:AddSyncAction('ShardDrawClearShapes', sdClearShapes)
		gadgetHandler:AddSyncAction('ShardDrawDisplay', sdDisplay)
		gadgetHandler:AddSyncAction('ShardStartTimer', sStartTimer)
		gadgetHandler:AddSyncAction('ShardStopTimer', sStopTimer)
		gadgetHandler:AddSyncAction('ShardSaveTable', sSaveTable)
	end
]]

		--[[
		Spring.Echo("Shard AI unsync gadget init")
		gadgetHandler:AddSyncAction("BuildingCommand", stBuildingCommand)
		gadgetHandler:AddSyncAction("shard_debug_position", handleShardDebugPosEvent)
		gadgetHandler:AddSyncAction('ShardDrawAddRectangle', sdAddRectangle)
		gadgetHandler:AddSyncAction('ShardDrawEraseRectangle', sdEraseRectangle)
		gadgetHandler:AddSyncAction('ShardDrawAddCircle', sdAddCircle)
		gadgetHandler:AddSyncAction('ShardDrawEraseCircle', sdEraseCircle)
		gadgetHandler:AddSyncAction('ShardDrawAddLine', sdAddLine)
		gadgetHandler:AddSyncAction('ShardDrawEraseLine', sdEraseLine)
		gadgetHandler:AddSyncAction('ShardDrawAddPoint', sdAddPoint)
		gadgetHandler:AddSyncAction('ShardDrawErasePoint', sdErasePoint)
		gadgetHandler:AddSyncAction('ShardDrawAddUnit', sdAddUnit)
		gadgetHandler:AddSyncAction('ShardDrawEraseUnit', sdEraseUnit)
		gadgetHandler:AddSyncAction('ShardDrawClearShapes', sdClearShapes)
		gadgetHandler:AddSyncAction('ShardDrawDisplay', sdDisplay)
		gadgetHandler:AddSyncAction('ShardStartTimer', sStartTimer)
		gadgetHandler:AddSyncAction('ShardStopTimer', sStopTimer)
		gadgetHandler:AddSyncAction('ShardSaveTable', sSaveTable)]]
	function gadget:Shutdown()
		Spring.Echo("Shard AI unsync gadget shutdown")
		gadgetHandler:RemoveSyncAction("shard_debug_position")
	end

	function handleShardDebugPosEvent(_, x, z, col)
		if Script.LuaUI("shard_debug_position") then
			Script.LuaUI.shard_debug_position(x, z, col)
		end
	end

end
