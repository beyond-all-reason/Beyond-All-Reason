---@diagnostic disable: undefined-field

local MODULE_PATH = "luaui/Include/widget_manifest_verifier.lua"
local WIDGET_DIRECTORY = "LuaUI/Widgets/example/"
local WIDGET_FILE = WIDGET_DIRECTORY .. "widget.lua"
local WIDGET_CONTENT = "return true\n"
local TEST_DIGEST = "c10f101e8be857bee1cd04dcd5392b877f215bfd1fb4067b414bf7d0d386ccf129176f5ac416de2fe4a6d470f958efa5537968ef93acd18eb04caeae6eff6818"
local TEST_PUBLIC_KEY = string.rep("00", 32)
local TEST_SIGNATURE = string.rep("A", 86) .. "=="

local function lengthPrefix(length)
	return string.char(length, 0, 0, 0)
end

local function loadVerifier()
	return assert(loadfile(MODULE_PATH))()
end

describe("widget manifest verifier", function()
	local originalJson
	local originalVFS

	before_each(function()
		originalJson = _G.Json
		originalVFS = _G.VFS
	end)

	after_each(function()
		_G.Json = originalJson
		_G.VFS = originalVFS
	end)

	-- Overlays the real VFS rather than replacing it: the spec helper's require, which luassert
	-- calls lazily, goes through VFS
	local function stubVFS(overrides)
		overrides.PackU32 = overrides.PackU32 or lengthPrefix
		_G.VFS = setmetatable(overrides, { __index = originalVFS })
	end

	it("matches the builder content hash framing", function()
		local hashedValue
		stubVFS({
			RAW = "raw",
			DirList = function()
				return { WIDGET_FILE }
			end,
			LoadFile = function(filename)
				assert.equals(WIDGET_FILE, filename)
				return WIDGET_CONTENT
			end,
			CalculateHash = function(value, hashType)
				hashedValue = value
				assert.equals(1, hashType)
				return TEST_DIGEST
			end,
		})

		local verifier = loadVerifier()
		assert.equals("sha512:" .. TEST_DIGEST, verifier.CalculateWidgetHash(WIDGET_DIRECTORY))
		assert.equals(
			lengthPrefix(21) .. "bar-widget-content-v1"
				.. lengthPrefix(10) .. "widget.lua"
				.. lengthPrefix(12) .. WIDGET_CONTENT,
			hashedValue
		)
	end)

	it("returns only widget files authorized by a valid catalog", function()
		local catalog = "signed catalog bytes"
		local verifiedMessage
		stubVFS({
			RAW = "raw",
			LoadFile = function(filename)
				local contents = {
					["LuaUI/Widgets/manifests.json"] = catalog,
					["LuaUI/Widgets/manifests.json.sig"] = TEST_SIGNATURE,
					[WIDGET_FILE] = WIDGET_CONTENT,
				}
				return contents[filename]
			end,
			DirList = function(directory, pattern, _, recursive)
				assert.equals(WIDGET_DIRECTORY, directory)
				if recursive then
					assert.equals("*", pattern)
				else
					assert.equals("*.lua", pattern)
				end
				return { WIDGET_FILE }
			end,
			SubDirs = function(directory)
				assert.equals("LuaUI/Widgets/", directory)
				return { WIDGET_DIRECTORY }
			end,
			CalculateHash = function()
				return TEST_DIGEST
			end,
			VerifyEd25519 = function(message, signature, publicKey)
				verifiedMessage = message
				assert.equals(64, #signature)
				assert.equals(32, #publicKey)
				return true
			end,
		})
		_G.Json = {
			decode = function(value)
				assert.equals(catalog, value)
				return {
					{ id = "example", content_hash = "sha512:" .. TEST_DIGEST },
				}
			end,
		}

		local files, errors = loadVerifier().GetVerifiedWidgetFiles("LuaUI/Widgets/", { publicKeys = { TEST_PUBLIC_KEY } })
		assert.same({ WIDGET_FILE }, files)
		assert.same({}, errors)
		assert.equals(catalog, verifiedMessage)
	end)

	describe("in anonymous mode", function()
		-- A validly signed catalog holding the single entry given, for the example widget installed as is
		local function stubCatalog(entry)
			stubVFS({
				RAW = "raw",
				LoadFile = function(filename)
					if filename:match("%.sig$") then
						return TEST_SIGNATURE
					end
					return filename == WIDGET_FILE and WIDGET_CONTENT or "catalog"
				end,
				DirList = function()
					return { WIDGET_FILE }
				end,
				SubDirs = function()
					return { WIDGET_DIRECTORY }
				end,
				CalculateHash = function()
					return TEST_DIGEST
				end,
				VerifyEd25519 = function()
					return true
				end,
			})
			entry.id = "example"
			entry.content_hash = "sha512:" .. TEST_DIGEST
			_G.Json = {
				decode = function()
					return { entry }
				end,
			}
		end

		local function getAnonymousSafeFiles()
			return loadVerifier().GetVerifiedWidgetFiles(
				"LuaUI/Widgets/",
				{ publicKeys = { TEST_PUBLIC_KEY }, requireAnonymousSafe = true }
			)
		end

		it("loads widgets the catalog marks anonymous_safe", function()
			stubCatalog({ anonymous_safe = true })

			local files, errors, notAnonymousSafe = getAnonymousSafeFiles()
			assert.same({ WIDGET_FILE }, files)
			assert.same({}, errors)
			assert.same({}, notAnonymousSafe)
		end)

		it("treats a missing anonymous_safe as not safe, without calling it a failure", function()
			stubCatalog({})

			local files, errors, notAnonymousSafe = getAnonymousSafeFiles()
			assert.same({}, files)
			assert.same({}, errors)
			assert.same({ "example" }, notAnonymousSafe)
		end)

		it("still loads catalogs without anonymous_safe outside anonymous mode", function()
			stubCatalog({})

			local files, errors, notAnonymousSafe = loadVerifier().GetVerifiedWidgetFiles("LuaUI/Widgets/", { publicKeys = { TEST_PUBLIC_KEY } })
			assert.same({ WIDGET_FILE }, files)
			assert.same({}, errors)
			assert.same({}, notAnonymousSafe)
		end)

		it("accepts only a literal true", function()
			stubCatalog({ anonymous_safe = "true" })

			local files, _, notAnonymousSafe = getAnonymousSafeFiles()
			assert.same({}, files)
			assert.same({ "example" }, notAnonymousSafe)
		end)
	end)

	it("fails closed when the catalog signature is invalid", function()
		stubVFS({
			RAW = "raw",
			LoadFile = function(filename)
				if filename:match("%.sig$") then
					return TEST_SIGNATURE
				end
				return "tampered catalog"
			end,
			VerifyEd25519 = function()
				return false
			end,
		})

		local files, errors = loadVerifier().GetVerifiedWidgetFiles("LuaUI/Widgets/", { publicKeys = { TEST_PUBLIC_KEY } })
		assert.is_nil(files)
		assert.same({ "invalid signature for manifests.json" }, errors)
	end)

	describe("with a malformed signature file", function()
		local function verifyWithSignature(encodedSignature)
			local verified = false
			stubVFS({
				RAW = "raw",
				LoadFile = function(filename)
					return filename:match("%.sig$") and encodedSignature or "catalog"
				end,
				SubDirs = function()
					return {}
				end,
				VerifyEd25519 = function()
					verified = true
					return true
				end,
			})
			_G.Json = {
				decode = function()
					return {}
				end,
			}

			local files, errors = loadVerifier().GetVerifiedWidgetFiles("LuaUI/Widgets/", { publicKeys = { TEST_PUBLIC_KEY } })
			return files, errors, verified
		end

		for description, encodedSignature in pairs({
			["a stray character"] = string.rep("A", 85) .. "!==",
			["padding in the middle"] = string.rep("A", 84) .. "=A==",
			["a length that is not a multiple of four"] = string.rep("A", 86),
			["a signature of the wrong size"] = string.rep("A", 84),
		}) do
			it("refuses " .. description .. " before verifying anything", function()
				local files, errors, verified = verifyWithSignature(encodedSignature)
				assert.is_nil(files)
				assert.same({ "invalid base64 signature in manifests.json.sig" }, errors)
				assert.is_false(verified)
			end)
		end

		it("ignores whitespace around a well formed one", function()
			local _, _, verified = verifyWithSignature("
" .. TEST_SIGNATURE .. "
")
			assert.is_true(verified)
		end)
	end)

	describe("with several trusted keys", function()
		local ROTATED_KEY = string.rep("11", 32)

		-- A catalog that only the given key's signature verifies, empty so nothing past the signature matters
		local function stubCatalogSignedBy(signingKey)
			stubVFS({
				RAW = "raw",
				LoadFile = function(filename)
					return filename:match("%.sig$") and TEST_SIGNATURE or "catalog"
				end,
				SubDirs = function()
					return {}
				end,
				VerifyEd25519 = function(_, _, publicKey)
					return publicKey == signingKey
				end,
			})
			_G.Json = {
				decode = function()
					return {}
				end,
			}
		end

		it("accepts a catalog signed by any of them", function()
			stubCatalogSignedBy(string.rep("\17", 32))

			local files, errors = loadVerifier().GetVerifiedWidgetFiles(
				"LuaUI/Widgets/",
				{ publicKeys = { TEST_PUBLIC_KEY, ROTATED_KEY } }
			)
			assert.same({}, files)
			assert.same({}, errors)
		end)

		it("fails closed when one of them is malformed", function()
			stubCatalogSignedBy(string.rep("\0", 32))

			local files, errors = loadVerifier().GetVerifiedWidgetFiles(
				"LuaUI/Widgets/",
				{ publicKeys = { TEST_PUBLIC_KEY, "not hex" } }
			)
			assert.is_nil(files)
			assert.same({ "invalid embedded Ed25519 public key" }, errors)
		end)
	end)
end)
