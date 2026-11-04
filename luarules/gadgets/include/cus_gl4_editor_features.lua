-- Map editor only: lets PBR features with an alpha cutout (customparams cuspbr + alphacutout = "yes",
-- e.g. leaf cards) render through the alpha (tree) program with their own tex2 values instead of the
-- tree bins' wind and fixed material. Outside the map editor this returns nil and cus_gl4 is unchanged.
-- The tree program still applies its per-instance size and colour variation to these features.

if (Spring.GetModOptions() or {}).mapeditor ~= "1" then
	return nil
end

local BIN = "editorpbrcutout"

return {
	-- adds the bin next to the stock ones; options = the stock defaults (no wind, no PBR override)
	addBins = function(uniformBins, defaultBitShaderOptions)
		uniformBins[BIN] = {
			bitOptions = defaultBitShaderOptions,
			baseVertexDisplacement = 0.0,
			brightnessFactor = 1.3,
		}
	end,
	-- returns the bin name for a feature that opts in, nil leaves the stock routing alone
	featureBin = function(featureDef)
		local cp = featureDef.customParams
		if cp and cp.cuspbr and cp.alphacutout == "yes" then
			return BIN
		end
		return nil
	end,
}
