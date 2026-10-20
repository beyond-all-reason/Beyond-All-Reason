-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {name="Portal dots recording",desc="Opt-in all-team replay diagnostics",author="Codex",license="GPL v2 or later",layer=100000,enabled=true}
end
return VFS.Include("tools/portal_worlds/dots/recorder.lua", getfenv())
