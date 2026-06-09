--------------------------------------------------------------------------------
-- Minimal 16-bit greyscale PNG codec for the Terraform Brush heightmap export.
--
-- Why this exists:
--   gl.SaveImage only writes 8-bit (256 height levels -> visible terracing on
--   re-import), and its grayscale16bit option is broken for framebuffer reads
--   (engine MakeGrayScale collapses 8-bit input to black). SpringRTS maps use
--   16-bit heightmaps, so we build the PNG ourselves from the full-precision
--   float heights -> 65536 levels, standard greyscale format that pymapconv /
--   World Machine read directly.
--
-- Constraints this code works around:
--   * Spring's Lua uses single-precision floats (LUA_NUMBER = float): integers
--     above 2^24 are inexact, so CRC32 is computed in 16-bit halves (each <=
--     65535) and never materialised as a full 32-bit number.
--   * math.bit_xor is 24-bit only; all XOR operands here are <= 16 bits.
--   * A PNG IDAT payload is exactly a zlib stream, which VFS.ZlibCompress /
--     VFS.ZlibDecompress produce/consume (zlib's compress()/uncompress()).
--------------------------------------------------------------------------------

local floor    = math.floor
local schar    = string.char
local sbyte    = string.byte
local ssub     = string.sub
local tconcat  = table.concat
local bxor     = math.bit_xor
local abs      = math.abs

local ZlibCompress   = VFS.ZlibCompress
local ZlibDecompress = VFS.ZlibDecompress

--------------------------------------------------------------------------------
-- CRC32 in 16-bit halves (value = hi * 65536 + lo, each half exact under float32)
--------------------------------------------------------------------------------

local crcHiT, crcLoT = {}, {}
for n = 0, 255 do
	local hi, lo = 0, n
	for _ = 1, 8 do
		local lsb = lo % 2
		-- (hi,lo) >> 1
		local nlo = floor(lo / 2) + (hi % 2) * 32768
		local nhi = floor(hi / 2)
		hi, lo = nhi, nlo
		if lsb == 1 then
			-- XOR polynomial 0xEDB88320 = {0xEDB8, 0x8320}
			hi = bxor(hi, 0xEDB8)
			lo = bxor(lo, 0x8320)
		end
	end
	crcHiT[n] = hi
	crcLoT[n] = lo
end

-- Returns the CRC as two 16-bit halves (hi, lo).
local function crc32(str)
	local hi, lo = 0xFFFF, 0xFFFF
	for i = 1, #str do
		local idx = bxor(lo % 256, sbyte(str, i))
		-- (hi,lo) >> 8
		local slo = floor(lo / 256) + (hi % 256) * 256
		local shi = floor(hi / 256)
		hi = bxor(shi, crcHiT[idx])
		lo = bxor(slo, crcLoT[idx])
	end
	return bxor(hi, 0xFFFF), bxor(lo, 0xFFFF)
end

--------------------------------------------------------------------------------
-- Byte helpers (big-endian)
--------------------------------------------------------------------------------

local function u16be(n)
	return schar(floor(n / 256) % 256, n % 256)
end

-- n is assumed < 2^24 here (chunk lengths / dimensions), which is exact under float32.
local function u32be(n)
	return schar(floor(n / 16777216) % 256, floor(n / 65536) % 256, floor(n / 256) % 256, n % 256)
end

local function readU32be(s, pos)
	local a, b, c, d = sbyte(s, pos, pos + 3)
	return ((a * 256 + b) * 256 + c) * 256 + d
end

local function chunk(ctype, data)
	local hi, lo = crc32(ctype .. data)
	return u32be(#data) .. ctype .. data .. u16be(hi) .. u16be(lo)
end

local PNG_SIG = schar(137, 80, 78, 71, 13, 10, 26, 10)

--------------------------------------------------------------------------------
-- Encode: 16-bit greyscale PNG.
--   width, height : image dimensions
--   samples       : flat array, row-major (row 0 first), length width*height,
--                   integer values 0..65535 (clamped here defensively)
--   Returns the PNG as a binary string, or nil on failure.
--------------------------------------------------------------------------------

local function encodeGray16(width, height, samples)
	-- IHDR: bitDepth 16, colorType 0 (greyscale), no compression/filter/interlace flags
	local ihdr = u32be(width) .. u32be(height) .. schar(16, 0, 0, 0, 0)

	local parts = {}
	local p = 0
	for row = 0, height - 1 do
		p = p + 1
		parts[p] = "\0" -- per-scanline filter type 0 (None)
		local rb = row * width
		local rowChars = {}
		for col = 1, width do
			local v = samples[rb + col]
			if v < 0 then v = 0 elseif v > 65535 then v = 65535 end
			local hi = floor(v / 256)
			rowChars[col] = schar(hi, v - hi * 256) -- big-endian 16-bit
		end
		p = p + 1
		parts[p] = tconcat(rowChars)
	end

	local comp = ZlibCompress(tconcat(parts))
	if not comp then return nil end

	return PNG_SIG .. chunk("IHDR", ihdr) .. chunk("IDAT", comp) .. chunk("IEND", "")
end

--------------------------------------------------------------------------------
-- Decode: greyscale / RGB PNG (8 or 16 bit), non-interlaced.
--   Returns { width, height, bitDepth, gray = <flat 0..1 array, row-major> }
--   or nil if the format is unsupported (caller falls back to the GL path).
--   For RGB sources the red channel is used (heightmaps are R==G==B).
--------------------------------------------------------------------------------

local function paeth(a, b, c)
	local p = a + b - c
	local pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
	if pa <= pb and pa <= pc then return a end
	if pb <= pc then return b end
	return c
end

local function decode(data)
	if not data or #data < 8 or ssub(data, 1, 8) ~= PNG_SIG then
		return nil
	end

	local width, height, bitDepth, colorType
	local idat = {}
	local pos = 9
	local n = #data
	while pos + 7 <= n do
		local len = readU32be(data, pos)
		local ctype = ssub(data, pos + 4, pos + 7)
		local dstart = pos + 8
		if ctype == "IHDR" then
			width = readU32be(data, dstart)
			height = readU32be(data, dstart + 4)
			bitDepth = sbyte(data, dstart + 8)
			colorType = sbyte(data, dstart + 9)
			local interlace = sbyte(data, dstart + 12)
			if interlace ~= 0 then return nil end -- interlaced not supported
		elseif ctype == "IDAT" then
			idat[#idat + 1] = ssub(data, dstart, dstart + len - 1)
		elseif ctype == "IEND" then
			break
		end
		pos = dstart + len + 4 -- skip data + 4-byte CRC
	end

	if not width or not height then return nil end

	local channels
	if colorType == 0 then channels = 1
	elseif colorType == 2 then channels = 3
	elseif colorType == 4 then channels = 2 -- grey + alpha
	elseif colorType == 6 then channels = 4 -- RGBA
	else return nil end -- palette unsupported

	local sampleBytes
	if bitDepth == 16 then sampleBytes = 2
	elseif bitDepth == 8 then sampleBytes = 1
	else return nil end

	local raw = ZlibDecompress(tconcat(idat))
	if not raw then return nil end

	local bpp = channels * sampleBytes -- bytes per pixel
	local rowBytes = width * bpp
	local maxval = (bitDepth == 16) and 65535 or 255

	local gray = {}
	local prev = {}
	for i = 1, rowBytes do prev[i] = 0 end

	local rowStart = 1 -- index into raw of the current scanline's filter byte
	for row = 0, height - 1 do
		local fbyte = sbyte(raw, rowStart)
		local base = rowStart -- filter byte at base, pixel bytes from base+1
		local cur = {}
		for i = 1, rowBytes do
			cur[i] = sbyte(raw, base + i)
		end
		rowStart = base + 1 + rowBytes

		-- Reconstruct (undo the scanline filter) in place.
		if fbyte == 1 then -- Sub
			for i = 1, rowBytes do
				local a = (i > bpp) and cur[i - bpp] or 0
				cur[i] = (cur[i] + a) % 256
			end
		elseif fbyte == 2 then -- Up
			for i = 1, rowBytes do
				cur[i] = (cur[i] + prev[i]) % 256
			end
		elseif fbyte == 3 then -- Average
			for i = 1, rowBytes do
				local a = (i > bpp) and cur[i - bpp] or 0
				cur[i] = (cur[i] + floor((a + prev[i]) / 2)) % 256
			end
		elseif fbyte == 4 then -- Paeth
			for i = 1, rowBytes do
				local a = (i > bpp) and cur[i - bpp] or 0
				local c = (i > bpp) and prev[i - bpp] or 0
				cur[i] = (cur[i] + paeth(a, prev[i], c)) % 256
			end
		elseif fbyte ~= 0 then
			return nil -- unknown filter
		end

		-- Extract the first channel (grey / red) per pixel as normalized 0..1.
		local outBase = row * width
		for px = 0, width - 1 do
			local pi = px * bpp
			local v
			if sampleBytes == 2 then
				v = cur[pi + 1] * 256 + cur[pi + 2]
			else
				v = cur[pi + 1]
			end
			gray[outBase + px + 1] = v / maxval
		end

		prev = cur
	end

	return { width = width, height = height, bitDepth = bitDepth, gray = gray }
end

return {
	encodeGray16 = encodeGray16,
	decode = decode,
}
