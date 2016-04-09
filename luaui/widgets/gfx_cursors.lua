
function widget:GetInfo()
	return {
		name = "Cursors",
		desc = "Set a different cursor type with /cursor" ,
		author = "Floris",
		date = "",
		license = "",
		layer = 1,
		enabled = true
	}
end

-- note: first entry should be icons inside base /anims folder
local cursorSets = {'old', 'bar_animated', 'bar_static'}


local Settings = {}
Settings['cursorSet'] = 1

function widget:Initialize()
    SetCursor(cursorSets[Settings['cursorSet']])
end

----------------------------
-- load cursors
function SetCursor(cursorSet)
    local cursorNames = {
        'cursornormal','cursorareaattack','cursorattack','cursorattack',
        'cursorbuildbad','cursorbuildgood','cursorcapture','cursorcentroid',
        'cursorwait','cursortime','cursorwait','cursorunload','cursorwait',
        'cursordwatch','cursorwait','cursordgun','cursorattack','cursorfight',
        'cursorattack','cursorgather','cursorwait','cursordefend','cursorpickup',
        'cursorrepair','cursorrevive','cursorrepair','cursorrestore','cursorrepair',
        'cursormove','cursorpatrol','cursorreclamate','cursorselfd','cursornumber',
        'cursorsettarget','cursorupgmex',
    }
    for i=1, #cursorNames do
        local topLeft = (cursorNames[i] == 'cursornormal')
        if cursorSet == cursorSets[1] then 
            Spring.ReplaceMouseCursor(cursorNames[i], cursorNames[i], topLeft)
        else
            Spring.ReplaceMouseCursor(cursorNames[i], cursorSet..'/'..cursorNames[i], topLeft)
        end
    end
    Spring.Echo('Loaded cursor set: '..cursorSet)
end


function widget:GetConfigData()
    return Settings
end

function widget:SetConfigData(data)
    if (data and type(data) == 'table') then
        Settings = data
    end
end

function widget:TextCommand(command)
    if (string.find(command, "cursor") == 1  and  string.len(command) == 6) then 
		Settings['cursorSet'] = Settings['cursorSet'] + 1
		if not cursorSets[Settings['cursorSet']] then
			Settings['cursorSet'] = 1
		end
		SetCursor(cursorSets[Settings['cursorSet']])
	end
end
