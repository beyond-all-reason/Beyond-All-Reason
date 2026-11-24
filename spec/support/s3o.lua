-- Reads the piece tree and texture names of an s3o model.
-- For specs that check models against the scripts and defs that use them.

local MAGIC = "Spring unit"
local HEADER_ROOT_PIECE = 36
local HEADER_TEXTURE_1 = 44
local HEADER_TEXTURE_2 = 48
local PIECE_NAME = 0
local PIECE_CHILD_COUNT = 4
local PIECE_CHILDREN = 8
local PIECE_VERTEX_COUNT = 12

local function uint32(data, offset)
	local b1, b2, b3, b4 = data:byte(offset + 1, offset + 4)
	return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
end

local function tocstring(data, offset)
	if offset == 0 then
		return ""
	end
	local stop = data:find("\0", offset + 1, true)
	return data:sub(offset + 1, (stop or #data + 1) - 1)
end

---@class S3OPiece
---@field name string
---@field parent string?
---@field vertexCount integer
---@field children string[]

---@class S3OModel
---@field pieces table<string, S3OPiece> by name; a repeated name keeps its first piece
---@field order string[] piece names, depth first
---@field duplicates string[] names that appear more than once
---@field textures string[] texture 1 and texture 2, empty when unset

---@param data string the file contents
---@return S3OModel
local function parse(data)
	assert(data:sub(1, #MAGIC) == MAGIC, "not an s3o model")

	local model = { pieces = {}, order = {}, duplicates = {} }

	local function crawl(offset, parentName)
		local name = tocstring(data, uint32(data, offset + PIECE_NAME))
		local piece = {
			name = name,
			parent = parentName,
			vertexCount = uint32(data, offset + PIECE_VERTEX_COUNT),
			children = {},
		}
		if model.pieces[name] then
			model.duplicates[#model.duplicates + 1] = name
		else
			model.pieces[name] = piece
		end
		model.order[#model.order + 1] = name

		local childCount = uint32(data, offset + PIECE_CHILD_COUNT)
		local children = uint32(data, offset + PIECE_CHILDREN)
		for i = 0, childCount - 1 do
			local childName = crawl(uint32(data, children + 4 * i), name)
			piece.children[#piece.children + 1] = childName
		end

		return name
	end

	crawl(uint32(data, HEADER_ROOT_PIECE), nil)

	model.textures = {
		tocstring(data, uint32(data, HEADER_TEXTURE_1)),
		tocstring(data, uint32(data, HEADER_TEXTURE_2)),
	}

	return model
end

---@param path string
---@return S3OModel
local function load(path)
	local file = assert(io.open(path, "rb"))
	local data = file:read("*a")
	file:close()
	return parse(data)
end

return {
	Load = load,
	Parse = parse,
}
