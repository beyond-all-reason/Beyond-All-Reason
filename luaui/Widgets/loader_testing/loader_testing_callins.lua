function setupTestCallins(widget, init, update)
	if init then
		function widget:Initialize()
			local parent = self.whInfo.parent and self.whInfo.parent.name or 'nil'
			Spring.Echo('[Initialize]: "' .. self.whInfo.name .. '" parent is "' .. parent .. '", has widget.parent: ' .. tostring(self.parent ~= nil))
			--Spring.Debug.TableEcho(self.widgetHandler.knownWidgetInfos[self.whInfo.name])
			Spring.Debug.TableEcho(getmetatable(self.whInfo))
		end
	end

	if update then
		function widget:Update()

			local frame = Spring.GetGameFrame()
			if (frame % 300 ~= 0 and frame > 30) then
				return
			end

			local parent = self.whInfo.parent and self.whInfo.parent.name or 'nil'
			local children = {}
			for _, c in pairs(self.whInfo.children or {}) do
				children[#children + 1] = '"' .. c.name .. '"'
			end

			if self.whInfo.layer ~= 0 then
				Spring.Echo('[Update]' .. self.whInfo.name .. ' layer is: ' .. tostring(self.whInfo.layer) .. ', parent is ' .. parent)
			else
				Spring.Echo('[Update]' .. self.whInfo.name .. ' parent is ' .. parent)
			end

			if #children > 0 then
				Spring.Echo('[Update]' .. self.whInfo.name .. ' children are [' .. table.concat(children, ', ') .. ']')
			end
		end
	end
end

return setupTestCallins
