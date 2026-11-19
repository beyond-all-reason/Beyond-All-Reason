-- Reports the globals it was given, and what a nested include saw, for spec_env_spec.

---@diagnostic disable: undefined-global

local nested = VFS.Include("spec/fixtures/env_probe_nested.lua")

writtenByFixture = "fixture"

return {
	marker = marker,
	springMarker = Spring and Spring.marker,
	springEcho = Spring and Spring.Echo,
	nestedMarker = nested.marker,
}
