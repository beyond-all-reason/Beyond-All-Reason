-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name = "CommandInsert",
    desc = "When pressing spacebar and shift, you can insert commands to arbitrary places in queue. When pressing spacebar alone, commands are inserted on front of queue. Based on FrontInsert by jK",
    author = "dizekat",
    date = "Jan,2008",
    license = "GNU GPL, v2 or later",
    layer = 5,
    enabled = true
  }
end

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:PlayerChanged(playerID)
    if Spring.GetSpectatingState() and Spring.GetGameFrame() > 0 then
        widgetHandler:RemoveWidget(self)
    end
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end
end

--[[
-- use this for debugging:
function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end
--]]

local function GetUnitOrFeaturePosition(id)
	if id<=Game.maxUnits then
		return Spring.GetUnitPosition(id)
	else
		return Spring.GetFeaturePosition(id-Game.maxUnits)
	end
end

local function GetCommandPos(command)	--- get the command position
  if command.id<0 or command.id==CMD.MOVE or command.id==CMD.REPAIR or command.id==CMD.RECLAIM or 
  command.id==CMD.RESURRECT or command.id==CMD.DGUN or command.id==CMD.GUARD or 
  command.id==CMD.FIGHT or command.id==CMD.ATTACK then
    if table.getn(command.params)>=3 then
		  return command.params[1], command.params[2], command.params[3]			
	  elseif table.getn(command.params)>=1 then
		  return GetUnitOrFeaturePosition(command.params[1])
	  end	
	end
  return -10,-10,-10
end

function widget:CommandNotify(id, params, options)
  local _,_,meta,_ = Spring.GetModKeyState()
  if (meta) then
    local opt = 0
    local insertfront=false
    if options.alt then opt = opt + CMD.OPT_ALT end
    if options.ctrl then opt = opt + CMD.OPT_CTRL end    
    if options.right then opt = opt + CMD.OPT_RIGHT end
    if options.shift then 
      opt = opt + CMD.OPT_SHIFT       
    else
      Spring.GiveOrder(CMD.INSERT,{0,id,opt,unpack(params)},{"alt"})
      return true
    end
    
    -- Spring.GiveOrder(CMD.INSERT,{0,id,opt,unpack(params)},{"alt"})
    local my_command={["id"]=id,["params"]=params,["options"]=options}
    local cx,cy,cz=GetCommandPos(my_command)
    if cx < -1 then
      return false
    end
    
    local units=Spring.GetSelectedUnits()
    for i, unit_id in ipairs(units) do
      local commands=Spring.GetCommandQueue(unit_id,100)
      local px,py,pz=Spring.GetUnitPosition(unit_id)
      local min_dlen=1000000
      local insert_tag=0
      local insert_pos=0
      for i, command in ipairs(commands) do
        --Spring.Echo("cmd:"..table.tostring(command))
        local px2,py2,pz2=GetCommandPos(command)
        if px2>-1 then
          local dlen=math.sqrt(((px2-cx)^2)+((py2-cy)^2)+((pz2-cz)^2))+math.sqrt(((px-cx)^2)+((py-cy)^2)+((pz-cz)^2)) - math.sqrt((((px2-px)^2)+((py2-py)^2)+((pz2-pz)^2)))
          --Spring.Echo("dlen "..dlen)
          if dlen<min_dlen then
            min_dlen=dlen
            insert_tag=command.tag
            insert_pos=i
          end
          px,py,pz=px2,py2,pz2
        end   
      end
      -- check for insert at end of queue if its shortest walk.
      local dlen=math.sqrt(((px-cx)^2)+((py-cy)^2)+((pz-cz)^2))          
      if dlen<min_dlen then
        --options.meta=nil
        --options.shift=true
        --Spring.GiveOrderToUnit(unit_id,id,params,options)
        Spring.GiveOrderToUnit(unit_id,id,params,{"shift"})
      else   
        Spring.GiveOrderToUnit(unit_id,CMD.INSERT,{insert_pos-1,id,opt,unpack(params)},{"alt"})
      end
    end
    return true
  end
  return false
end
