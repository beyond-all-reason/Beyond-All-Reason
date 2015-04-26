function widget:GetInfo()
	return {
		name = "Partial hotfix for stuck in draw mode",
		desc = "Consumes return if pressed in combination with draw keys" ,
		author = "Bluestone",
		date = "",
		license = "WTFPL",
		layer = 0,
		enabled = true
	}
end

-- hacky hotfix for http://springrts.com/mantis/view.php?id=4455
-- see also https://github.com/spring/spring/blob/develop/rts/Game/UI/KeyCodes.cpp and https://github.com/spring/spring/blob/develop/cont/LuaUI/Headers/keysym.h.lua
include('keysym.h.lua')
local BACKQUOTE = KEYSYMS.BACKQUOTE
local BACKSLASH = KEYSYMS.BACKSLASH
local PAR = KEYSYMS.WORLD_23
local Q = KEYSYMS.Q 
local RETURN = KEYSYMS.RETURN
local wasDrawKey = false
function widget:KeyPress(key, mods, isRepeat)
    if key==RETURN and (Spring.GetKeyState(BACKQUOTE) or Spring.GetKeyState(BACKSLASH) or Spring.GetKeyState(PAR) or Spring.GetKeyState(Q)) then
        return true
    end
end
