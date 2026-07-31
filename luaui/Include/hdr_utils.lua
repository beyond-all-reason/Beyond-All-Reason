-- Shared helpers for the RecoilEngine HDR output API.
--
-- Spring.GetHDRInfo() rebuilds a fairly large table on every call, so the result
-- is cached per draw frame and shared between all consumers (bloom, screen-copy
-- manager, model material template, ...) instead of each one querying it again.

local Engine = Engine
local Spring = Spring

local hasApi = false
do
	local featureSupport = Engine and Engine.FeatureSupport
	hasApi = (featureSupport ~= nil)
		and (featureSupport.hdrOutputApiVersion ~= nil)
		and (Spring.GetHDRInfo ~= nil)
end

local spGetDrawFrame = Spring.GetDrawFrame
local spGetHDRInfo = Spring.GetHDRInfo

local cachedFrame = -1
local cachedInfo = nil

local HDR = {}

-- Whether the running engine exposes the HDR output API at all.
function HDR.IsSupported()
	return hasApi
end

-- Cached Spring.GetHDRInfo() for the current draw frame, or nil when unsupported.
function HDR.GetInfo()
	if not hasApi then
		return nil
	end

	local frame = spGetDrawFrame()
	if frame ~= cachedFrame then
		cachedFrame = frame
		cachedInfo = spGetHDRInfo()
	end

	return cachedInfo
end

-- True while the engine owns the resolved HDR scene target, meaning effects must
-- read $scene_color / $scene_depth instead of their legacy per-frame copies.
-- The engine only reports this active when HDR is genuinely being presented, so
-- SDR and HDRMode=off both return false and keep the legacy code paths.
function HDR.IsSceneTargetActive()
	local info = HDR.GetInfo()
	return (info ~= nil) and (info.sceneTargetActive == true)
end

return HDR
