-- $Id:$
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

--// Timers are unsynced objects
if (SendToUnsynced) then
	return
end

function Spring.Utilities.TimeCheck(name, func,...)
	local t=Spring.GetTimer()
	func(...)
	Spring.Echo(("%s %.2fsec"):format(name, Spring.DiffTimers(Spring.GetTimer(),t)))
end