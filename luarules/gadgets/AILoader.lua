function gadget:GetInfo()
	return {
		name = "Shard AI Loader",
		desc = "Shard by AF for Spring Lua",
		author = "eronoobos, based on gadget by raaar, and original AI by AF,maintained by Pandaro(bio)",
		date = "May 2025",
		license = "GPL",
		layer = 999999,
		enabled = true,
	}
end

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
local spGiveOrderTounit = Spring.GiveOrderToUnit
local spGiveOrderArrayTounit = Spring.GiveOrderArrayToUnit
local spGiveOrderTounitArray = Spring.GiveOrderToUnitArray
local spGiveOrderArrayTounitArray = Spring.GiveOrderArrayToUnitArray
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameFrame = Spring.GetGameFrame
local teamList = Spring.GetTeamList()
local syncTables = {}
local cmdCounter = {ii = 0 ,zi=0,iz=0,zz=0,old=0}



for i = 1, #teamList do
	local luaAI = spGetTeamLuaAI(teamList[i])
	if luaAI ~= "" then
		if type(luaAI) == "string" and (VFS.FileExists("luarules/gadgets/ai/" .. luaAI .. "/boot.lua")) then
			shardEnabled = true
		end
	end
end

if not shardEnabled then
	spEcho("[AI Loader] ShardLua bot Deactivated!")
	return false
end

spEcho("[AI Loader] ShardLua bot Activated!")

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


if gadgetHandler:IsSyncedCode() then

	function gadget:Initialize()
	end

	function gadget:RezTable()
			return table.remove(syncTables) or {}
	end


	-- Function to recursively process a table and discard everything that is not a table
	function gadget:KillTable(t)
		if not t or type(t) ~= 'table' then
			spEcho("incorrect type in SIT_TABLE",t)
			return
		end
		--spEcho("SIT_TABLE: Before clearing", t)
		for key, value in pairs(t) do
			if type(value) == 'table' then
				gadget:KillTable(value)
			end
			t[key] = nil
			if  next(t) == nil then
				table.insert(syncTables, t)
			end
		end
	end

	function gadget:ResetTable(t)
		if type(t) == 'table' then
			gadget:KillTable(t)
		end
		return gadget:RezTable()
	end

	local deserializedOrder = {}
	function gadget:DeserializeOrder(str)
		if not str then
			spEcho('Deserialize Order missing parameters')
			return
		end
		deserializedOrder = gadget:ResetTable(deserializedOrder)
		for s in string.gmatch(str, "([^&]+)") do
			local key, value = string.match(s, "(%w+):(.+)")
			if not value then spEcho('Deserialize Order missing value',s,key,value) return end
			if string.find(value,'|') or string.find(value,',') then
				deserializedOrder[key] = self:StringToTable(value)
			else
				deserializedOrder[key] = tonumber(value) or value
			end
		end
		--spEcho('sync order',order)
		return deserializedOrder
	end
	local StrToTbl = {}
	function gadget:StringToTable(str)
		StrToTbl = gadget:ResetTable()
		local i = 1
		if string.find(str,'|') then
			for s in string.gmatch(str, "([^|]+)") do

				StrToTbl[i] = gadget:RezTable()
				for value in string.gmatch(s, "([^,]+)") do
				table.insert(StrToTbl[i],tonumber(value) or value)
				end
				i = i + 1
			end
		else
			for value in string.gmatch(str, "([^,]+)") do
				table.insert(StrToTbl,tonumber(value) or value)
			end
		end
		--spEcho("Sync Deserialized:", t)
		return StrToTbl
	end

	function gadget:RecvLuaMsg(msg)

		if string.sub(msg,1,17) == 'StGiveOrderToSync' then
			spEcho('warn:  Shard  receive a old give order protocol',msg)
			cmdCounter.old = cmdCounter.old + 1
			return
		end
		if string.sub(msg,1,12) ~= '@Shard[STGO]' or string.sub(msg,-12,-1) ~= '[STGO]Shard@' then
			--spEcho('not a STAI Give Order ',string.sub(msg,1,10),string.sub(msg,-10,-1))
			return

		else
			msg = string.sub(msg,13,-13)
			local order = gadget:RezTable()
			order = gadget:DeserializeOrder(msg)
			if not order then
				spEcho('Deserialize Order failed')
				return
			end

			if order.method == '1-1' then
				--('Receiveluarulesmsg GiveOrder to:',UnitDefs[spGetUnitDefID ( order.id )].name,order.cmd)
				local cmd = spGiveOrderTounit(order.id,order.cmd,order.parameters,order.options)
				--spEcho(order.id,order.cmd,order.parameters,order.options,cmd)
				--spEcho('GiveOrderToUnit',order.id,UnitDefs[order.id].name,order.cmd,order.parameters,order.options)
				cmdCounter.ii = cmdCounter.ii + 1
				local cmdTag = order.cmd
				if cmdTag < 0 then
					cmdTag = 'BUILD'
				end

				cmdCounter[cmdTag]	= cmdCounter[cmdTag]  or 0
				cmdCounter[cmdTag] = cmdCounter[cmdTag] + 1
				if not cmd then
					spEcho('GiveOrderToUnit Error:',cmd)
				end
			elseif order.method == '2-1' then
				local arrayOfCmd = gadget:RezTable()
				for i in pairs(order.cmd) do
					arrayOfCmd[i] = gadget:RezTable()
					arrayOfCmd[i][1] = order.cmd[i]
					arrayOfCmd[i][2] = order.parameters[i]
					arrayOfCmd[i][3] = order.options[i]
				end
				local cmd = spGiveOrderArrayTounit(order.id,arrayOfCmd)
				cmdCounter.zi = cmdCounter.zi + 1
				if not cmd then
					spEcho('GiveOrderArrayTounit Error:',cmd)
				end
				gadget:KillTable(arrayOfCmd)
				gadget:KillTable(order)
			elseif order.method == '1-2' then
				--spEcho(type(order.id),type(order.cmd),type(order.parameters[1]),type(order.options))
				local cmd = spGiveOrderTounitArray(order.id,order.cmd,order.parameters,order.options)
				cmdCounter.iz = cmdCounter.iz + 1
				if not cmd then
					spEcho('GiveOrderToUnitArray Error:',cmd)
				end
			elseif order.method == '2-2' then
				local arrayOfCmd = gadget:RezTable()
				for i in pairs(order.cmd) do
					arrayOfCmd[i] = gadget:RezTable()
					arrayOfCmd[i][1] = order.cmd[i]
					arrayOfCmd[i][2] = order.parameters[i]
					arrayOfCmd[i][3] = order.options[i]
				end
				local cmd = spGiveOrderArrayTounitArray(order.id,arrayOfCmd,true)
				cmdCounter.zz = cmdCounter.zz + 1
				if not cmd then
					spEcho('GiveOrderArrayTounitArray Error:',cmd)
				end
				gadget:KillTable(arrayOfCmd)
				gadget:KillTable(order)
			else
				spEcho('Shard AI Loader: unknown method',order.method)
			end

		end
		--spEcho('cmdCounter','1-1',cmdCounter.ii,'2-1',cmdCounter.zi,'1-2',cmdCounter.iz,'2-2',cmdCounter.zz,'old',cmdCounter.old)
		--spEcho('cmdCounter',cmdCounter)
	end

	function gadget:Shutdown()
		spEcho("Shard AI sync gadget shutdown")
		spEcho('STAI commands issued:',cmdCounter)

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
		if spGetGameFrame() > 1 then
			self:GameStart()
			-- catch up to current units
			for _, uId in ipairs(spGetAllUnits()) do
				self:UnitCreated(uId, spGetUnitDefID(uId), spGetUnitTeam(uId))
				self:UnitFinished(uId, spGetUnitDefID(uId), spGetUnitTeam(uId))
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
	local memoryRecord = 0

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
			spEcho(string.format("AI %d (%s) using %d MB RAM, adjusting limit to %d MB", thisAI.id, thisAI.fullname, basememlimit/1000, garbagelimit/1000))
			numShards = numShards + 1

		end
	end
