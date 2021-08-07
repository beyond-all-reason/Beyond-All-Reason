-- This file holds common functions that should be available globally

VFS.Include('initBase.lua')

VFS.Include('common/utilities.lua')
VFS.Include('common/debugFunctions.lua')

if not ( Script.GetSynced() ) then
	-- I18N is purely client side and should never be called in a synced context
	VFS.Include("modules/i18n/i18n.lua")
end
