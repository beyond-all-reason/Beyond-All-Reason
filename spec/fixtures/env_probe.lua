-- Reports the globals it was given and what a nested include sees, so a spec can
-- prove an env reaches the code under test and its dependencies alike.

---@diagnostic disable: undefined-global

local nested = VFS.Include("spec/fixtures/env_probe_nested.lua")

writtenByFixture = "fixture"

return {
	marker = marker,
	springMarker = Spring and Spring.marker,
	springEcho = Spring and Spring.Echo,
	nestedMarker = nested.marker,
}
