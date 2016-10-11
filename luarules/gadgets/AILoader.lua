function gadget:GetInfo()
   return {
      name = "ShardLua",
      desc = "Shard by AF for Spring Lua",
      author = "eronoobos, based on gadget by raaar, and original AI by AF",
      date = "April 2016",
      license = "whatever",
      layer = 999999,
      enabled = true,
   }
end

-- globals
ShardSpringLua = true -- this is the AI Boot gadget, so we're in Spring Lua
VFS.Include("luarules/gadgets/ai/preload/globals.lua")

-- fake os object
os = shard_include("spring_lua/fakeos")

-- missing math function
function math.mod(number1, number2)
	return number1 % number2
end
math.fmod = math.mod

shard_include("behaviourfactory")
shard_include("unit")
shard_include("module")
shard_include("modules")

-- Shard object
Shard = shard_include("spring_lua/shard")
Shard.AIs = {}
Shard.AIsByTeamID = {}
local AIs = Shard.AIs

-- fake api object
api = shard_include("spring_lua/fakeapi")

-- AI class
shard_include("ai")

-- localization
local mAbs = math.abs
local mSqrt = math.sqrt
local tRemove = table.remove
local spEcho = Spring.Echo
local spGetTeamList = Spring.GetTeamList
local spGetTeamInfo = Spring.GetTeamInfo
local spGetTeamLuaAI = Spring.GetTeamLuaAI
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamUnits = Spring.GetTeamUnits
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding

--SYNCED CODE
if (gadgetHandler:IsSyncedCode()) then

local activeCommands = {}

local function prepareTheAI(thisAI)
	if not thisAI.modules then thisAI:Init() end
	ai = thisAI
	game = thisAI.game
	map = thisAI.map
end

local function AddActiveCommand(unitID, cmdID, cmdParams)
	local frame = spGetGameFrame()
	local x, y, z = spGetUnitPosition(unitID)
	activeCommands[#activeCommands+1] = {
		unitID = unitID,
		cmdID = cmdID,
		cmdParams = cmdParams,
		frame = frame,
		nextCheck = frame + 200,
		lastX = x,
		lastY = y,
		lastZ = z,
	}
end

local function RemoveActiveCommands(unitID, cmdID, cmdParams)
	for i = #activeCommands, 1, -1 do
		local ac = activeCommands[i]
		if (not unitID or ac.unitID == unitID) and (not cmdID or ac.cmdID == cmdID) then
			local match = true
			if cmdParams then
				if #cmdParams == 3 then
					local x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]
					local ax, ay, az = ac.cmdParams[1], ac.cmdParams[2], ac.cmdParams[3]
					if not (x > ax - 16 and x < ax + 16 and z > az - 16 and z < az + 16) then
						match = false
					end
				else
					for ip = 1, #cmdParams do
						if cmdParams[ip] ~= ac.cmdParams[ip] then
							match = false
							break
						end
					end
				end
			end
			if match then
				-- Spring.Echo("removed active command", UnitDefs[Spring.GetUnitDefID(ac.unitID)].name, ac.unitID, ac.cmdID, ac.cmdParams[1], ac.cmdParams[2], ac.cmdParams[3])
				tRemove(activeCommands, i)
			end
		end
	end
end

