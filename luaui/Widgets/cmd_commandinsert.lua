-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name = "CommandInsert",
    version = 2,
    desc = "When pressing spacebar and shift, you can insert commands to arbitrary places in queue. When pressing spacebar alone, commands are inserted on front of queue. Based on FrontInsert by jK",
    author = "dizekat",
    date = "Jan,2008",
    license = "GNU GPL, v2 or later",
    layer = 5,
    enabled = true
  }
end


-- Localized functions for performance
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetUnitPosition = Spring.GetUnitPosition
local spGetGameFrame = Spring.GetGameFrame
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spEcho = Spring.Echo

local math_sqrt = math.sqrt

local modifiers = {
	prepend_between = false,
	prepend_queue = false,
}

-- Current position in prepend queue for prepend_queue mode
local prependPos = 0

-- [v2] Failsafe for a lost key-release: if the insert action's key-release is never
-- delivered (the window losing focus while the key is held -- e.g. alt-tab or a
-- compositor key-grab on Wayland), the mode flag stays set and every subsequent order
-- silently becomes a CMD.INSERT. Re-validate the held state against the bound key(s).
local STUCK_GRACE_FRAMES = 3 -- not configurable; frames the key must read released before clearing (avoids a single-frame state race)

local spGetModKeyState = Spring.GetModKeyState
local spGetKeyState = Spring.GetKeyState

local insertKeyCodes -- resolved once, then cached
local insertModifiers
local stuckFrames = 0

-- The keys are bound to the action+arg combinations, not the bare "commandinsert"
-- action, so each combination must be queried for its hotkey(s).
local INSERT_ACTIONS = { "commandinsert prepend_between", "commandinsert prepend_queue" }

local function cacheInsertKeys()
	insertKeyCodes, insertModifiers = {}, {}
	for _, action in ipairs(INSERT_ACTIONS) do
		local hotkeys = Spring.GetActionHotKeys(action)
		if hotkeys then
			for _, hotkey in ipairs(hotkeys) do
				local baseKey = hotkey:match("[^+]+$") -- strip modifier prefixes like "Any+"
				if baseKey then
					baseKey = baseKey:lower()
					if baseKey == "alt" or baseKey == "ctrl" or baseKey == "meta" or baseKey == "shift" then
						insertModifiers[baseKey] = true
					else
						local keyCode = Spring.GetKeyCode(baseKey)
						if keyCode then
							insertKeyCodes[#insertKeyCodes + 1] = keyCode
						end
					end
				end
			end
		end
	end
end

local function isInsertKeyHeld()
	if not insertKeyCodes then
		cacheInsertKeys()
	end

	-- Could not resolve a bound key (e.g. queried before keybinds were loaded): fail safe by
	-- reporting held, so the insert feature is never broken, and retry the lookup next time.
	if not next(insertModifiers) and insertKeyCodes[1] == nil then
		insertKeyCodes = nil
		return true
	end

	if next(insertModifiers) then
		local alt, ctrl, meta, shift = spGetModKeyState()
		if (insertModifiers.alt and alt) or (insertModifiers.ctrl and ctrl)
			or (insertModifiers.meta and meta) or (insertModifiers.shift and shift) then
			return true
		end
	end

	for i = 1, #insertKeyCodes do
		if spGetKeyState(insertKeyCodes[i]) then
			return true
		end
	end

	return false
end

function widget:Update()
	if modifiers.prepend_between or modifiers.prepend_queue then
		if isInsertKeyHeld() then
			stuckFrames = 0
		else
			stuckFrames = stuckFrames + 1
			if stuckFrames >= STUCK_GRACE_FRAMES then
				modifiers.prepend_between = false
				modifiers.prepend_queue = false
				prependPos = 0
				stuckFrames = 0
			end
		end
	else
		stuckFrames = 0
	end
end

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:PlayerChanged()
    if Spring.GetSpectatingState() and spGetGameFrame() > 0 then
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
    if Spring.IsReplay() or spGetGameFrame() > 0 then
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
    tableInsert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      tableInsert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "," ) .. "}"
end
--]]

local function GetUnitOrFeaturePosition(id)
	if id < Game.maxUnits then
		return spGetUnitPosition(id)
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
  -- options.meta not forwarded since we're doing insert with it
  -- and don't want to alias with engine at the same time.
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
    local px,py,pz = spGetUnitPosition(unit_id)
    local min_dlen = 1000000
    local insert_pos = 0
    for j=1,#commands do
      local command = commands[j]
      --spEcho("cmd:"..table.tostring(command))
      local px2,py2,pz2 = GetCommandPos(command)
      if px2 and px2>-1 then
        local dlen = math_sqrt(((px2-cx)*(px2-cx)) + ((py2-cy)*(py2-cy)) + ((pz2-cz)*(pz2-cz))) + math_sqrt(((px-cx)*(px-cx)) + ((py-cy)*(py-cy)) + ((pz-cz)*(pz-cz))) - math_sqrt((((px2-px)*(px2-px)) + ((py2-py)*(py2-py)) + ((pz2-pz)*(pz2-pz))))
        --spEcho("dlen "..dlen)
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
      --spGiveOrderToUnit(unit_id,id,params,options)
      spGiveOrderToUnit(unit_id, id, params, {"shift"})
    else
      spGiveOrderToUnit(unit_id, CMD.INSERT, {insert_pos-1, id, opt, unpack(params)}, {"alt"})
    end
  end

  -- When we are editing the build order we want to keep same active command after unset by engine
  if id < 0 then
    Spring.SetActiveCommand(Spring.GetCmdDescIndex(id), 1, true, false, options.alt, options.ctrl, false, false)
  end

  return true
end
