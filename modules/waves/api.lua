---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Waves
	assert(surface ~= nil, "Waves." .. name .. " called before the wave_director gadget initialized")
	return surface
end

return {
	---@param spec WaveSpec
	---@return boolean started
	Start = function(spec)
		return gadgetSurface("Start").Start(spec)
	end,

	---@param name string
	---@return boolean stopped
	Stop = function(name)
		return gadgetSurface("Stop").Stop(name)
	end,

	---@param name string
	---@return boolean
	IsActive = function(name)
		return gadgetSurface("IsActive").IsActive(name)
	end,

	---@param name string
	---@return WaveStatus|nil
	Status = function(name)
		return gadgetSurface("Status").Status(name)
	end,

	---@param name string
	---@param intensity number
	SetIntensity = function(name, intensity)
		gadgetSurface("SetIntensity").SetIntensity(name, intensity)
	end,

	---@param name string
	---@param overrides table|nil
	Surge = function(name, overrides)
		gadgetSurface("Surge").Surge(name, overrides)
	end,

	---@param name string
	---@param defName UnitDefName
	---@param count integer
	---@param burrowID integer|nil nil for any live burrow
	---@return boolean spawned
	SpawnNamed = function(name, defName, count, burrowID)
		return gadgetSurface("SpawnNamed").SpawnNamed(name, burrowID, defName, count)
	end,

	---@param name string
	---@param burrowID integer|nil nil for any live burrow
	---@return boolean spawned
	SpawnOffWave = function(name, burrowID)
		return gadgetSurface("SpawnOffWave").SpawnOffWave(name, burrowID)
	end,

	---@param name string
	SpawnStructures = function(name)
		gadgetSurface("SpawnStructures").SpawnStructures(name)
	end,

	---@param name string
	---@param amount number
	AddAggression = function(name, amount)
		gadgetSurface("AddAggression").AddAggression(name, amount)
	end,

	---@return string[]
	Names = function()
		return gadgetSurface("Names").Names()
	end,
}
