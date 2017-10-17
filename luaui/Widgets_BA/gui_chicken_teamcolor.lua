--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Chicken Team Colour",
    desc      = "Changes the Chicken team colour as the queen gets angrier",
    author    = "TheFatController",
    date      = "Aug 07, 2011",
    license   = "MIT",
    layer     = -9, 
    enabled   = false  --  loaded by default?
  }
end

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI ~= "" then
		if luaAI == "Chicken: Very Easy" or 
		luaAI == "Chicken: Easy" or 
		luaAI == "Chicken: Normal" or 
		luaAI == "Chicken: Hard" or 
		luaAI == "Chicken: Very Hard" or 
		luaAI == "Chicken: Epic!" or 
		luaAI == "Chicken: Custom" or 
		luaAI == "Chicken: Survival" then
			chickensEnabled = true
		end
	end
end

if chickensEnabled == true then
	Spring.Echo("[ChickenDefense: Chicken Team Colour] Activated!")
else
	Spring.Echo("[ChickenDefense: Chicken Team Colour] Deactivated!")
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not Spring.GetGameRulesParam("difficulty")) then
  return false
end

local chickenTeamID = Spring.GetGameRulesParam("chickenTeamID")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GameFrame(n)
  if (n == 1) then
    chickenTeamID = Spring.GetGameRulesParam("chickenTeamID")
  end
  if (n%63< 1) then
    queenAnger = (Spring.GetGameRulesParam("queenAnger") or 0)
    gracePeriod = (Spring.GetGameRulesParam("gracePeriod") or 0)
    queenTime = (Spring.GetGameRulesParam("queenTime") or 0)
    queenAnger = 1 - math.ceil((((Spring.GetGameSeconds()-gracePeriod+queenAnger)/(queenTime-gracePeriod))*100) -0.5) / 100
    Spring.SetTeamColor(chickenTeamID, 1,queenAnger,queenAnger)
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------