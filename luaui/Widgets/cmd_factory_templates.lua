function widget:GetInfo()
  return {
    name      = "Factory Templates + Auto-Refill",
    desc      = "Save/apply factory build queue templates, keep queues topped up, and auto-apply to new factories.",
    author    = "you + GPT-5 Pro",
    date      = "2025-08-20",
    license   = "MIT",
    version   = 1,
    layer     = 0,
    enabled   = false, -- enable via F11 widget list or /ft help
  }
end

--------------------------------------------------------------------------------
-- Engine refs
--------------------------------------------------------------------------------

local Echo                    = Spring.Echo
local GetMyTeamID             = Spring.GetMyTeamID
local GetSpectatingState      = Spring.GetSpectatingState
local GetUnitDefID            = Spring.GetUnitDefID
local GetUnitTeam             = Spring.GetUnitTeam
local GetSelectedUnits        = Spring.GetSelectedUnits
local GetFactoryCommands      = Spring.GetFactoryCommands
local GiveOrderToUnit         = Spring.GiveOrderToUnit
local GetUnitPosition         = Spring.GetUnitPosition

local CMD_STOP                = CMD.STOP
local CMD_REPEAT              = CMD.REPEAT
local CMD_INSERT              = CMD.INSERT  -- usually not needed for factories
-- Factory build commands are -unitDefID (negative)
-- e.g. GiveOrderToUnit(factory, -unitDefID, {}, {"shift"})

local glColor                 = gl.Color
local glText                  = gl.Text
local glPushMatrix            = gl.PushMatrix
local glPopMatrix             = gl.PopMatrix
local glTranslate             = gl.Translate
local glBillboard             = gl.Billboard
local glDepthTest             = gl.DepthTest

--------------------------------------------------------------------------------
-- Config (also configurable via /ft chat commands)
--------------------------------------------------------------------------------

local autoRefillEnabled       = true      -- keep queues topped up if low
local refillThreshold         = 2         -- when queue size <= this, top up
local autoApplyNewEnabled     = false     -- if a new factory of known type is finished, apply default template
local clearBeforeApply        = true      -- clear queue when applying
local defaultRepeatOnApply    = true      -- set repeat when applying template
local drawLabels              = true      -- draw floating template labels over factories
local labelColor              = {0.9, 1.0, 0.7, 0.9}

--------------------------------------------------------------------------------
-- State (persisted via widget config)
--------------------------------------------------------------------------------

-- templates[name] = {
--   factoryDefID = 123,          -- (optional) factory unitdef where template was recorded
--   buildList    = { udid1, udid2, ... },  -- sequence to enqueue
-- }
local templates  = {}

-- defaultTemplateByFactoryDef[udid] = "templateName"
local defaultTemplateByFactoryDef = {}

-- assignment[unitID] = { template="name", keep=true }
local assignment = {}

-- per-session (not persisted)
local myTeamID   = nil
local isSpec     = false

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

local function IsMyUnit(unitID)
  return GetUnitTeam(unitID) == myTeamID
end

local function IsFactoryDef(udid)
  local ud = UnitDefs[udid]
  return (ud and ud.isFactory) or false
end

local function IsFactory(unitID)
  local udid = GetUnitDefID(unitID)
  return IsFactoryDef(udid)
end

