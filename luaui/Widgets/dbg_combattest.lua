function widget:GetInfo()
   return {
      name      = "DBG fightertest",
      desc      = "use /luaui givecore, /luaui givearm and /luaui givefeatures",
      author    = "Beherith",
      version   = "v1.1",
      date      = "2016",
      license   = "GNU GPL, v3 or later",
      layer     = 200,
      enabled   = false,
   }
end

local maxfighters = 200
local feedstep = 20
local mapcx = Game.mapSizeX/2
local mapcz = Game.mapSizeZ/2
local mapcy = Spring.GetGroundHeight(mapcx,mapcz)
local enabled = false
local testunit = "armbull"

local function feedteam(teamid)
	local unitcount = Spring.GetTeamUnits(teamid)
	if (#unitcount < maxfighters) then
		local cmd = string.format(
			"give %d %s %d @%d,%d,%d",
			feedstep,
			testunit,
			teamid,
			mapcx + 2000*math.random(),
			mapcy,
			mapcz + 2000*math.random()
		)
		Spring.SendCommands({cmd})
	end
end

   
function widget:GameFrame(n)
	if (n % 3 == 0) and enabled then
		feedteam(0, 'armfig')
		feedteam(1, 'corveng')
	end
end

function widget:TextCommand(command)
	--Spring.Echo(command)
	if (string.find(command, "fightertest") == 1) then 
		enabled = not enabled 
	end
end
	

--[[
function widget:TextCommand(command)
	--Spring.Echo(command)
	if (string.find(command, "givearm") == 1) then GiveStuff("Arm") end
	if (string.find(command, "givecore") == 1) then GiveStuff("Core") end
	if (string.find(command, "givefeatures") == 1) then GiveFeatures() end
end

function GiveStuff(key)
  -- Spring.SendCommands({"say .cheat 1"}) -- enable cheating
  --reserve a 
  local cnt=0
  local mx, my= Spring.GetMouseState()
  local at, pos=Spring.TraceScreenRay(mx,my,true,false)
  Spring.Echo(at)
  if at ~= "ground" then return end
  
  cx,cy,cz = Spring.GetCameraPosition()
  local x=0
  local y=0
  local spacing=128
	for udid,ud in pairs(UnitDefs) do
		if (ud.customParams) and ud.customParams["normaltex"] then
			Spring.Echo(ud.customParams["normaltex"], string.find(ud.customParams["normaltex"],key ) )
			if (string.find(ud.customParams["normaltex"],key ) ) then
				--Spring.SetCameraTarget(pos[1]+x, pos[2], pos[3]+y)
				x=x+spacing
				if x> 10*spacing then
					x=0
					y=y+spacing
				end
				cmd="give 1 " .. ud.name .. " 0 @"..math.floor(pos[1])+x .. "," ..  math.floor(pos[2]) ..",".. math.floor( pos[3]+y ) 
				Spring.Echo(cmd)
				Spring.SendCommands({cmd})
			end
		end
	end 
end
function GiveFeatures()
  Spring.SendCommands({"cheat 1"}) -- enable cheating

  local cnt=0
  local mx, my= Spring.GetMouseState()
  local at, pos=Spring.TraceScreenRay(mx,my,true,false)
  Spring.Echo(at)
  if at ~= "ground" then return end
  
  cx,cy,cz = Spring.GetCameraPosition()
  local x=0
  local y=0
  local spacing=192
  local cols = 60
	for id,featureDef in pairs(FeatureDefs) do
		if string.find(featureDef.name,"treetype") == nil and 
			string.find(featureDef.name,'_heap') == nil and 
			string.find(featureDef.name,'_dead') == nil then 
		
			x=x+spacing
			if x + pos[1] > Game.mapSizeX then
				x=0
				y=y+spacing
			end
			cmd="give 1 " .. featureDef.name .. " @"..math.floor(pos[1])+x .. "," ..  math.floor(pos[2]) ..",".. math.floor( pos[3]+y ) 
			Spring.Echo(cmd)
			Spring.SendCommands({cmd})
		end
	end
end
]]--