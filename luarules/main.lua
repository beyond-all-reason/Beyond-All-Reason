local gradualSolars = {}
local sleep4FramesSolars = {}
function GameFrame(n)
	if not spawnFrame then
		spawnFrame = n + (3 * Game.gameSpeed)
		for _, unitID in pairs(Spring.GetAllUnits()) do
			Spring.DestroyUnit(unitID, false, true)
		end
	end

	if n == spawnFrame then
		for i = 1, 10 do
		for j = 1, 10 do
			local x = 1000 + i*80
			local z = 1000 + j*80
			gradualSolars[#gradualSolars + 1] = Spring.CreateUnit("armsolar", x, Spring.GetGroundHeight(x, z), z, 0, 0)
		end end

		for i = 1, 10 do
		for j = 1, 10 do
			local x = 2000 + i*80
			local z = 1000 + j*80
			sleep4FramesSolars[#sleep4FramesSolars + 1] = Spring.CreateUnit("armsolar", x, Spring.GetGroundHeight(x, z), z, 0, 0)
		end end
	end

	if n == spawnFrame + 4 then
		for _, unitID in pairs(sleep4FramesSolars) do
			Spring.SetUnitHealth(unitID, { build = 0.9 })
		end
	end

	local id = n-spawnFrame+1
	if id >= 1 and id <= 100 then
		Spring.SetUnitHealth(gradualSolars[id], { build = 0.9 })
	end

	if n > spawnFrame + (5 * Game.gameSpeed) and n % 4 == 0 then
		for _, unitID in pairs(Spring.GetAllUnits()) do
			Spring.SetUnitHealth(unitID, { build = (math.random() < 0.3) and 1 or (0.5 + math.random()*0.5) }) -- small build% doesn't draw enough to be visible
		end
	end
end

Script.UpdateCallIn("GameFrame")

do return end

if (select == nil) then
  select = function(n,...)
    local arg = arg
    if (not arg) then arg = {...}; arg.n = #arg end
    return arg[((n=='#') and 'n')or n]
  end
end

VFS.Include(Script.GetName() .. '/gadgets.lua', nil, VFS.ZIP_ONLY)
