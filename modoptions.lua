--  Custom Options Definition Table format
--  NOTES:
--  using an enumerated table lets you specify the options order
--
--  These keywords must be lowercase for LuaParser to read them.
--
--  key:      the string used in the script.txt
--  name:     the displayed name
--  desc:     the description (could be used as a tooltip)
--  hint:     greyed out text that appears in input field when empty
--  type:     the option type ('list','string','number','bool','subheader','separator')
--  def:      the default value
--  min:      minimum value for number options
--  max:      maximum value for number options
--  step:     quantization step, aligned to the def value
--  maxlen:   the maximum string length for string options
--  items:    array of item strings for list options
--  section:  so lobbies can order options in categories/panels
--  scope:    'all', 'player', 'team', 'allyteam'      <<< not supported yet >>>
--  collumn:  moves the option 1 row up if value is greater than the preivous row's one, default: 1
--         |  negative value forces new row, absolute value is used
--         |  zero moves to the left, 1 is default, 2 is half way to the right
--         |  recommened values: for 2 columns: 1 and 2, for 3 columns 1, 1.66, and 2.33
--
--  lock:     if type is bool: hides the table of keys when set to TRUE     <<< can not hide separators >>>
--      |     if type is list: add under each item what it should SHOW when set to
--  unlock:   if type is bool: hides the table of keys when set to FALSE    <<< can not hide separators >>>
--        |   if type is list: add under each item what it should HIDE when set to
--  bitmask:  int (1|2|4|8...etc), for when multiple options can hide an item

local path = "modoptions.json"
local jsonOptionsFile = VFS.LoadFile(path)
if not jsonOptionsFile then
	error("Cannot open modoption file at " .. path)
else
	return Json.decode(jsonOptionsFile)
end

