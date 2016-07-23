
function widget:GetInfo()
	return {
		name = "Cursors",
		desc = "Toggle a different cursor set with /cursor" ,
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
Settings['cursorSet'] = 2

function widget:Initialize()
	if Settings['cursorSet'] >= #cursorSets then
		cursorSets = #cursorSets
	end
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
        if cursorSet == 'old' then 
            Spring.ReplaceMouseCursor(cursorNames[i], cursorNames[i], topLeft)
        else
            Spring.ReplaceMouseCursor(cursorNames[i], cursorSet..'/'..cursorNames[i], topLeft)
        end
    end
    
    local result = ''
    local color = ''
    local separator = ''
    for i=1, #cursorSets do
	    if cursorSets[i] == cursorSet then
	    	color = '\255\255\255\255'
	    else
	    	color = '\255\200\200\200'
	    end
    	result = result..separator..'  '..color..cursorSets[i]..'  '
    	separator = '|'
    end
    Spring.Echo('Loaded \255\255\255\255cursor\255\200\200\200:'..result)
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
