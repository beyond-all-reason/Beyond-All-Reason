function widget:GetInfo()
  return {
    name      = "Frame Grapher",
    desc      = "Draw frame time graph in bottom right",
    author    = "Beherith",
    date      = "2020",
    layer     = -10000000000000000000,
    enabled   = false,  --  loaded by default
  }
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spGetTimer = Spring.GetTimer 
local spDiffTimers = Spring.DiffTimers

local deltats = {}
local timerold = 0
local viewSizeX, viewSizeY = 0,0
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:Initialize()
	startframe = Spring.GetGameFrame()
	oldframe = startframe
	viewSizeX, viewSizeY = gl.GetViewSizes()
end

function widget:ViewResize(vsx, vsy)
	viewSizeX, viewSizeY = vsx	, vsy
end

function widget:DrawScreen()
	if timerold==0 then
		timerold=Spring.GetTimer()
	end
	
	local timernew=Spring.GetTimer()
	deltats [#deltats + 1] = Spring.DiffTimers(timernew,timerold)
	
	timerold = timernew

	--draw the bottom half of the screen as 2 seconds
	--width of graph is e.q to 2sec
	--height is 4 px = 1 ms
	gl.PushMatrix()
	gl.Color(0.0, 0.0, 0.0, 1.0)
	gl.Rect(viewSizeX/2,0,viewSizeX,64);
	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.Text("DrawFrame times, top of this black area means 16ms (60fps), 2s window", viewSizeX/2, 48, 16, "d")

	local leftpos = viewSizeX
	local tindex = #deltats
	local xmul = (viewSizeX/2.0)/2000.0
	while leftpos > (viewSizeX/2) and tindex > 1 do-- we are not at halfway yet
		deltat_ms = deltats[tindex]*1000
		if deltat_ms > 16 then
			local badness = math.min((deltat_ms-16.0)/16.0,1.0)
			gl.Color(badness, 1.0-badness, 0.0, 1.0)
		else
			gl.Color(0.0, 1.0, 0.0, 1.0)
		end
		
		if deltat_ms < 100 then -- some minimal sanity
			gl.Rect(leftpos-1,0	,leftpos - deltat_ms*xmul,  deltat_ms*4)
		end
		--Spring.Echo(leftpos,viewSizeY,leftpos - deltat_ms*xmul, viewSizeY - deltat_ms)
		leftpos = leftpos - deltat_ms*xmul
		tindex = tindex - 1
	end
	gl.Color(1.0, 1.0, 1.0, 1.0)
	
	gl.PopMatrix()
end