local function GetFactoryQueue(unitID)
  -- returns ordered list of unitDefIDs from current factory queue
  local cmds = GetFactoryCommands(unitID, 256) or {}
  local out = {}
  for i = 1, #cmds do
    local c = cmds[i]
    -- build command ids are negative unitdefs
    if c.id and c.id < 0 then
      out[#out+1] = -c.id
    end
  end
  return out
end

local function ClearFactoryQueue(factoryID)
  -- STOP clears current queue for factories
  GiveOrderToUnit(factoryID, CMD_STOP, {}, {})
end

local function SetFactoryRepeat(factoryID, on)
  GiveOrderToUnit(factoryID, CMD_REPEAT, { on and 1 or 0 }, {})
end

local function EnqueueBuildList(factoryID, buildList)
  for i = 1, #buildList do
    local udid = buildList[i]
    GiveOrderToUnit(factoryID, -udid, {}, {"shift"})
  end
end

local function ApplyTemplateToFactory(factoryID, tplName, opts)
  local tpl = templates[tplName]
  if not tpl then
    Echo("[FT] No template named '".. tostring(tplName) .."'. Use /ft list.")
    return false
  end

  opts = opts or {}
  local clear  = (opts.clear  ~= nil) and opts.clear  or clearBeforeApply
  local repeatOn = (opts.repeatOn ~= nil) and opts.repeatOn or defaultRepeatOnApply

  if clear then ClearFactoryQueue(factoryID) end
  EnqueueBuildList(factoryID, tpl.buildList)
  SetFactoryRepeat(factoryID, repeatOn)

  return true
end

local function SaveTemplateFromFactory(tplName, factoryID)
  local udid = GetUnitDefID(factoryID)
  if not IsFactoryDef(udid) then
    Echo("[FT] Selected unit is not a factory.")
    return false
  end

  local buildList = GetFactoryQueue(factoryID)
  if #buildList == 0 then
    Echo("[FT] Factory queue is empty; nothing to save.")
    return false
  end

  templates[tplName] = {
    factoryDefID = udid,
    buildList    = buildList,
  }
  defaultTemplateByFactoryDef[udid] = tplName
  Echo(("[FT] Saved template '%s' from %s (%d items).")
    :format(tplName, UnitDefs[udid].humanName or UnitDefs[udid].name, #buildList))
  return true
end

local function ListTemplates()
  local names = {}
  for k,_ in pairs(templates) do names[#names+1] = k end
  table.sort(names)
  Echo("[FT] Templates: " .. ( (#names>0 and table.concat(names, ", ") ) or "(none)"))
end

local function RemoveTemplate(name)
  if templates[name] then
    -- remove defaults pointing to this
    for udid,t in pairs(defaultTemplateByFactoryDef) do
      if t == name then defaultTemplateByFactoryDef[udid] = nil end
    end
    templates[name] = nil
    Echo("[FT] Removed template '"..name.."'.")
  else
    Echo("[FT] No template named '"..name.."'.")
  end
end

local function SelectedFactories()
  local sel = GetSelectedUnits() or {}
  local out = {}
  for i = 1, #sel do
    local u = sel[i]
    if IsMyUnit(u) and IsFactory(u) then
      out[#out+1] = u
    end
  end
  return out
end

local function Assign(factoryID, name, keep)
  assignment[factoryID] = { template = name, keep = keep ~= false }
end

--------------------------------------------------------------------------------
-- Auto refill
--------------------------------------------------------------------------------

local function MaybeRefill(factoryID)
  local a = assignment[factoryID]
  if not a or not a.keep then return end

  local queue = GetFactoryQueue(factoryID)
  if #queue <= refillThreshold then
    local ok = ApplyTemplateToFactory(factoryID, a.template, { clear=false })
    if ok then
      -- keep repeat on; we don't force it here (user might have changed)
    end
  end
end

--------------------------------------------------------------------------------
-- Drawing labels
--------------------------------------------------------------------------------

local function DrawLabel(factoryID, text)
  local x,y,z = GetUnitPosition(factoryID)
  if not x then return end
  glDepthTest(true)
  glPushMatrix()
  glTranslate(x,y+40,z)
  glBillboard()
  glColor(labelColor)
  glText(text, 0, 0, 12, "cno")
  glPopMatrix()
  glColor(1,1,1,1)
  glDepthTest(false)
end

function widget:DrawWorld()
  if not drawLabels then return end
  for unitID,data in pairs(assignment) do
    if IsMyUnit(unitID) then
      local q = GetFactoryQueue(unitID)
      local txt = ("[%s] q:%d%s"):format(data.template or "?", #q, data.keep and " (keep)" or "")
      DrawLabel(unitID, txt)
    end
  end
end

--------------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------------

function widget:Initialize()
  myTeamID = GetMyTeamID()
  isSpec   = select(3, GetSpectatingState())
  if isSpec then
    widgetHandler:RemoveWidget()
    return
  end
  Echo("[FT] Factory Templates loaded. /ft help for commands.")
end

function widget:Shutdown()
  -- nothing
end

-- When a factory finishes, auto apply default template if enabled
function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if unitTeam ~= myTeamID then return end
  if not IsFactoryDef(unitDefID) then return end
  if not autoApplyNewEnabled then return end

  local tplName = defaultTemplateByFactoryDef[unitDefID]
  if tplName and templates[tplName] then
    local ok = ApplyTemplateToFactory(unitID, tplName, { clear=true, repeatOn=defaultRepeatOnApply })
    if ok then
      Assign(unitID, tplName, autoRefillEnabled)
      Echo(("[FT] Applied default '%s' to new %s."):format(
        tplName, UnitDefs[unitDefID].humanName or UnitDefs[unitDefID].name))
    end
  end
end

-- If a factory goes idle, keep topped up
function widget:UnitIdle(unitID, unitDefID, unitTeam)
  if unitTeam ~= myTeamID then return end
  if not IsFactoryDef(unitDefID) then return end
  if autoRefillEnabled then
    MaybeRefill(unitID)
  end
end

-- Also check occasionally (covers partial queues)
function widget:GameFrame(n)
  if (n % 90) ~= 0 then return end  -- ~1.5s @60fps
  if not autoRefillEnabled then return end
  for unitID,_ in pairs(assignment) do
    if IsMyUnit(unitID) then
      MaybeRefill(unitID)
    end
  end
end

--------------------------------------------------------------------------------
-- Config persistence
--------------------------------------------------------------------------------

function widget:GetConfigData()
  return {
    templates                  = templates,
    defaultTemplateByFactoryDef= defaultTemplateByFactoryDef,
    autoRefillEnabled          = autoRefillEnabled,
    refillThreshold            = refillThreshold,
    autoApplyNewEnabled        = autoApplyNewEnabled,
    clearBeforeApply           = clearBeforeApply,
    defaultRepeatOnApply       = defaultRepeatOnApply,
    drawLabels                 = drawLabels,
  }
end

function widget:SetConfigData(data)
  templates                   = data.templates or templates
  defaultTemplateByFactoryDef = data.defaultTemplateByFactoryDef or defaultTemplateByFactoryDef
  autoRefillEnabled           = (data.autoRefillEnabled ~= nil) and data.autoRefillEnabled or autoRefillEnabled
  refillThreshold             = data.refillThreshold or refillThreshold
  autoApplyNewEnabled         = (data.autoApplyNewEnabled ~= nil) and data.autoApplyNewEnabled or autoApplyNewEnabled
  clearBeforeApply            = (data.clearBeforeApply ~= nil) and data.clearBeforeApply or clearBeforeApply
  defaultRepeatOnApply        = (data.defaultRepeatOnApply ~= nil) and data.defaultRepeatOnApply or defaultRepeatOnApply
  drawLabels                  = (data.drawLabels ~= nil) and data.drawLabels or drawLabels
end

--------------------------------------------------------------------------------
-- Chat commands (/ft ...)
--------------------------------------------------------------------------------

local function boolFrom(s, default)
  if s == nil then return default end
  s = tostring(s):lower()
  if s == "1" or s == "true" or s == "on" or s == "yes" then return true end
  if s == "0" or s == "false" or s == "off" or s == "no" then return false end
  return default
end

local function ApplyToTargets(tplName, scope)
  local targets = {}
  if scope == "selected" then
    targets = SelectedFactories()
  else
    -- all my factories
    local myUnits = Spring.GetTeamUnits(myTeamID) or {}
    for i=1,#myUnits do
      local u = myUnits[i]
      if IsFactory(u) then targets[#targets+1] = u end
    end
  end
  if #targets == 0 then
    Echo("[FT] No target factories.")
    return
  end
  local applied = 0
  for i=1,#targets do
    if ApplyTemplateToFactory(targets[i], tplName, {}) then
      Assign(targets[i], tplName, autoRefillEnabled)
      applied = applied + 1
    end
  end
  Echo(("[FT] Applied '%s' to %d factory(ies)."):format(tplName, applied))
end

function widget:TextCommand(cmd)
  if cmd:sub(1,3) ~= "ft " then return end
  local args = {}
  for tok in cmd:gmatch("%S+") do args[#args+1] = tok end
  local sub = args[2]

  if not sub or sub == "help" then
    Echo("[FT] Factory Templates — commands:")
    Echo("  /ft save <name>         - save template from the first selected factory's queue")
    Echo("  /ft apply <name> [selected|all] - apply template to selected or all my factories")
    Echo("  /ft list                - list templates")
    Echo("  /ft rm <name>           - remove a template")
    Echo("  /ft keep <on|off>       - toggle auto-refill for assigned factories")
    Echo("  /ft repeat <on|off>     - set default repeat on apply")
    Echo("  /ft clear <on|off>      - clear queue before apply (default on)")
    Echo("  /ft threshold <n>       - queue length threshold to trigger refill (default 2)")
    Echo("  /ft auto_new <on|off>   - auto-apply default template to newly built factories")
    Echo("  /ft default <name>      - set template as default for the selected factory type")
    Echo("  /ft label <on|off>      - toggle floating labels")
    Echo("Examples:")
    Echo("  /ft save kbot_opening")
    Echo("  /ft apply kbot_opening selected")
    Echo("  /ft default kbot_opening  (with a kbot lab selected)")
    return true
  end

  if sub == "save" and args[3] then
    local name = args[3]
    local sel  = SelectedFactories()
    if #sel == 0 then Echo("[FT] Select a factory.") return true end
    SaveTemplateFromFactory(name, sel[1])
    return true
  elseif sub == "apply" and args[3] then
    local name  = args[3]
    local scope = args[4] or "selected"
    ApplyToTargets(name, scope)
    return true
  elseif sub == "list" then
    ListTemplates()
    return true
  elseif sub == "rm" and args[3] then
    RemoveTemplate(args[3])
    return true
  elseif sub == "keep" and args[3] then
    autoRefillEnabled = boolFrom(args[3], autoRefillEnabled)
    Echo("[FT] auto-refill = " .. tostring(autoRefillEnabled))
    return true
  elseif sub == "repeat" and args[3] then
    defaultRepeatOnApply = boolFrom(args[3], defaultRepeatOnApply)
    Echo("[FT] default repeat = " .. tostring(defaultRepeatOnApply))
    return true
  elseif sub == "clear" and args[3] then
    clearBeforeApply = boolFrom(args[3], clearBeforeApply)
    Echo("[FT] clear-before-apply = " .. tostring(clearBeforeApply))
    return true
  elseif sub == "threshold" and args[3] then
    local n = tonumber(args[3])
    if n and n >= 0 then
      refillThreshold = math.floor(n)
      Echo("[FT] refillThreshold = " .. refillThreshold)
    end
    return true
  elseif sub == "auto_new" and args[3] then
    autoApplyNewEnabled = boolFrom(args[3], autoApplyNewEnabled)
    Echo("[FT] auto-apply to new factories = " .. tostring(autoApplyNewEnabled))
    return true
  elseif sub == "default" and args[3] then
    local name = args[3]
    local sel  = SelectedFactories()
    if #sel == 0 then Echo("[FT] Select a factory.") return true end
    local udid = GetUnitDefID(sel[1])
    if not templates[name] then Echo("[FT] No template named '"..name.."'.") return true end
    defaultTemplateByFactoryDef[udid] = name
    Echo(("[FT] Default for %s set to '%s'."):format(UnitDefs[udid].humanName or UnitDefs[udid].name, name))
    return true
  elseif sub == "label" and args[3] then
    drawLabels = boolFrom(args[3], drawLabels)
    Echo("[FT] draw labels = " .. tostring(drawLabels))
    return true
  end

  Echo("[FT] Unknown command. Use /ft help")
  return true
end
