------------------------------------------------------------------
-- A simple TGA loader.
-- Loads the TGA file with the given fileName.
-- Supports only 8 (type 3), 24 or 32 bits (type 2) TGAs with no compression.
-- Returns a table with row major data, e.g. texture[row][column]
-- each column is in bgr or bgra order
-- origin is bottom left by default
-- Author: Beherith, 20210421
------------------------------------------------------------------
local function loadTGA(fileName) -- returns texture | nil, error on failure
	local file = VFS.LoadFile(fileName)

	if file == nil then
		return nil, "VFS Unable to open file '" .. fileName .. "'."
	end

	local texture = {}
	local header = string.sub(file,1,18)

	if header == nil then
		return nil, "Error loading header data."
	end

	texture.channels   = VFS.UnpackU8(header, 17)/8 -- bits per pixel  --:byte(17) / 8
	texture.width      = VFS.UnpackU16(header, 13)  --header:byte(14) * 256 + header:byte(13)
	texture.height     = VFS.UnpackU16(header, 15)  --header:byte(16) * 256 + header:byte(15)
	texture.type       = VFS.UnpackU8(header,3)
	texture.format     = (texture.channels == 4) and "RGBA" or "RGB"
	texture.filename   = fileName

	if header:byte(3) ~= 2 and header:byte(3) ~= 3 then
		return nil, "Unsupported tga type. Only 8/24/32 bits uncompressed images are supported."
	end

	local data = string.sub(file,19, texture.width * texture.height * texture.channels + 18)
	if string.len(data) ~= texture.width * texture.height * texture.channels  then  --WHY +1?????
		Spring.Echo("Failed to load",fileName,string.len(data), texture.width, texture.height, texture.channels)
		return nil, "Error loading file, size mismatch"
	end

	--Spring.Echo("Trying to load",fileName,string.len(data), texture.width, texture.height, texture.channels)
	local offset = 0
	local channels = texture.channels
	for j=1, texture.height do
		local line = {}
		for i=1, texture.width do
			for k=1, channels do
				offset = offset + 1
				local val = VFS.UnpackU8(data, offset)
				if val and val >=0 and val <256 then

				else
					--Spring.Echo("LoadTGA failed to parse",j,i,k,val,offset)
					val = 0
				end
				table.insert(line,val)
			end
		end
		table.insert(texture, line)
	end
	return texture
end

local function saveTGA(texture, fileName) --return nil | error on failure
	Spring.Echo("Saving",fileName)

	local file = io.open(fileName,'wb')
	if file == nil then
		return "Failed to open file"
	end

	local datatype = 2
	if texture.channels == 1 then datatype = 3 end

	local header = VFS.PackU16(0,datatype,0,0,0,0, texture.width, texture.height, 8* texture.channels)
	file:write(header)

	for j = 1, texture.height do
		for i = 1, texture.width do
			for k = 1, texture.channels do
				file:write(VFS.PackU8(texture[j][(i-1)*texture.channels + k]))
			end
		end
	end
	file:close()
	Spring.Echo("Saved",fileName)
	return nil
end

local function newTGA(width, height, channels, initvalue) -- returns the new 'texture table' or nil, error
	-- initvalue is a table of b,g,r,a
	if initvalue == nil then  initvalue = {0,0,0,0} end
	if width < 1 then return nil, "Width must be greater than 0" end
	if height < 1 then return nil, "Height must be greater than 0" end
	if channels ~= 1 and channels ~= 3 and channels ~=4 then return nil, "Channels must be 1,3 or 4" end

	local texture = {}

	texture.channels   = channels
	texture.width      = width
	texture.height     = height

	for j=1, height do
		local line = {}
		for i=1, width do
			for k=1, channels do
				table.insert(line,initvalue[k])
			end
		end
		table.insert(texture, line)
	end
	return texture
end

return {
	LoadTGA = loadTGA,
	SaveTGA = saveTGA,
	NewTGA = newTGA,
}
