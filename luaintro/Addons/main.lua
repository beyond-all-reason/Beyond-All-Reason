
if addon.InGetInfo then
	return {
		name    = "Main",
		desc    = "displays a simplae loadbar",
		author  = "jK",
		date    = "2012,2013",
		license = "GPL2",
		layer   = 0,
		depend  = {"LoadProgress"},
		enabled = true,
	}
end

-- for guishader
local function CheckHardware()
	if (not (gl.CopyToTexture ~= nil)) then
		return false
	end
	if (not (gl.RenderToTexture ~= nil)) then
		return false
	end
	if (not (gl.CreateShader ~= nil)) then
		return false
	end
	if (not (gl.DeleteTextureFBO ~= nil)) then
		return false
	end
	if (not gl.HasExtension("GL_ARB_texture_non_power_of_two")) then
		return false
	end
	if Platform ~= nil and Platform.gpuVendor == 'Intel' then
		return false
	end
	return true
end
local guishader = CheckHardware()

local blurIntensity = 0.004
local blurShader
local screencopy
local blurtex
local blurtex2
local stenciltex
local screenBlur = false
local guishaderRects = {}
local guishaderDlists = {}
local oldvs = 0
local vsx, vsy   = Spring.GetViewGeometry()
local ivsx, ivsy = vsx, vsy
local lastLoadMessage = ""

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
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

local vsx,vsy = Spring.GetViewGeometry()
local fontScale = (0.5 + (vsx*vsy / 5700000))/2
local font = gl.LoadFont(fontfile, 64*fontScale, 16*fontScale, 1.4)
local font2 = gl.LoadFont(fontfile2, 64*fontScale, 16*fontScale, 1.4)
local loadedFontSize =  64*fontScale


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

function CreateShaders()

    if (blurShader) then
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
        --widgetHandler:RemoveWidget(self)
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

