function gadget:GetInfo()
  return {
    name      = "Build Icons Slowy (/luarules buildiconslow)",
    desc      = "builds them all slow-like, 1 per minute for hours on end",
    author    = "Beherith",
    date      = "2015",
    license   = "Horses",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local startframe = 1000000000
local index=1
local counter = 1
local unitnames={}
local timedelay=45*10 --yeah this crap takes 8 hours, for a total of 427 units :D

function buildslowly(_,_,params)
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			index = tonumber(params[1])
		end
	end
	Spring.Echo('building icons all slow-like, starting from '..index)
	startframe=Spring.GetGameFrame()
end


function gadget:Initialize()
	gadgetHandler:AddChatAction('buildiconslow', buildslowly, "")
	
	for i,unitdefname in pairs(UnitDefNames) do
		--Spring.Echo('unitdefname',i,unitdefname)
		unitnames[#unitnames+1]=i
    end
	-- unitnames={
		-- "armah",
		-- "armanni",
		-- "armason",
		-- "armawac",
	-- }
end

function gadget:GameFrame(n)
	-- Spring.Echo(n,startframe,index)
	if (n>startframe+timedelay*counter and index <=#unitnames) then 
		-- Spring.Echo(" Drawing unit ",index,UnitDefNames[index]["name"])
		Spring.Echo(" Drawing unit ",index,unitnames[index]," out of ", #unitnames)
		Spring.SendCommands("luarules buildicon "..unitnames[index])
		index=index+1
		counter=counter+1
	end
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('buildiconslow')
end
