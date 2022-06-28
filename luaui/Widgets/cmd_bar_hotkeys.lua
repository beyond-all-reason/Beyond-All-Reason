function widget:GetInfo()
	return {
		name = "BAR Hotkeys",
		desc = "Enables BAR Hotkeys, including ZXCV,BN,YJ,O,Q" ,
		author = "Beherith",
		date = "23 march 2012",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true,
		handler = true,
	}
end

local currentLayout
local keyConfig = VFS.Include("luaui/configs/keyboard_layouts.lua")

-- table of stuff that we unbind on load
-- copypaste the contents from rts/Game/UI/KeyBindings.cpp on engine to update
local engineBinds = {
	{            "esc", "quitmessage" },
	{      "Shift+esc", "quitmenu"    },
	{ "Ctrl+Shift+esc", "quitforce"   },
	{  "Alt+Shift+esc", "reloadforce" },
	{      "Any+pause", "pause"       },

	{     "c", "controlunit" },
	{ "Any+h", "sharedialog" },
	{ "Any+i", "gameinfo"    },

	{           "Any+j", "mouse2"         },
	{       "backspace", "mousestate"     },
	{ "Shift+backspace", "togglecammode"  },
	{  "Ctrl+backspace", "togglecammode"  },
	{         "Any+tab", "toggleoverview" },

	{  "Any+enter", "chat"           },
	{ "Alt+ctrl+a", "chatswitchally" },
	{ "Alt+ctrl+s", "chatswitchspec" },

	{       "Any+tab", "edit_complete"  },
	{ "Any+backspace", "edit_backspace" },
	{    "Any+delete", "edit_delete"    },
	{      "Any+home", "edit_home"      },
	{      "Alt+left", "edit_home"      },
	{       "Any+end", "edit_end"       },
	{     "Alt+right", "edit_end"       },
	{        "Any+up", "edit_prev_line" },
	{      "Any+down", "edit_next_line" },
	{      "Any+left", "edit_prev_char" },
	{     "Any+right", "edit_next_char" },
	{     "Ctrl+left", "edit_prev_word" },
	{    "Ctrl+right", "edit_next_word" },
	{     "Any+enter", "edit_return"    },
	{    "Any+escape", "edit_escape"    },

	{ "Ctrl+v", "pastetext" },

	{ "Any+home", "increaseViewRadius" },
	{ "Any+end",  "decreaseViewRadius" },

	{ "Alt+insert",  "speedup"  },
	{ "Alt+delete",  "slowdown" },
	{ "Alt+=",       "speedup"  },
	{ "Alt++",       "speedup"  },
	{ "Alt+-",       "slowdown" },
	{ "Alt+numpad+", "speedup"  },
	{ "Alt+numpad-", "slowdown" },

	{       ",", "prevmenu" },
	{       ".", "nextmenu" },
	{ "Shift+,", "decguiopacity" },
	{ "Shift+.", "incguiopacity" },

	{      "1", "specteam", "0"  },
	{      "2", "specteam", "1"  },
	{      "3", "specteam", "2"  },
	{      "4", "specteam", "3"  },
	{      "5", "specteam", "4"  },
	{      "6", "specteam", "5"  },
	{      "7", "specteam", "6"  },
	{      "8", "specteam", "7"  },
	{      "9", "specteam", "8"  },
	{      "0", "specteam", "9"  },
	{ "Ctrl+1", "specteam", "10" },
	{ "Ctrl+2", "specteam", "11" },
	{ "Ctrl+3", "specteam", "12" },
	{ "Ctrl+4", "specteam", "13" },
	{ "Ctrl+5", "specteam", "14" },
	{ "Ctrl+6", "specteam", "15" },
	{ "Ctrl+7", "specteam", "16" },
	{ "Ctrl+8", "specteam", "17" },
	{ "Ctrl+9", "specteam", "18" },
	{ "Ctrl+0", "specteam", "19" },

	{ "Any+0", "group0" },
	{ "Any+1", "group1" },
	{ "Any+2", "group2" },
	{ "Any+3", "group3" },
	{ "Any+4", "group4" },
	{ "Any+5", "group5" },
	{ "Any+6", "group6" },
	{ "Any+7", "group7" },
	{ "Any+8", "group8" },
	{ "Any+9", "group9" },

	{       "[", "buildfacing",  "inc" },
	{ "Shift+[", "buildfacing",  "inc" },
	{       "]", "buildfacing",  "dec" },
	{ "Shift+]", "buildfacing",  "dec" },
	{   "Any+z", "buildspacing", "inc" },
	{   "Any+x", "buildspacing", "dec" },

	{            "a", "attack"          },
	{      "Shift+a", "attack"          },
	{        "Alt+a", "areaattack"      },
	{  "Alt+Shift+a", "areaattack"      },
	{        "Alt+b", "debug"           },
	{        "Alt+v", "debugcolvol"     },
	{        "Alt+p", "debugpath"       },
	{            "d", "manualfire"      },
	{      "Shift+d", "manualfire"      },
	{       "Ctrl+d", "selfd"           },
	{ "Ctrl+Shift+d", "selfd", "queued" },
	{            "e", "reclaim"         },
	{      "Shift+e", "reclaim"         },
	{            "f", "fight"           },
	{      "Shift+f", "fight"           },
	{        "Alt+f", "forcestart"      },
	{            "g", "guard"           },
	{      "Shift+g", "guard"           },
	{            "k", "cloak"           },
	{      "Shift+k", "cloak"           },
	{            "l", "loadunits"       },
	{      "Shift+l", "loadunits"       },
	{            "m", "move"            },
	{      "Shift+m", "move"            },
	{        "Alt+o", "singlestep"      },
	{            "p", "patrol"          },
	{      "Shift+p", "patrol"          },
	{            "q", "groupselect"     },
	{            "q", "groupadd"        },
	{       "Ctrl+q", "aiselect"        },
	{      "Shift+q", "groupclear"      },
	{            "r", "repair"          },
	{      "Shift+r", "repair"          },
	{            "s", "stop"            },
	{      "Shift+s", "stop"            },
	{            "u", "unloadunits"     },
	{      "Shift+u", "unloadunits"     },
	{            "w", "wait"            },
	{      "Shift+w", "wait", "queued"  },
	{            "x", "onoff"           },
	{      "Shift+x", "onoff"           },


	{  "Ctrl+t", "trackmode" },
	{   "Any+t", "track" },

	{ "Ctrl+f1", "viewfps"  },
	{ "Ctrl+f2", "viewta"   },
	{ "Ctrl+f3", "viewspring" },
	{ "Ctrl+f4", "viewrot"  },
	{ "Ctrl+f5", "viewfree" },

	{ "Any+f1", "ShowElevation"          },
	{ "Any+f2", "ShowPathTraversability" },
	{ "Any+f3", "LastMsgPos"             },
	{ "Any+f4", "ShowMetalMap"           },
	{ "Any+f5", "HideInterface"          },
	{ "Any+f6", "MuteSound"              },
	{ "Any+f7", "DynamicSky"             },
	{  "Any+l",  "togglelos"             },

	{ "Ctrl+Shift+f8",  "savegame" },
	{ "Ctrl+Shift+f10", "createvideo" },
	{ "Any+f11", "screenshot"     },
	{ "Any+f12", "screenshot"     },
	{ "Alt+enter", "fullscreen"  },

	{ "Any+`" , "drawlabel" },
	{ "Any+\\", "drawlabel" },
	{ "Any+~" , "drawlabel" },
	{ "Any+§" , "drawlabel" },
	{ "Any+^" , "drawlabel" },

	{ "Any+`",    "drawinmap"  },
	{ "Any+\\",   "drawinmap"  },
	{ "Any+~",    "drawinmap"  },
	{ "Any+§",    "drawinmap"  },
	{ "Any+^",    "drawinmap"  },

	{ "Any+up",       "moveforward" },
	{ "Any+down",     "moveback"    },
	{ "Any+right",    "moveright"   },
	{ "Any+left",     "moveleft"    },
	{ "Any+pageup",   "moveup"      },
	{ "Any+pagedown", "movedown"    },

	{     "Any+ctrl", "moveslow" },
	{    "Any+shift", "movefast" },

	{ "Ctrl+a", "select", "AllMap++_ClearSelection_SelectAll+"                                        },
	{ "Ctrl+b", "select", "AllMap+_Builder_Idle+_ClearSelection_SelectOne+"                           },
	{ "Ctrl+c", "select", "AllMap+_ManualFireUnit+_ClearSelection_SelectOne+"                         },
	{ "Ctrl+r", "select", "AllMap+_Radar+_ClearSelection_SelectAll+"                                  },
	{ "Ctrl+v", "select", "AllMap+_Not_Builder_Not_Commander_InPrevSel_Not_InHotkeyGroup+_SelectAll+" },
	{ "Ctrl+w", "select", "AllMap+_Not_Aircraft_Weapons+_ClearSelection_SelectAll+"                   },
	{ "Ctrl+x", "select", "AllMap+_InPrevSel_Not_InHotkeyGroup+_SelectAll+"                           },
	{ "Ctrl+z", "select", "AllMap+_InPrevSel+_ClearSelection_SelectAll+"                              }
}

