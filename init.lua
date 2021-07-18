VFS.Include('common/numberfunctions.lua')
VFS.Include('common/utilities.lua')

VFS.Include("modules/flowui/flowui.lua")

if not Script.GetSynced() then
	-- I18N is purely client side and should never be called in a synced context
	VFS.Include("modules/i18n/i18n.lua")
end