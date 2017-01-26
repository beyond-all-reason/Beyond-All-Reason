-- $Id: general.lua 3171 2008-11-06 09:06:29Z det $
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
--
--  file:    nanoupdate.lua
--  brief:   shared code between all nano particle effects
--  authors: jK
--  last updated: Feb. 2010
--
--  Copyright (C) 2010.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
---------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------

local function GetUnitMidPos(unitID)
    local _,_,_, x, y, z = Spring.GetUnitPosition(unitID, true)
    return x, y, z
end

local function GetFeatureMidPos(featureID)
    local _,_,_, x, y, z = Spring.GetFeaturePosition(featureID, true)
    return x, y, z
end

local function GetCmdTag(unitID) 
    local cmdTag = 0
    local cmds = Spring.GetFactoryCommands(unitID,1)
	if (cmds) then
        local cmd = cmds[1]
        if cmd then
           cmdTag = cmd.tag
        end
    end
	if cmdTag == 0 then 
		local cmds = Spring.GetUnitCommands(unitID,1)
		if (cmds) then
			local cmd = cmds[1]
			if cmd then
				cmdTag = cmd.tag
			end
        end
	end 
	return cmdTag
end 


function UpdateNanoParticles(self)
  --// UPDATE START- & FINALPOS
  local lastup = self._lastupdate or (thisGameFrame - 1)
  if (not self._dead)and(thisGameFrame - lastup >= 1) then
    self._lastupdate = thisGameFrame

    --// UPDATE STARTPOS
    local uid = self.unitID
    if Spring.ValidUnitID(uid) then
      self.pos = {Spring.GetUnitPiecePosDir(uid,self.unitpiece)}
    else
      if (not self._dead) then
        --// assigned source unit died
        self._dead = true
        return
      end
    end

    --// UPDATE FINALPOS
    local tid = self.targetID
    if (tid >= 0) then
      if (not self.isFeature) then
        if Spring.ValidUnitID(tid) then
          self.targetpos = {GetUnitMidPos(tid)}
        else
          if (not self._dead) then
            --// assigned target unit died
            self._dead = true
            return
          end
        end
      else
        if Spring.ValidFeatureID(tid) then
          self.targetpos = {GetFeatureMidPos(tid)}
          self.targetpos[2] = self.targetpos[2] + 25
        else
          if (not self._dead) then
            --// assigned target feature died
            self._dead = true
            return
          end
        end
      end
    end

    local cmdTag = GetCmdTag(self.unitID)
    if (cmdTag == 0 or cmdTag ~= self.cmdTag) then
        self._dead = true
        return
    end
  end



  --// UPDATE LOS
  local allied = (self.allyID==LocalAllyTeamID)or(LocalAllyTeamID==Script.ALL_ACCESS_TEAM)
  local lastup_los = self._lastupdate_los or (thisGameFrame - 16)
  if
    (not self._lastupdate_los) or
    ((thisGameFrame - lastup_los > 16)and(not allied))
  then
    self._lastupdate_los = thisGameFrame

    local startPos = self.pos
    local endPos   = self.targetpos

    if (not endPos) then
      --//this just happens when the target feature/unit was already dead when the fx was created
      self._dead = true
      RemoveParticles(self.id)
      return
    end

    if (allied) then
      self.visibility = 1
    else
      self.visibility = 0
      local _,startLos = Spring.GetPositionLosState(startPos[1],startPos[2],startPos[3], LocalAllyTeamID)
      local _,endLos   = Spring.GetPositionLosState(  endPos[1],  endPos[2],  endPos[3], LocalAllyTeamID)

      if (not startLos)and(not endLos) then
        self.visibility = 0
      elseif (startLos and endLos) then
        self.visibility = 1
      elseif (startLos) then
        local dir = Vsub(endPos, startPos)
        local losRayTile = math.ceil(Vlength(dir)/Game.squareSize)
        for i=losRayTile,0,-1 do
          local losPos = Vadd(self.pos,Vmul(dir,i/losRayTile))
          local _,los = Spring.GetPositionLosState(losPos[1],losPos[2],losPos[3], LocalAllyTeamID)
          if (los) then self.visibility = i/losRayTile; break end
        end
        endPos = Vadd(endPos,Vmul(dir,self.visibility-1))
        self.targetpos = endPos
      else --//if (endLos) then
        local dir = Vsub(endPos, startPos)
        local losRayTile = math.ceil(Vlength(dir)/Game.squareSize)
        for i=0,losRayTile do
          local losPos = Vadd(self.pos,Vmul(dir,i/losRayTile))
          local _,los  = Spring.GetPositionLosState(losPos[1],losPos[2],losPos[3], LocalAllyTeamID)
          if (los) then self.visibility = -i/losRayTile; break end
        end
        startPos = Vadd(startPos,Vmul(dir,-self.visibility))
        self.pos = startPos
      end
    end

	
    local dir      = Vsub(endPos, startPos)
    local half_dir = Vmul(dir, 0.5)
    local length   = Vlength(dir)
    self.dir       = dir
    self.normdir   = Vmul( dir, 1/length )
    self._midpos   = Vadd(startPos, half_dir)
    self._radius   = length*0.5 + 200
  end
end