local function makeBindsTable(keyLayout)
	local Z = keyLayout[1][1]
	local X = keyLayout[1][2]
	local C = keyLayout[1][3]
	local V = keyLayout[1][4]
	local B = keyLayout[1][5]
	local M = keyLayout[1][7]
	local A = keyLayout[2][1]
	local S = keyLayout[2][2]
	local D = keyLayout[2][3]
	local F = keyLayout[2][4]
	local G = keyLayout[2][5]
	local H = keyLayout[2][6]
	local J = keyLayout[2][7]
	local K = keyLayout[2][8]
	local L = keyLayout[2][9]
	local Q = keyLayout[3][1]
	local W = keyLayout[3][2]
	local E = keyLayout[3][3]
	local R = keyLayout[3][4]
	local T = keyLayout[3][5]
	local Y = keyLayout[3][6]
	local U = keyLayout[3][7]
	local I = keyLayout[3][8]
	local O = keyLayout[3][9]
	local P = keyLayout[3][10]

	local _binds = {
		{            "esc", "quitmessage"                },
		{      "Shift+esc", "quitmenu"                   },
		{ "Ctrl+Shift+esc", "quitforce"                  },
		{  "Alt+Shift+esc", "reloadforce"                },
		{     "Any+escape", "edit_escape"                },
		{      "Any+pause", "pause"                      },
		{            "esc", "teamstatus_close"           },
		{            "esc", "customgameinfo_close"       },
		{            "esc", "buildmenu_pregame_deselect" },

		{         C, "controlunit"    },
		{ "Any+"..H, "sharedialog"    },
		{         I, "customgameinfo" },

		{         "Any+"..J, "mouse2" },
		{       "backspace", "mousestate" },
		{ "Shift+backspace", "togglecammode" },
		{  "Ctrl+backspace", "togglecammode" },
		{         "Any+tab", "toggleoverview" },

		{     "Any+enter", "chat"           },
		{  "Alt+ctrl+"..A, "chatswitchally" },
		{  "Alt+ctrl+"..S, "chatswitchspec" },

		{       "Any+tab", "edit_complete"  },
		{ "Any+backspace", "edit_backspace" },
		{    "Any+delete", "edit_delete"    },
		{      "Any+home", "edit_home"      },
		{      "Alt+left", "edit_home"      },
		{       "Any+end", "edit_end"       },
		{     "Alt+right", "edit_end"       },
		{        "Any+up", "edit_prev_line" },
		{      "Any+down", "edit_next_line" },
		{      "Any+left", "edit_prev_char" },
		{     "Any+right", "edit_next_char" },
		{     "Ctrl+left", "edit_prev_word" },
		{    "Ctrl+right", "edit_next_word" },
		{     "Any+enter", "edit_return"    },

		{ "Ctrl+v", "pastetext" },

		{ "Any+home", "increaseViewRadius" },
		{ "Any+end",  "decreaseViewRadius" },

		{ "Alt+insert",  "increasespeed" },
		{ "Alt+delete",  "decreasespeed" },
		{ "Alt+=",       "increasespeed" },
		{ "Alt++",       "increasespeed" },
		{ "Alt+-",       "decreasespeed" },
		{ "Alt+numpad+", "increasespeed" },
		{ "Alt+numpad-", "decreasespeed" },

		{       "sc_[", "buildfacing" , "inc" },
		{ "Shift+sc_[", "buildfacing" , "inc" },
		{       "sc_]", "buildfacing" , "dec" },
		{ "Shift+sc_]", "buildfacing" , "dec" },

		{       "Alt+sc_z", "buildspacing", "inc" },
		{ "Shift+Alt+sc_z", "buildspacing", "inc" },
		{       "Alt+sc_x", "buildspacing", "dec" },
		{ "Shift+Alt+sc_x", "buildspacing", "dec" },

		{                A, "attack"          },
		{      "Shift+"..A, "attack"          },
		{        "Alt+"..A, "areaattack"      },
		{  "Alt+Shift+"..A, "areaattack"      },
		{          "Alt+b", "debug"           },
		{          "Alt+v", "debugcolvol"     },
		{          "Alt+p", "debugpath"       },
		{                D, "manualfire"      },
		{      "Shift+"..D, "manualfire"      },
		{                D, "manuallaunch"    },
		{      "Shift+"..D, "manuallaunch"    },
		{       "Ctrl+"..D, "selfd"           },
		{ "Ctrl+Shift+"..D, "selfd", "queued" },
		{                E, "reclaim"         },
		{      "Shift+"..E, "reclaim"         },
		{                F, "fight"           },
		{      "Shift+"..F, "fight"           },
		{        "Alt+"..F, "forcestart"      },
		{                G, "guard"           },
		{      "Shift+"..G, "guard"           },
		{                J, "canceltarget"    },
		{                K, "cloak"           },
		{      "Shift+"..K, "cloak"           },
		{                K, "wantcloak"       },
		{        "Any+"..K, "wantcloak"       },
		{                L, "loadunits"       },
		{      "Shift+"..L, "loadunits"       },
		{                M, "move"            },
		{      "Shift+"..M, "move"            },
		{                P, "patrol"          },
		{      "Shift+"..P, "patrol"          },
		{        "Any+"..Q, "drawinmap"       }, --some keyboards don't have ` or \
		{        "Any+"..Q, "drawlabel"       },
		{        Q..','..Q, "drawlabel"       }, -- double hit Q for drawlabel
		{                R, "repair"          },
		{      "Shift+"..R, "repair"          },
		{                S, "stop"            },
		{      "Shift+"..S, "stop"            },
		{       "Ctrl+"..S, "stopproduction"  },
		{                U, "unloadunits"     },
		{      "Shift+"..U, "unloadunits"     },
		{                W, "wait"            },
		{      "Shift+"..W, "wait", "queued"  },
		{                X, "onoff"           },
		{      "Shift+"..X, "onoff"           },

		{ "Any+"..L,   "togglelos"             },

		{  "Ctrl+"..T, "trackmode" },
		{   "Any+"..T, "track" },

		{ "Ctrl+f1", "viewfps"  },
		{ "Ctrl+f2", "viewta"   },
		{ "Ctrl+f3", "viewspring" },
		{ "Ctrl+f4", "viewrot"  },
		{ "Ctrl+f5", "viewfree" },

		{ "Any+f1" , "ShowElevation"          },
		{ "Any+f2" , "ShowPathTraversability" },
		{ "Any+f3" , "LastMsgPos"             },
		{ "Any+f4" , "ShowMetalMap"           },
		{ "Any+f5" , "HideInterface"          },
		{ "Any+f6" , "MuteSound"              },
		{ "Any+f7" , "DynamicSky"             },
		{    "f11" , "luaui selector"         },
		{ "Any+f12", "screenshot"     , "png" },

		{ "Ctrl+Shift+f8", "savegame"       },
		{ "Alt+enter",     "fullscreen"     },

		{ "Any+sc_`" , "drawinmap" },
		{ "Any+sc_`" , "drawlabel" },
		{ "sc_`,sc_`", "drawlabel" },

		{ "Any+up",       "moveforward"  },
		{ "Any+down",     "moveback"     },
		{ "Any+right",    "moveright"    },
		{ "Any+left",     "moveleft"     },
		{ "Any+pageup",   "moveup"       },
		{ "Any+pagedown", "movedown"     },

		{ "Any+ctrl",     "moveslow"     },
		{ "Any+shift",    "movefast"     },

		{ "Ctrl+"..A,    "select", "AllMap++_ClearSelection_SelectAll+"                                                                                       },
		{ "Ctrl+"..B,    "select", "AllMap+_Builder_Idle+_ClearSelection_SelectOne+"                                                                          },
		{ "Ctrl+"..C,    "select", "AllMap+_ManualFireUnit_Not_IdMatches_cordecom_Not_IdMatches_armdecom_Not_IdMatches_armthor+_ClearSelection_SelectOne+"    },
		{ "Ctrl+"..R,    "select", "AllMap+_Radar+_ClearSelection_SelectAll+"                                                                                 },
		{ "Ctrl+"..V,    "select", "AllMap+_Not_Builder_Not_Commander_InPrevSel_Not_InHotkeyGroup+_SelectAll+"                                                },
		{ "Ctrl+"..W,    "select", "AllMap+_Not_Aircraft_Weapons+_ClearSelection_SelectAll+"                                                                  },
		{ "Ctrl+"..X,    "select", "AllMap+_InPrevSel_Not_InHotkeyGroup+_SelectAll+"                                                                          },
		{ "Ctrl+"..Z,    "select", "AllMap+_InPrevSel+_ClearSelection_SelectAll+"                                                                             },

		-- building hotkeys
		{              Z, "buildunit_armmex"        },
		{    "Shift+"..Z, "buildunit_armmex"        },
		{              Z, "buildunit_armamex"       },
		{    "Shift+"..Z, "buildunit_armamex"       },
		{              Z, "buildunit_cormex"        },
		{    "Shift+"..Z, "buildunit_cormex"        },
		{              Z, "buildunit_corexp"        },
		{    "Shift+"..Z, "buildunit_corexp"        },
		{              Z, "buildunit_armmoho"       },
		{    "Shift+"..Z, "buildunit_armmoho"       },
		{              Z, "buildunit_cormoho"       },
		{    "Shift+"..Z, "buildunit_cormoho"       },
		{              Z, "buildunit_cormexp"       },
		{    "Shift+"..Z, "buildunit_cormexp"       },
		{              Z, "buildunit_coruwmex"      },
		{    "Shift+"..Z, "buildunit_coruwmex"      },
		{              Z, "buildunit_armuwmex"      },
		{    "Shift+"..Z, "buildunit_armuwmex"      },
		{              Z, "buildunit_coruwmme"      },
		{    "Shift+"..Z, "buildunit_coruwmme"      },
		{              Z, "buildunit_armuwmme"      },
		{    "Shift+"..Z, "buildunit_armuwmme"      },
		{              Z, "areamex"                 },
		{    "Shift+"..Z, "areamex"                 },
		{ "Ctrl+Alt+"..Z, "areamex"                 },
		{              X, "buildunit_armsolar"      },
		{    "Shift+"..X, "buildunit_armsolar"      },
		{              X, "buildunit_armwin"        },
		{    "Shift+"..X, "buildunit_armwin"        },
		{              X, "buildunit_corsolar"      },
		{    "Shift+"..X, "buildunit_corsolar"      },
		{              X, "buildunit_corwin"        },
		{    "Shift+"..X, "buildunit_corwin"        },
		{              X, "buildunit_armadvsol"     },
		{    "Shift+"..X, "buildunit_armadvsol"     },
		{              X, "buildunit_coradvsol"     },
		{    "Shift+"..X, "buildunit_coradvsol"     },
		{              X, "buildunit_armfus"        },
		{    "Shift+"..X, "buildunit_armfus"        },
		{              X, "buildunit_armmmkr"       },
		{    "Shift+"..X, "buildunit_armmmkr"       },
		{              X, "buildunit_corfus"        },
		{    "Shift+"..X, "buildunit_corfus"        },
		{              X, "buildunit_cormmkr"       },
		{    "Shift+"..X, "buildunit_cormmkr"       },
		{              X, "buildunit_armtide"       },
		{    "Shift+"..X, "buildunit_armtide"       },
		{              X, "buildunit_cortide"       },
		{    "Shift+"..X, "buildunit_cortide"       },
		{              X, "buildunit_armuwfus"      },
		{    "Shift+"..X, "buildunit_armuwfus"      },
		{              X, "buildunit_coruwfus"      },
		{    "Shift+"..X, "buildunit_coruwfus"      },
		{              X, "buildunit_armuwmmm"      },
		{    "Shift+"..X, "buildunit_armuwmmm"      },
		{              X, "buildunit_coruwmmm"      },
		{    "Shift+"..X, "buildunit_coruwmmm"      },
		{              C, "buildunit_armllt"        },
		{    "Shift+"..C, "buildunit_armllt"        },
		{              C, "buildunit_armrad"        },
		{    "Shift+"..C, "buildunit_armrad"        },
		{              C, "buildunit_corllt"        },
		{    "Shift+"..C, "buildunit_corllt"        },
		{              C, "buildunit_corrad"        },
		{    "Shift+"..C, "buildunit_corrad"        },
		{              C, "buildunit_corrl"         },
		{    "Shift+"..C, "buildunit_corrl"         },
		{              C, "buildunit_armrl"         },
		{    "Shift+"..C, "buildunit_armrl"         },
		{              C, "buildunit_armpb"         },
		{    "Shift+"..C, "buildunit_armpb"         },
		{              C, "buildunit_armflak"       },
		{    "Shift+"..C, "buildunit_armflak"       },
		{              C, "buildunit_corvipe"       },
		{    "Shift+"..C, "buildunit_corvipe"       },
		{              C, "buildunit_corflak"       },
		{    "Shift+"..C, "buildunit_corflak"       },
		{              C, "buildunit_armgplat"      },
		{    "Shift+"..C, "buildunit_armgplat"      },
		{              C, "buildunit_corgplat"      },
		{    "Shift+"..C, "buildunit_corgplat"      },
		{              C, "buildunit_armtl"         },
		{    "Shift+"..C, "buildunit_armtl"         },
		{              C, "buildunit_cortl"         },
		{    "Shift+"..C, "buildunit_cortl"         },
		{              C, "buildunit_armsonar"      },
		{    "Shift+"..C, "buildunit_armsonar"      },
		{              C, "buildunit_corsonar"      },
		{    "Shift+"..C, "buildunit_corsonar"      },
		{              C, "buildunit_armfrad"       },
		{    "Shift+"..C, "buildunit_armfrad"       },
		{              C, "buildunit_corfrad"       },
		{    "Shift+"..C, "buildunit_corfrad"       },
		{              C, "buildunit_armfrt"        },
		{    "Shift+"..C, "buildunit_armfrt"        },
		{              C, "buildunit_corfrt"        },
		{    "Shift+"..C, "buildunit_corfrt"        },
		{              V, "buildunit_armnanotc"     },
		{    "Shift+"..V, "buildunit_armnanotc"     },
		{              V, "buildunit_armnanotcplat" },
		{    "Shift+"..V, "buildunit_armnanotcplat" },
		{              V, "buildunit_cornanotcplat" },
		{    "Shift+"..V, "buildunit_cornanotcplat" },
		{              V, "buildunit_armlab"        },
		{    "Shift+"..V, "buildunit_armlab"        },
		{              V, "buildunit_armvp"         },
		{    "Shift+"..V, "buildunit_armvp"         },
		{              V, "buildunit_armap"         },
		{    "Shift+"..V, "buildunit_armap"         },
		{              V, "buildunit_cornanotc"     },
		{    "Shift+"..V, "buildunit_cornanotc"     },
		{              V, "buildunit_corlab"        },
		{    "Shift+"..V, "buildunit_corlab"        },
		{              V, "buildunit_corvp"         },
		{    "Shift+"..V, "buildunit_corvp"         },
		{              V, "buildunit_corap"         },
		{    "Shift+"..V, "buildunit_corap"         },
		{              V, "buildunit_armsy"         },
		{    "Shift+"..V, "buildunit_armsy"         },
		{              V, "buildunit_corsy"         },
		{    "Shift+"..V, "buildunit_corsy"         },

		-- numpad movement
		{ "numpad2", "moveback"    },
		{ "numpad6", "moveright"   },
		{ "numpad4", "moveleft"    },
		{ "numpad8", "moveforward" },
		{ "numpad9", "moveup"      },
		{ "numpad3", "movedown"    },
		{ "numpad1", "movefast"    },

		-- snd_volume_osd
		{ "      +", "snd_volume_increase" },
		{ "numpad+", "snd_volume_increase" },
		{ "      =", "snd_volume_increase" },
		{ "      -", "snd_volume_decrease" },
		{ "numpad-", "snd_volume_decrease" },

		-- los_colors
		{ "Any+sc_;", "losradar" },

		--unit_stats
		{ "Any+space", 'unit_stats' },
	}

	-- if WG['CameraFlip'] then
	table.insert(_binds,  { "Ctrl+Shift+"..O, "cameraflip" })

	--if not WG['Set target default'] then
	table.insert(_binds,  { "Alt+"..Y, "settarget"         })
	table.insert(_binds,  {         Y, "settargetnoground" })

	-- if WG['Auto Group'] then
	table.insert(_binds,  { "Alt+sc_`",  "remove_from_autogroup" })
	table.insert(_binds,  { "Ctrl+sc_`", "remove_one_unit_from_group" })

	for i = 0, 9 do
		if i ~= 0 then
			table.insert(_binds, { i , "specteam", i-1 })
		end

		table.insert(_binds, { 'Alt+'..i , "add_to_autogroup", i })

		table.insert(_binds, { i               , "group", i                  })
		table.insert(_binds, { 'Ctrl+'..i      , "group", "set "..i          })
		table.insert(_binds, { 'Shift+'..i     , "group", "selectadd "..i    })
		table.insert(_binds, { 'Ctrl+Shift+'..i, "group", "add "..i          })
		table.insert(_binds, { 'Ctrl+Alt+'..i  , "group", "selecttoggle "..i })

	end


	return _binds