function gradientv(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(px, sy, 0)
	gl.Vertex(sx, sy, 0)
	gl.Color(c2)
	gl.Vertex(sx, py, 0)
	gl.Vertex(px, py, 0)
end

function gradienth(px,py,sx,sy, c1,c2)
	gl.Color(c1)
	gl.Vertex(sx, sy, 0)
	gl.Vertex(sx, py, 0)
	gl.Color(c2)
	gl.Vertex(px, py, 0)
	gl.Vertex(px, sy, 0)
end

function bartexture(px,py,sx,sy, texLength, texHeight)
	local texHeight = texHeight or 1
	local width = (sx-px) / texLength * 4
	gl.TexCoord(width, texHeight)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(width, 0)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(0,0)
	gl.Vertex(px, py, 0)
	gl.TexCoord(0,texHeight)
	gl.Vertex(px, sy, 0)
end

local lastLoadMessage = ""
local lastProgress = {0, 0}

local progressByLastLine = {
	["Parsing Map Information"] = {0, 15},
	["Loading GameData Definitions"] = {10, 20},
	["Creating Unit Textures"] = {15, 25},
	["Loading Weapon Definitions"] = {20, 50},
	["Loading LuaRules"] = {40, 80},
	["Loading LuaUI"] = {70, 95},
	["[LoadFinalize] finalizing PFS"] = {80, 95},
	["Finalizing"] = {100, 100}
}
for name,val in pairs(progressByLastLine) do
	progressByLastLine[name] = {val[1]*0.01, val[2]*0.01}
end

function addon.LoadProgress(message, replaceLastLine)
	lastLoadMessage = message
	if message:find("Path") then -- pathing has no rigid messages so cant use the table
		lastProgress = {0.8, 1.0}
	end
	lastProgress = progressByLastLine[message] or lastProgress
end

function addon.DrawLoadScreen()
	local loadProgress = SG.GetLoadProgress()
	if loadProgress == 0 then
		loadProgress = lastProgress[1]
	else
		loadProgress = math.min(math.max(loadProgress, lastProgress[1]), lastProgress[2])
	end

	local vsx, vsy = gl.GetViewSizes()

	-- draw progressbar
	local yPos =  0 --0.054
	local loadvalue = math.max(0, loadProgress)
	loadvalue = math.floor((loadvalue * vsx)+0.5) / vsx

	local height = math.floor(vsy * 0.02)
	local borderSize = math.max(1, math.floor(vsy * 0.0007))

	if guishader then
		if not blurShader then
			CreateShaders()
			guishaderRects['loadprocess1'] = {0,0,vsx,height}
			DrawStencilTexture()
		end

		if next(guishaderRects) or next(guishaderDlists) then

			gl.Texture(false)
			gl.Color(1,1,1,1)
			gl.Blending(false)

			gl.CopyToTexture(screencopy, 0, 0, 0, 0, vsx, vsy)
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

			if blurIntensity >= 0.0016 then
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
				gl.Uniform(intensityLoc, blurIntensity*0.5)

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

	-- background
	gl.Color(0.2,0.2,0.2,(blurShader and 0.25 or 0.3))
	gl.Rect(0,0,1,(height/vsy))

	-- border
	gl.Color(0,0,0,0.03)
	gl.Rect(0,((height-borderSize)/vsy),1,(height/vsy))
	-- border at loadvalue rightside
	gl.Rect(loadvalue,0,loadvalue+(borderSize/vsx),(height-borderSize)/vsy)
	-- gradient on top
	gl.BeginEnd(GL.QUADS, gradientv, 0, (height+(height*0.33)/vsy), 1, ((height-borderSize)/vsy), {0,0,0,0}, {0,0,0,0.035})

	-- progress value
	local lightness = 0.3
	gl.Color(lightness + (0.4-(loadProgress/7)), lightness + (loadProgress*0.3), lightness, 0.3)
	gl.Rect(0,0,loadvalue,(height-borderSize)/vsy)
	gl.Blending(GL.SRC_ALPHA, GL.ONE)

	-- background
	gl.Color(0.22,0.22,0.22,0.12)
	gl.Rect(0,0,1,(height/vsy))

	-- progress value
	gl.Color(lightness + (0.4-(loadProgress/7)), lightness + (loadProgress*0.3), lightness, 0.3)
	gl.Rect(0,0,loadvalue,(height-borderSize)/vsy)
	gl.BeginEnd(GL.QUADS, gradientv, 0, 0, loadvalue, ((height-borderSize)/vsy), {1,1,1,0.2}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, 0, loadvalue, (((height-borderSize)*0.3)/vsy), {1,1,1,0}, {1,1,1,0.04})
	-- progress value texture
	gl.Color(lightness + (0.4-(loadProgress/7)), lightness + (loadProgress*0.3), lightness, 0.085)
	gl.Texture(':ng:luaui/images/rgbnoise.png')
	gl.BeginEnd(GL.QUADS, bartexture, 0,0,loadvalue,(height-borderSize)/vsy, (height*7)/vsy, (height*7)/vsy)
	gl.Texture(false)
	-- progress value gloss
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.93)/vsy), loadvalue, ((height-borderSize)/vsy), {1,1,1,0.04}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.77)/vsy), loadvalue, ((height-borderSize)/vsy), {1,1,1,0.03}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.3)/vsy), loadvalue, ((height-borderSize)/vsy), {1,1,1,0.04}, {1,1,1,0})
	-- load value end
	gl.Rect(loadvalue,0,loadvalue+((borderSize*(vsy/vsx))/vsx),(height-borderSize)/vsy)

	-- bar gloss
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.93)/vsy), 1, ((height-borderSize)/vsy), {1,1,1,0.08}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.77)/vsy), 1, ((height-borderSize)/vsy), {1,1,1,0.07}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, (((height-borderSize)*0.3)/vsy), 1, ((height-borderSize)/vsy), {1,1,1,0.08}, {1,1,1,0})
	gl.BeginEnd(GL.QUADS, gradientv, 0, 0, 1, (((height-borderSize)*0.3)/vsy), {1,1,1,0}, {1,1,1,0.017})
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)

	-- progress text
	gl.PushMatrix()
		gl.Scale(1/vsx,1/vsy,1)
		gl.Color(0.1,0.1,0.1,0.8)
		local barTextSize = height*0.66
		font:Print(lastLoadMessage, barTextSize*0.33, barTextSize, barTextSize, "a")
		--if loadProgress>0 then
		--	font2:Print(("%.0f%%"):format(loadProgress * 100), vsx * 0.5, vsy * (yPos-0.03), barTextSize, "oc")
		--else
		--	font:Print("Loading...", vsx * 0.5, vsy * (yPos-0.0285), barTextSize, "oc")
		--end
	gl.PopMatrix()

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
		if (gl.DeleteShader) then
			gl.DeleteShader(blurShader or 0)
		end
		blurShader = nil
	end
	gl.DeleteFont(font)
	gl.DeleteFont(font2)
end
