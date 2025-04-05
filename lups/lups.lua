---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    api_gfx_lups.lua
--  brief:   Lua Particle System
--  authors: jK
--  last updated: Jan. 2008
--
--  Copyright (C) 2007,2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------


local function GetInfo()
	return {
		name      = "Lups",
		desc      = "Lua Particle System",
		author    = "jK",
		date      = "2008-2014",
		license   = "GNU GPL, v2 or later",
		layer     = 1000,
		api       = true,
		enabled   = true
	}
end


--// FIXME
-- 1. add los handling (inRadar,alwaysVisible, etc.)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// Error Log Handling

PRIO_MAJOR = 0
PRIO_ERROR = 1
PRIO_LESS  = 2

local errorLog = {}
local printErrorsAbove = PRIO_MAJOR
function print(priority,...)
	local errorMsg = ""
	for i=1,select('#',...) do
		errorMsg = errorMsg .. select(i,...)
	end
	errorLog[#errorLog+1] = {priority=priority,message=errorMsg}

	if (priority<=printErrorsAbove) then
		Spring.Echo(...)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// locals

local pop  = table.remove
local StrToLower = string.lower

local pairs  = pairs
local ipairs = ipairs
local next   = next

local spGetUnitRadius        = Spring.GetUnitRadius
local spIsSphereInView       = Spring.IsSphereInView
local spGetUnitIsActive      = Spring.GetUnitIsActive
local spGetUnitRulesParam    = Spring.GetUnitRulesParam
local spGetGameFrame         = Spring.GetGameFrame
local spGetFrameTimeOffset   = Spring.GetFrameTimeOffset
local spGetSpectatingState   = Spring.GetSpectatingState
local spGetLocalAllyTeamID   = Spring.GetLocalAllyTeamID
local scGetReadAllyTeam      = Script.GetReadAllyTeam
local spGetUnitPieceMap      = Spring.GetUnitPieceMap
local spValidUnitID          = Spring.ValidUnitID
local spGetUnitIsStunned     = Spring.GetUnitIsStunned
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetUnitHealth		 = Spring.GetUnitHealth

local glPushMatrix      = gl.PushMatrix
local glPopMatrix       = gl.PopMatrix
local glTranslate       = gl.Translate
local glScale           = gl.Scale
local glBlending        = gl.Blending
local glAlphaTest       = gl.AlphaTest
local glDepthTest       = gl.DepthTest
local glDepthMask       = gl.DepthMask
local glUnitMultMatrix  = gl.UnitMultMatrix
local glUnitPieceMultMatrix = gl.UnitPieceMultMatrix

local GL_GREATER = GL.GREATER
local GL_ONE     = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// hardware capabilities
local GL_VENDOR   = 0x1F00
local GL_RENDERER = 0x1F01
local GL_VERSION  = 0x1F02

local glVendor   = gl.GetString(GL_VENDOR)
local glRenderer = (gl.GetString(GL_RENDERER)):lower()

isNvidia  = (glVendor:find("NVIDIA"))
isATI     = (glVendor:find("ATI "))
isMS      = (glVendor:find("Microsoft"))
isIntel   = (glVendor:find("Intel"))
canCTT    = (gl.CopyToTexture    ~= nil)
canFBO    = (gl.DeleteTextureFBO ~= nil)
canRTT    = (gl.RenderToTexture  ~= nil)
canShader = (gl.CreateShader     ~= nil)
canDistortions = false --// check Initialize()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


--// widget/gadget handling
local handler = (widget and widgetHandler)or(gadgetHandler)
local GG      = (widget and WG)or(GG)
local VFSMODE = (widget and VFS.RAW_FIRST)or(VFS.ZIP_ONLY)

local this = widget or gadget

--// locations
local LUPS_LOCATION    = 'lups/'
local PCLASSES_DIRNAME = LUPS_LOCATION .. 'ParticleClasses/'
local HEADERS_DIRNAME  = LUPS_LOCATION .. 'headers/'

--// helpers
VFS.Include(LUPS_LOCATION .. 'loadconfig.lua',nil,VFSMODE)

--// load some headers
VFS.Include(HEADERS_DIRNAME .. 'general.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'mathenv.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'figures.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'vectors.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'hsl.lua',nil,VFSMODE)
VFS.Include(HEADERS_DIRNAME .. 'nanoupdate.lua',nil,VFSMODE)

--// load binary insert library
VFS.Include(HEADERS_DIRNAME .. 'tablebin.lua')
local flayer_comp = function( partA,partB )
	return ( partA==partB )or
				 ( (partA.layer==partB.layer)and((partA.unit or -1)<(partB.unit or -1)) )or
				 ( partA.layer<partB.layer )
end

--// workaround for broken UnitDraw() callin
local nilDispList


--// global function (fx classes can use it) for easier access to Lups.cfg
function GetLupsSetting(key, default)
	local value = LupsConfig[key]
	if (value~=nil) then
		return value
	else
		return default
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// some global vars (so the effects can use them)
vsx, vsy, vpx, vpy = Spring.GetViewGeometry() --// screen pos & view pos (view pos only unequal zero if dualscreen+minimapOnTheLeft)
LocalAllyTeamID = 0
thisGameFrame   = 0
frameOffset     = 0
LupsConfig      = {}

local noDrawUnits = {}
function SetUnitLuaDraw(unitID,nodraw)
	if nodraw then
		noDrawUnits[unitID] = (noDrawUnits[unitID] or 0) + 1
		if noDrawUnits[unitID]==1 then
			Spring.UnitRendering.ActivateMaterial(unitID,1)
			--Spring.UnitRendering.SetLODLength(unitID,1,-1000)
			for pieceID in ipairs(Spring.GetUnitPieceList(unitID) or {}) do
				Spring.UnitRendering.SetPieceList(unitID,1,pieceID,nilDispList)
			end
		end
	else
		noDrawUnits[unitID] = (noDrawUnits[unitID] or 0) - 1
		if noDrawUnits[unitID]==0 then
			Spring.UnitRendering.DeactivateMaterial(unitID,1)
			noDrawUnits[unitID] = nil
		end
	end
end

local function DrawUnit(_,unitID,drawMode)
--[[
 drawMode:
	notDrawing     = 0,
	normalDraw     = 1,
	shadowDraw     = 2,
	reflectionDraw = 3,
	refractionDraw = 4
--]]

	if drawMode==1 and noDrawUnits[unitID] then
		return true
	end
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local oldVsx,oldVsy = vsx-1,vsy-1

--// load particle classes
local fxClasses = {}
local DistortionClass

local files = VFS.DirList(PCLASSES_DIRNAME, "*.lua",VFSMODE)
for _,filename in ipairs(files) do
	local Class = VFS.Include(filename,nil,VFSMODE)
	if Class then
		if Class.GetInfo then
			Class.pi = Class.GetInfo()
			local sClassName = string.lower(Class.pi.name)
			if fxClasses[sClassName] then
				print(PRIO_LESS,'LUPS: duplicated particle class name "' .. sClassName .. '"')
			else
				fxClasses[sClassName] = Class
			end
		else
			print(PRIO_ERROR,'LUPS: "' .. Class .. '" is missing GetInfo() ')
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// saves all particles
particles = {}
local particles = particles
local particlesCount = 0

local RenderSequence = {}  --// mult-dim table with: [layer][partClass][unitID][fx]
local effectsInDelay = {}  --// fxs which use the delay tag, and waiting for their spawn
local partIDCount = 0  --// increasing ID used to identify the particles

--[[
local function DebugPieces(unit,piecenum,level)
	local piece = Spring.GetUnitPieceInfo(unit,piecenum)
	Spring.Echo( string.rep(" ", level) .. "->" .. piece.name .. " (" .. piecenum .. ")")
	for _,pieceChildName in ipairs(piece.children) do
		local pieceNum = spGetUnitPieceMap(unit)[pieceChildName]
		DebugPieces(unit,pieceNum,level+1)
	end
end
--]]


--// the id param is internal don't use it!
function AddParticles(Class,Options   ,__id)
	if not Options then
		print(PRIO_LESS,'LUPS->AddFX: no options given');
		return -1;
	end

	if Options.quality and Options.quality > GetLupsSetting("quality", 3) then
		return -1;
	end

	if Options.delay and Options.delay~=0 then
		partIDCount = partIDCount+1
		local newOptions = {}
		table.mergeInPlace(newOptions, Options)
		newOptions.delay=nil
		effectsInDelay[#effectsInDelay+1] = {frame=thisGameFrame+Options.delay, class=Class, options=newOptions, id=partIDCount};
		return partIDCount
	end

	Class = StrToLower(Class)
	local particleClass = fxClasses[Class]

	if not particleClass then
		print(PRIO_LESS,'LUPS->AddFX: couldn\'t find a particle class named "' .. Class .. '"');
		return -1;
	end

	if Options.unit and not spValidUnitID(Options.unit) then
		print(PRIO_LESS,'LUPS->AddFX: unit is already dead/invalid "' .. Class .. '"');
		return -1;
	end

	--// piecename to piecenum conversion (spring >=76b1 only!)
	if Options.unit and Options.piece then
		local pieceMap = spGetUnitPieceMap(Options.unit)
		Options.piecenum = pieceMap and pieceMap[Options.piece] --added check. switching spectator view can cause "attempt to index a nil value"
		if not Options.piecenum then
			local udid = Spring.GetUnitDefID(Options.unit)
			if not udid then
				print(PRIO_LESS,"LUPS->AddFX:wrong unitID")
			else
				print(PRIO_ERROR,"LUPS->AddFX:wrong unitpiece " .. Options.piece .. "(" .. UnitDefs[udid].name .. ")")
			end
			return -1;
		end
	end

	--Spring.Echo("-------------")
	--DebugPieces(Options.unit,1,0)


	local newParticles,reusedFxID = particleClass.Create(Options)
	if newParticles then
		particlesCount = particlesCount + 1
		if __id then
			newParticles.id = __id
		else
			partIDCount = partIDCount+1
			newParticles.id = partIDCount
		end
		particles[ newParticles.id ] = newParticles

		local space = (not newParticles.worldspace and newParticles.unit or -1)
		local fxTable = CreateSubTables(RenderSequence,{newParticles.layer,particleClass,space})
		newParticles.fxTable = fxTable
		fxTable[#fxTable+1] = newParticles

		return newParticles.id;
	else
		if reusedFxID then
			return reusedFxID;
		else
			if newParticles~=false then
				print(PRIO_LESS,"LUPS->AddFX:FX creation failed");
			end
			return -1;
		end
	end
end


function AddParticlesArray(array)
	local class = ""
	for i=1,#array do
		local fxSettings = array[i]
		class = fxSettings.class
		fxSettings.class = nil
		AddParticles(class,fxSettings)
	end
end

function GetParticles(particlesID)
	return particles[particlesID]
end

function RemoveParticles(particlesID)
	local fx = particles[particlesID]
	if fx then
		if type(fx.fxTable)=="table" then
			for j,w in pairs(fx.fxTable) do
				if w.id==particlesID then
					pop(fx.fxTable,j)
				end
			end
		end
		fx:Destroy()
	    if fx.lightID then
	      if (WG and WG['lighteffects']) or Script.LuaUI("GadgetRemoveLight") then
			if WG then
			  WG['lighteffects'].removeLight(fx.lightID)
			else
			  Script.LuaUI.GadgetRemoveLight(fx.lightID)
			end
			fx.lightID = nil
	      end
	    end
		particles[particlesID] = nil
		particlesCount = particlesCount-1;
		return
	else
		local status,err = pcall(function()
--//FIXME
			for i=1,#effectsInDelay do
				if effectsInDelay[i].id==particlesID then
					table.remove(effectsInDelay,i)
					return
				end
			end
--//
		end)

		if not status then
			Spring.Echo("Error (Lups) - "..(#effectsInDelay).." :"..err)
			for i=1,#effectsInDelay do
				Spring.Echo("->",effectsInDelay[i],type(effectsInDelay[i]))
			end
			effectsInDelay = {}
		end
	end
end

function GetStats()
	local count   = particlesCount
	local effects = {}
	local layers  = 0

	for i=-50,50 do
		if RenderSequence[i] then
			local layer = RenderSequence[i];

			if next(layer or {}) then layers=layers+1 end

			for partClass,Units in pairs(layer) do
				if not effects[partClass.pi.name] then
					effects[partClass.pi.name] = {0,0} --//[1]:=fx count  [2]:=part count
				end
				for unitID,UnitEffects in pairs(Units) do
					for _,fx in pairs(UnitEffects) do
						effects[partClass.pi.name][1] = effects[partClass.pi.name][1] + 1
						effects[partClass.pi.name][2] = effects[partClass.pi.name][2] + (fx.count or 0)
						--count = count+1
					end
				end
			end
		end
	end

	return count,layers,effects
end


function HasParticleClass(ClassName)
	local Class = StrToLower(ClassName)
	return (fxClasses[Class] and true)or(false)
end


function GetErrorLog(minPriority)
	if minPriority then
		local log = ""
		for i=1,#errorLog do
			if (errorLog[i].priority<=minPriority) then
				log = log .. errorLog[i].message .. "\n"
			end
		end
		if log~="" then
			local sysinfo = "Vendor:" .. glVendor ..
											"\nRenderer:" .. glRenderer ..
											(((isATI)and("\nisATI: true"))or("")) ..
											(((isMS)and("\nisMS: true"))or("")) ..
											(((isIntel)and("\nisIntel: true"))or("")) ..
											"\ncanFBO:" .. tostring(canFBO) ..
											"\ncanRTT:" .. tostring(canRTT) ..
											"\ncanCTT:" .. tostring(canCTT) ..
											"\ncanShader:" .. tostring(canShader) .. "\n"
			log = sysinfo..log
		end
		return log
	else
		if errorlog~="" then
			local sysinfo = "Vendor:" .. glVendor ..
											"\nRenderer:" .. glRenderer ..
											"\nisATI:" .. tostring(isATI) ..
											"\nisMS:" .. tostring(isMS) ..
											"\nisIntel:" .. tostring(isIntel) ..
											"\ncanFBO:" .. tostring(canFBO) ..
											"\ncanRTT:" .. tostring(canRTT) ..
											"\ncanCTT:" .. tostring(canCTT) ..
											"\ncanShader:" .. tostring(canShader) .. "\n"
			return sysinfo..errorLog
		else
			return errorLog
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local anyFXVisible = false
local anyDistortionsVisible = false

local unitMovetype = {}
for unitDefID, ud in pairs(UnitDefs) do
	local moveType = nil
	if ud.canFly or ud.isAirUnit then
		if ud.isHoveringAirUnit then
			moveType = 1 -- gunship
		else
			moveType = 0 -- fixedwing
		end
	elseif not ud.isBuilding or ud.isFactory or ud.speed == 0 then
		moveType = 2 -- ground/sea
	end
	unitMovetype[unitDefID] = moveType
end

local function IsUnitPositionKnown(unitID)
	if LocalAllyTeamID < 0 then
		return true
	end
	local targetVisiblityState = Spring.GetUnitLosState(unitID, LocalAllyTeamID, true)
	if not targetVisiblityState then
		return false
	end
	local inLos = (targetVisiblityState == 15)
	if inLos then
		return true
	end
	local identified = (targetVisiblityState > 2)

	if not identified then
		return false
	end
	local unitDefID = Spring.GetUnitDefID(unitID)
	if not unitDefID then
		return false
	end
	return not unitMovetype[unitDefID]
end

local function RadarDotCheck(unitID)
	return true
end

local function Draw(extension,layer,water)
	local FxLayer = RenderSequence[layer];
	if not FxLayer then return end

	local BeginDrawPass = "BeginDraw"..extension
	local DrawPass      = "Draw"..extension
	local EndDrawPass   = "EndDraw"..extension

	for partClass,Units in pairs(FxLayer) do
		local beginDraw = partClass[BeginDrawPass]
		if beginDraw then
			if tracy then tracy.ZoneBeginN("LUPS:Draw:"..tostring(partClass.pi.name)) end 
			beginDraw()
			local drawfunc = partClass[DrawPass]

			if not next(Units) then
				FxLayer[partClass]=nil
			else
				for unitID,UnitEffects in pairs(Units) do
					if not UnitEffects[1] then
						Units[unitID]=nil
					else

						if unitID>-1 then

							------------------------------------------------------------------------------------
							-- render in unit/piece space ------------------------------------------------------
							------------------------------------------------------------------------------------
							glPushMatrix()
							if gadget and not IsUnitPositionKnown(unitID) then
								local x, y, z = Spring.GetUnitPosition(unitID)
								local a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34, a41, a42, a43, a44 = Spring.GetUnitTransformMatrix(unitID)
								if a11 then
									gl.MultMatrix(a11, a12, a13, a14, a21, a22, a23, a24, a31, a32, a33, a34, x, y, z , a44)
								else
									glUnitMultMatrix(unitID)
								end
							else
								glUnitMultMatrix(unitID)
							end


							--// render effects
							for i=1,#UnitEffects do
								local fx = UnitEffects[i]
								if fx.alwaysVisible or fx.visible then
									if not water or not fx.nowater then
										if fx.piecenum then
											--// enter piece space
											glPushMatrix()
												glUnitPieceMultMatrix(unitID,fx.piecenum)
												glScale(1,1,-1)
												drawfunc(fx)
											glPopMatrix()
											--// leave piece space
										else
											fx[DrawPass](fx)
										end
									end
								end
							end

							--// leave unit space
							glPopMatrix()

						else

							------------------------------------------------------------------------------------
							-- render in world space -----------------------------------------------------------
							------------------------------------------------------------------------------------
							for i=1,#UnitEffects do
								local fx = UnitEffects[i]
								if fx.alwaysVisible or fx.visible then
									if not water or not fx.nowater then
										glPushMatrix()
										if fx.projectile and not fx.worldspace then
											local x,y,z = spGetProjectilePosition(fx.projectile)
											glTranslate(x,y,z)
										end
										drawfunc(fx)
										glPopMatrix()
									end
								end
							end -- for
						end -- if
					end  --if
				end  --for
			end

			partClass[EndDrawPass]()
			
			if tracy then tracy.ZoneEnd() end 
		end
	end
end

local function DrawDistortionLayers()
	glBlending(GL_ONE,GL_ONE)

	for i=-50,50 do
		Draw("Distortion",i)
	end

	glBlending(GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA)
end

local function DrawParticlesOpaque()
	if not anyFXVisible then return end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	if vsx~=oldVsx or vsy~=oldVsy then
		for _,partClass in pairs(fxClasses) do
			if partClass.ViewResize then partClass.ViewResize(vsx, vsy) end
		end
		oldVsx, oldVsy = vsx, vsy
	end

	glDepthTest(true)
	glDepthMask(true)
	for i=-50,50 do
		Draw("Opaque",i)
	end
	glDepthMask(false)
	glDepthTest(false)
end

local function DrawParticles()
	if not anyFXVisible then return end

	glDepthTest(true)

	--// Draw() (layers: -50 upto 0)
	glAlphaTest(GL_GREATER, 0)
	for i=-50,0 do
		Draw("",i)
	end
	glAlphaTest(false)

	--// DrawDistortion()
	if anyDistortionsVisible and DistortionClass then
		DistortionClass.BeginDraw()
		gl.ActiveFBO(DistortionClass.fbo,DrawDistortionLayers)
		DistortionClass.EndDraw()
	end

	--// Draw() (layers: 1 upto 50)
	glAlphaTest(GL_GREATER, 0)
	for i=1,50 do
		Draw("",i)
	end

	glAlphaTest(false)
	glDepthTest(false)
end


local function DrawParticlesWater()
	if not anyFXVisible then return end

	glDepthTest(true)

	--// DrawOpaque()
	glDepthMask(true)
	for i=-50,50 do
		Draw("Opaque",i)
	end
	glDepthMask(false)

	--// Draw() (layers: -50 upto 50)
	glAlphaTest(GL_GREATER, 0)
	for i=-50,50 do
		Draw("",i,true)
	end
	glAlphaTest(false)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Unit activity
local activeUnit = {}
local activeUnitCheckTime = {}
local ACTIVE_CHECK_PERIOD = 10

local function GetUnitIsActive(unitID)
	if activeUnitCheckTime[unitID] and activeUnitCheckTime[unitID] > thisGameFrame then
		return activeUnit[unitID]
	end

	activeUnitCheckTime[unitID] = thisGameFrame + ACTIVE_CHECK_PERIOD
	activeUnit[unitID] = (spGetUnitIsActive(unitID) or spGetUnitRulesParam(unitID, "unitActiveOverride") == 1)
		and	(spGetUnitRulesParam(unitID, "disarmed") ~= 1)
		and (spGetUnitRulesParam(unitID, "morphDisable") ~= 1)
		and not spGetUnitIsStunned(unitID)
	return activeUnit[unitID]
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function UpdateAllyTeamStatus()
	local spec, specFullView = spGetSpectatingState()
	if specFullView then
		LocalAllyTeamID = scGetReadAllyTeam() or 0
	else
		LocalAllyTeamID = spGetLocalAllyTeamID() or 0
	end
end

function IsPosInLos(x,y,z)
	if LocalAllyTeamID == 0 then
		UpdateAllyTeamStatus()
	end
	return LocalAllyTeamID == Script.ALL_ACCESS_TEAM or (LocalAllyTeamID ~= Script.NO_ACCESS_TEAM and Spring.IsPosInLos(x,y,z, LocalAllyTeamID))
end

function IsPosInRadar(x,y,z)
	if LocalAllyTeamID == 0 then
		UpdateAllyTeamStatus()
	end
	return LocalAllyTeamID == Script.ALL_ACCESS_TEAM or (LocalAllyTeamID ~= Script.NO_ACCESS_TEAM and Spring.IsPosInRadar(x,y,z, LocalAllyTeamID))
end

function IsPosInAirLos(x,y,z)
	if LocalAllyTeamID == 0 then
		UpdateAllyTeamStatus()
	end
	return LocalAllyTeamID == Script.ALL_ACCESS_TEAM or (LocalAllyTeamID ~= Script.NO_ACCESS_TEAM and Spring.IsPosInAirLos(x,y,z, LocalAllyTeamID))
end

function GetUnitLosState(unitID)
	if LocalAllyTeamID == 0 then
		UpdateAllyTeamStatus()
	end
	return LocalAllyTeamID == Script.ALL_ACCESS_TEAM or (LocalAllyTeamID ~= Script.NO_ACCESS_TEAM and (Spring.GetUnitLosState(unitID, LocalAllyTeamID) or {}).los) or false
end

local function IsUnitFXVisible(fx)
	local unitActive = true
	local unitID = fx.unit
	local unitHealth = spGetUnitHealth(unitID)
	if not unitHealth or unitHealth <= 0 then
		return false
	end
	if fx.onActive then
		unitActive = GetUnitIsActive(unitID)
	end
	if fx.xzVelocity then
		local uvx,_,uvz = Spring.GetUnitVelocity(unitID)
		if math.abs(uvx)+math.abs(uvz) > fx.xzVelocity then
			unitActive = true
		else
			return false
		end
	end
	--Spring.Utilities.UnitEcho(unitID, "w")
	if not fx.onActive or unitActive then
		if fx.alwaysVisible then
			return true
		elseif fx.Visible then
			return fx:Visible()
		else
			local unitRadius = (spGetUnitRadius(unitID) or 0) + 40
			local r = fx.radius or 0
			return Spring.IsUnitVisible(unitID, unitRadius + r, fx.noIconDraw)
		end
	else
		return fx.alwaysVisible
	end
end

local function IsProjectileFXVisible(fx)
	if fx.alwaysVisible then
		return true
	elseif fx.Visible then
		return fx:Visible()
	else
		local proID = fx.projectile
		local x,y,z = Spring.GetProjectilePosition(proID)
		if IsPosInLos(x,y,z) and spIsSphereInView(x,y,z,(fx.radius or 200)+100) then
			return true
		end
	end
end

local function IsWorldFXVisible(fx)
	if fx.alwaysVisible then
		return true
	elseif fx.Visible then
		return fx:Visible()
	elseif fx.pos then
		local pos = fx.pos
		if IsPosInLos(pos[1],pos[2],pos[3]) and spIsSphereInView(pos[1],pos[2],pos[3],(fx.radius or 200)+100) then
			return true
		end
	end
end


local function CreateVisibleFxList()
	local removeFX = {}
	local removeCnt = 1

	for _,fx in pairs(particles) do
		if (fx.unit or -1) > -1 then
			fx.visible = IsUnitFXVisible(fx)
			if fx.visible then
				if not anyFXVisible then anyFXVisible = true end
				if not anyDistortionsVisible then anyDistortionsVisible = fx.pi.distortion end
			end
		elseif (fx.projectile or -1) > -1 then
			fx.visible = IsProjectileFXVisible(fx)
			if fx.visible then
			if not anyFXVisible then anyFXVisible = true end
			if not anyDistortionsVisible then anyDistortionsVisible = fx.pi.distortion end
			end
		else
			fx.visible = IsWorldFXVisible(fx)
			if fx.visible then
				if not anyFXVisible then anyFXVisible = true end
				if not anyDistortionsVisible then anyDistortionsVisible = fx.pi.distortion end
			elseif fx.Valid and not fx:Valid() then
				removeFX[removeCnt] = fx.id
				removeCnt = removeCnt + 1
			end
		end
	end
	--Spring.Echo("Lups fx cnt", particles.GetIndexMax())

	for i=1,removeCnt-1 do
		RemoveParticles(removeFX[i])
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CleanInvalidUnitFX()
	local removeFX = {}
	local removeCnt = 1

	for layerID,layer in pairs(RenderSequence) do
		for partClass,Units in pairs(layer) do
			for unitID,UnitEffects in pairs(Units) do
				if not UnitEffects[1] then
					Units[unitID] = nil
				else
					if unitID>-1 then
						if not spValidUnitID(unitID) then --// UnitID isn't valid anymore, remove all its effects
							for i=1,#UnitEffects do
								local fx = UnitEffects[i]
								removeFX[removeCnt] = fx.id
								removeCnt = removeCnt + 1
							end
							Units[unitID]=nil
						end
					end
				end
			end
		end
	end

	for i=1,removeCnt-1 do
		RemoveParticles(removeFX[i])
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--// needed to allow to use RemoveParticles in :Update of the particleclasses
local fxRemoveList = {}
function BufferRemoveParticles(id)
	fxRemoveList[#fxRemoveList+1] = id
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local lastGameFrame = 0

local function GameFrame(_,n)
	thisGameFrame = n
	if not next(particles) and not effectsInDelay[1] then return end

	--// create delayed FXs
	if effectsInDelay[1] then
		local remaingFXs,cnt={},1
		for i=1,#effectsInDelay do
			local fx = effectsInDelay[i]
			if fx.frame>thisGameFrame then
				remaingFXs[cnt]=fx
				cnt=cnt+1
			else
				AddParticles(fx.class,fx.options, fx.id)
				if fx.frame-thisGameFrame > 0 then
					particles[fx.id]:Update(fx.frame-thisGameFrame)
				end
			end
		end
		effectsInDelay = remaingFXs
	end

	--// cleanup FX from dead/invalid units
	CleanInvalidUnitFX()

	--// update FXs
	framesToUpdate = thisGameFrame - lastGameFrame
	for _,partFx in pairs(particles) do
		if n>=partFx.dieGameFrame then
			--// lifetime ended
			if partFx.repeatEffect then
				if type(partFx.repeatEffect)=="number" then
					partFx.repeatEffect = partFx.repeatEffect - 1
					if (partFx.repeatEffect==1) then partFx.repeatEffect = nil end
				end
				if partFx.ReInitialize then
					partFx:ReInitialize()
				else
					partFx.dieGameFrame = partFx.dieGameFrame + partFx.life
				end
			else
				--// we can't remove items from a table we are iterating atm, so just buffer them and remove them later
				BufferRemoveParticles(partFx.id)
			end
		else
			--// update particles
			if partFx.Update then
				partFx:Update(framesToUpdate)
			end
		end
	end

	--// now we can remove particles
	if #fxRemoveList>0 then
		for i=1,#fxRemoveList do
			RemoveParticles(fxRemoveList[i])
		end
		fxRemoveList = {}
	end
end

local function Update(_,dt)
	UpdateAllyTeamStatus()

	--// update frameoffset
	frameOffset = spGetFrameTimeOffset()

	--// Game Frame Update
	local x = spGetGameFrame()
	if x-lastGameFrame >=1 then
		GameFrame(nil,x)
		lastGameFrame = x
	end

	--// check which fxs are visible
	anyFXVisible = false
	anyDistortionsVisible = false
	if next(particles) then
		CreateVisibleFxList()
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function CheckParticleClassReq(pi)
	return
		(canShader or (not pi.shader))and
		(canFBO or (not pi.fbo))and
		(canRTT or (not pi.rtt))and
		(canCTT or (not pi.ctt))and
		(canDistortions or (not pi.distortion))and
		((not isIntel) or (pi.intel~=0))and
		((not isMS)  or (pi.ms~=0))
end


local function Initialize()
	LupsConfig = LoadConfig("./lups.cfg")

	--// set verbose level
	local showWarnings = LupsConfig.showwarnings
	if showWarnings then
		local t = type(showWarnings)
		if t=="number" then
			printErrorsAbove = showWarnings
		elseif t=="boolean" then
			printErrorsAbove = PRIO_LESS
		end
	end


	--// is distortion is supported?
	DistortionClass = fxClasses["postdistortion"]
	if DistortionClass then
		fxClasses["postdistortion"]=nil --// remove it from default classes
		local di = DistortionClass.pi
		if di and CheckParticleClassReq(di) then
			local fine = true
			if (DistortionClass.Initialize) then fine = DistortionClass.Initialize() end
			if fine~=nil and fine==false then
				print(PRIO_LESS,'LUPS: disabled Distortions');
				DistortionClass=nil
			end
		else
			print(PRIO_LESS,'LUPS: disabled Distortions');
			DistortionClass=nil
		end
	end
	canDistortions = (DistortionClass~=nil)


	--// get list of user disabled fx classes
	local disableFX = {}
	for i,v in pairs(LupsConfig.disablefx or {}) do
		disableFX[i:lower()]=v;
	end

	local linkBackupFXClasses = {}

	--// initialize particle classes
	for fxName,fxClass in pairs(fxClasses) do
		local fi = fxClass.pi --// .fi = fxClass.GetInfo()
		if not disableFX[fxName] and (fi) and CheckParticleClassReq(fi) then
			local fine = true
			if fxClass.Initialize then fine = fxClass.Initialize() end
			if fine~=nil and fine==false then
				print(PRIO_LESS,'LUPS: "' .. fi.name .. '" FXClass removed (class requested it during initialization)');
				fxClasses[fxName]=nil
				if fi.backup and fi.backup~="" then
					linkBackupFXClasses[fxName] = fi.backup:lower()
				end
				if fxClass.Finalize then fxClass.Finalize() end
			end
		else --// unload particle class (not supported by this computer)
			print(PRIO_LESS,'LUPS: "' .. fi.name .. '" FXClass removed (hardware doesn\'t support it)');
			fxClasses[fxName]=nil
			if fi.backup and fi.backup~="" then
				linkBackupFXClasses[fxName] = fi.backup:lower()
			end
		end
	end


	--// link backup FXClasses
	for className,backupName in pairs(linkBackupFXClasses) do
		fxClasses[className]=fxClasses[backupName]
	end

	--// link Distortion Class
	fxClasses["postdistortion"]=DistortionClass

	--// update screen geometric
	--ViewResize(_,handler:GetViewSizes())

	--// make global
	GG.Lups = {}
	GG.Lups.GetStats          = GetStats
	GG.Lups.GetErrorLog       = GetErrorLog
	GG.Lups.AddParticles      = AddParticles
	GG.Lups.GetParticles      = GetParticles
	GG.Lups.RemoveParticles   = RemoveParticles
	GG.Lups.AddParticlesArray = AddParticlesArray
	GG.Lups.HasParticleClass  = HasParticleClass
	GG.Lups.IsPosInLos        = IsPosInLos

	for fncname,fnc in pairs(GG.Lups) do
		handler:RegisterGlobal('Lups_'..fncname,fnc)
	end

	GG.Lups.Config = LupsConfig

	nilDispList = gl.CreateList(function() end)
end

local function Shutdown()
	for fncname,fnc in pairs(GG.Lups) do
		handler:DeregisterGlobal('Lups_'..fncname)
	end
	GG.Lups = nil

	for _,fxClass in pairs(fxClasses) do
		if (fxClass.Finalize) then
			fxClass.Finalize()
		end
	end

	gl.DeleteList(nilDispList)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

this.GetInfo    = GetInfo
this.Initialize = Initialize
this.Shutdown   = Shutdown
this.DrawWorldPreUnit    = DrawParticlesOpaque
this.DrawWorld           = DrawParticles
this.ViewResize = ViewResize
this.Update     = Update
if gadget then
	this.DrawUnit = DrawUnit
	--this.GameFrame  = GameFrame; // doesn't work for unsynced parts >yet<
end