end

local function loadEngineBindings(prefix)
	prefix = prefix or ''

	for _, v in ipairs(engineBinds) do
		local command = prefix..'bind '..v[1]..' '..v[2]
		if prefix == '' and v[3] then
			command = command..' '..v[3]
		end
		Spring.SendCommands(command)
	end
end

local function loadBindings(prefix)
	prefix = prefix or ''
	local keyLayout = keyConfig.keyLayouts[currentLayout]

	if prefix == '' and WG['buildmenu'] and WG['buildmenu'].reloadBindings then
		WG['buildmenu'].reloadBindings()
	end

	for _, v in ipairs(makeBindsTable(keyLayout)) do
		local command = prefix..'bind '..v[1]..' '..v[2]
		if prefix == '' and v[3] then
			command = command..' '..v[3]
		end
		Spring.SendCommands(command)
	end
end

local function reloadBindings()
	local newLayout = Spring.GetConfigString("KeyboardLayout", 'qwerty')

	if currentLayout then
		loadBindings('un')
	end

	currentLayout = newLayout
	loadBindings()
end

function widget:Initialize()
	loadEngineBindings('un')
	reloadBindings()

	WG.reloadBindings = reloadBindings
end

function widget:Shutdown()
	loadBindings('un')
	loadEngineBindings()
end