function gadget:Initialize()

	local numberOfmFAITeams = 0
	local teamList = spGetTeamList()

	for i=1,#teamList do
		local id = teamList[i]
		local _,_,_,isAI,side,allyId = spGetTeamInfo(id)
        
		--spEcho("Player " .. teamList[i] .. " is " .. side .. " AI=" .. tostring(isAI))

		---- adding AI
		if (isAI) then
			local aiInfo = spGetTeamLuaAI(id)
			if (string.sub(aiInfo,1,8) == "ShardLua") then
				numberOfmFAITeams = numberOfmFAITeams + 1
				spEcho("Player " .. teamList[i] .. " is " .. aiInfo)
				-- add AI object
				thisAI = AI()
				thisAI.id = id
				thisAI.allyId = allyId
				-- thisAI:Init()
				AIs[#AIs+1] = thisAI
				Shard.AIsByTeamID[id] = thisAI
			else
				spEcho("Player " .. teamList[i] .. " is another type of lua AI! ")
			end
		end
	end

	-- add allied teams for each AI
	for _,thisAI in ipairs(AIs) do
		alliedTeamIds = {}
		enemyTeamIds = {}
		for i=1,#teamList do
			if (spAreTeamsAllied(thisAI.id,teamList[i])) then
				alliedTeamIds[teamList[i]] = true
			else
				enemyTeamIds[teamList[i]] = true
			end
		end
		-- spEcho("AI "..thisAI.id.." : allies="..#alliedTeamIds.." enemies="..#enemyTeamIds)
		thisAI.alliedTeamIds = alliedTeamIds
		thisAI.enemyTeamIds = enemyTeamIds
	end

	-- catch up to started game
	local frame = spGetGameFrame()
	if frame > 0 then
		self:GameStart()
		self:GameFrame(frame-1)
		-- catch up to current units
		for _,uID in ipairs(spGetAllUnits()) do
			self:UnitCreated(uID, Spring.GetUnitDefID(uID), Spring.GetUnitTeam(uID))
			self:UnitFinished(uID, Spring.GetUnitDefID(uID), Spring.GetUnitTeam(uID))
		end
	end
end

function gadget:GameStart() 
    -- Initialise AIs
    for _,thisAI in ipairs(AIs) do
        local _,_,_,isAI,side = spGetTeamInfo(thisAI.id)
		thisAI.side = side
		local x,y,z = spGetTeamStartPosition(thisAI.id)
		thisAI.startPos = {x,y,z}
		if not thisAI.modules then thisAI:Init() end
    end
end


function gadget:GameFrame(n)
	for i = #activeCommands, 1, -1 do
		local ac = activeCommands[i]
		if n == ac.nextCheck then
			if spGetUnitIsBuilding(ac.unitID) then
				-- if a constructor is nano-ing something, the move hasn't failed
				-- Spring.Echo("unit is building something", UnitDefs[spGetUnitDefID(ac.unitID)].name, ac.unitID)
				tRemove(activeCommands, i)
			else
				local x, y, z = spGetUnitPosition(ac.unitID)
				if x ~= nil then
					if (ac.lastX == x and ac.lastZ == z) or (mAbs(x-ac.lastX) + mAbs(z-ac.lastZ) < 10) then
						-- unit move failed
						tRemove(activeCommands, i)
						local unit = Shard:shardify_unit(ac.unitID)
						if unit then
							local unitTeam = spGetUnitTeam(ac.unitID)
						    for _,thisAI in ipairs(AIs) do
							    prepareTheAI(thisAI)
						    	if unitTeam == thisAI.id then
							    	thisAI:UnitMoveFailed(unit)
							    elseif thisAI.alliedTeamIds[unitTeam] then
							    	-- thisAI:AllyUnitMoveFailed()
							    else
							    	-- thisAI:EnemyUnitMoveFailed()
							    end
							end
						end
					else
						ac.lastX, ac.lastY, ac.lastZ = x, y, z
						ac.nextCheck = n + 200
					end
				end
			end
		end
	end

	-- for each AI...
    for _,thisAI in ipairs(AIs) do
        
        -- update sets of unit ids : own, friendlies, enemies
		thisAI.ownUnitIds = {}
        thisAI.friendlyUnitIds = {}
        thisAI.alliedUnitIds = {}
        thisAI.enemyUnitIds = {}

        for _,uID in ipairs(spGetAllUnits()) do
        	if (spGetUnitTeam(uID) == thisAI.id) then
        		thisAI.ownUnitIds[uID] = true
        		thisAI.friendlyUnitIds[uID] = true
        	elseif (thisAI.alliedTeamIds[spGetUnitTeam(uID)] or spGetUnitTeam(uID) == thisAI.id) then
        		thisAI.alliedUnitIds[uID] = true
        		thisAI.friendlyUnitIds[uID] = true
        	else
        		thisAI.enemyUnitIds[uID] = true
        	end
        end 
	
		-- run AI game frame update handlers
		prepareTheAI(thisAI)
		thisAI:Update()
    end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	local x, y, z = spGetUnitPosition(unitID)
	-- if builderID then
	-- 	Spring.Echo("unit created by", UnitDefs[Spring.GetUnitDefID(builderID)].name, builderID, -unitDefID, x, y, z)
	-- end
	RemoveActiveCommands(builderID, -unitDefID, {x, y, z})
	local udef = UnitDefs[unitDefID]
	-- for each AI...
	local unit = Shard:shardify_unit(unitID)
    for _,thisAI in ipairs(AIs) do
    	prepareTheAI(thisAI)
    	if teamID == thisAI.id then
    		thisAI:UnitCreated(unit)
    	elseif thisAI.alliedTeamIds[teamID] then
    		-- thisAI:AllyUnitCreated(unit)
    	else
    		-- thisAI:EnemyUnitCreated(unit)
    	end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeamID, attackerID, attackerDefID, attackerTeamID) 
	RemoveActiveCommands(unitID)
	-- for each AI...
	local unit = Shard:shardify_unit(unitID)
	if unit then
		local teamID = unitTeamID
		for _,thisAI in ipairs(AIs) do
			prepareTheAI(thisAI)
			if teamID == thisAI.id then
    			thisAI:UnitDead(unit)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitDead(unit)
	    	else
	    		-- thisAI:EnemyUnitDead(unit)
	    	end
		end
		Shard:unshardify_unit(self.engineUnit)
	end
end


function gadget:UnitDamaged(unitID, unitDefID, unitTeamID, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeamID)
	-- for each AI...
	local unit = Shard:shardify_unit(unitID)
	if unit then
		local teamID = unitTeamID
		local attackerUnit = Shard:shardify_unit(attackerID)
		local damageObj = Shard:shardify_damage(damage, weaponDefID, paralyzer, projectileID, attackerUnit)
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	if teamID == thisAI.id then
	    		thisAI:UnitDamaged(unit, attackerUnit, damageObj)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitDamaged(unit, attackerUnit, damageObj)
	    	else
	    		-- thisAI:EnemyUnitDamaged(unit, attackerUnit, damageObj)
	    	end
		end	
	end
end

function gadget:UnitIdle(unitID, unitDefID, teamID)
	RemoveActiveCommands(unitID)
	-- for each AI...
	local unit = Shard:shardify_unit(unitID)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	if teamID == thisAI.id then
    			thisAI:UnitIdle(unit)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitIdle(unit)
	    	else
	    		-- thisAI:EnemyUnitIdle(unit)
	    	end
		end
	end
end

function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not UnitDefs[unitDefID].isImmobile and (#cmdParams == 3 or #cmdParams == 4 or #cmdParams == 1) and (cmdID < 0 or cmdID == CMD.MOVE or cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or cmdID == CMD.GUARD) then
		-- Spring.Echo("got position command", UnitDefs[unitDefID].name, unitID, cmdID, cmdParams[1], cmdParams[2], cmdParams[3])
		local _, _, _, _, buildProgress = spGetUnitHealth(unitID)
		if buildProgress == 1 then
			local x, y, z
			if #cmdParams == 1 then
				x, y, z = spGetUnitPosition(cmdParams[1])
			else
				x, y, z = cmdParams[1], cmdParams[2], cmdParams[3]
			end
			local ux, uy, uz = spGetUnitPosition(unitID)
			if x and ux then
				local dx = x - ux
				local dz = z - uz
				local dist = mSqrt((ux*ux)+(uz*uz))
				if dist > (UnitDefs[unitDefID].buildDistance or 0) + 10 + (cmdParams[4] or 0) then
					RemoveActiveCommands(unitID)
					AddActiveCommand(unitID, cmdID, cmdParams)
				end
			end
		end
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not UnitDefs[unitDefID].isImmobile and (#cmdParams == 3 or #cmdParams == 4 or #cmdParams == 1) and (cmdID < 0 or cmdID == CMD.MOVE or cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or cmdID == CMD.GUARD) then
		-- Spring.Echo("position command done", UnitDefs[unitDefID].name, unitID, cmdID, cmdParams[1], cmdParams[2], cmdParams[3])
		RemoveActiveCommands(unitID, cmdID, cmdParams)
	end
end

function gadget:UnitFinished(unitID, unitDefID, teamID) 
	-- for each AI...
	local unit = Shard:shardify_unit(unitID)
	if unit then
	    for _,thisAI in ipairs(AIs) do
			-- thisAI:UnitFinished(unitID, unitDefID, teamID)
			prepareTheAI(thisAI)
			if teamID == thisAI.id then
    			thisAI:UnitBuilt(unit)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitBuilt(unit)
	    	else
	    		-- thisAI:EnemyUnitBuilt(unit)
	    	end
		end
	end
end

function gadget:UnitTaken(unitID, unitDefID, teamID, newTeamID) 
	local unit = Shard:shardify_unit(unitID)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	if teamID == thisAI.id then
    			thisAI:UnitDead(unit)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitDead(unit)
	    	else
	    		-- thisAI:EnemyUnitDead(unit)
	    	end
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, teamID, oldTeamId) 
	local unit = Shard:shardify_unit(unitID)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	if teamID == thisAI.id then
    			thisAI:UnitGiven(unit)
	    	elseif thisAI.alliedTeamIds[teamID] then
	    		-- thisAI:AllyUnitGiven(unit)
	    	else
	    		-- thisAI:EnemyUnitGiven(unit)
	    	end
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
else

local function sdAddRectangle(_, x1, z1, x2, z2, r, g, b, a, label, filled, teamID, channel)
	if (Script.LuaUI('ShardDrawAddRectangle')) then
		Script.LuaUI.ShardDrawAddRectangle(x1, z1, x2, z2, {r, g, b, a}, label, filled, teamID, channel)
	end
end

local function sdEraseRectangle(_, x1, z1, x2, z2, r, g, b, a, label, filled, teamID, channel)
	if (Script.LuaUI('ShardDrawEraseRectangle')) then
		Script.LuaUI.ShardDrawEraseRectangle(x1, z1, x2, z2, {r, g, b, a}, label, filled, teamID, channel)
	end
end

local function sdAddCircle(_, x, z, radius, r, g, b, a, label, filled, teamID, channel)
	if (Script.LuaUI('ShardDrawAddCircle')) then
		Script.LuaUI.ShardDrawAddCircle(x, z, radius, {r, g, b, a}, label, filled, teamID, channel)
	end
end

local function sdEraseCircle(_, x, z, radius, r, g, b, a, label, filled, teamID, channel)
	if (Script.LuaUI('ShardDrawEraseCircle')) then
		Script.LuaUI.ShardDrawEraseCircle(x, z, radius, {r, g, b, a}, label, filled, teamID, channel)
	end
end

local function sdAddLine(_, x1, z1, x2, z2, r, g, b, a, label, arrow, teamID, channel)
	if (Script.LuaUI('ShardDrawAddLine')) then
		Script.LuaUI.ShardDrawAddLine(x1, z1, x2, z2, {r, g, b, a}, label, arrow, teamID, channel)
	end
end

local function sdEraseLine(_, x1, z1, x2, z2, r, g, b, a, label, arrow, teamID, channel)
	if (Script.LuaUI('ShardDrawEraseLine')) then
		Script.LuaUI.ShardDrawEraseLine(x1, z1, x2, z2, {r, g, b, a}, label, arrow, teamID, channel)
	end
end

local function sdAddPoint(_, x, z, r, g, b, a, label, teamID, channel)
	if (Script.LuaUI('ShardDrawAddPoint')) then
		Script.LuaUI.ShardDrawAddPoint(x, z, {r, g, b, a}, label, teamID, channel)
	end
end

local function sdErasePoint(_, x, z, r, g, b, a, label, teamID, channel)
	if (Script.LuaUI('ShardDrawErasePoint')) then
		Script.LuaUI.ShardDrawErasePoint(x, z, {r, g, b, a}, label, teamID, channel)
	end
end

local function sdAddUnit(_, unitID, r, g, b, a, label, teamID, channel)
	if (Script.LuaUI('ShardDrawAddUnit')) then
		Script.LuaUI.ShardDrawAddUnit(unitID, {r, g, b, a}, label, teamID, channel)
	end
end

local function sdEraseUnit(_, unitID, r, g, b, a, label, teamID, channel)
	if (Script.LuaUI('ShardDrawEraseUnit')) then
		Script.LuaUI.ShardDrawEraseUnit(unitID, {r, g, b, a}, label, teamID, channel)
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

function gadget:Initialize()
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
end

end