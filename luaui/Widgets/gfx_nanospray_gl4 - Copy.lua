--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Nanospray GL4",
		version = 3,
		desc = "Draws Dense Nano Spray",
		author = "Beherith",
		date = "2023.01.04",
		license = "Lua code is GPL V2, GLSL is (c) Beherith (mysterme@gmail.com)",
		layer = 9999,
		enabled = false
	}
end

-------------------------------- Notes, TODO ----------------------------------
-- Spawn 1000 geoshader billboards from a buffer of points filled with random
-- use startframe to start anim, and endframe to end anim

-- PROBLEMS:
-- GetUnitNanoPieces returns nil if unit is not building
	-- use 'hardcoded' nanopiecenames by scrounging through the cobs

-- When a piece is hidden, its matrix is zero'd out, so gotta workaround sustainy type effects
	--  use a different emit piece, one thats not hidden

-- Hard to query who what where when is building
	-- UnitCmdDone signifies completion (sometimes?)

-- Needs some unitform buffer shit to convey buildpower
-- Needs stop and start times added to it
-- If builder is not visible, then no nano spray produced (this is bad for LOS)

-- If target is mobile, and unit has to chase it, the script_buildstartstop doenst get called multiple times

-- See \luarules\gadgets\gfx_unit_script_buildstartstop.lua !!!!!!

-- Change all nano-lights to hide only after some time, to allow for the last particles to get there

--X Fall back to drawpos if matrix not present

-- Handle Team Changes

-- 'Detach' sprays?
--X direction
-- timing
-- strength
-- velocity adjust
--X a mobile target can only ever be a unitID!

-- Allow a texture to be defined

-- Build types
	-- construction
	-- repair
		-- mobile
		-- immobile
	-- reclaim
		-- feature
		-- unit
		-- mobile
		-- immobile
	-- resurrect
		-- feature
		-- unit
	-- capture
		-- mobile
		-- immobile
	-- restore
-- Area Commands?

----------------------------- Localize for optmization ------------------------------------

local glBlending = gl.Blending
local glTexture = gl.Texture


-- Strong:
local spGetGroundHeight = Spring.GetGroundHeight
local spIsSphereInView  = Spring.IsSphereInView
local spGetUnitPosition  = Spring.GetUnitPosition

<<<<<<< Updated upstream
local fadeout = 60
=======
<<<<<<< Updated upstream
local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()
=======
local fadeout = 60 
-- TODO: SUPER IMPORTANT: set the nanolight hide timeout to this as well for DLGl4 stuff lights in unitscripts!

>>>>>>> Stashed changes
>>>>>>> Stashed changes

local shaderConfig = {
	POINTCOUNT = 64,
	FADEOUT = fadeout,
}
local nanoParticleTexture = 'LuaUI/images/nanoparticle_gl4.tga'

local intensityMultiplier = 1.0
------------------------------ Debug switches ------------------------------
<<<<<<< Updated upstream
local autoupdate = true
<<<<<<< Updated upstream
=======

=======
local autoupdate = false
>>>>>>> Stashed changes
>>>>>>> Stashed changes
------------------------------ Data structures and management variables ------------

local nanoSprayVBO  -- for immobile targets
local nanoSprayMobileVBO  -- for mobile targets (pretty much repair + reclaim only)

local mobileSprays = {} -- table of instanceID to mobileUnitID

local nanoSprayShader

local sprayRemoveQueue = {} -- stores sprays that have expired life {gameframe = {lightIDs ... }}

local unitDefCanNanoSpray = {} -- maps unitDefID to wether a unit can ever spray nanos
local unitDefPeiceMapCache = {} -- maps unitDefID to piecemap

local nanoSprayCacheTable = {} -- this is a reusable table cache for saving memory later on
local unitAttachedNanoSprays = {}
local numSprays = 0
local numScriptEvents = 0

local autoSprayInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones

local gameFrame = 0

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local shaderSourceCache = {
	shaderName = 'Nanospray GL4',
	vssrcpath = "LuaUI/Widgets/Shaders/nanospray_gl4.vert.glsl",
	gssrcpath = "LuaUI/Widgets/Shaders/nanospray_gl4.geom.glsl",
	fssrcpath = "LuaUI/Widgets/Shaders/nanospray_gl4.frag.glsl",
	shaderConfig = shaderConfig,
	uniformInt = {
		nanoParticleTexture = 0,
		},
	uniformFloat = {
		nightFactor = 1.0,
		intensityMultiplier = 1.0,
	  },
}

local spec = Spring.GetSpectatingState()

---------------------- INITIALIZATION FUNCTIONS ----------------------------------

local function goodbye(reason)
	Spring.Echo('Nanospray GL4 exiting:', reason)
	widgetHandler:RemoveWidget()
end

local function createLightInstanceVBO(vboLayout, vertexVBO, numVertices, indexVBO, VBOname, unitIDattribID)
	local targetLightVBO = makeInstanceVBOTable( vboLayout, 16, VBOname, unitIDattribID)
	if vertexVBO == nil or targetLightVBO == nil then goodbye("Failed to make "..VBOname) end
	targetLightVBO.vertexVBO = vertexVBO
	targetLightVBO.numVertices = numVertices
	targetLightVBO.indexVBO = indexVBO
	targetLightVBO.VAO = makeVAOandAttach(targetLightVBO.vertexVBO, targetLightVBO.instanceVBO, targetLightVBO.indexVBO)
	return targetLightVBO
end

