
hooks = {}
fselfs = {}

function add_hook(hookname,f,fself)
	if hooks[hookname] == nil then
		hooks[hookname] = {}
	end
	hooks[hookname][f] = true
	if fself ~= nil then
		fselfs[f] = fself
	end
end

function remove_hook(hookname, f)
	if hooks[hookname] == nil then
		hooks[hookname] = {}
	end
	hooks[hookname][f] = nil
	fselfs[f] = nil
end

function remove_hooks(hookname)
	if hooks[hookname] ~= nil then
		for k,v in pairs(hooks[hookname]) do
			remove_hook(k,fselfs[k])
		end
		hooks[hookname] = nil
	end
end

function do_hook(hookname,data)
	if hooks[hookname] ~= nil then
		for k,v in pairs(hooks[hookname]) do
			local s = fselfs[k]
			if s == nil then
				k(data)
			else
				k(s,data)
			end
		end
	end
end