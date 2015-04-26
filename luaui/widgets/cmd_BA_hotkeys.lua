function widget:GetInfo()
	return {
		name = "BA Hotkeys",
		desc = "Enables BA Hotkeys, including ZXCV,BN,YJ,O,Q" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true,
        handler = true,
	}
end


-- table of stuff that we unbind on load
local unbinds={
    "bind any+c controlunit",
    "bind c controlunit",
    "bind any+x  buildspacing dec",
    "bind x  buildspacing dec",
    "bindaction buildspacing dec",
    "bind any+z buildspacing inc",
    "bind z buildspacing inc",
    "bindaction buildspacing inc",

    "bind , prevmenu",
    "bind . nextmenu",
    
    -- hotfixes for 98.0
    "bind backspace	mousestate", --http://springrts.com/mantis/view.php?id=4578
}

-- table of stuff that we bind on load
local binds = {}
function MakeBindsTable (swapYZ)
    -- handle swapping YZ, its very awkward to have them the 'wrong' way around on AZERTY keyboards
    if swapYZ==nil then swapYZ=false end
    local Y = swapYZ and "z" or "y"
    local Z = swapYZ and "y" or "z"
    
    local _binds = {
        -- building hotkeys
        "bind "..Z.." buildunit_armmex",
        "bind shift+"..Z.." buildunit_armmex",
        "bind "..Z.." buildunit_armamex",
        "bind shift+"..Z.." buildunit_armamex",
        "bind "..Z.." buildunit_cormex",
        "bind shift+"..Z.." buildunit_cormex",
        "bind "..Z.." buildunit_corexp",
        "bind shift+"..Z.." buildunit_corexp",
        "bind "..Z.." buildunit_armmoho",
        "bind shift+"..Z.." buildunit_armmoho",
        "bind "..Z.." buildunit_cormoho",
        "bind shift+"..Z.." buildunit_cormoho",
        "bind "..Z.." buildunit_cormexp",
        "bind shift+"..Z.." buildunit_cormexp",
        "bind "..Z.." buildunit_coruwmex",
        "bind shift+"..Z.." buildunit_coruwmex",
        "bind "..Z.." buildunit_armuwmex",
        "bind shift+"..Z.." buildunit_armuwmex",
        "bind "..Z.." buildunit_coruwmme",
        "bind shift+"..Z.." buildunit_coruwmme",
        "bind "..Z.." buildunit_armuwmme",
        "bind shift+"..Z.." buildunit_armuwmme",
        "bind x buildunit_armsolar",
        "bind shift+x buildunit_armsolar",
        "bind x buildunit_armwin",
        "bind shift+x buildunit_armwin",
        "bind x buildunit_corsolar",
        "bind shift+x buildunit_corsolar",
        "bind x buildunit_corwin",
        "bind shift+x buildunit_corwin",
        "bind x buildunit_armadvsol",
        "bind shift+x buildunit_armadvsol",
        "bind x buildunit_coradvsol",
        "bind shift+x buildunit_coradvsol",
        "bind x buildunit_armfus",
        "bind shift+x buildunit_armfus",
        "bind x buildunit_armmmkr",
        "bind shift+x buildunit_armmmkr",
        "bind x buildunit_corfus",
        "bind shift+x buildunit_corfus",
        "bind x buildunit_cormmkr",
        "bind shift+x buildunit_cormmkr",
        "bind x buildunit_armtide",
        "bind shift+x buildunit_armtide",
        "bind x buildunit_cortide",
        "bind shift+x buildunit_cortide",
        "bind x buildunit_armuwfus",
        "bind shift+x buildunit_armuwfus",
        "bind x buildunit_coruwfus",
        "bind shift+x buildunit_coruwfus",
        "bind x buildunit_armuwmmm",
        "bind shift+x buildunit_armuwmmm",
        "bind x buildunit_coruwmmm",
        "bind shift+x buildunit_coruwmmm",
        "bind c buildunit_armllt",
        "bind shift+c buildunit_armllt",
        "bind c buildunit_armrad",
        "bind shift+c buildunit_armrad",
        "bind c buildunit_corllt",
        "bind shift+c buildunit_corllt",
        "bind c buildunit_corrad",
        "bind shift+c buildunit_corrad",
        "bind c buildunit_corrl",
        "bind shift+c buildunit_corrl",
        "bind c buildunit_armrl",
        "bind shift+c buildunit_armrl",
        "bind c buildunit_armpb",
        "bind shift+c buildunit_armpb",
        "bind c buildunit_armflak",
        "bind shift+c buildunit_armflak",
        "bind c buildunit_corvipe",
        "bind shift+c buildunit_corvipe",
        "bind c buildunit_corflak",
        "bind shift+c buildunit_corflak",
        "bind c buildunit_armtl",
        "bind shift+c buildunit_armtl",
        "bind c buildunit_cortl",
        "bind shift+c buildunit_cortl",
        "bind c buildunit_armsonar",
        "bind shift+c buildunit_armsonar",
        "bind c buildunit_corsonar",
        "bind shift+c buildunit_corsonar",
        "bind c buildunit_armfrad",
        "bind shift+c buildunit_armfrad",
        "bind c buildunit_corfrad",
        "bind shift+c buildunit_corfrad",
        "bind c buildunit_armfrt",
        "bind shift+c buildunit_armfrt",
        "bind c buildunit_corfrt",
        "bind shift+c buildunit_corfrt",
        "bind v buildunit_armnanotc",
        "bind shift+v buildunit_armnanotc",
        "bind v buildunit_armlab",
        "bind shift+v buildunit_armlab",
        "bind v buildunit_armvp",
        "bind shift+v buildunit_armvp",
        "bind v buildunit_cornanotc",
        "bind shift+v buildunit_cornanotc",
        "bind v buildunit_corlab",
        "bind shift+v buildunit_corlab",
        "bind v buildunit_corvp",
        "bind shift+v buildunit_corvp",
        "bind v buildunit_armsy",
        "bind shift+v buildunit_armsy",
        "bind v buildunit_corsy",
        "bind shift+v buildunit_corsy",
        
        -- build spacing
        "bind any+b buildspacing inc",
        "bind any+n buildspacing dec",    
        
        -- numpad movement
        "bind numpad2 moveback",
        "bind numpad6 moveright",
        "bind numpad4 moveleft",
        "bind numpad8 moveforward",
        "bind numpad9 moveup",
        "bind numpad3 movedown",
        "bind numpad1 movefast",
        
        -- set target
        "bind "..Y.." settarget",
        "bind j canceltarget",
        
        "bind q drawinmap", --some ke"..Y.."boards don't have ` or \
        "bind ,	buildfacing inc", --because some ke"..Y.."boards don't have [ and ] ke"..Y.."s
        "bind .	buildfacing dec",
        "bind o buildfacing inc", --apparentl"..Y.." some ke"..Y.."boards don't have , and . either...

        -- hotfixes for 98.0
        "bind f6 mutesound", --http://springrts.com/mantis/view.php?id=4576        
    }
    
    binds = _binds
end

-----------

function LoadBindings()
	for k,v in ipairs(unbinds) do
		Spring.SendCommands("un"..v)
	end
    
    MakeBindsTable(WG.swapYZbinds) -- in case Y/Z swap has changed since last load
    
	for k,v in ipairs(binds) do
		Spring.SendCommands(v)
	end
end

function UnloadBindings()
	for k,v in ipairs(binds) do
		Spring.SendCommands("un"..v)
	end

	for k,v in ipairs(unbinds) do
		Spring.SendCommands(v)
	end
end

function ReloadBindings()
    UnloadBindings()
    LoadBindings()
end

function widget:Initialize()
    MakeBindsTable(WG.swapYZbinds)    
    LoadBindings()
    
    WG.Reload_BA_Hotkeys = ReloadBindings
end

function widget:Shutdown()
    UnloadBindings()
    WG.Reload_BA_Hotkeys = nil

    if widgetHandler.orderList and (widgetHandler.orderList["BA Hotkeys -- swap YZ"] or 0) > 0 then
        widgetHandler:DisableWidget("BA Hotkeys -- swap YZ")
    end
end
