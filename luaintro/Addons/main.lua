if addon.InGetInfo then
	return {
		name    = "Main",
		desc    = "loadbar and tips",
		author  = "jK, Floris",
		date    = "2012",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

local showTipAboveBar = true
local showTipBackground = false	-- false = tips shown below the loading bar

local gameID
local usingIntelPotato = false
local infolog = VFS.LoadFile("infolog.txt")
if infolog then
	local function lines(str)
		local t = {}
		local function helper(line) table.insert(t, line) return "" end
		helper((str:gsub("(.-)\r?\n", helper)))
		return t
	end

	-- store changelog into array
	local fileLines = lines(infolog)
	for i, line in ipairs(fileLines) do
		if string.sub(line, 1, 3) == '[F='  then
			break
		end
		if string.find(line, 'GL vendor') then
			if string.find(string.lower(line), 'intel') then
				usingIntelPotato = true
			end
		end
		if string.find(line, 'GLSL version') then
			if string.find(string.lower(line), 'intel') then
				usingIntelPotato = true
			end
		end
		if string.find(line, 'GL renderer') then
			if string.find(string.lower(line), 'intel') then
				usingIntelPotato = true
			end
			if string.find(string.lower(line), 'intel') and string.find(string.lower(line), 'arc') then
				usingIntelPotato = false
			end
		end
		if string.find(line, '001] GameID: ') then
			gameID = string.sub(line, string.find(line, ': ')+2)
		end
	end
end

-- use gameID so everyone launching the match will see the same loadscreen
if gameID then
	local seed = tonumber(string.sub(gameID, 1, 4), 16)
	if seed then
		math.randomseed(seed)
	end
end

local loadscreens = {}
local loadscreenPath = "bitmaps/loadpictures/"

local teamList = Spring.GetTeamList()
for _, teamID in ipairs(teamList) do
	local luaAI = Spring.GetTeamLuaAI(teamID)
	if luaAI then
		if luaAI:find("Raptors") then
			loadscreens = VFS.DirList(loadscreenPath.."manual/raptors/")
			if loadscreens[1] then
				break
			end
		elseif luaAI:find("Scavengers") then
			loadscreens = VFS.DirList(loadscreenPath.."manual/scavengers/")
			if loadscreens[1] then
				break
			end
		end
	end
end
if not loadscreens[1] then
	loadscreens = VFS.DirList(loadscreenPath)
end
local backgroundTexture = loadscreens[math.random(#loadscreens)]

if math.random(1,15) == 1 then
	showDonationTip = true
	backgroundTexture = "bitmaps/loadpictures/manual/donations.jpg"
end

local showTips = (Spring.GetConfigInt("loadscreen_tips",1) == 1)
if string.find(backgroundTexture, "guide") then
	showTips = false
end

local hasLowRam = false
local ram = string.match(Platform.hwConfig, '([0-9]*MB RAM)')
if ram ~= nil then
	ram = string.gsub(ram, "MB RAM", "")
end
if tonumber(ram) and tonumber(ram) > 1000 and tonumber(ram) < 11000 then
	hasLowRam = true
end

-- I18N module does not support accessing translation keys by index number, so need to concatenate name
local tipKeys = {
	'alwaysExpand',
	'armyDiversity',
	'assistFactories',
	'autogroups',
	'buildingHotkeys',
	'completelyDisappear',
	'destroyFighters',
	'dGun',
	'dGunAssassin',
	'disableAntiNukes',
	'factoryCannibalism',
	'factoryRepeat',
	'graphicsSettings',
	'groups',
	'howShieldsWork',
	'idleConstructors',
	'ignoreUsers',
	'insertFactoryQuickBuild',
	'joinDiscord',
	'lastCommander',
	'lastNotification',
	'longRangeUnits',
	'mapmarks',
	'mohoGeoExplosion',
	'nanoTurretFight',
	'overflowingEnergy',
	'queues',
	'reclaimWrecks',
	'reportUsers',
	'resurrectFight',
	'screenBombers',
	'selectCommander',
	'selectSameType',
	'separateBuildings',
	'separateBuildings2',
	'shareResources',
	'shareUnits',
	'showMetalSpots',
	'takeUnits',
	'transportBuildings',
	'useAntiAir',
	'useCloak',
	'useDragMove',
	'useFighters',
	'useJuno',
	'useMines',
	'usePause',
	'useRadar',
	'useRadarJammers',
	'useReclaim',
	'useRepair',
	'useSelfDestruct',
	'useSpotters',
	'vehiclesOrBots',
	'windEnergyBuffer',
	'windSpeed',
}

local randomTip = ''
if showTips then
	local index = math.random(#tipKeys)
	randomTip = Spring.I18N('tips.loadscreen.' .. tipKeys[index])
end

if showDonationTip then
	randomTip = Spring.I18N('tips.loadscreen.donations')
end


-- for guishader
local function CheckHardware()
	if not (gl.CopyToTexture ~= nil) then
		return false
	end
	if not (gl.RenderToTexture ~= nil) then
		return false
	end
	if not (gl.CreateShader ~= nil) then
		return false
	end
	if not (gl.DeleteTextureFBO ~= nil) then
		return false
	end
	if not gl.HasExtension("GL_ARB_texture_non_power_of_two") then
		return false
	end
	if Platform ~= nil and Platform.gpuVendor == 'Intel' then
		return false
	end
	return true
end
local guishader = CheckHardware()

local blurIntensity = 0.007
local blurShader
local screencopy
local blurtex
local blurtex2
local stenciltex
local guishaderRects = {}
local guishaderDlists = {}
local vsx, vsy, vpx, vpy   = Spring.GetViewGeometry()
local ivsx, ivsy = vsx, vsy

local wsx, wsy, _, _ = Spring.GetWindowGeometry()
local ssx, ssy, _, _ = Spring.GetScreenGeometry()
if wsx > ssx or wsy > ssy then

end

function lines(str)
	local t = {}
	local function helper(line)
		t[#t + 1] = line
		return ""
	end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

local defaultFont = 'Poppins-Regular.otf'
local fontfile = 'fonts/'..Spring.GetConfigString("bar_font", defaultFont)
if not VFS.FileExists(fontfile) then
	Spring.SetConfigString('bar_font', defaultFont)
	fontfile = 'fonts/'..defaultFont
end

local defaultFont2 = 'Exo2-SemiBold.otf'
local fontfile2 = 'fonts/'..Spring.GetConfigString("bar_font2", defaultFont2)
if not VFS.FileExists(fontfile2) then
	Spring.SetConfigString('bar_font2', defaultFont2)
	fontfile2 = 'fonts/'..defaultFont2
end

local height = math.floor(vsy * 0.038) -- loading bar height (in pixels)

local posYorg = math.floor((0.065 * vsy)+0.5) / vsy
local posX = math.floor(((((posYorg*1.44)*vsy)/vsx) * vsx)+0.5) / vsx

local borderSize = math.max(1, math.floor(vsy * 0.0027))

local fontSize = 40
local fontScale = math.min(3, (0.5 + (vsx*vsy / 3500000)))
local font = gl.LoadFont(fontfile, fontSize*fontScale, (fontSize/2)*fontScale, 1)
local font2Size = 45
local font2 = gl.LoadFont(fontfile2, font2Size*fontScale, (font2Size/4)*fontScale, 1.3)

function DrawStencilTexture()
    if next(guishaderRects) or next(guishaderDlists) then
		if stenciltex then
			gl.DeleteTextureFBO(stenciltex)
		end
		stenciltex = gl.CreateTexture(vsx, vsy, {
			border = false,
			min_filter = GL.NEAREST,
			mag_filter = GL.NEAREST,
			wrap_s = GL.CLAMP,
			wrap_t = GL.CLAMP,
			fbo = true,
		})
    else
        gl.RenderToTexture(stenciltex, gl.Clear, GL.COLOR_BUFFER_BIT ,0,0,0,0)
        return
    end

    gl.RenderToTexture(stenciltex, function()
        gl.Clear(GL.COLOR_BUFFER_BIT,0,0,0,0)
        gl.PushMatrix()
        gl.Translate(-1,-1,0)
        gl.Scale(2/vsx,2/vsy,0)
		for _,rect in pairs(guishaderRects) do
			gl.Rect(rect[1],rect[2],rect[3],rect[4])
		end
		for _,dlist in pairs(guishaderDlists) do
			gl.CallList(dlist)
		end
        gl.PopMatrix()
    end)
end

local function CreateShaders()
    if blurShader then
        gl.DeleteShader(blurShader or 0)
    end

    -- create blur shaders
    blurShader = gl.CreateShader({
        fragment = [[
		#version 150 compatibility
        uniform sampler2D tex2;
        uniform sampler2D tex0;
        uniform float intensity;

        void main(void)
        {
            vec2 texCoord = vec2(gl_TextureMatrix[0] * gl_TexCoord[0]);
            float stencil = texture2D(tex2, texCoord).a;
            if (stencil<0.01)
            {
                gl_FragColor = texture2D(tex0, texCoord);
                return;
            }
            gl_FragColor = vec4(0.0,0.0,0.0,1.0);

            float sum = 0.0;
            for (int i = -1; i <= 1; ++i)
                for (int j = -1; j <= 1; ++j) {
                    vec2 samplingCoords = texCoord + vec2(i, j) * intensity;
                    float samplingCoordsOk = float( all( greaterThanEqual(samplingCoords, vec2(0.0)) ) && all( lessThanEqual(samplingCoords, vec2(1.0)) ) );
                    gl_FragColor.rgb += texture2D(tex0, samplingCoords).rgb * samplingCoordsOk;
                    sum += samplingCoordsOk;
            }
            gl_FragColor.rgb /= sum;
        }
    ]],

        uniformInt = {
            tex0 = 0,
            tex2 = 2,
        },
        uniformFloat = {
            intensity = blurIntensity,
        }
    })

    if (blurShader == nil) then
        --Spring.Log(widget:GetInfo().name, LOG.ERROR, "guishader blurShader: shader error: "..gl.GetShaderLog())
        --widgetHandler:RemoveWidget()
        return false
    end

    -- create blurtextures
    screencopy = gl.CreateTexture(vsx, vsy, {
        border = false,
        min_filter = GL.NEAREST,
        mag_filter = GL.NEAREST,
    })
    blurtex = gl.CreateTexture(ivsx, ivsy, {
        border = false,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
    })
    blurtex2 = gl.CreateTexture(ivsx, ivsy, {
        border = false,
        wrap_s = GL.CLAMP,
        wrap_t = GL.CLAMP,
        fbo = true,
    })

    intensityLoc = gl.GetUniformLocation(blurShader, "intensity")
end

local function gradientv(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(px, sy, 0)
	gl.Vertex(sx, sy, 0)
	gl.Color(c2)
	gl.Vertex(sx, py, 0)
	gl.Vertex(px, py, 0)
end

local function gradienth(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(sx, sy, 0)
	gl.Vertex(sx, py, 0)
	gl.Color(c2)
	gl.Vertex(px, py, 0)
	gl.Vertex(px, sy, 0)
end

local function bartexture(px,py,sx,sy, texLength, texHeight)
	local texHeight = texHeight or 1
	local width = (sx-px) / texLength * 4
	gl.TexCoord(width or 1, texHeight)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(width or 1, 0)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(0,0)
	gl.Vertex(px, py, 0)
	gl.TexCoord(0,texHeight)
	gl.Vertex(px, sy, 0)
end

local lastLoadMessage = ""
local lastProgress = {0, 0}
local progressByLastLine = {
	["Loading Map"] = {0, 10},
	["Parsing Map Information"] = {7, 15},
	["Loading GameData Definitions"] = {10, 20},
	["Creating QuadField and CEGs"] = {13, 22},
	["Creating Unit Textures"] = {16, 25},
	["Creating Sky"] = {19, 35},
	["Loading Weapon Definitions"] = {22, 40},
	["Loading Unit Definitions"] = {25, 45},
	["Loading Feature Definitions"] = {29, 45},
	["Loading Models and Textures"] = {33, 50},
	["Loading Map Tiles"] = {38, 55},
	["Loading Square Textures"] = {43, 55},
	["Creating Projectile Textures"] = {48, 60},
	["Creating Water"] = {54, 65},
	["PathCosts"] = {58, 65},
	["[LoadFinalize] finalizing PFS"] = {62, 65},
	["Loading LuaRules"] = {69, 75},
	["Loading LuaUI"] = {82, 85},
	["Loading Skirmish AIs"] = {90, 95},
	["Finalizing"] = {100, 100}
}
for name,val in pairs(progressByLastLine) do
	progressByLastLine[name] = {val[1]*0.01, val[2]*0.01}
end

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
	if progressByLastLine[message] then
		lastProgress = progressByLastLine[message] or lastProgress
	else
		for msg, v in pairs(progressByLastLine) do
			if msg:find(message) then
				lastProgress = progressByLastLine[msg] or lastProgress
				break
			end
		end
	end
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()

	if not Platform.gl then return end

	if not aspectRatio then
		local texInfo = gl.TextureInfo(backgroundTexture)
		if not texInfo then return end
		aspectRatio = texInfo.xsize / texInfo.ysize
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	local screenAspectRatio = vsx / vsy

	local xDiv = 0
	local yDiv = 0
	local ratioComp = screenAspectRatio / aspectRatio

	if math.abs(ratioComp-1)>0.15 then
		if (ratioComp > 1) then
			yDiv = (1 - ratioComp) * 0.5;
		else
			xDiv = (1 - (1 / ratioComp)) * 0.5;
		end
	end

	-- background
	local scale = 1
	local ssx,ssy,spx,spy = Spring.GetScreenGeometry()
	if ssx / vsx < 1 then	-- adjust when window is larger than the screen resolution
		--scale = ssx / vsx
		--xDiv = xDiv * scale	-- this doesnt work
		--yDiv = yDiv * scale
	end
	gl.Color(1,1,1,1)
	gl.Texture(backgroundTexture)
	gl.TexRect(0+xDiv,(1-scale)+yDiv,scale-xDiv,1-yDiv)
	gl.Texture(false)

	-----------------------
	-- draw loadbar + tip
	-----------------------
	local posY = posYorg

	-- tip
	local tipTextSize = height*0.7
	local tipTextLineHeight = tipTextSize * 1.17
	local wrappedTipText, numLines = font2:WrapText(randomTip, vsx * 1.35)
	local tipLines = lines(wrappedTipText)
	local tipPosYtop = posY + (height/vsy)+(borderSize/vsy) + (posY*0.9) + ((tipTextLineHeight * #tipLines)/vsy)
	if showTips and not showTipBackground and not showTipAboveBar then
		if #tipLines > 1 then
			posY = posY + ( (tipTextLineHeight*0.75/vsy) * (#tipLines-1) )
			tipPosYtop = posY
		else
			tipPosYtop = posY - (tipTextLineHeight* 0.2/vsy)
		end
	end

	local barTextSize = height*0.55

	if guishader then
		if not blurShader then
			CreateShaders()
			guishaderRects['loadprocess1'] = {(posX*vsx)-borderSize, (posY*vsy)-borderSize, (vsx-(posX*vsx))+borderSize, ((posY*vsy)+height+borderSize)}
			if showTips and showTipAboveBar and showTipBackground then
				guishaderRects['loadprocess2'] = {(posX*vsx)-borderSize, ((posY*vsy)+height+borderSize), (vsx-(posX*vsx))+borderSize, tipPosYtop*vsy}
			end
			if usingIntelPotato or hasLowRam then
				guishaderRects['loadprocess3'] = {0, ((usingIntelPotato and hasLowRam) and 0.9 or 0.95)*vsy, vsx,vsy}
			end
			DrawStencilTexture()
		end

		if next(guishaderRects) or next(guishaderDlists) then

			gl.Texture(false)
			gl.Color(1,1,1,1)
			gl.Blending(false)

			gl.CopyToTexture(screencopy, 0, 0, vpx, vpy, vsx, vsy)
			gl.Texture(screencopy)
			gl.TexRect(0,1,1,0)
			gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)

			gl.UseShader(blurShader)
			gl.Uniform(intensityLoc, blurIntensity)
			gl.Texture(2,stenciltex)
			gl.Texture(2,false)

			gl.Texture(blurtex)
			gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
			gl.Texture(blurtex2)
			gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
			gl.UseShader(0)

			if blurIntensity >= 0.0015 then
				gl.UseShader(blurShader)
				gl.Uniform(intensityLoc, blurIntensity*0.5)

				gl.Texture(blurtex)
				gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
				gl.Texture(blurtex2)
				gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
				gl.UseShader(0)
			end

			if blurIntensity >= 0.003 then
				gl.UseShader(blurShader)
				gl.Uniform(intensityLoc, blurIntensity*0.25)

				gl.Texture(blurtex)
				gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
				gl.Texture(blurtex2)
				gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
				gl.UseShader(0)
			end

			if blurIntensity >= 0.005 then
				gl.UseShader(blurShader)
				gl.Uniform(intensityLoc, blurIntensity*0.125)

				gl.Texture(blurtex)
				gl.RenderToTexture(blurtex2, gl.TexRect, -1,1,1,-1)
				gl.Texture(blurtex2)
				gl.RenderToTexture(blurtex, gl.TexRect, -1,1,1,-1)
				gl.UseShader(0)
			end

			gl.Texture(blurtex)
			gl.TexRect(0,1,1,0)
			gl.Texture(false)

			gl.Blending(true)
		end
	end

	local loadProgress = SG.GetLoadProgress()
	if loadProgress == 0 then
		loadProgress = lastProgress[1]
	else
		loadProgress = math.clamp(loadProgress, lastProgress[1], lastProgress[2])
	end

	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()

	local loadvalue = math.max(0, loadProgress) * (1-posX-posX)
	loadvalue = math.floor((loadvalue * vsx)+0.5) / vsx

	-- fade away bottom
	if showTips and not showTipBackground then
		gl.BeginEnd(GL.QUADS, gradientv, 0, 0, 1, tipPosYtop+(height*3/vsy), {0,0,0,0}, {0,0,0,0.55})
	end

	-- border
	gl.Color(0,0,0,0.6)
	gl.Rect(posX,posY+(height/vsy),1-posX,posY+((height+borderSize)/vsy))	-- top
	gl.Rect(posX,posY,1-posX,posY-(borderSize/vsy))	-- bottom
	gl.Rect(posX-(borderSize/vsx),posY-(borderSize/vsy),posX,posY+((height+borderSize)/vsy))	-- left
	gl.Rect(1-posX,posY-(borderSize/vsy),(1-posX)+(borderSize/vsx),posY+((height+borderSize)/vsy))	-- right

	-- background
	gl.Color(0.15,0.15,0.15,(blurShader and 0.55 or 0.7))
	gl.Rect(posX+loadvalue,posY,1-posX,posY+(height/vsy))

	-- progress value
	gl.Color((0.4-(loadProgress/7)), (loadProgress*0.35), 0, 0.85)
	gl.Rect(posX,posY,posX+loadvalue,posY+(height)/vsy)

	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	-- background
	gl.Color(0.2,0.2,0.2,0.12)
	gl.Rect(posX,posY,1-posX,posY+(height/vsy))

	-- progress value
	gl.Color((0.45-(loadProgress/7)), (loadProgress*0.38), 0, 0.2)
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY, posX+loadvalue, posY+((height)/vsy), {1,1,1,0.2}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY, posX+loadvalue, posY+(((height)*0.3)/vsy), {1,1,1,0}, {1,1,1,0.04})
	-- progress value texture
	gl.Color((0.4-(loadProgress/7)), (loadProgress*0.3), 0, 0.19)
	gl.Texture(':ng:luaui/images/rgbnoise.png')
	gl.BeginEnd(GL.QUADS, bartexture, posX,posY,1-posX,posY+((height)/vsy), (height*7)/vsy, (height*7)/vsy)
	gl.Texture(false)

	-- progress value gloss
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY+(((height)*0.93)/vsy), posX+loadvalue, posY+((height)/vsy), {1,1,1,0.18}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY+(((height)*0.77)/vsy), posX+loadvalue, posY+((height)/vsy), {1,1,1,0.15}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY+(((height)*0.3)/vsy),  posX+loadvalue, posY+((height)/vsy), {1,1,1,0.15}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX, posY, posX+loadvalue, posY+(((height)*0.3)/vsy), {1,1,1,0}, {1,1,1,0.01})

	-- bar gloss
	gl.Color(1,1,1, 0.1)
	gl.BeginEnd(GL.QUADS, gradientv, posX+loadvalue, posY+(((height)*0.93)/vsy), 1-posX, posY+((height)/vsy), {1,1,1,0.12}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX+loadvalue, posY+(((height)*0.77)/vsy), 1-posX, posY+((height)/vsy), {1,1,1,0.1}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX+loadvalue, posY+(((height)*0.3)/vsy),  1-posX, posY+((height)/vsy), {1,1,1,0.1}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, posX+loadvalue, posY, 1-posX, posY+(((height)*0.3)/vsy), {1,1,1,0}, {1,1,1,0.018})

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- progress text
	gl.PushMatrix()
	gl.Scale(1/vsx,1/vsy,1)
	gl.Translate(vsx/2, (posY*vsy)+(height*0.68), 0)
	font:SetTextColor(0.88,0.88,0.88,1)
	font:SetOutlineColor(0,0,0,0.85)
	font:Print(lastLoadMessage, 0, 0, barTextSize, "oac")
	gl.PopMatrix()


	if showTips then

		-- tip background
		if showTipBackground and showTipAboveBar then
			gl.Color(0,0,0,(blurShader and 0.22 or 0.3))
			gl.Rect(posX-(borderSize/vsx), posY+(height/vsy)+(borderSize/vsy), 1-posX+(borderSize/vsx), tipPosYtop)

			gl.BeginEnd(GL.QUADS, gradientv, posX-(borderSize/vsx), posY+(height/vsy)+(borderSize/vsy), 1-posX+(borderSize/vsx), tipPosYtop, {1,1,1,0.045}, {1,1,1,0})
			--gl.BeginEnd(GL.QUADS, gradientv, posX-(borderSize/vsx), tipPosYtop-(height/vsy), 1-posX+(borderSize/vsx), tipPosYtop, {1,1,1,0.04}, {1,1,1,0})
			--gl.Color(0,0,0,0.1)
			--gl.Rect(posX, posY+(height/vsy)+(borderSize/vsy), 1-posX, tipPosYtop-(borderSize/vsy))
		end

		-- tip text
		gl.PushMatrix()
		gl.Scale(1/vsx,1/vsy,1)
		gl.Translate(vsx/2, (tipPosYtop*vsy)-(tipTextSize*0.75), 0)
		font2:SetTextColor(1,1,1,1)
		font2:SetOutlineColor(0,0,0,0.8)
		for i,line in pairs(tipLines) do
			font2:Print(line, 0, -tipTextLineHeight*(i-1), tipTextSize, "oac")
		end
		gl.PopMatrix()
	end

	if hasLowRam then
		if usingIntelPotato then
			gl.Color(0.066,0.066,0.066,(blurShader and 0.55 or 0.7))
		else
			gl.Color(0.15,0.15,0.15,(blurShader and 0.55 or 0.7))
		end
		gl.Rect(0,(usingIntelPotato and 0.9 or 0.95),1,usingIntelPotato and 0.95 or 1)
		gl.PushMatrix()
		gl.Scale(1/vsx,1/vsy,1)
		gl.Translate(vsx/2, (usingIntelPotato and 0.938 or 0.988)*vsy, 0)
		font2:SetTextColor(0.8,0.8,0.8,1)
		font2:SetOutlineColor(0,0,0,0.8)
		font2:Print(Spring.I18N('ui.loadScreen.lowRamWarning', { textColor = '\255\200\200\200', warnColor = '\255\255\255\255' }), 0, 0, height*0.66, "oac")
		gl.PopMatrix()
	end
end


function addon.MousePress(...)
	--Spring.Echo(...)
end


function addon.Shutdown()
	if guishader then
		for id, dlist in pairs(guishaderDlists) do
			gl.DeleteList(dlist)
		end
		if blurtex then
			gl.DeleteTextureFBO(blurtex)
			gl.DeleteTextureFBO(blurtex2)
			gl.DeleteTextureFBO(stenciltex)
		end
		gl.DeleteTexture(screencopy or 0)
		if gl.DeleteShader then
			gl.DeleteShader(blurShader or 0)
		end
		blurShader = nil
	end
	gl.DeleteFont(font)
	gl.DeleteFont(font2)
	if backgroundTexture then
		gl.DeleteTexture(backgroundTexture)
	end
end
