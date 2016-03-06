function widget:GetInfo()
	return {
		name      = "Comgate",
		desc      = "Commander gate effect.",
		author    = "who you want it to be",
		date      = "June 22, 2007",
		license   = "WTFPL",
		layer     = 0,
		enabled   = false  --  loaded by default?
	}
end

-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

local SYSTEM_ID = -1 -- see LuaUnsyncedRead::GetPlayerTraffic, playerID to get hosts traffic from
local NETMSG_STARTPLAYING = 4 -- see BaseNetProtocol.h, packetID sent during the 3.2.1 countdown
local gameStarting = -1
local gaiaTeamID = Spring.GetGaiaTeamID()

local Lups = WG.Lups

local lupsIDs = {}

local GetPlayerTraffic = Spring.GetPlayerTraffic
local GetGameFrame = Spring.GetGameFrame

local blast = {
  speed        = 0,
  speedSpread  = 0,
  life         = 240,
  lifeSpread   = 10,
  partpos      = "x,0,0 | if(rand()*2>1) then x=0 else x=20 end",
  colormap     = { {0.8, 0.8, 0.8, 0.01}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, },
  rotSpeed     = 0.1,
  rotFactor    = 1.0,
  rotFactorSpread = -2.0,
  rotairdrag   = 0.99,
  rotSpread    = 360,
  size         = 60,
  sizeSpread   = 80,
  sizeGrowth   = 4,
  emitVector   = {0,0,0},
  emitRotSpread = 70,
  texture      = 'bitmaps/PD/Lightningball.TGA',
  count        = 6,
  repeatEffect = false,
  delay				 = 2,
}

local sparks = {
  speed        = 0,
  speedSpread  = 0,
  life         = 400,
  lifeSpread   = 10,
  partpos      = "x,0,0 | if(rand()*2>1) then x=0 else x=20 end",
  colormap     = { {0.8, 0.8, 0.8, 0.01}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, {0, 0, 0, 0.0}, },
  rotSpeed     = 0.1,
  rotFactor    = 1.0,
  rotFactorSpread = -2.0,
  rotairdrag   = 0.99,
  rotSpread    = 360,
  size         = 60,
  sizeSpread   = 80,
  sizeGrowth   = 10,
  emitVector   = {0,0,0},
  emitRotSpread = 30,
  texture      = 'bitmaps/PD/Lightningball.TGA',
  count        = 2,
  repeatEffect = false,
  delay				 = 2,
}

local burst = {
  life       = 120,
  rotSpeed   = 0.5,
  rotSpread  = 1,
  rotairdrag = 1,
  arc        = 90,
  arcSpread  = 0,
  size       = 20,
  sizeSpread = 0,
  colormap   = { {0.7,0.9,0.55, 0.5} },
  directional= true,
  repeatEffect = false,
  count      = 20,
}

local flash = {
  life       = 60,
  size       = 40,
  texture    = "bitmaps/GPL/Lups/groundflash.png",
  colormap   = { {0.55,0.55,0.9, 0.1}, {0.55,0.55,0.9, 0.12},{0.55,0.55,0.9, 0.12},{0.55,0.55,0.9, 0.1}, },
  repeatEffect = false,
}

local groundHalo = {
  life       = 120,
  size       = 40,
  texture    = "bitmaps/GPL/Lups/groundflash.png",
  colormap   = { {0.55,0.55,0.9, 0}, {0.55,0.55,0.9, 0.1},{0.55,0.55,0.9, 0.5},{0.55,0.55,0.9, 0.1}, },
  repeatEffect = false,
}

local jitter = {
	layer=0, 
	life=400, 
	size=50, 
	precision=22, 
	repeatEffect=false,
}

function widget:Shutdown()
	if Lups then
		for lupsID in pairs(lupsIDs) do
			Lups.RemoveParticles(lupsID)
		end
	end
end

local function MergeTable(table1,table2)
  local result = {}
  for i,v in pairs(table2) do 
    if (type(v)=='table') then
      result[i] = MergeTable(v,{})
    else
      result[i] = v
    end
  end
  for i,v in pairs(table1) do 
    if (result[i]==nil) then
      if (type(v)=='table') then
        if (type(result[i])~='table') then result[i] = {} end
        result[i] = MergeTable(v,result[i])
      else
        result[i] = v
      end
    end
  end
  return result
end


function widget:Update()
	if GetGameFrame() > 0 then
		if gameStarting == 10 then
			Spring.Echo("Commander Gate Complete")
		end
		widgetHandler:RemoveWidget()
		return
	end
	--check for 3.2.1 countdown
	--ugly but effective (can also detect by parsing state string)
	--counts forward from 0 to 10
	local previousCountDown = gameStarting
	gameStarting = (GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0)
	if gameStarting > 0 and previousCountDown ~= gameStarting then
		--we need to re-import lups here because it could not be available during init
		Lups = WG.Lups
		if not Lups then
			Spring.Echo("Warning: Commander gate effect requires Lups to be enabled to work.")
			widgetHandler:RemoveWidget()
			return
		end
			Spring.Echo("Initializing Commander Gate")
		for _,teamID in pairs(Spring.GetTeamList()) do
			if teamID ~= gaiaTeamID then
				local x,y,z = Spring.GetTeamStartPosition(teamID)
				if x and y and z then
					if y == 0 then
						y = Spring.GetGroundHeight(x,z)
					end
					for deltaX in pairs({20,0,-20}) do
						for deltaZ in pairs({20,0,-20}) do
							lupsIDs[Lups.AddParticles('GroundFlash',MergeTable({pos={x+deltaX,y+90,z+deltaZ}},groundHalo))] = true
							lupsIDs[Lups.AddParticles('SimpleParticles2',MergeTable({pos={x+deltaX,y+90,z+deltaZ}},blast))] = true
							lupsIDs[Lups.AddParticles('SimpleParticles2',MergeTable({pos={x+deltaX,y+90,z+deltaZ}},sparks))] = true
						end
					end
						lupsIDs[Lups.AddParticles('GroundFlash',MergeTable({pos={x,y+90,z}},flash))] = true
						lupsIDs[Lups.AddParticles('ShieldJitter',MergeTable({pos={x,y+90,z}},jitter))] = true
						Spring.PlaySoundFile("sounds/comgate.wav", 100, x, y+90, z)
				end
			end
		end
	end
end
