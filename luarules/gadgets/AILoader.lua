function gadget:GetInfo()
   return {
      name = "ShardLua",
      desc = "Shard by AF for Spring Lua",
      author = "eronoobos, based on gadget by raaar, and original AI by AF",
      date = "April 2016",
      license = "GPL",
      layer = 999999,
      enabled = true,
   }
end

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "DAI" then
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

local teams = Spring.GetTeamList()

-- globals
ShardSpringLua = true -- this is the AI Boot gadget, so we're in Spring Lua
VFS.Include("luarules/gadgets/ai/boot.lua")

-- fake os object
--os = shard_include("spring_lua/fakeos")

-- missing math function
function math.mod(number1, number2)
	return number1 % number2
end
math.fmod = math.mod

-- Shard object
Shard = shard_include("spring_lua/shard")
Shard.AIs = {}
Shard.AIsByTeamID = {}
local AIs = Shard.AIs

-- fake api object
--api = shard_include("spring_lua/fakeapi")

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

local function prepareTheAI(thisAI)
	if not thisAI.modules then thisAI:Init() end
	ai = thisAI
	game = thisAI.game
	map = thisAI.map
end

--SYNCED CODE
if (gadgetHandler:IsSyncedCode()) then

function gadget:Initialize()
	GG.AiHelpers.Start()
	local numberOfmFAITeams = 0
	local teamList = spGetTeamList()
	spEcho( "k9: ailoader gadget go!")

	for i=1,#teamList do
		local id = teamList[i]
		local _,_,_,isAI,side,allyId = spGetTeamInfo(id)

		--spEcho("Player " .. teamList[i] .. " is " .. side .. " AI=" .. tostring(isAI))

		---- adding AI
		spEcho( "K9: Is AI?")
		if (isAI) then
			spEcho( "K9: IT IS AI")
			local aiInfo = spGetTeamLuaAI(id)
			if (type(aiInfo) == "string") and (string.sub(aiInfo,1,8) == "DAI") then
				numberOfmFAITeams = numberOfmFAITeams + 1
				spEcho("Moomin Player " .. teamList[i] .. " is " .. aiInfo)
				-- add AI object
				thisAI = ShardAI()
				thisAI.id = id
				thisAI.allyId = allyId
				-- thisAI:Init()
				AIs[#AIs+1] = thisAI
				Shard.AIsByTeamID[id] = thisAI
			else
				spEcho("Player " .. teamList[i] .. " is another type of lua AI!")
			end
		else
			spEcho( "K9: IS NOT AI!?")
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
		thisAI.ownUnitIds = thisAI.ownUnitIds or {}
        thisAI.friendlyUnitIds = thisAI.friendlyUnitIds or {}
        thisAI.alliedUnitIds = thisAI.alliedUnitIds or {}
        thisAI.enemyUnitIds = thisAI.enemyUnitIds or {}
	end

	-- catch up to started game
	if Spring.GetGameFrame() > 1 then
		self:GameStart()
		-- catch up to current units
		for _,uId in ipairs(spGetAllUnits()) do
			self:UnitCreated(uId, Spring.GetUnitDefID(uId), Spring.GetUnitTeam(uId))
			self:UnitFinished(uId, Spring.GetUnitDefID(uId), Spring.GetUnitTeam(uId))
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

	-- for each AI...
    for _,thisAI in ipairs(AIs) do

        -- update sets of unit ids : own, friendlies, enemies
		-- run AI game frame update handlers
		prepareTheAI(thisAI)
		thisAI:Update()
    end
end


function gadget:UnitCreated(unitId, unitDefId, teamId, builderId)
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
    for _,thisAI in ipairs(AIs) do
        if (spGetUnitTeam(unitId) == thisAI.id) then
        	thisAI.ownUnitIds[unitId] = true
        	thisAI.friendlyUnitIds[unitId] = true
        elseif (thisAI.alliedTeamIds[spGetUnitTeam(unitId)] or spGetUnitTeam(unitId) == thisAI.id) then
       		thisAI.alliedUnitIds[unitId] = true
       		thisAI.friendlyUnitIds[unitId] = true
       	else
        	thisAI.enemyUnitIds[unitId] = true
        end
		
    	if Spring.GetUnitTeam(unitId) == thisAI.id then
	    	prepareTheAI(thisAI)
	    	thisAI:UnitCreated(unit)
	    end
		-- thisAI:UnitCreated(unitId, unitDefId, teamId, builderId)
	end
end

function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
		for _,thisAI in ipairs(AIs) do
			prepareTheAI(thisAI)
			thisAI:UnitDead(unit)
		    thisAI.ownUnitIds[unitId] = nil
        	thisAI.friendlyUnitIds[unitId] = nil
		    thisAI.alliedUnitIds[unitId] = nil
		    thisAI.enemyUnitIds[unitId] = nil
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
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	thisAI:UnitDamaged(unit, attackerUnit, damageObj)
			-- thisAI:UnitDamaged(unitId, unitDefId, unitTeamId, attackerId, attackerDefId, attackerTeamId)
		end
	end
end

function gadget:UnitIdle(unitId, unitDefId, teamId)
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
	    	thisAI:UnitIdle(unit)
			-- thisAI:UnitIdle(unitId, unitDefId, teamId)
		end
	end
end


function gadget:UnitFinished(unitId, unitDefId, teamId)
	-- for each AI...
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
			-- thisAI:UnitFinished(unitId, unitDefId, teamId)
			prepareTheAI(thisAI)
			thisAI:UnitBuilt(unit)
		end
	end
end

function gadget:UnitTaken(unitId, unitDefId, teamId, newTeamId)
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
			-- thisAI:UnitTaken(unitId, unitDefId, teamId, newTeamId)
			thisAI:UnitDead(unit)
		end
	end
end

function gadget:UnitGiven(unitId, unitDefId, teamId, oldTeamId)
	local unit = Shard:shardify_unit(unitId)
	if unit then
	    for _,thisAI in ipairs(AIs) do
	    	prepareTheAI(thisAI)
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
else

	function gadget:Initialize()
		Spring.Echo("Shard AI unsync gadget init")
		gadgetHandler:AddSyncAction("shard_debug_position", handleShardDebugPosEvent)
	end

	function gadget:Shutdown()
		Spring.Echo("Shard AI unsync gadget shutdown")
		gadgetHandler:RemoveSyncAction("shard_debug_position")
	end

	function handleShardDebugPosEvent(_,x,z,col)
	--	Spring.Echo("handleShardDebugPosEvent 1")
		if Script.LuaUI("shard_debug_position") then
			Spring.Echo("handleShardDebugPosEvent 2")
			Script.LuaUI.shard_debug_position(x,z,col)
			Spring.Echo("handleShardDebugPosEvent 3")
		end
	end

end
