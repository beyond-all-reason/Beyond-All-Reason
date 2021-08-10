-- This file includes common functionality that should be available globally

VFS.Include('common/numberfunctions.lua')
VFS.Include('common/stringFunctions.lua')
VFS.Include('common/tablefunctions.lua')
VFS.Include('common/springFunctions.lua')

if not (Script.GetSynced and Script.GetSynced()) then
	-- I18N is purely client side and should never be called in a synced context
	VFS.Include("modules/i18n/i18n.lua")
end

Spring.Echo("Baz")
Spring.Echo('string.split', string.split)
Spring.Echo('table.copy', table.copy)
Spring.Foo = true