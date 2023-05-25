------------------------------------------------------------------
-- A simple TGA loader.
-- Loads the TGA file with the given fileName.
-- Supports only 8 (type 3), 24 or 32 bits (type 2) TGAs with no compression.
-- Returns a table with row major data, e.g. texture[row][column]
-- each column is in bgr or bgra order
-- origin is bottom left by default
-- Author: Beherith, 20210421
------------------------------------------------------------------
local function loadTGA(fileName)
    local file = VFS.LoadFile(fileName)
    if not file then
        return nil, "VFS Unable to open file '" .. fileName .. "'."
    end

    local texture = {}
    local header = file:sub(1, 18)
    if not header then
        return nil, "Error loading header data."
    end

    texture.channels = VFS.UnpackU8(header, 17) / 8
    texture.width = VFS.UnpackU16(header, 13)
    texture.height = VFS.UnpackU16(header, 15)
    texture.type = VFS.UnpackU8(header, 3)
    texture.format = (texture.channels == 4) and "RGBA" or "RGB"
    texture.filename = fileName

    if header:byte(3) ~= 2 and header:byte(3) ~= 3 then
        return nil, "Unsupported tga type. Only 8/24/32 bits uncompressed images are supported."
    end

    local data = file:sub(19, texture.width * texture.height * texture.channels + 18)
    if #data ~= texture.width * texture.height * texture.channels then
        Spring.Echo("Failed to load", fileName, #data, texture.width, texture.height, texture.channels)
        return nil, "Error loading file, size mismatch"
    end

    local offset = 0
    local channels = texture.channels
    for j = 1, texture.height do
        local line = {}
        for i = 1, texture.width do
            for k = 1, channels do
                offset = offset + 1
                local val = VFS.UnpackU8(data, offset) or 0
                line[#line + 1] = val
            end
        end
        texture[#texture + 1] = line
    end
    return texture
end

local function saveTGA(texture, fileName)
    local file = io.open(fileName, "wb")
    if not file then
        return "Failed to open file"
    end

    local datatype = (texture.channels == 1) and 3 or 2
    local header = VFS.PackU16(0, datatype, 0, 0, 0, 0, texture.width, texture.height, 8 * texture.channels)
    file:write(header)

    for j = 1, texture.height do
        for i = 1, texture.width do
            for k = 1, texture.channels do
                file:write(VFS.PackU8(texture[j][(i - 1) * texture.channels + k] or 0))
            end
        end
    end
    file:close()
    return nil
end

local function newTGA(width, height, channels, initvalue)
    if initvalue == nil then
        initvalue = {0, 0, 0, 0}
    end
    if width < 1 then
        return nil, "Width must be greater than 0"
    end
    if height < 1 then
        return nil, "Height must be greater than 0"
    end
    if channels ~= 1 and channels ~= 3 and channels ~= 4 then
        return nil, "Channels must be 1, 3, or 4"
    end

    local texture = {
        channels = channels,
        width = width,
        height = height
    }

    for j = 1, height do
        local line = {}
        for i = 1, width do
            for k = 1, channels do
                line[#line + 1] = initvalue[k]
            end
        end
        texture[#texture + 1] = line
    end
    return texture
end

return {
    LoadTGA = loadTGA,
    SaveTGA = saveTGA,
    NewTGA = newTGA,
}
