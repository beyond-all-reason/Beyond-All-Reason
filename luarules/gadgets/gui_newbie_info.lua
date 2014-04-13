function gadget:GetInfo()
	return {
		name	= 'Newbie Info',
		desc	= 'Displays some heplful info for newbies',
		author	= 'Bluestone',
		version	= 'v1.0',
		date	= 'March 2014',
		license	= 'GNU GPL, v2 or later',
		layer	= -1, --must run before game_initial_spawn, because game_initial_spawn must control the return of GameSteup
		enabled	= true
	}
end

--unsynced only
if gadgetHandler:IsSyncedCode() then
	return false
end

local vsx,vsy = Spring.GetViewGeometry()
local keyInfo --glList for keybind info
local amNewbie 		
local myPlayerID = Spring.GetMyPlayerID()
local _,_,_,myTeamID = Spring.GetPlayerInfo(myPlayerID) 

function gadget:DrawScreen()
	-- are we are newbie?
	amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)

	--remove if after gamestart
	if Spring.GetGameFrame() > 0 then 
		if keyInfo then 
			gl.DeleteList(keyInfo)
		end
		gadgetHandler:RemoveGadget()
		return
	end

	--draw key bind info for newbies
	if amNewbie and keyInfo then
		gl.CallList(keyInfo)
	end
end

-- remove when countdown starts
function gadget:GameSetup()
	if (Spring.GetPlayerTraffic(-1, 4) or 0) > 0 then
		if keyInfo then 
			gl.DeleteList(keyInfo)
		end
		gadgetHandler:RemoveGadget()	
	end
end

function gadget:GameOver()
		if keyInfo then 
			gl.DeleteList(keyInfo)
		end
		gadgetHandler:RemoveGadget()	
end


-- make draw list for newbie info (TODO: for ba:r, transfer to chili)
function gadget:Initialize()
	local indent = 15
	local textSize = 16

	local gaps = 5
	local lines = 11
	local width = 650

	local gapSize = textSize*1.5
	local lineHeight = textSize*1.15
	local height = gaps*gapSize + (lines+1)*lineHeight
	local dx = vsx*0.5-width/2
	local dy = vsy*0.47 + height/2
	local curPos = 0
	
	keyInfo = gl.CreateList(function()
		-- draws background rectangle
		gl.Color(0.1,0.1,.45,0.18)                              
		gl.Rect(dx-5,dy+textSize, dx+width, dy-height)
	
		-- draws black border
		gl.Color(0,0,0,1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(dx-5,dy+textSize)
			gl.Vertex(dx-5,dy-height)
			gl.Vertex(dx+width,dy-height)
			gl.Vertex(dx+width,dy+textSize)
		end)
		gl.Color(1,1,1,1)
	
		-- draws text
		gl.Text("Welcome to BA! Some useful info:", dx, dy, textSize, "o")
		curPos = curPos + gapSize
		gl.Text("Click left mouse and drag to select units.", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Click the right mouse to move units", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("To select orders or build commands, use the unit menu or hotkeys", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("To give an order to selected unit(s), use the left/right mouse", dx+indent, dy-curPos, textSize, "o")	
		curPos = curPos + gapSize
		gl.Text("Select multiple units, right click and drag to give a formation command", dx+indent, dy-curPos, textSize, "o")	
		curPos = curPos + lineHeight
		gl.Text("Hold shift to queue multiple orders", dx+indent, dy-curPos, textSize, "o")	
		curPos = curPos + gapSize
		gl.Text("\255\250\250\0Energy\255\255\255\255 comes from solar collectors, wind/tidal generators and fusions", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("\255\20\20\20Metal\255\255\255\255 comes from metal extractors, which should be placed onto metal spots", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("You can also get metal by using constructors to reclaim dead units!", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + gapSize
		gl.Text("BA has many keybinds", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("For example \255\255\150\000a\255\255\255\255ttack, \255\255\150\0f\255\255\255\255ight, \255\255\150\0r\255\255\255\255epair, \255\255\150\0p\255\255\255\255atrol, r\255\255\150\0e\255\255\255\255claim, \255\255\150\0g\255\255\255\255uard, \255\255\150\0w\255\255\255\255ait", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("With a constructor selected, use \255\255\150\000z\255\255\255\255,\255\255\150\000x\255\255\255\255,\255\255\150\000c\255\255\255\255,\255\255\150\000v\255\255\255\255 to cycle through some useful buildings", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Check out the Balanced Annihilation forum on springrts.com for a list of them", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + gapSize	
		gl.Text("For your first few games, a faction and start position will be chosen for you", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("After that, you will be able to choose your own", dx+indent, dy-curPos, textSize, "o")
		curPos = curPos + lineHeight
		gl.Text("Good luck!", dx+indent, dy-curPos, textSize, "o")

	end)
end