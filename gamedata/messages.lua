
--[[ engine death messages as of 13/09/13:
    "Player %i (%s) resigned and is now spectating!"     -- when a player resigns (note: these ones don't get parsed by messages.lua anyway)
	"Team %i is no more" ]								 -- when a team dies because all its players resigned (note: can't use %s when replacing these)
	"Team %i (lead by %s) is no more" 					 -- when a team dies because it was killed
--]]
	
--[[ 
How BA death messages work:
1. return an empty table from messages.lua; this leaves engine death messages untouched
2. red_console receives the engines death messages and replaces them within the console (so the infolog contains just the engine ones)
3. the table of death messages used by red_console is in luaui/config/death_messages.lua
4. this is currently the least hacky thing to do...
--]]

return {}