local function initGL4()
	nanoSprayShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0)
	if not nanoSprayShader then
		goodbye("Failed to compile nanoSprayShader GL4 shader")
		return false
	end
	-- init the VBO
	local vboLayout = {
			{id = 1, name = 'endworldposrad', size = 4}, -- target world pos and radius
			{id = 2, name = 'otherparams', size = 4}, -- startframe, endframe, count, direction
			{id = 3, name = 'pieceIndex', size = 1, type = GL.UNSIGNED_INT},
			{id = 4, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
	}

	local vertexVBO, numVertices  = makePointVBO(shaderConfig.POINTCOUNT, 1, true)
	nanoSprayVBO = makeInstanceVBOTable( vboLayout, 16, "nanoSprayShader GL4", 4)
	if vertexVBO == nil or nanoSprayVBO == nil then goodbye("Failed to make nanoSprayVBO") end
	nanoSprayVBO.vertexVBO = vertexVBO
	nanoSprayVBO.numVertices = numVertices
	nanoSprayVBO.VAO = makeVAOandAttach(nanoSprayVBO.vertexVBO, nanoSprayVBO.instanceVBO)
end

local function GetUnitNanoPieces(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID == nil then return nil end
	if unitDefPeiceMapCache[unitDefID] then return unitDefPeiceMapCache[unitDefID] end
	local nanolist = Spring.GetUnitNanoPieces(unitID)
	--Spring.Echo("GetUnitNanoPieces", unitID, unitDefID, nanolist)
	if nanolist == nil then
		return nil
	else
		unitDefPeiceMapCache[unitDefID] = nanolist
		return nanolist
	end
end

---calcLightExpiry(targetVBO, lightParamTable, instanceID)
---Calculates the gameframe that a light might expire at, and if it will, then it places it into the removal queue
local function calcLightExpiry(targetVBO, lightParamTable, instanceID)
	if lightParamTable[18] <= 0 then -- LifeTime less than 0 means never expires
		return nil
	end
	local deathtime = math_ceil(lightParamTable[17] + lightParamTable[18])
	if sprayRemoveQueue[deathtime] == nil then
		sprayRemoveQueue[deathtime] = {}
	end
	sprayRemoveQueue[deathtime][instanceID] = targetVBO
	return deathtime
end

---AddSpray(instanceID, unitID, pieceIndex, nanoparams, noUpload)
local function AddSpray(instanceID, unitID, pieceIndex, noUpload, x,y,z,r,m, sprayType )
	--if autoupdate then Spring.Echo("AddSpray", unitID, pieceIndex, 'xyzrm', x,y,z,r,m ) end
	if instanceID == nil then
		autoSprayInstanceID = autoSprayInstanceID + 1
		instanceID = autoSprayInstanceID
	end
	local gameFrame = Spring.GetGameFrame()
	if noUpload then gameFrame = -500 end -- shitty hax
<<<<<<< Updated upstream
	--Spring.Echo(x,y,z,r)
	instanceID = pushElementInstance(nanoSprayVBO, {x,y,z,r,gameFrame,0,1023,sprayType, pieceIndex, 0,0,0,0}, instanceID, true, noUpload, unitID)
=======
<<<<<<< Updated upstream
	instanceID = pushElementInstance(nanoSprayVBO, {200,0,200,50, gameFrame,1000000,1023,1, pieceIndex, 0,0,0,0}, instanceID, true, noUpload, unitID)
=======
	--Spring.Echo(x,y,z,r)
	tracy.ZoneBeginN("pushElementInstance")
	instanceID = pushElementInstance(nanoSprayVBO, {x,y,z,r,gameFrame,0,1023,sprayType, pieceIndex, 0,0,0,0}, instanceID, true, noUpload, unitID)
	tracy.ZoneEnd()
>>>>>>> Stashed changes
>>>>>>> Stashed changes
	-- calcLightExpiry
	return instanceID
end


-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

<<<<<<< Updated upstream
local function AddSprayForUnit(unitID, unitDefID, noUpload, reason, x,y,z,r,m, sprayType)
=======
<<<<<<< Updated upstream
local function AddSprayForUnit(unitID, unitDefID, noUpload)
=======
local function AddSprayForUnit(unitID, unitDefID, noUpload, reason, x,y,z,r,m, sprayType)
	
	tracy.ZoneBeginN("AddSprayForUnit")
>>>>>>> Stashed changes
>>>>>>> Stashed changes
	-- canbuild
	local nanos = GetUnitNanoPieces(unitID)
	--Spring.Debug.TraceEcho()
	--Spring.Echo("AddSprayForUnit",unitID, unitDefID, noUpload,nanos)
	if nanos then
		if unitAttachedNanoSprays[unitID] == nil then
			unitAttachedNanoSprays[unitID] = {}
		end
		for i,pieceIndex in ipairs(nanos) do
			local instanceID = AddSpray(nil, unitID, pieceIndex, noUpload, x,y,z,r,m, sprayType)
			if m then 
				mobileSprays[instanceID] = m
			end
			unitAttachedNanoSprays[unitID][instanceID] = true
		end
	end
	tracy.ZoneEnd()
end

<<<<<<< Updated upstream


local function RemoveSprayForUnit(unitID, instanceID, noUpload)
=======
<<<<<<< Updated upstream
local function RemoveSprayForUnit(unitID, instanceID)
=======

-- If instanceID is given, then only that nanospray is removed, if not, then all nanosprays are removed
local function RemoveSprayForUnit(unitID, instanceID, noUpload)
	tracy.ZoneBeginN("RemoveSprayForUnit")
>>>>>>> Stashed changes
>>>>>>> Stashed changes
	local numremoved = 0
	if unitAttachedNanoSprays[unitID] then
		if instanceID and unitAttachedNanoSprays[unitID][instanceID] then
			popElementInstance(nanoSprayVBO,instanceID, noUpload)
			numremoved = numremoved + 1
			unitAttachedNanoSprays[unitID][instanceID] = nil
		else
			for instanceID, _ in pairs(unitAttachedNanoSprays[unitID]) do
				if nanoSprayVBO.instanceIDtoIndex[instanceID] then
					numremoved = numremoved + 1
<<<<<<< Updated upstream
					popElementInstance(nanoSprayVBO,instanceID)
<<<<<<< Updated upstream
					mobileSprays[instanceID] = nil
=======
=======
					popElementInstance(nanoSprayVBO,instanceID, noUpload)
					mobileSprays[instanceID] = nil
>>>>>>> Stashed changes
>>>>>>> Stashed changes
				else
					--Spring.Echo("Light attached to unit no longer is in targetVBO", unitID, instanceID, targetVBO.myName)
				end
			end
			--Spring.Echo("Removed lights from unitID", unitID, numremoved, successes)
			unitAttachedNanoSprays[unitID] = nil
		end
	else
		--Spring.Echo("RemoveunitAttachedNanoSprays: No lights attached to", unitID)
	end
	tracy.ZoneEnd()
	return numremoved
end
<<<<<<< Updated upstream
=======

<<<<<<< Updated upstream
=======
local updateSprayTable = {}
local function UpdateSprayPosition(instanceID, mobileID, noUpload)
	tracy.ZoneBeginN("UpdateSprayPosition")
	local _,_,_,x,y,z = spGetUnitPosition(mobileID, true)
	if x then 
		local instanceIndex = nanoSprayVBO.instanceIDtoIndex[instanceID]
		if instanceIndex == nil then return nil end
		getElementInstanceData(nanoSprayVBO, instanceID, updateSprayTable)
		updateSprayTable[1] = x
		updateSprayTable[2] = y
		updateSprayTable[3] = z
		local unitID = nanoSprayVBO.indextoUnitID[instanceIndex]
		pushElementInstance(nanoSprayVBO, updateSprayTable, instanceID, true, noUpload, unitID)
	end
	tracy.ZoneEnd()
end

local function StopSprayForUnit(unitID, gameFrame, diequeue, noUpload)
	if unitAttachedNanoSprays[unitID] then
		for instanceID, _ in pairs(unitAttachedNanoSprays[unitID]) do
			tracy.ZoneBeginN("UpdateSprayDieTime")
			local instanceIndex = nanoSprayVBO.instanceIDtoIndex[instanceID]
			if instanceIndex then 
				getElementInstanceData(nanoSprayVBO, instanceID, updateSprayTable)
				updateSprayTable[6] = gameFrame
				updateSprayTable[9] = 0 -- try setting piece index to 0 
				local unitID = nanoSprayVBO.indextoUnitID[instanceIndex]
				pushElementInstance(nanoSprayVBO, updateSprayTable, instanceID, true, noUpload, unitID)
				tracy.ZoneEnd()
				diequeue[instanceID] = unitID
			end
		end
	end
end

>>>>>>> Stashed changes
>>>>>>> Stashed changes
function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()
	local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID, false)
end

<<<<<<< Updated upstream


--[[
Stuff needed in the cob script:

lua_UnitScriptBuildStartStop(onoff, param1, param2, param3) 
{
	return 0;
}

call-script lua_UnitScriptBuildStartStop(onoff, 1,2,3);
]]--
-- only add them to a table for further processing!
local unitScriptBuildEventQueue = {}

local function UnitScriptBuildStartStop(unitID, unitDefID, onoff, param1, param2, param3)
	--Spring.Echo("Widgetside UnitScriptBuildStartStop", unitID, unitDefID, whichDecal, posx,posz, heading)
	if unitDefCanNanoSpray[unitDefID] and Spring.ValidUnitID(unitID) and Spring.GetUnitIsDead(unitID) == false then
		--Spring.Echo("Queued spray for", unitID, unitDefID, onoff)
		if Spring.IsUnitAllied(unitID) then 
			unitScriptBuildEventQueue[unitID] = onoff
		end
	end
end


function widget:Initialize()
	if initGL4() == false then return end
=======
<<<<<<< Updated upstream
function widget:Initialize()
	if initGL4() == false then return end
=======

--[[
Stuff needed in the cob script:

lua_UnitScriptBuildStartStop(onoff, param1, param2, param3) 
{
	return 0;
}

call-script lua_UnitScriptBuildStartStop(onoff, 1,2,3);
]]--
-- only add them to a table for further processing!
local unitScriptBuildEventQueue = {}
local numQueued = 0

local function UnitScriptBuildStartStop(unitID, unitDefID, onoff, param1, param2, param3)
	--Spring.Echo("Widgetside UnitScriptBuildStartStop", unitID, unitDefID, whichDecal, posx,posz, heading)
	if unitDefCanNanoSpray[unitDefID] and Spring.ValidUnitID(unitID) and Spring.GetUnitIsDead(unitID) == false then
		--Spring.Echo("Queued spray for", unitID, unitDefID, onoff)
		if Spring.IsUnitAllied(unitID) then 
			unitScriptBuildEventQueue[unitID] = onoff
			numQueued = numQueued + 1
		end
	end
end

local function UnitScriptBuildStartStopBatched(numVisible, buildStartStopCache)
	Spring.Echo("Widgetside UnitScriptBuildStartStopBatched", numVisible)
	for unitID, onoff in pairs(buildStartStopCache) do 
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitDefID and unitDefCanNanoSpray[unitDefID] and Spring.ValidUnitID(unitID) and Spring.GetUnitIsDead(unitID) == false then
			--Spring.Echo("Queued spray for", unitID, unitDefID, onoff)
			if Spring.IsUnitAllied(unitID) then 
				unitScriptBuildEventQueue[unitID] = onoff
				numQueued = numQueued + 1
			end
		end
	end
end


function widget:Initialize()
	if initGL4() == false then return end
>>>>>>> Stashed changes
	
	-- find all builders
	for unitDefID, unitDef in pairs(UnitDefs) do 
		if unitDef.canAssist or unitDef.canRepair or unitDef.canReclaim or #unitDef.buildOptions > 0 then 
			unitDefCanNanoSpray[unitDefID] = true
		end
	end
	
	widgetHandler:RegisterGlobal('UnitScriptBuildStartStop', UnitScriptBuildStartStop)
<<<<<<< Updated upstream
=======
	widgetHandler:RegisterGlobal('UnitScriptBuildStartStopBatched', UnitScriptBuildStartStopBatched)
>>>>>>> Stashed changes
>>>>>>> Stashed changes
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	--AddSprayForUnit(unitID, unitDefID, false, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(nanoSprayVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		--AddSprayForUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(nanoSprayVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove all the lights for this unit
	--if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	RemoveSprayForUnit(unitID)
end


function widget:Shutdown()
<<<<<<< Updated upstream
	widgetHandler:DeregisterGlobal('UnitScriptBuildStartStop')
end

=======
<<<<<<< Updated upstream
end

function widget:GameFrame(n)
	gameFrame = n
	if sprayRemoveQueue[n] then
		for instanceID, _ in pairs(sprayRemoveQueue[n]) do
			if nanoSprayVBO.instanceIDtoIndex[instanceID] then
				--Spring.Echo("removing dead light", targetVBO.usedElements, 'id:', instanceID)
				popElementInstance(nanoSprayVBO, instanceID)
=======
	widgetHandler:DeregisterGlobal('UnitScriptBuildStartStop')
	widgetHandler:DeregisterGlobal('UnitScriptBuildStartStopBatched')
end

>>>>>>> Stashed changes
local function isMobile(unitID) 
	local buildprogress = select(5,Spring.GetUnitHealth(unitID))
	if not buildprogress then return nil end
	if buildprogress < 1 then 
		return nil
	else
		local unitDefID = Spring.GetUnitDefID(unitID)
		if UnitDefs[unitDefID].canMove then 
			return unitID
		else
			return nil
<<<<<<< Updated upstream
		end
=======
		end
	end
end

-- This is the true hell!
-- returns the x,y,z,radius,mobileUnitID or nil
-- spraytype is 1=forward, -1=reverse, 0=bidirectional
local function GetNanoSprayTargetType(unitID, unitDefID)
	local index, name, cmdtype, cmdstr = Spring.GetActiveCommand(unitID)
	local x,y,z,r,mobile
	local spraytype = 1
	local buildTargetID = Spring.GetUnitIsBuilding(unitID)
	if buildTargetID then -- Easiest case, the unit is building something
		_,_,_, x, y, z = spGetUnitPosition(buildTargetID, true)
		r = Spring.GetUnitRadius(buildTargetID)
		mobile = isMobile(buildTargetID)
		return x, y, z, r, mobile, spraytype
	end
	
	local nanopieces =  Spring.GetUnitNanoPieces (  unitID ) --return: nil | { [1] = number piece1, etc ... }
	local cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4 =  Spring.GetUnitCurrentCommand(unitID, 1)
	
	if cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or cmdID == CMD.CAPTURE then  
		--Spring.Echo("Cmdtarget", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3)
		buildTargetID = cmdParam1
		if buildTargetID < 32000 then  
			_,_,_, x, y, z = spGetUnitPosition(buildTargetID, true)
			r = Spring.GetUnitRadius(buildTargetID)
			mobile = isMobile(buildTargetID)
		else -- if buildTargetID > maxunits then its a feature
			for i, featureID in ipairs(Spring.GetAllFeatures()) do 
				--Spring.Echo(featureID, FeatureDefs[Spring.GetFeatureDefID(featureID)].name)
>>>>>>> Stashed changes
			end
		end
<<<<<<< Updated upstream
		sprayRemoveQueue[n] = nil
>>>>>>> Stashed changes
	end
end


-- This is the true hell!
-- returns the x,y,z,radius,mobileUnitID or nil
-- spraytype is 1=forward, -1=reverse, 0=bidirectional
local function GetNanoSprayTargetType(unitID, unitDefID)
	local index, name, cmdtype, cmdstr = Spring.GetActiveCommand(unitID)
	local x,y,z,r,mobile
	local spraytype = 1
	local buildTargetID = Spring.GetUnitIsBuilding(unitID)
	if buildTargetID then -- Easiest case, the unit is building something
		_,_,_, x, y, z = spGetUnitPosition(buildTargetID, true)
		r = Spring.GetUnitRadius(buildTargetID)
		mobile = isMobile(buildTargetID)
		return x, y, z, r, mobile, spraytype
	end
	
	local nanopieces =  Spring.GetUnitNanoPieces (  unitID ) --return: nil | { [1] = number piece1, etc ... }
	local cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4 =  Spring.GetUnitCurrentCommand(unitID, 1)
	
	if cmdID == CMD.RECLAIM or cmdID == CMD.REPAIR or cmdID == CMD.CAPTURE then  
		--Spring.Echo("Cmdtarget", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3)
		buildTargetID = cmdParam1
		if buildTargetID < 32000 then  
			_,_,_, x, y, z = spGetUnitPosition(buildTargetID, true)
			r = Spring.GetUnitRadius(buildTargetID)
			mobile = isMobile(buildTargetID)
		else -- if buildTargetID > maxunits then its a feature
			for i, featureID in ipairs(Spring.GetAllFeatures()) do 
				--Spring.Echo(featureID, FeatureDefs[Spring.GetFeatureDefID(featureID)].name)
			end
			buildTargetID = buildTargetID - 32000
			_,_,_, x, y, z = Spring.GetFeaturePosition(buildTargetID, true)
			r = Spring.GetFeatureRadius(buildTargetID)
		end
			
		if cmdID == CMD.RECLAIM then spraytype = -1	end
		if cmdID == CMD.CAPTURE then spraytype = 0	end
	end
	
	if cmdID == CMD.RESTORE then -- Resp
		--Spring.Echo("CMD.RESTORE", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4)
		x,y,z,r = cmdParam1, cmdParam2, cmdParam3, cmdParam4
		spraytype = 0
	end
	
	if cmdID == CMD.RESURRECT then 
		--Spring.Echo("CMD.RESURRECT", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4)
		buildTargetID = cmdParam1 - 32000
		_,_,_, x, y, z = Spring.GetFeaturePosition(buildTargetID, true)
		r = Spring.GetFeatureRadius(buildTargetID)
		spraytype = 0
	end
	
	--Spring.Echo("Target?", unitID, 'cmdID=', cmdID, 'cmdTag=',cmdTag, 'isbuilding=', isbuilding, 'nanopieces = ' , nanopieces, "xyzr", x,y,z,r, "buildTargetID=",buildTargetID)

	return x, y, z, r, mobile, spraytype
end

<<<<<<< Updated upstream
local updateSprayTable = {}
local function UpdateSprayPosition(instanceID, mobileID)
	local _,_,_,x,y,z = spGetUnitPosition(mobileID, true)
	if x then 
		local instanceIndex = nanoSprayVBO.instanceIDtoIndex[instanceID]
		if instanceIndex == nil then return nil end
		getElementInstanceData(nanoSprayVBO, instanceID, updateSprayTable)
		updateSprayTable[1] = x
		updateSprayTable[2] = y
		updateSprayTable[3] = z
		local unitID = nanoSprayVBO.indextoUnitID[instanceIndex]
		pushElementInstance(nanoSprayVBO, updateSprayTable, instanceID, true, nil, unitID)
	end
end

local function UpdateSprayDieTime(instanceID, gameFrame)
	local instanceIndex = nanoSprayVBO.instanceIDtoIndex[instanceID]
	if instanceIndex == nil then return nil end
	getElementInstanceData(nanoSprayVBO, instanceID, updateSprayTable)
	updateSprayTable[6] = gameFrame
	updateSprayTable[9] = 0 -- try setting piece index to 0 
	local unitID = nanoSprayVBO.indextoUnitID[instanceIndex]
	pushElementInstance(nanoSprayVBO, updateSprayTable, instanceID, true, nil, unitID)
end

local function StopSprayForUnit(unitID, gameFrame, diequeue)
	if unitAttachedNanoSprays[unitID] then
		for instanceID, _ in pairs(unitAttachedNanoSprays[unitID]) do
			UpdateSprayDieTime(instanceID, gameFrame)
			diequeue[instanceID] = unitID
		end
	end
end
=======
------------------------------- Drawing all the lights ---------------------------------
=======
			
		if cmdID == CMD.RECLAIM then spraytype = -1	end
		if cmdID == CMD.CAPTURE then spraytype = 0	end
	end
	
	if cmdID == CMD.RESTORE then -- Resp
		--Spring.Echo("CMD.RESTORE", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4)
		x,y,z,r = cmdParam1, cmdParam2, cmdParam3, cmdParam4
		spraytype = 0
	end
	
	if cmdID == CMD.RESURRECT then 
		--Spring.Echo("CMD.RESURRECT", cmdID, cmdOpts, cmdTag, cmdParam1, cmdParam2, cmdParam3, cmdParam4)
		buildTargetID = cmdParam1 - 32000
		_,_,_, x, y, z = Spring.GetFeaturePosition(buildTargetID, true)
		r = Spring.GetFeatureRadius(buildTargetID)
		spraytype = 0
	end
	
	--Spring.Echo("Target?", unitID, 'cmdID=', cmdID, 'cmdTag=',cmdTag, 'isbuilding=', isbuilding, 'nanopieces = ' , nanopieces, "xyzr", x,y,z,r, "buildTargetID=",buildTargetID)

	return x, y, z, r, mobile, spraytype
end


>>>>>>> Stashed changes

local lastGameFrame = Spring.GetGameFrame() -1 
function widget:Update()
	local gameFrame = Spring.GetGameFrame()
	
	if gameFrame > lastGameFrame then 
		lastGameFrame = gameFrame
<<<<<<< Updated upstream
		
		for unitID, buildstatus in pairs(unitScriptBuildEventQueue) do
			local index, name, cmdtype, cmdstr = Spring.GetActiveCommand(unitID)
			
			local isbuilding = Spring.GetUnitIsBuilding ( unitID )
			local nanopieces =  Spring.GetUnitNanoPieces (  unitID ) --return: nil | { [1] = number piece1, etc ... }
			--Spring.Echo("TRY", unitID, isbuilding,nanopieces )
			if buildstatus == 1 then 
				local  x,y,z, r, mobileID, sprayType = GetNanoSprayTargetType(unitID)
				if x then 
					AddSprayForUnit(unitID, unitDefID, nil, "fuck", x,y,z,r, mobileID, sprayType )
				end
			else
=======
		local numnanos = 0
		local noUpload = false
		if numQueued > 20 then noUpload = true end
		for unitID, buildstatus in pairs(unitScriptBuildEventQueue) do
			
			numnanos = numnanos + 1
			local index, name, cmdtype, cmdstr = Spring.GetActiveCommand(unitID)
			
			local isbuilding = Spring.GetUnitIsBuilding(unitID )
			local nanopieces =  Spring.GetUnitNanoPieces(unitID ) -- return: nil | { [1] = number piece1, etc ... }
			--Spring.Echo("TRY", unitID, isbuilding,nanopieces )
			if buildstatus == 1 then -- ON
				local x,y,z, r, mobileID, sprayType = GetNanoSprayTargetType(unitID)
				if x then 
					AddSprayForUnit(unitID, unitDefID, noUpload, "fuck", x,y,z,r, mobileID, sprayType )
				end
			else -- OFF
>>>>>>> Stashed changes
				local dietime = gameFrame + fadeout
				if sprayRemoveQueue[dietime] == nil then
					sprayRemoveQueue[dietime] = {}
				end
<<<<<<< Updated upstream
				StopSprayForUnit(unitID, gameFrame, sprayRemoveQueue[dietime])
=======
				StopSprayForUnit(unitID, gameFrame, sprayRemoveQueue[dietime], noUpload)
>>>>>>> Stashed changes
				--RemoveSprayForUnit(unitID)
			end
			unitScriptBuildEventQueue[unitID] = nil
		end
			
		for instanceID, mobileUnitID in pairs(mobileSprays) do 
			UpdateSprayPosition(instanceID, mobileUnitID)
		end
		
<<<<<<< Updated upstream
=======
		if numnanos > 0 then
			tracy.Message(numnanos)
		end
>>>>>>> Stashed changes
		
		if sprayRemoveQueue[gameFrame] then
			for instanceID, unitID in pairs(sprayRemoveQueue[gameFrame]) do
				if nanoSprayVBO.instanceIDtoIndex[instanceID] then
					--Spring.Echo("removing dead light", targetVBO.usedElements, 'id:', instanceID)
<<<<<<< Updated upstream
					popElementInstance(nanoSprayVBO, instanceID)
=======
					popElementInstance(nanoSprayVBO, instanceID, noUpload)
>>>>>>> Stashed changes
					unitAttachedNanoSprays[unitID][instanceID] = nil
					if next(unitAttachedNanoSprays[unitID]) == nil then 
						unitAttachedNanoSprays[unitID] = nil
					end
				end
<<<<<<< Updated upstream
				

			end
			sprayRemoveQueue[gameFrame] = nil
		end
	end
end
=======
			end
			sprayRemoveQueue[gameFrame] = nil
		end
		if noUpload then 
			uploadAllElements(nanoSprayVBO)
		end
		numQueued = 0
	end
end
>>>>>>> Stashed changes
>>>>>>> Stashed changes

function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	if autoupdate then
		nanoSprayShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0) or nanoSprayShader
	end

	if nanoSprayVBO.usedElements > 0 then
		--if Spring.GetDrawFrame() % 100 == 0 then Spring.Echo(nanoSprayVBO.usedElements) end 
		gl.DepthTest(true)
		gl.Texture(0, nanoParticleTexture)
		nanoSprayShader:Activate()
		--nanoSprayShader:SetUniformFloat("nightFactor", nightFactor)
		glBlending(GL.SRC_ALPHA, GL.ONE)
		nanoSprayVBO:draw(GL.POINTS)
		nanoSprayShader:Deactivate()
		gl.Texture(0, false)
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		--gl.DepthMask(true) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end

-- Register /luaui dlgl4stats to dump light statistics
function widget:TextCommand(command)
	if string.find(command, "asdfasdfasfasdfsadfsdafsd", nil, true) then
		return true
	end
	return false
end
