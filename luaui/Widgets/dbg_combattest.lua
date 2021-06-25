function widget:GetInfo()
   return {
      name      = "DBG fightertest",
      desc      = "use /luaui fightertest [unitname1] [unitname2] [unitcount]",
      author    = "Beherith",
      version   = "v1.1",
      date      = "2016",
      license   = "GNU GPL, v3 or later",
      layer     = 200,
      enabled   = false,
   }
end

local maxunits = 200
local feedstep = 20
local mapcx = Game.mapSizeX/2
local mapcz = Game.mapSizeZ/2
local mapcy = Spring.GetGroundHeight(mapcx,mapcz)
local enabled = false
local team1unit = "corvamp"
local team2unit = "corvamp"



local function feedteam(teamid, teamunit)
	local unitcount = Spring.GetTeamUnits(teamid)
	if (#unitcount < maxunits) then
		local cmd = string.format(
			"give %d %s %d @%d,%d,%d",
			feedstep,
			teamunit,
			teamid,
			mapcx + 1500*(math.random() -0.5),
			mapcy,
			mapcz + 1500* (math.random() -0.5)
		)
		Spring.SendCommands({cmd})
	end
end

   
function widget:GameFrame(n)
	if (n % 3 == 0) and enabled then
		feedteam(0, team1unit)
		feedteam(1, team2unit)
	end
end

-- a possible command structure could be:
-- /luaui fightertest [noparams = stop]

-- /luaui fightertest unitdefnamea unitdefnameb targetperteam

local function Split(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

split_string = Split("Hello World!", " ")

function widget:TextCommand(command)
	if (string.find(command, "fightertest") == 1) then 
    Spring.Echo(command)
    enabled = not enabled 
    if enabled then
        local tokens = Split(command," ")
        if tokens[2] then 
          team1unit = tokens[2]
          if tokens[3] then
            team2unit = tokens[3]
            if tokens[4] then
              maxunits = tonumber(tokens[4])
              if maxunits == nil then maxunits = 200 end
            end
          else
            team2unit = team1unit
          end
          
        end
    
    end
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