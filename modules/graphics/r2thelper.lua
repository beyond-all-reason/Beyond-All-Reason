local RenderToTextureBlend = function(tex, drawFn, customBlend)
	if customBlend == nil then
		customBlend = true
	end
	-- use this when rendering on top of a transparent texture
	gl.RenderToTexture(tex, function()
		-- setup
		if customBlend then
			gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA, GL.ONE_MINUS_DST_ALPHA, GL.ONE)
		end
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.PushMatrix()
		-- draw
		drawFn()
		-- cleanup
		gl.PopMatrix()
		if customBlend then
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		end
	end)
end

local BlendTexRect = function(tex, x1, y1, x2, y2, customBlend)
	if customBlend == nil then
		customBlend = true
	end
	-- use this to render into the screen, for textures rendered with RenderToTextureBlend
	if customBlend then
		gl.Blending(GL.ONE, GL.ONE_MINUS_SRC_ALPHA)
	end
	gl.Color(1, 1, 1, 1)
	gl.Texture(tex)
	gl.TexRect(x1, y1, x2, y2, false, true)
	gl.Texture(false)
	if customBlend then
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end


return {
	RenderToTexture = RenderToTextureBlend,
	BlendTexRect = BlendTexRect,
}
