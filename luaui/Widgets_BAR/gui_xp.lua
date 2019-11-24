-- $Id: gui_xp.lua 3395 2008-12-09 16:28:55Z lurker $
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Rank Icons",
    desc      = "Shows a rank icon depending on experience next to units",
    author    = "trepan (idea quantum,jK)",
    date      = "Feb, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  -- loaded by default?
  }
end
--Version = 1.1 (fix on line 173-178 for crash at line 179, commit on 19.12.2011, xponen)
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- speed-ups
local GetUnitDefID         = Spring.GetUnitDefID
local GetUnitExperience    = Spring.GetUnitExperience
local GetAllUnits          = Spring.GetAllUnits
local IsUnitAllied         = Spring.IsUnitAllied
local GetSpectatingState   = Spring.GetSpectatingState

local glDepthTest      = gl.DepthTest
local glDepthMask      = gl.DepthMask
local glAlphaTest      = gl.AlphaTest
local glTexture        = gl.Texture
local glTexRect        = gl.TexRect
local glTranslate      = gl.Translate
local glBillboard      = gl.Billboard
local glDrawFuncAtUnit = gl.DrawFuncAtUnit

local GL_GREATER = GL.GREATER

local min   = math.min
local floor = math.floor

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

local ranks = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
local PWranks = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }

local PWUnits = {}
local unitPowerXpCoeffient = {}
local unitHeights  = {}

local iconsize   = 33
local iconoffset = 14

local rankTexBase = 'LuaUI/Images/ranks/'
local rankTextures = {
  [0] = nil,
  [1] = rankTexBase .. 'rank1.png',
  [2] = rankTexBase .. 'rank2.png',
  [3] = rankTexBase .. 'rank3.png',
  [4] = rankTexBase .. 'star.png',
}
local PWrankTextures = {
  [0] = rankTexBase .. 'PWrank0.png',
  [1] = rankTexBase .. 'PWrank1.png',
  [2] = rankTexBase .. 'PWrank2.png',
  [3] = rankTexBase .. 'PWrank3.png',
  [4] = rankTexBase .. 'PWstar.png',
}

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

--function PWCreate(unitID)
--  PWUnits[unitID] = true
--  SetUnitRank(unitID)
--end

function widget:Initialize()

  --widgetHandler:RegisterGlobal("PWCreate", PWCreate)

  for unitDefID, ud in pairs(UnitDefs) do
    ud.power_xp_coeffient  = ((ud.power / 1000) ^ -0.2) / 6  -- dark magic
    unitPowerXpCoeffient[unitDefID] = ud.power_xp_coeffient
    unitHeights[unitDefID] = ud.height + iconoffset
  end

  local allUnits = GetAllUnits()
  for i=1,#allUnits do
    SetUnitRank(allUnits[i])
  end
end

function widget:Shutdown()
  --widgetHandler:DeregisterGlobal("PWCreate")
  for _,rankTexture in ipairs(rankTextures) do
    gl.DeleteTexture(rankTexture)
  end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function SetUnitRank(unitID)
  --if not GetUnitDefID(unitID) then
  --  return
  --end

  local xp = GetUnitExperience(unitID)
  if (not xp) then
    return
  end
  xp = min(floor(xp / unitPowerXpCoeffient[GetUnitDefID(unitID)]),4)

  if not PWUnits[unitID] then
    if (xp>0) then
      ranks[xp][unitID] = GetUnitDefID(unitID)
    end
  else
    PWranks[xp][unitID] = GetUnitDefID(unitID)
  end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:UnitExperience(unitID,unitDefID,unitTeam, xp, oldXP)

  if xp < 0 then xp = 0 end
  if oldXP < 0 then oldXP = 0 end
  
  local rank    = min(floor(xp / unitPowerXpCoeffient[unitDefID]),4)
  local oldRank = min(floor(oldXP / unitPowerXpCoeffient[unitDefID]),4)

  if (rank~=oldRank) then
	if not PWUnits[unitID] then
      for i=0,rank-1 do ranks[i][unitID] = nil end
      ranks[rank][unitID] = unitDefID
    else
      for i=0,rank-1 do PWranks[i][unitID] = nil end
      PWranks[rank][unitID] = unitDefID
    end
  end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if (IsUnitAllied(unitID)or(GetSpectatingState())) then
    SetUnitRank(unitID)
  end
end


function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  for i=0,4 do ranks[i][unitID] = nil PWranks[i][unitID] = nil end
end


function widget:UnitGiven(unitID, unitDefID, oldTeam, newTeam)
  if (not IsUnitAllied(unitID))and(not GetSpectatingState())  then
    for i=0,4 do ranks[i][unitID] = nil PWranks[i][unitID] = nil end
  end
end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local function DrawUnitFunc(yshift)
  glTranslate(0,yshift,0)
  glBillboard()
  glTexRect(-iconsize+10.5, -9, 10.5, iconsize-9)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
  if chobbyInterface then return end
  if Spring.IsGUIHidden() then return end

  gl.Color(1,1,1,1)
  glDepthMask(true)
  glDepthTest(true)
  glAlphaTest(GL_GREATER, 0.001)

  for i=1,4 do
    if (next(ranks[i])) then
      glTexture( rankTextures[i] )
      for unitID,unitDefID in pairs(ranks[i]) do
        glDrawFuncAtUnit(unitID, false, DrawUnitFunc, unitHeights[unitDefID])
      end
    end
  end
  for i=0,4 do
    if (next(PWranks[i])) then
      glTexture( PWrankTextures[i] )
      for unitID,unitDefID in pairs(PWranks[i]) do
        glDrawFuncAtUnit(unitID, false, DrawUnitFunc, unitHeights[unitDefID])
      end
    end
  end
  glTexture(false)

  glAlphaTest(false)
  glDepthTest(false)
  glDepthMask(false)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
