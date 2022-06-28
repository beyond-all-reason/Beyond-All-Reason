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

local teams = Spring.GetTeamList()
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if (type(luaAI) == "string") and (VFS.FileExists("luarules/gadgets/ai/" .. luaAI .. "/boot.lua")) then
			shardEnabled = true
		end
	end
end

if shardEnabled == true then
	Spring.Echo("[AI Loader] ShardLua bot Activated!")
else
	Spring.Echo("[AI Loader] ShardLua bot Deactivated!")
	return false
end

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
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitNeutral = Spring.GetUnitNeutral
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetGaiaTeamID = Spring.GetGaiaTeamID()


--SYNCED CODE
if gadgetHandler:IsSyncedCode() then


	function gadget:Initialize()

		GG.AiHelpers.Start()
	end
function gadget:RecvLuaMsg(msg, playerID)

		if string.sub(msg,1,17) == 'StGiveOrderToSync' then
			local id = string.split(msg,"*")
			local cmd = string.split(msg,'_')
			local pos = string.split(msg,':')
			local opts = string.split(msg,';')
			local timeout = string.split(msg,'#')
			local unit = string.split(msg,'!')

			if #id ~= 3 or #cmd ~= 3 or #pos ~= 3 or #opts ~= 3 or #timeout ~= 3 or #unit ~= 3 then

				spEcho('format incomplete',unit,#id,#cmd,#pos,#opts,#timeout,#unit)
				spEcho('recvluamsg',msg)
				spEcho('splitting lenght',unit,#id,#cmd,#pos,#opts,#timeout,#unit)
				spEcho('GiveOrderToUnit : ')
				spEcho('unit',unit,type(unit))
				spEcho('id',id,type(id))
				spEcho('cmd',cmd,type(cmd))
				spEcho('pos',pos,type(pos))
				spEcho('opts',opts,type(opts))
				spEcho('timeout',timeout,type(timeout))
				Spring.Debug.TableEcho(pos)
				return
			end

			id = id[2]
			cmd = cmd[2]
			pos = pos[2]
			opts = opts[2]
			timeout = timeout[2]
			unit = unit[2]
			if not Spring.ValidUnitID ( id )  then
				Spring.Echo('ST RECEIVEDGOTS ID INVALID','name',unit,'id',id,'cmd',cmd)
				return
			end
			if string.split(pos,',') then
				pos = string.split(pos,',')
				if not pos[1] or pos[1] == '' then
					Spring.Debug.TableEcho(pos)
					spEcho('warn! invalid pos argument in STAI gotu luarules message')
					return
				end
			end
			if string.split(opts,',') then
				opts = string.split(opts,',')
				if not opts[1] or opts[1] == '' then
					Spring.Debug.TableEcho(pos)
					spEcho('warn! invalid opts argument in STAI gotu luarules message')
					return
				end
			end
			if type(timeout) ~= 'table' then--maybe this is not required
				timeout = {timeout}
			end
			if dbg then
				spEcho('recvluamsg',msg)
				spEcho('splitting lenght',unit,#id,#cmd,#pos,#opts,#timeout,#unit)
				spEcho('GiveOrderToUnit : ')
				spEcho('unit',unit,type(unit))
				spEcho('id',id,type(id))
				spEcho('cmd',cmd,type(cmd))
				spEcho('pos',pos,type(pos))
				spEcho('opts',opts,type(opts))
				spEcho('timeout',timeout,type(timeout))
				Spring.Debug.TableEcho(pos)
			end
			local order = Spring.GiveOrderToUnit(id,cmd,pos,opts,timeout)
			if order ~= true then
				spEcho('order error in STAI unsync to sync give order to unit',msg)
				spEcho('order', order,id,cmd,pos,opts,timeout)
			end
		end
	end
else

	-- UNSYNCED CODE
	function gadget:Initialize()
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
		local teamList = spGetTeamList()
		spEcho("Looking for AIs")

		for i = 1, #teamList do
			local id = teamList[i]
			local _, _, _, isAI, side, allyId = spGetTeamInfo(id, false)
			if isAI then
				local thisAI = self:SetupAI(id)
				if thisAI ~= nil then
					Shard.AIsByTeamID[id] = thisAI
					Shard.AIs[#Shard.AIs + 1] = thisAI
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

	end

	function gadget:SetupAI(id)
		local aiInfo = spGetTeamLuaAI(id)
		local teamList = spGetTeamList()
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

	function gadget:GameStart()
		-- Initialise AIs
		for _, thisAI in ipairs(Shard.AIs) do
			local _, _, _, isAI, side = spGetTeamInfo(thisAI.id, false)
			thisAI.side = side
			local x, y, z = spGetTeamStartPosition(thisAI.id)
			thisAI.startPos = { x, y, z }
			thisAI:Prepare()
			--thisAI:Init()
		end
	end

	function gadget:GameFrame(n)

		-- for each AI...

		for _, thisAI in ipairs(Shard.AIs) do
			-- update sets of unit ids : own, friendlies, enemies
			--1 run AI game frame update handlers
			thisAI:Prepare()
			thisAI:Update()
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
				--prepareTheAI(thisAI)
				thisAI:Prepare()
				thisAI.UnitCreated(thisAI, unit,builderId)
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
				thisAI:UnitDead(unit)

				thisAI.ownUnitIds[unitId] = nil
				thisAI.friendlyUnitIds[unitId] = nil
				thisAI.alliedUnitIds[unitId] = nil
				thisAI.enemyUnitIds[unitId] = nil
				thisAI.neutralUnitIds[unitId] = nil
				-- thisAI:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
			end
			Shard:unshardify_unit(self.engineUnit)
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
				thisAI:UnitIdle(unit)
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
				thisAI:UnitBuilt(unit)
			end
		end
	end

	function gadget:UnitTaken(unitId, unitDefId, teamId, newTeamId)
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				-- thisAI:UnitTaken(unitId, unitDefId, teamId, newTeamId)
				thisAI:UnitDead(unit)
			end
		end
	end

	function gadget:UnitGiven(unitId, unitDefId, teamId, oldTeamId)
		local unit = Shard:shardify_unit(unitId)
		if unit then
			for _, thisAI in ipairs(Shard.AIs) do
				thisAI:Prepare()
				-- thisAI:UnitCreated(unitId, unitDefId, teamId, oldTeamId)
				thisAI:UnitCreated(unit)
			end
		end
	end

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
