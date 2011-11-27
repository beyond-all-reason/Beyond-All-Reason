--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Last Msg. Pos.",
    version   = "0.9",
    desc      = "Goes to the last pointer",
    author    = "Pako",
    date      = "2010.11.26",
    license   = "GNU GPL, v2 or later",
    layer     = -1,
    enabled   = true
  }
end

function widget:Initialize()
  --widgetHandler:AddAction("LastMsgPos", LastMsgPos)
  widgetHandler:AddAction("lastmsgpos", LastMsgPos) --gets called before the engine action
end

function widget:Shutdown()
  widgetHandler:RemoveAction("lastmsgpos", LastMsgPos)
end

local lastPositions = {{},{},{}}
local nCount = 1
local nPoint = 0

function LastMsgPos(cmd, optLine, optWords, _,isRepeat, release)
  if release then return true end
  
  local a,c,m, shift = Spring.GetModKeyState()
  --local poss = Spring.GetLastMessagePositions()
  if shift then
    nPoint = nPoint - 1
  else
    nPoint = nPoint + 1
  end
  nPoint = math.min(nCount-1, math.max(1, nPoint))
  local x,y,z = unpack(lastPositions[nCount-nPoint])
  Spring.SetCameraTarget(x,y,z, 0.4)
  return true
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, label)
  lastPositions[nCount] = {px, py, pz}
  nCount = (nCount + 1)
  nPoint = 0
end