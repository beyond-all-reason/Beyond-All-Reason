-- $Id: Sound.lua 3171 2008-11-06 09:06:29Z det $
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local Sound = {}
Sound.__index = Sound

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

function Sound.GetInfo()
  return {
    name      = "Sound",
    backup    = "",
    desc      = "Plays '.wav'-files",
    layer     = 0,
  }
end

Sound.Default = {
  layer = 0,
  worldspace = true,

  file   = '',
  volume = 1.0,
  pos    = nil, --{0,0,0}
  blockfor = 55, --//in gameframes. used to block the sound for a specific amount of time (-> don't oversample the sound)
  length = 60,

  unit   = -1,

  repeatEffect = false,
  dieGameFrame = math.huge
}

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

local lastPlayed = {}

function Sound:Valid()
  return true
end

function Sound:ReInitialize()
  self:CreateParticle()
end

function Sound:CreateParticle()
  --// play sound and exit
  local pos    = self.pos

  if (self.unit) then
    local losState = Spring.GetUnitLosState(self.unit,LocalAllyTeamID) or {}
    if not(losState and losState.los) then return false end
    pos = {Spring.GetUnitPosition(self.unit)}
  end

  if (self.file) then
    if (thisGameFrame>(lastPlayed[self.file] or 0)) then  --// is the sound blocked?
      lastPlayed[self.file] = thisGameFrame + self.blockfor
      if (pos) then
        Spring.PlaySoundFile(self.file,self.volume,pos[1],pos[2],pos[3], 'sfx')
      else
        Spring.PlaySoundFile(self.file,self.volume, 'sfx')
      end
    end
  end

  self.dieGameFrame = Spring.GetGameFrame() + self.length
end

function Sound.Create(Options)
  local newObject = MergeTable(Options, Sound.Default)
  setmetatable(newObject,Sound)  -- make handle lookup
  newObject:CreateParticle()
  if (not newObject.repeatEffect) then
    --// destroy object
    return false
  end
  return newObject
end


function Sound:Destroy()
end

-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

return Sound