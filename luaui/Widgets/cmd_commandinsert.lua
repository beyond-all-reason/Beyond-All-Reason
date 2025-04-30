-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local widget = widget ---@type Widget

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

local math_sqrt = math.sqrt

local modifiers = {
	prepend_between = false,
	prepend_queue = false,
}

-- Current position in prepend queue for prepend_queue mode
local prependPos = 0

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:PlayerChanged()
    if Spring.GetSpectatingState() and Spring.GetGameFrame() > 0 then
        widgetHandler:RemoveWidget()
    end
end

local function pressHandler(_, _, args)
	if not args then return end

	if modifiers[args[1]] == nil then return end

	modifiers[args[1]] = true

	if args[1] == 'prepend_queue' then
		prependPos = 0
	end
end

local function releaseHandler(_, _, args)
	if not args then return end

	if modifiers[args[1]] == nil then return end

	modifiers[args[1]] = false
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        widget:PlayerChanged()
    end

	widgetHandler:AddAction("commandinsert", pressHandler, nil, "p")
	widgetHandler:AddAction("commandinsert", releaseHandler, nil, "r")
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
	if id < Game.maxUnits then
		return Spring.GetUnitPosition(id)
	else
		return Spring.GetFeaturePosition(id - Game.maxUnits)
	end
end

local function GetCommandPos(command)	--- get the command position
  if command.id < 0 or command.id == CMD.MOVE or command.id == CMD.REPAIR or command.id == CMD.RECLAIM or
  command.id == CMD.RESURRECT or command.id == CMD.DGUN or command.id == CMD.GUARD or
  command.id == CMD.FIGHT or command.id == CMD.ATTACK then
    if table.getn(command.params) >= 3 then
		  return command.params[1], command.params[2], command.params[3]
	  elseif table.getn(command.params) >= 1 then
		  return GetUnitOrFeaturePosition(command.params[1])
	  end
	end
  return -10,-10,-10
end

function widget:CommandNotify(id, params, options)
  if not (modifiers.prepend_between or modifiers.prepend_queue) then
  	return false
  end

  local opt = 0
  if options.alt then opt = opt + CMD.OPT_ALT end
  if options.ctrl then opt = opt + CMD.OPT_CTRL end
  if options.right then opt = opt + CMD.OPT_RIGHT end
  if options.shift then
    opt = opt + CMD.OPT_SHIFT

	if modifiers.prepend_queue then
		Spring.GiveOrder(CMD.INSERT, { prependPos, id, opt, unpack(params) }, { "alt" })

		prependPos = prependPos + 1

		return true
	end
  else
    Spring.GiveOrder(CMD.INSERT,{0,id,opt,unpack(params)},{"alt"})

    return true
  end

  -- Spring.GiveOrder(CMD.INSERT,{0,id,opt,unpack(params)},{"alt"})
  local my_command = {["id"]=id, ["params"]=params, ["options"]=options}
  local cx,cy,cz = GetCommandPos(my_command)
  if cx < -1 then
    return false
  end

  local units = Spring.GetSelectedUnits()
  for i=1,#units do
    local unit_id = units[i]
    local commands = Spring.GetUnitCommands(unit_id,100)
    local px,py,pz = Spring.GetUnitPosition(unit_id)
    local min_dlen = 1000000
    local insert_pos = 0
    for j=1,#commands do
      local command = commands[j]
      --Spring.Echo("cmd:"..table.tostring(command))
      local px2,py2,pz2 = GetCommandPos(command)
      if px2 and px2>-1 then
        local dlen = math_sqrt(((px2-cx)*(px2-cx)) + ((py2-cy)*(py2-cy)) + ((pz2-cz)*(pz2-cz))) + math_sqrt(((px-cx)*(px-cx)) + ((py-cy)*(py-cy)) + ((pz-cz)*(pz-cz))) - math_sqrt((((px2-px)*(px2-px)) + ((py2-py)*(py2-py)) + ((pz2-pz)*(pz2-pz))))
        --Spring.Echo("dlen "..dlen)
        if dlen < min_dlen then
          min_dlen = dlen
          insert_pos = j
        end
        px,py,pz = px2,py2,pz2
      end
    end
    -- check for insert at end of queue if its shortest walk.
    local dlen = math_sqrt(((px-cx)*(px-cx)) + ((py-cy)*(py-cy)) + ((pz-cz)*(py-cy)))
    if dlen < min_dlen then
      --options.meta=nil
      --options.shift=true
      --Spring.GiveOrderToUnit(unit_id,id,params,options)
      Spring.GiveOrderToUnit(unit_id, id, params, {"shift"})
    else
      Spring.GiveOrderToUnit(unit_id, CMD.INSERT, {insert_pos-1, id, opt, unpack(params)}, {"alt"})
    end
  end

  -- When we are editing the build order we want to keep same active command after unset by engine
  if id < 0 then
    Spring.SetActiveCommand(Spring.GetCmdDescIndex(id), 1, true, false, options.alt, options.ctrl, false, false)
  end

  return true
end