--local lastRamRead= 0
--local RAM
	function gadget:GameFrame(n)
		-- for each AI...

		for i, thisAI in ipairs(Shard.AIs) do
			-- update sets of unit ids : own, friendlies, enemies
			--1 run AI game frame update handlers
			thisAI:Prepare()
			thisAI:Update()

			if i == 1 and n % 121 == 0 then
				local ramuse = gcinfo()
				memoryRecord = math.max(memoryRecord,ramuse)
				--spEcho("STAI use",ramuse .. ' kb of RAM of ' .. garbagelimit, 'available' )
				if ramuse > garbagelimit then
					collectgarbage("collect")
					local notgarbagemem = gcinfo()
					local newgarbagelimit = math.min(1000000, notgarbagemem + basememlimit + pershardmemlimit * numShards) -- peak 1 GB
					spEcho(string.format("%d STAIs using %d MB RAM > %d MB limit, performing garbage collection and adjusting limit to %d MB",
						numShards, math.floor(ramuse/1000), math.floor(garbagelimit/1000), math.floor(newgarbagelimit/1000) ) )
					garbagelimit = newgarbagelimit
				end
			end

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
				thisAI:UnitCreated(unit, unitDefId, teamId, oldTeamId)
			end
		end
	end

	function gadget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
	end

	function gadget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
	end

	function gadget:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitEnteredRadar(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
	end

	function gadget:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
		local unit = Shard:shardify_unit(unitID)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				thisAI:UnitLeftRadar(unitID, unitTeam, allyTeam, unitDefID)
			end
		end
	end

-- 	function gadget:UnitMoved(a,b,c,d)
-- 		print('unit moved',a,b,c,d)
-- 	end

 	--function gadget:UnitMoveFailed(a,b,c,d)
 	--end
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
			-- spEcho("randomseed", rseed)
			Shard.randomseed = rseed
		end
	end

	function gadget:Shutdown()
		spEcho("Shard AI unsync gadget shutdown")
		spEcho('STAI memory record:',memoryRecord)
		gadgetHandler:RemoveSyncAction("shard_debug_position")
	end

	function handleShardDebugPosEvent(_, x, z, col)
		if Script.LuaUI("shard_debug_position") then
			Script.LuaUI.shard_debug_position(x, z, col)
		end
	end

	function gadget:DrawScreen()--usefull drawing function
		return
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
		spEcho("Shard AI unsync gadget init")
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
		spEcho("Shard AI unsync gadget init")
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

