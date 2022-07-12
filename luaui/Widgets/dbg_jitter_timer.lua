

function widget:GetInfo()
	return {
		name = "Jitter Timer",
		desc = "Draw the sim time offset from real time. Allows adding drawframe load via /drawframeload X (millisecs) and simframeload via /gameframeload Y (millisecs)",
		author = "Beherith",
		date = "2022.02.01",
		license = "GPLv2",
		layer = -200000,
		enabled = false, --  loaded by default
	}
end

--------------------------- INFO -------------------------------
-- You can also add an exponential component to the load in ms with a second number param to the /****frameload commands


---------------------------Speedups-----------------------------
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers 
---------------------------Internal vars---------------------------


local viewSizeX, viewSizeY = 0,0
local timerstart = nil

local drawtimer = 0
local drawtimesmooth = 0
local simtime = 0
local camX, camY, camZ
local cammovemean = 0
local cammovespread = 0 
local camalpha = 0.03

function widget:Initialize()
	drawtimer = Spring.GetTimer()
	timerstart = Spring.GetTimer()
	timerold = Spring.GetTimer()
	viewSizeX, viewSizeY = gl.GetViewSizes()
	--simtime = Spring.GetGameFrame()/30
	camX, camY, camZ = Spring.GetCameraPosition()
end

local gameframeload = 0
local drawframeload = 0
local gameframespread = 0
local drawframespread = 0


local function Loadms(millisecs, spread)
	if spread ~= nil then millisecs = millisecs + math.min(10*spread, -1.0 * spread * math.log(1.0 - math.random())) end 
	--Spring.Echo(millisecs)
	local starttimer = Spring.GetTimer()
	local nowtimer
	for i = 1, 10000000 do
		nowtimer = Spring.GetTimer()
		if Spring.DiffTimers(nowtimer, starttimer )*1000 >= millisecs then 
			break
		end
	end
	--Spring.Echo("Load millisecs = ", Spring.DiffTimers(nowtimer,starttimer)*1000)
end

function widget:TextCommand(command)
	words = {}
	for substring in command:gmatch("%S+") do
		table.insert(words, substring)
	end
	
	if words and words[1] == "gameframeload" then
		gameframeload = tonumber(words[2]) or 0 
		gameframespread = tonumber(words[3]) or 0
		Spring.Echo("Setting gameframeload to ", gameframeload, "spread", gameframespread)
	end
	
	if words and words[1] == "drawframeload" then
		drawframeload = tonumber(words[2]) or 0 
		drawframespread = tonumber(words[3]) or 0
		Spring.Echo("Setting drawframeload to ", drawframeload, "spread", drawframespread)
	end
	
end

function widget:ViewResize(vsx, vsy)
	viewSizeX, viewSizeY = vsx	, vsy
end

function widget:Shutdown()
end

local wasgameframe = 0
local prevframems = 0
local gameFrameHappened = false
local drawspergameframe = 0
local actualdrawspergameframe = 0

function widget:GameFrame(n)
  simtime = simtime + 1
  wasgameframe =  wasgameframe + 1
  gameFrameHappened = true
  if drawspergameframe ~= 2 then
	--Spring.Echo(drawspergameframe, "draws instead of 2", n)
  end
  actualdrawspergameframe = drawspergameframe
  drawspergameframe = 0
  if gameframeload > 0 then Loadms(gameframeload, gameframespread) end
end

local timerwidth = 512
local timerheight = 64
local timerYoffset = 128

local correctionfactor = 0
local avgjitter = 0.0
local alpha = 0.01
local drawduration

--- CTO uniformity
lastdrawCTO = Spring.GetGameFrame()
averageCTO = 0
spreadCTO = 0

function widget:DrawScreen()
	local newcamx, newcamy, newcamz = Spring.GetCameraPosition()
	local deltacam = math.sqrt(math.pow(newcamx- camX,2) + math.pow(newcamz - camZ, 2))-- + math.pow(newcamy - camY, 2))
	cammovemean = (camalpha) * deltacam + (1.0 - camalpha) * cammovemean
	cammovespread = camalpha * math.abs(cammovemean - deltacam) + (1.0 - camalpha) * cammovespread
	camX = newcamx
	camY = newcamy
	camZ = newcamz
	local camerarelativejitter = cammovespread / math.max(cammovemean, 0.001)

	drawspergameframe = drawspergameframe + 1 
	local drawpersimframe = math.floor(Spring.GetFPS()/30.0 +0.5 )
	local fto = Spring.GetFrameTimeOffset()
	
	local timernew = spGetTimer()
	drawtimesmooth = spDiffTimers(timernew, drawtimer) + correctionfactor
	local smoothsimtime = (simtime + fto) / 30
	local deltajitter = smoothsimtime - drawtimesmooth
	avgjitter = (1.0 - alpha) * avgjitter + math.abs(alpha * deltajitter)
	correctionfactor = correctionfactor + deltajitter * alpha

	local lastframeduration = spDiffTimers(timernew, timerold)*1000 -- in MILLISECONDS
	timerold = timernew
	local lastframetime = spDiffTimers(timernew, timerstart) * 1000 -- in MILLISECONDS

	local CTOError = 0

	local currdrawCTO = Spring.GetGameFrame() + fto
	local currCTOdelta = currdrawCTO - lastdrawCTO
	lastdrawCTO = currdrawCTO
	spreadCTO = (1.0 - alpha) * spreadCTO + alpha * math.abs(averageCTO - currCTOdelta)
	averageCTO = (1.0 - alpha ) * averageCTO + alpha * currCTOdelta

	if drawpersimframe == 2 then
		CTOError = 4 * math.min(math.abs(fto-0.5), math.abs(fto))
	elseif drawpersimframe ==3 then
		CTOError = 6 * math.min(math.min(math.abs(fto-0.33), math.abs(fto -0.66)), math.abs(fto))
	elseif drawpersimframe ==4 then
		CTOError = 8 * math.min(math.min(math.abs(fto-0.25), math.abs(fto -0.5)), math.min(math.abs(fto), math.abs(fto-0.75)))
	end
	--Spring.Echo(Spring.GetGameFrame(), fto, CTOError)

	gl.PushMatrix()
	gl.Color(0.0, 0.0, 0.0, 1.0)
	gl.Rect(viewSizeX - timerwidth,viewSizeY - timerYoffset,viewSizeX,viewSizeY - timerYoffset + timerheight);
	gl.Color(1.0, 0.0, 1.0, 1.0)
	gl.Rect(viewSizeX - (timerwidth*0.5),viewSizeY - timerYoffset + timerheight /2 ,viewSizeX + timerwidth * 0.5 - (timerwidth * (1.0 - deltajitter*30)),viewSizeY - timerYoffset + timerheight );
	
	gl.Color(0.0, 0.5, 0.0, 1.0)
	gl.Rect(viewSizeX - (timerwidth*0.5),viewSizeY - timerYoffset ,viewSizeX + timerwidth * 0.5 - (timerwidth * (1.0 - spreadCTO)),viewSizeY - timerYoffset + timerheight / 2);
	
	
	
	
	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.Text(string.format("DrawFrame FTODelta = %.3f  FTO = %.3f", currCTOdelta, fto), viewSizeX - timerwidth, viewSizeY - timerYoffset, 16, "d")
	
	gl.Text(string.format("deltajitter = %.3f  d/s = %d", deltajitter * 30, actualdrawspergameframe), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight - 16, 16, "d")
	gl.Text(string.format("mean jitter = %.3f  ", avgjitter* 30), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight-32, 16, "d")
	
	gl.Text(string.format("averageCTO = %.3f, spreadCTO = %.3f  ", averageCTO, spreadCTO ), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight-48, 16, "d")
	
	
	--gl.Text(string.format("CamSpread = %.3f, CamMean = %.3f deltacam = %.3f jitter = %.3f",cammovespread, cammovemean, deltacam,camerarelativejitter), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight-84, 16, "d")
	gl.Text(string.format("CamJitter = %.3f",camerarelativejitter), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight-84, 16, "d")
	gl.Text(string.format("DrawFrame = %d",Spring.GetDrawFrame()), viewSizeX - timerwidth, viewSizeY - timerYoffset + timerheight-116, 32, "d")
	gl.Color(1.0, 1.0, 1.0, 1.0)
	
	gl.PopMatrix()
	
	if drawframeload > 0 then Loadms(drawframeload, drawframespread) end
end


