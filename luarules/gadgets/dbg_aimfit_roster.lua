local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AimFit Roster",
		desc = "Measures aimFromEstimate parameters for every ground-attack weapon slot (modoption aimfit_roster=1, see tools/aimfit/README.md)",
		author = "Aron Wieck",
		layer = 1000001,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local M = {}
	-- Shared maths for the aimFromEstimate fitting gadgets.
	--
	-- Model (unit-local space: x = rightdir, y = updir, z = frontdir):
	--   d  : aim direction the script will be asked for
	--   h = |d.xz|, s = d.y (sin pitch), k = h (cos pitch), d normalised
	--   H = (d.x/h, 0, d.z/h)  yaw forward,  R = (d.z/h, 0, -d.x/h)  yaw right,  U = up
	--   muzzle = c + r0*R + f0*H + f1*(k*H + s*U) + u1*(k*U - s*H)
	-- Linear in the 7 parameters {c.x, c.y, c.z, r0, f0, f1, u1} => least squares.

	local RIDGE = 1e-2

	function M.solve(N, rhs, n)
		local A = {}
		for i = 1, n do
			A[i] = {}
			for j = 1, n do
				A[i][j] = N[i][j]
			end
			A[i][n + 1] = rhs[i]
		end
		for col = 1, n do
			local piv, pv = col, math.abs(A[col][col])
			for r = col + 1, n do
				if math.abs(A[r][col]) > pv then
					piv, pv = r, math.abs(A[r][col])
				end
			end
			if pv < 1e-12 then
				return nil
			end
			A[col], A[piv] = A[piv], A[col]
			for r = 1, n do
				if r ~= col then
					local f = A[r][col] / A[col][col]
					if f ~= 0 then
						for j = col, n + 1 do
							A[r][j] = A[r][j] - f * A[col][j]
						end
					end
				end
			end
		end
		local x = {}
		for i = 1, n do
			x[i] = A[i][n + 1] / A[i][i]
		end
		return x
	end

	function M.basis(d)
		local h = math.sqrt(d[1] * d[1] + d[3] * d[3])
		local L = math.sqrt(h * h + d[2] * d[2])
		local Hx, Hz
		if h > 1e-4 then
			Hx, Hz = d[1] / h, d[3] / h
		else
			Hx, Hz = 0, 1
		end
		local s, k = d[2] / L, h / L
		return {
			{ 1, 0, 0 },
			{ 0, 1, 0 },
			{ 0, 0, 1 },
			{ Hz, 0, -Hx },
			{ Hx, 0, Hz },
			{ k * Hx, s, k * Hz },
			{ -s * Hx, k, -s * Hz },
		}
	end

	M.MODELS = {
		fixed = { 1, 2, 3 },
		yaw = { 1, 2, 3, 4, 5 },
		full = { 1, 2, 3, 4, 5, 6, 7 },
	}

	function M.predictLocal(params, d)
		local B = M.basis(d)
		local x, y, z = 0, 0, 0
		for k = 1, 7 do
			local p = params[k]
			if p ~= 0 then
				x, y, z = x + p * B[k][1], y + p * B[k][2], z + p * B[k][3]
			end
		end
		return x, y, z
	end

	-- samples need .dl (local aim dir) and .muzL (local muzzle); accept(s) selects samples
	function M.fit(samples, modelName, accept)
		local idx = M.MODELS[modelName]
		local n = #idx
		local N, rhs = {}, {}
		for i = 1, n do
			N[i] = {}
			for j = 1, n do
				N[i][j] = 0
			end
			rhs[i] = 0
		end
		local count = 0
		for _, s in ipairs(samples) do
			if s.muzL and s.dl and (accept == nil or accept(s)) then
				count = count + 1
				local B = M.basis(s.dl)
				for i = 1, n do
					local Bi = B[idx[i]]
					for j = 1, n do
						local Bj = B[idx[j]]
						N[i][j] = N[i][j] + Bi[1] * Bj[1] + Bi[2] * Bj[2] + Bi[3] * Bj[3]
					end
					rhs[i] = rhs[i] + Bi[1] * s.muzL[1] + Bi[2] * s.muzL[2] + Bi[3] * s.muzL[3]
				end
			end
		end
		for i = 1, n do
			if idx[i] >= 4 then
				N[i][i] = N[i][i] + RIDGE
			end
		end
		local x = M.solve(N, rhs, n)
		local params = { 0, 0, 0, 0, 0, 0, 0 }
		if x then
			for i = 1, n do
				params[idx[i]] = x[i]
			end
		end
		return params, count, x ~= nil
	end

	function M.unitFrame(unitID)
		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		local f, u, r = Spring.GetUnitVectors(unitID)
		return { p = { ux, uy, uz }, F = f, U = u, R = r }
	end

	function M.toLocal(fr, wx, wy, wz)
		local dx, dy, dz = wx - fr.p[1], wy - fr.p[2], wz - fr.p[3]
		return {
			dx * fr.R[1] + dy * fr.R[2] + dz * fr.R[3],
			dx * fr.U[1] + dy * fr.U[2] + dz * fr.U[3],
			dx * fr.F[1] + dy * fr.F[2] + dz * fr.F[3],
		}
	end

	function M.dirToLocal(fr, dx, dy, dz)
		return {
			dx * fr.R[1] + dy * fr.R[2] + dz * fr.R[3],
			dx * fr.U[1] + dy * fr.U[2] + dz * fr.U[3],
			dx * fr.F[1] + dy * fr.F[2] + dz * fr.F[3],
		}
	end

	function M.toWorld(fr, lx, ly, lz)
		return fr.p[1] + fr.R[1] * lx + fr.U[1] * ly + fr.F[1] * lz,
			fr.p[2] + fr.R[2] * lx + fr.U[2] * ly + fr.F[2] * lz,
			fr.p[3] + fr.R[3] * lx + fr.U[3] * ly + fr.F[3] * lz
	end

	function M.dist(a, b)
		local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
		return math.sqrt(dx * dx + dy * dy + dz * dz)
	end

	function M.stats(errs)
		local n = #errs
		if n == 0 then
			return { n = 0, mean = 0, rms = 0, p90 = 0, max = 0 }
		end
		table.sort(errs)
		local sum, sq = 0, 0
		for _, e in ipairs(errs) do
			sum = sum + e
			sq = sq + e * e
		end
		return {
			n = n,
			mean = sum / n,
			rms = math.sqrt(sq / n),
			p90 = errs[math.max(1, math.ceil(n * 0.9))],
			max = errs[n],
		}
	end

	function M.rng(seed)
		local s = seed % 2147483647
		if s == 0 then
			s = 1
		end
		return function()
			s = (s * 48271) % 2147483647
			return s / 2147483647
		end
	end

	local TIMEOUT_FRAMES = 150
	local GAP_FRAMES = 20
	local YAWS, DISTS, HEIGHTS = 12, { 0.4, 0.8 }, { 0, 60 }

	local spEcho = Spring.Echo
	local spGetUnitWeaponVectors = Spring.GetUnitWeaponVectors
	local spGetUnitWeaponAimFromPos = Spring.GetUnitWeaponAimFromPos
	local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
	local spGetGroundHeight = Spring.GetGroundHeight

	local instances, byUnit, pending, placed = {}, {}, {}, {}
	local started, finished = false, false
	local stats = { done = 0, skippedSpawn = 0 }

	local function log(fmt, ...)
		spEcho(("AIMFIT " .. fmt):format(...))
	end
	local function b2s(b)
		return b and "1" or "0"
	end

	-------------------------------------------------------------------------------
	-- unit / weapon selection
	-------------------------------------------------------------------------------

	local SKIP_NAME_PATTERNS = {
		"_scav$",
		"^raptor",
		"^chip",
		"^critter",
		"^lootbox",
		"^dbg",
		"comlvl%d",
		"^armdecom",
		"^cordecom",
		"^legdecom",
		"_zombie$",
	}
	local SKIP_WEAPON_TYPES = { Shield = true, NoWeapon = true, AircraftBomb = true, Melee = true }

	local function wantUnit(ud)
		if ud.canFly or ud.isFactory then
			return false
		end
		if not ud.weapons or #ud.weapons == 0 then
			return false
		end
		for _, pat in ipairs(SKIP_NAME_PATTERNS) do
			if ud.name:find(pat) then
				return false
			end
		end
		return true
	end

	local function wantWeapon(ud, slot)
		local w = ud.weapons[slot]
		if not w or not w.weaponDef then
			return false
		end
		local wd = WeaponDefs[w.weaponDef]
		if not wd then
			return false
		end
		if SKIP_WEAPON_TYPES[wd.type] or wd.isShield or (wd.interceptor or 0) ~= 0 or wd.stockpile or wd.manualFire then
			return false
		end
		if not wd.canAttackGround or wd.range < 60 then
			return false
		end
		if wd.name:lower():find("noweapon") then
			return false
		end
		return true, wd
	end

	-------------------------------------------------------------------------------
	-- placement
	-------------------------------------------------------------------------------

	local function separation(r1, r2)
		return 1.3 * math.max(r1, r2) + 96
	end

	-- land grid points, computed once
	local landPoints = {}

	local function buildLandPoints()
		for gz = 96, Game.mapSizeZ - 96, 96 do
			for gx = 96, Game.mapSizeX - 96, 96 do
				if spGetGroundHeight(gx, gz) > 8 then
					landPoints[#landPoints + 1] = { gx, gz }
				end
			end
		end
	end

	local function fits(inst, gx, gz)
		local r = inst.range
		local need = 0.85 * r + 48
		if gx < need or gz < need or gx > Game.mapSizeX - need or gz > Game.mapSizeZ - need then
			return false
		end
		for _, o in ipairs(placed) do
			local dx, dz = o.cx - gx, o.cz - gz
			if dx * dx + dz * dz < separation(r, o.range) ^ 2 then
				return false
			end
		end
		return true
	end

	local function makeTargets(inst)
		local list = {}
		for yi = 0, YAWS - 1 do
			local a = math.rad(yi * 360 / YAWS + 7)
			for _, df in ipairs(DISTS) do
				local d = df * inst.range
				for _, hgt in ipairs(HEIGHTS) do
					local x, z = inst.cx + math.sin(a) * d, inst.cz + math.cos(a) * d
					local gh = spGetGroundHeight(x, z)
					if gh > 2 then
						list[#list + 1] = { x, gh + hgt, z }
					end
				end
			end
		end
		local r = M.rng(#list * 7919 + inst.range)
		for i = #list, 2, -1 do
			local j = math.floor(r() * i) + 1
			list[i], list[j] = list[j], list[i]
		end
		return list
	end

	local function spawnInstance(inst, cx, cz)
		inst.cx, inst.cz = cx, cz
		placed[#placed + 1] = inst
		inst.targets = makeTargets(inst)
		-- face the centroid of the targets (arc-limited turrets)
		local sx, sz = 0, 0
		for _, t in ipairs(inst.targets) do
			sx, sz = sx + (t[1] - cx), sz + (t[3] - cz)
		end
		local facing = ({ "north", "east", "south", "west" })[math.floor((math.deg(math.atan2(sx, sz)) % 360 + 45) / 90) % 4 + 1]
		local unitID = Spring.CreateUnit(inst.unitName, cx, spGetGroundHeight(cx, cz), cz, facing, 0)
		if not unitID then
			log("ROSTERSKIP unit=%s w=%d reason=spawn", inst.unitName, inst.weaponNum)
			inst.state = "complete"
			inst.samples = {}
			stats.skippedSpawn = stats.skippedSpawn + 1
			for i = #placed, 1, -1 do
				if placed[i] == inst then
					table.remove(placed, i)
				end
			end
			return
		end
		inst.unitID = unitID
		byUnit[unitID] = inst
		Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
		Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, 0)
		inst.pieceMap = Spring.GetUnitPieceMap(unitID)
		inst.idx, inst.samples, inst.state = 0, {}, "idle"
		inst.nextAt = Spring.GetGameFrame() + 5
	end

	-------------------------------------------------------------------------------
	-- sampling
	-------------------------------------------------------------------------------

	local function nearestPiece(inst, x, y, z)
		local best, bestD = "?", 1e9
		for name, num in pairs(inst.pieceMap) do
			local px, py, pz = spGetUnitPiecePosDir(inst.unitID, num)
			if px then
				local d = (px - x) ^ 2 + (py - y) ^ 2 + (pz - z) ^ 2
				if d < bestD then
					best, bestD = name, d
				end
			end
		end
		return best, math.sqrt(bestD)
	end

	local function beginTarget(inst, frame)
		inst.idx = inst.idx + 1
		local t = inst.targets[inst.idx]
		if not t then
			inst.state = "complete"
			return
		end
		local u, w = inst.unitID, inst.weaponNum
		local fr = M.unitFrame(u)
		local ax, ay, az = spGetUnitWeaponAimFromPos(u, w, t[1], t[2], t[3])
		local s = { t = { t[1], t[2], t[3] }, fr = fr, preAim = { ax, ay, az }, t0 = frame }
		inst.cur = s
		Spring.SetUnitTarget(u, t[1], t[2], t[3], false, true, w)
		Spring.SetUnitWeaponState(u, w, { reloadState = frame, forceAim = 30 })
		inst.state = "dir"
	end

	local function readDir(inst)
		local s, u, w = inst.cur, inst.unitID, inst.weaponNum
		local dx, dy, dz
		local wt = inst.wtype
		if wt == "MissileLauncher" or wt == "TorpedoLauncher" or wt == "StarburstLauncher" then
			dx, dy, dz = s.t[1] - s.preAim[1], s.t[2] - s.preAim[2], s.t[3] - s.preAim[3]
			local l = math.sqrt(dx * dx + dy * dy + dz * dz)
			if l > 0 then
				dx, dy, dz = dx / l, dy / l, dz / l
			end
			if wt == "MissileLauncher" and inst.trajectoryHeight > 0 then
				dy = dy + inst.trajectoryHeight
				l = math.sqrt(dx * dx + dy * dy + dz * dz)
				dx, dy, dz = dx / l, dy / l, dz / l
			end
		else
			local _, _, _, wx, wy, wz = spGetUnitWeaponVectors(u, w)
			dx, dy, dz = wx, wy, wz
		end
		s.dl = M.dirToLocal(s.fr, dx, dy, dz)
		inst.state = "aim"
	end

	local function finishSample(inst, frame, fired)
		local s = inst.cur
		s.fired = fired
		if fired then
			s.muzL = M.toLocal(s.fr, s.muz[1], s.muz[2], s.muz[3])
			s.preAimL = M.toLocal(s.fr, s.preAim[1], s.preAim[2], s.preAim[3])
		end
		inst.samples[#inst.samples + 1] = s
		inst.cur = nil
		Spring.SetUnitTarget(inst.unitID)
		inst.state = "idle"
		inst.nextAt = frame + GAP_FRAMES
	end

	function gadget:ProjectileCreated(proID, ownerID, weaponDefID)
		local inst = byUnit[ownerID]
		if not inst or inst.state ~= "aim" or weaponDefID ~= inst.wdid then
			return
		end
		local s = inst.cur
		if s.firedFlag then
			return
		end
		local mx, my, mz = spGetUnitWeaponVectors(ownerID, inst.weaponNum)
		s.muz = { mx, my, mz }
		s.piece = nearestPiece(inst, mx, my, mz)
		s.firedFlag = true
	end

	-------------------------------------------------------------------------------
	-- evaluation
	-------------------------------------------------------------------------------

	local function fmtParams(p)
		return ("%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f"):format(p[1], p[2], p[3], p[4], p[5], p[6], p[7])
	end

	local function finishInstance(inst)
		local fired = {}
		for _, s in ipairs(inst.samples) do
			if s.fired then
				fired[#fired + 1] = s
			end
		end
		local n = #fired
		-- barrels: pieces with enough shots; firing order = order of first appearance
		local pieceCount, pieceOrder = {}, {}
		for _, s in ipairs(fired) do
			if not pieceCount[s.piece] then
				pieceCount[s.piece] = 0
				pieceOrder[#pieceOrder + 1] = s.piece
			end
			pieceCount[s.piece] = pieceCount[s.piece] + 1
		end
		local barrels = {}
		for _, pn in ipairs(pieceOrder) do
			if pieceCount[pn] >= 4 then
				barrels[#barrels + 1] = pn
			end
		end

		local even = function(s)
			return s.k % 2 == 0
		end
		local odd = function(s)
			return s.k % 2 == 1
		end
		for k, s in ipairs(fired) do
			s.k = k
		end

		local fits = {}
		fits.full = M.fit(fired, "full", even)
		fits.fixed = M.fit(fired, "fixed", even)
		local perPiece = {}
		if #barrels >= 2 then
			for _, pn in ipairs(barrels) do
				perPiece[pn] = M.fit(fired, "full", function(s)
					return s.piece == pn and even(s)
				end)
			end
		end

		local errs = { aimPre = {}, fixed = {}, full = {}, perPiece = {} }
		for _, s in ipairs(fired) do
			if odd(s) then
				errs.aimPre[#errs.aimPre + 1] = M.dist(s.preAimL, s.muzL)
				for _, m in ipairs({ "fixed", "full" }) do
					local x, y, z = M.predictLocal(fits[m], s.dl)
					errs[m][#errs[m] + 1] = M.dist({ x, y, z }, s.muzL)
				end
				local pp = perPiece[s.piece] or fits.full
				local x, y, z = M.predictLocal(pp, s.dl)
				errs.perPiece[#errs.perPiece + 1] = M.dist({ x, y, z }, s.muzL)
			end
		end
		local st = {}
		for k, e in pairs(errs) do
			st[k] = M.stats(e)
		end

		log(
			"ROSTER unit=%s w=%d wd=%s type=%s range=%.0f targets=%d fired=%d eval=%d barrels=%s aimPre=%.2f/%.2f fixed=%.2f/%.2f full=%.2f/%.2f perPiece=%.2f/%.2f",
			inst.unitName,
			inst.weaponNum,
			inst.wdname,
			inst.wtype,
			inst.range,
			#inst.samples,
			n,
			st.aimPre.n,
			#barrels > 0 and table.concat(barrels, ",") or "-",
			st.aimPre.mean,
			st.aimPre.p90,
			st.fixed.mean,
			st.fixed.p90,
			st.full.mean,
			st.full.p90,
			st.perPiece.mean,
			st.perPiece.p90
		)
		-- parameters refitted on all fired samples for the generated data
		local allFull = M.fit(fired, "full")
		log("ROSTERPARAMS unit=%s w=%d piece=- n=%d params=%s", inst.unitName, inst.weaponNum, n, fmtParams(allFull))
		if #barrels >= 2 then
			for order, pn in ipairs(barrels) do
				local p, cnt = M.fit(fired, "full", function(s)
					return s.piece == pn
				end)
				log(
					"ROSTERPARAMS unit=%s w=%d piece=%s order=%d n=%d params=%s",
					inst.unitName,
					inst.weaponNum,
					pn,
					order,
					cnt,
					fmtParams(p)
				)
			end
		end

		if inst.unitID and Spring.ValidUnitID(inst.unitID) then
			byUnit[inst.unitID] = nil
			Spring.DestroyUnit(inst.unitID, false, true)
		end
		for i = #placed, 1, -1 do
			if placed[i] == inst then
				table.remove(placed, i)
			end
		end
		inst.state = "done"
		stats.done = stats.done + 1
	end

	-------------------------------------------------------------------------------
	-- driver
	-------------------------------------------------------------------------------

	local function setup()
		for _, u in ipairs(Spring.GetAllUnits()) do
			Spring.DestroyUnit(u, false, true)
		end
		for _, res in ipairs({ "ms", "es", "m", "e" }) do
			Spring.SetTeamResource(0, res, 1e8)
		end
		local only = Spring.GetModOptions().aimfit_units
		local onlySet
		if only then
			onlySet = {}
			for name in only:gmatch("[^,%s]+") do
				onlySet[name] = true
			end
		end
		local nUnits = 0
		for name, ud in pairs(UnitDefNames) do
			if wantUnit(ud) and (not onlySet or onlySet[name]) then
				local any = false
				for slot = 1, #ud.weapons do
					local ok, wd = wantWeapon(ud, slot)
					if ok then
						any = true
						Script.SetWatchProjectile(wd.id, true)
						local inst = {
							unitName = name,
							weaponNum = slot,
							wdid = wd.id,
							wdname = wd.name,
							wtype = wd.type,
							range = wd.range,
							trajectoryHeight = wd.trajectoryHeight or 0,
							maxHealth = ud.health,
							state = "pending",
						}
						instances[#instances + 1] = inst
						pending[#pending + 1] = inst
					end
				end
				if any then
					nUnits = nUnits + 1
				end
			end
		end
		-- slots whose target ring does not fit on the map can never be placed
		for i = #pending, 1, -1 do
			local inst = pending[i]
			if 2 * (0.85 * inst.range + 48) > math.min(Game.mapSizeX, Game.mapSizeZ) then
				log("ROSTERSKIP unit=%s w=%d reason=range range=%.0f", inst.unitName, inst.weaponNum, inst.range)
				inst.state = "done"
				table.remove(pending, i)
			end
		end
		table.sort(pending, function(a, b)
			return a.range < b.range
		end)
		buildLandPoints()
		log(
			"ROSTERLAYOUT map=%dx%d units=%d instances=%d landPoints=%d",
			Game.mapSizeX,
			Game.mapSizeZ,
			nUnits,
			#pending,
			#landPoints
		)
		started = true
	end

	-- one pass over the land grid: every free point takes the first pending instance that fits
	-- (pending is sorted by ascending range, so bots pack densely and artillery follows later)
	local function schedule()
		if #pending == 0 then
			return
		end
		for _, pt in ipairs(landPoints) do
			for i, inst in ipairs(pending) do
				if fits(inst, pt[1], pt[2]) then
					table.remove(pending, i)
					spawnInstance(inst, pt[1], pt[2])
					break
				end
			end
			if #pending == 0 then
				return
			end
		end
	end

	function gadget:Initialize()
		local enabled = Spring.GetModOptions().aimfit_roster
		if not (enabled == true or enabled == 1 or enabled == "1") then
			gadgetHandler:RemoveGadget(self)
		end
	end

	function gadget:GameFrame(frame)
		if finished then
			return
		end
		if frame == 5 then
			setup()
			return
		end
		if not started then
			return
		end

		if frame % 30 == 5 then
			schedule()
		end

		local active = 0
		for _, inst in ipairs(instances) do
			local st = inst.state
			if st ~= "pending" and st ~= "done" then
				active = active + 1
				if st == "complete" then
					local ok, err = pcall(finishInstance, inst)
					if not ok then
						log("ROSTERERROR unit=%s w=%d err=%s", inst.unitName, inst.weaponNum, tostring(err))
						inst.state = "done"
						stats.done = stats.done + 1
					end
				else
					if frame % 15 == 0 then
						Spring.SetUnitHealth(inst.unitID, inst.maxHealth)
					end
					if st == "idle" then
						if frame >= inst.nextAt then
							beginTarget(inst, frame)
						end
					elseif st == "dir" then
						readDir(inst)
					elseif st == "aim" then
						local s = inst.cur
						if s.firedFlag then
							finishSample(inst, frame, true)
						elseif frame - s.t0 > TIMEOUT_FRAMES then
							finishSample(inst, frame, false)
						end
					end
				end
			end
		end

		if frame % 100 == 0 then
			Spring.SetTeamResource(0, "m", 1e8)
			Spring.SetTeamResource(0, "e", 1e8)
		end
		if frame % 300 == 0 then
			log("ROSTERPROGRESS frame=%d done=%d active=%d pending=%d", frame, stats.done, active, #pending)
		end

		if active == 0 and #pending == 0 then
			finished = true
			log("ROSTERDONE done=%d skippedSpawn=%d", stats.done, stats.skippedSpawn)
			SendToUnsynced("aimfit_done")
		end
	end

else -- unsynced

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("aimfit_done", function()
			Spring.SendCommands("quitforce")
		end)
	end

	function gadget:GameStart()
		Spring.SendCommands("setminspeed 20", "setmaxspeed 20", "setspeed 20")
	end

end
