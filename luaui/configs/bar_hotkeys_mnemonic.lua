-- BAR hotkey config file - for users with non-qwerty layouts who have
-- learned _mnemonic_ binds instead of _positional_ binds.
local bindings = {
	{            "esc", "quitmessage"                },
	{      "Shift+esc", "quitmenu"                   },
	{ "Ctrl+Shift+esc", "quitforce"                  },
	{  "Alt+Shift+esc", "reloadforce"                },
	{     "Any+escape", "edit_escape"                },
	{      "Any+pause", "pause"                      },
	{            "esc", "teamstatus_close"           },
	{            "esc", "customgameinfo_close"       },
	{            "esc", "buildmenu_pregame_deselect" },

		{  "Any+sc_z", "selectbox_same"     }, -- select only units that share type with current selection modifier | Smart Select Widget
		{ "Any+space", "selectbox_idle"     }, -- select only idle units modifier | Smart Select Widget
		{ "Any+shift", "selectbox_all"      }, -- select all units modifier | Smart Select Widget
		{  "Any+ctrl", "selectbox_deselect" }, -- remove units from current selection modifier | Smart Select Widget
		{   "Any+alt", "selectbox_mobile"   }, -- select only mobile units modifier | Smart Select Widget

		{      "Any+space", "selectloop"        }, -- activate select shape | Loop Select Widget
		{       "Any+ctrl", "selectloop_invert" }, -- select units not present in current selection modifier | Loop Select Widget
		{      "Any+shift", "selectloop_add"    }, -- add to selection modifier | Loop Select Widget

	{     "sc_c", "controlunit"    },
	{ "Any+sc_h", "sharedialog"    },
	{     "sc_i", "customgameinfo" },

	{        "Any+sc_j", "mouse2" },
	{ "Shift+backspace", "togglecammode" },
	{  "Ctrl+backspace", "togglecammode" },
	{         "Any+tab", "toggleoverview" },

	{     "Any+enter", "chat"           },
	{ "Alt+ctrl+sc_a", "chatswitchally" },
	{ "Alt+ctrl+sc_s", "chatswitchspec" },

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

	{            "a", "attack"          },
	{      "Shift+a", "attack"          },
	{        "Alt+a", "areaattack"      },
	{  "Alt+Shift+a", "areaattack"      },
	{        "Alt+b", "debug"           },
	{        "Alt+v", "debugcolvol"     },
	{        "Alt+p", "debugpath"       },
	{            "d", "manualfire"      },
	{      "Shift+d", "manualfire"      },
	{            "d", "manuallaunch"    },
	{      "Shift+d", "manuallaunch"    },
	{       "Ctrl+d", "selfd"           },
	{ "Ctrl+Shift+d", "selfd", "queued" },
	{            "e", "reclaim"         },
	{      "Shift+e", "reclaim"         },
	{            "f", "fight"           },
	{      "Shift+f", "fight"           },
	{        "Alt+f", "forcestart"      },
	{            "g", "guard"           },
	{      "Shift+g", "guard"           },
	{            "j", "canceltarget"    },
	{            "k", "cloak"           },
	{      "Shift+k", "cloak"           },
	{            "k", "wantcloak"       },
	{        "Any+k", "wantcloak"       },
	{            "l", "loadunits"       },
	{      "Shift+l", "loadunits"       },
	{            "m", "move"            },
	{      "Shift+m", "move"            },
	{            "p", "patrol"          },
	{      "Shift+p", "patrol"          },
	{     "Any+sc_q", "drawinmap"       }, --some keyboards don't have ` or \
	{     "Any+sc_q", "drawlabel"       },
	{    "sc_q,sc_q", "drawlabel"       }, -- double hit Q for drawlabel
	{            "r", "repair"          },
	{      "Shift+r", "repair"          },
	{            "s", "stop"            },
	{      "Shift+s", "stop"            },
	{       "Ctrl+s", "stopproduction"  },
	{            "u", "unloadunits"     },
	{      "Shift+u", "unloadunits"     },
	{            "w", "wait"            },
	{      "Shift+w", "wait", "queued"  },
	{            "x", "onoff"           },
	{      "Shift+x", "onoff"           },

	{ "Any+l", "togglelos" },

	{ "Ctrl+t", "trackmode" },
	{  "Any+t", "track" },

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

	{ "Any+alt",   "movereset" }, -- fast camera reset on some camera states, e.g. middle mouse held
	{ "Any+ctrl",  "movetilt"  }, -- Move inclination of camera

	{ "Ctrl+a", "select", "AllMap++_ClearSelection_SelectAll+"                                                                                    },
	{ "Ctrl+b", "select", "AllMap+_Builder_Idle+_ClearSelection_SelectOne+"                                                                       },
	{ "Ctrl+c", "select", "AllMap+_ManualFireUnit_Not_IdMatches_cordecom_Not_IdMatches_armdecom_Not_IdMatches_armthor+_ClearSelection_SelectOne+" },
	{ "Ctrl+r", "select", "AllMap+_Radar+_ClearSelection_SelectAll+"                                                                              },
	{ "Ctrl+v", "select", "AllMap+_Not_Builder_Not_Commander_InPrevSel_Not_InHotkeyGroup+_SelectAll+"                                             },
	{ "Ctrl+w", "select", "AllMap+_Not_Aircraft_Weapons+_ClearSelection_SelectAll+"                                                               },
	{ "Ctrl+x", "select", "AllMap+_InPrevSel_Not_InHotkeyGroup+_SelectAll+"                                                                       },
	{ "Ctrl+z", "select", "AllMap+_InPrevSel+_ClearSelection_SelectAll+"                                                                          },

	-- building hotkeys
	{          "sc_z", "buildunit_armmex"        },
	{    "Shift+sc_z", "buildunit_armmex"        },
	{          "sc_z", "buildunit_armamex"       },
	{    "Shift+sc_z", "buildunit_armamex"       },
	{          "sc_z", "buildunit_cormex"        },
	{    "Shift+sc_z", "buildunit_cormex"        },
	{          "sc_z", "buildunit_corexp"        },
	{    "Shift+sc_z", "buildunit_corexp"        },
	{          "sc_z", "buildunit_armmoho"       },
	{    "Shift+sc_z", "buildunit_armmoho"       },
	{          "sc_z", "buildunit_cormoho"       },
	{    "Shift+sc_z", "buildunit_cormoho"       },
	{          "sc_z", "buildunit_cormexp"       },
	{    "Shift+sc_z", "buildunit_cormexp"       },
	{          "sc_z", "buildunit_coruwmex"      },
	{    "Shift+sc_z", "buildunit_coruwmex"      },
	{          "sc_z", "buildunit_armuwmex"      },
	{    "Shift+sc_z", "buildunit_armuwmex"      },
	{          "sc_z", "buildunit_coruwmme"      },
	{    "Shift+sc_z", "buildunit_coruwmme"      },
	{          "sc_z", "buildunit_armuwmme"      },
	{    "Shift+sc_z", "buildunit_armuwmme"      },
	{          "sc_z", "areamex"                 },
	{    "Shift+sc_z", "areamex"                 },
	{ "Ctrl+Alt+sc_z", "areamex"                 },
	{          "sc_x", "buildunit_armsolar"      },
	{    "Shift+sc_x", "buildunit_armsolar"      },
	{          "sc_x", "buildunit_armwin"        },
	{    "Shift+sc_x", "buildunit_armwin"        },
	{          "sc_x", "buildunit_corsolar"      },
	{    "Shift+sc_x", "buildunit_corsolar"      },
	{          "sc_x", "buildunit_corwin"        },
	{    "Shift+sc_x", "buildunit_corwin"        },
	{          "sc_x", "buildunit_armadvsol"     },
	{    "Shift+sc_x", "buildunit_armadvsol"     },
	{          "sc_x", "buildunit_coradvsol"     },
	{    "Shift+sc_x", "buildunit_coradvsol"     },
	{          "sc_x", "buildunit_armfus"        },
	{    "Shift+sc_x", "buildunit_armfus"        },
	{          "sc_x", "buildunit_armmmkr"       },
	{    "Shift+sc_x", "buildunit_armmmkr"       },
	{          "sc_x", "buildunit_corfus"        },
	{    "Shift+sc_x", "buildunit_corfus"        },
	{          "sc_x", "buildunit_cormmkr"       },
	{    "Shift+sc_x", "buildunit_cormmkr"       },
	{          "sc_x", "buildunit_armtide"       },
	{    "Shift+sc_x", "buildunit_armtide"       },
	{          "sc_x", "buildunit_cortide"       },
	{    "Shift+sc_x", "buildunit_cortide"       },
	{          "sc_x", "buildunit_armuwfus"      },
	{    "Shift+sc_x", "buildunit_armuwfus"      },
	{          "sc_x", "buildunit_coruwfus"      },
	{    "Shift+sc_x", "buildunit_coruwfus"      },
	{          "sc_x", "buildunit_armuwmmm"      },
	{    "Shift+sc_x", "buildunit_armuwmmm"      },
	{          "sc_x", "buildunit_coruwmmm"      },
	{    "Shift+sc_x", "buildunit_coruwmmm"      },
	{          "sc_c", "buildunit_armllt"        },
	{    "Shift+sc_c", "buildunit_armllt"        },
	{          "sc_c", "buildunit_armrad"        },
	{    "Shift+sc_c", "buildunit_armrad"        },
	{          "sc_c", "buildunit_corllt"        },
	{    "Shift+sc_c", "buildunit_corllt"        },
	{          "sc_c", "buildunit_corrad"        },
	{    "Shift+sc_c", "buildunit_corrad"        },
	{          "sc_c", "buildunit_corrl"         },
	{    "Shift+sc_c", "buildunit_corrl"         },
	{          "sc_c", "buildunit_armrl"         },
	{    "Shift+sc_c", "buildunit_armrl"         },
	{          "sc_c", "buildunit_armpb"         },
	{    "Shift+sc_c", "buildunit_armpb"         },
	{          "sc_c", "buildunit_armflak"       },
	{    "Shift+sc_c", "buildunit_armflak"       },
	{          "sc_c", "buildunit_corvipe"       },
	{    "Shift+sc_c", "buildunit_corvipe"       },
	{          "sc_c", "buildunit_corflak"       },
	{    "Shift+sc_c", "buildunit_corflak"       },
	{          "sc_c", "buildunit_armgplat"      },
	{    "Shift+sc_c", "buildunit_armgplat"      },
	{          "sc_c", "buildunit_corgplat"      },
	{    "Shift+sc_c", "buildunit_corgplat"      },
	{          "sc_c", "buildunit_armtl"         },
	{    "Shift+sc_c", "buildunit_armtl"         },
	{          "sc_c", "buildunit_cortl"         },
	{    "Shift+sc_c", "buildunit_cortl"         },
	{          "sc_c", "buildunit_armsonar"      },
	{    "Shift+sc_c", "buildunit_armsonar"      },
	{          "sc_c", "buildunit_corsonar"      },
	{    "Shift+sc_c", "buildunit_corsonar"      },
	{          "sc_c", "buildunit_armfrad"       },
	{    "Shift+sc_c", "buildunit_armfrad"       },
	{          "sc_c", "buildunit_corfrad"       },
	{    "Shift+sc_c", "buildunit_corfrad"       },
	{          "sc_c", "buildunit_armfrt"        },
	{    "Shift+sc_c", "buildunit_armfrt"        },
	{          "sc_c", "buildunit_corfrt"        },
	{    "Shift+sc_c", "buildunit_corfrt"        },
	{          "sc_v", "buildunit_armnanotc"     },
	{    "Shift+sc_v", "buildunit_armnanotc"     },
	{          "sc_v", "buildunit_armnanotcplat" },
	{    "Shift+sc_v", "buildunit_armnanotcplat" },
	{          "sc_v", "buildunit_cornanotcplat" },
	{    "Shift+sc_v", "buildunit_cornanotcplat" },
	{          "sc_v", "buildunit_armlab"        },
	{    "Shift+sc_v", "buildunit_armlab"        },
	{          "sc_v", "buildunit_armvp"         },
	{    "Shift+sc_v", "buildunit_armvp"         },
	{          "sc_v", "buildunit_armap"         },
	{    "Shift+sc_v", "buildunit_armap"         },
	{          "sc_v", "buildunit_cornanotc"     },
	{    "Shift+sc_v", "buildunit_cornanotc"     },
	{          "sc_v", "buildunit_corlab"        },
	{    "Shift+sc_v", "buildunit_corlab"        },
	{          "sc_v", "buildunit_corvp"         },
	{    "Shift+sc_v", "buildunit_corvp"         },
	{          "sc_v", "buildunit_corap"         },
	{    "Shift+sc_v", "buildunit_corap"         },
	{          "sc_v", "buildunit_armsy"         },
	{    "Shift+sc_v", "buildunit_armsy"         },
	{          "sc_v", "buildunit_corsy"         },
	{    "Shift+sc_v", "buildunit_corsy"         },

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

	-- if WG['CameraFlip'] then
	{ "Ctrl+Shift+o", "cameraflip" },

	--if not WG['Set target default'] then
	{ "Alt+y", "settarget"         },
	{     "y", "settargetnoground" },

	-- if WG['Auto Group'] then
	{ "Alt+sc_`",  "remove_from_autogroup" },
	{ "Ctrl+sc_`", "remove_one_unit_from_group" },
}

for i = 0, 9 do
	if i ~= 0 then
		table.insert(bindings, { i , "specteam", i-1 })
	end

	table.insert(bindings, { 'Alt+'..i , "add_to_autogroup", i })

	table.insert(bindings, { i               , "group", i                  })
	table.insert(bindings, { 'Ctrl+'..i      , "group", "set "..i          })
	table.insert(bindings, { 'Shift+'..i     , "group", "selectadd "..i    })
	table.insert(bindings, { 'Ctrl+Shift+'..i, "group", "add "..i          })
	table.insert(bindings, { 'Ctrl+Alt+'..i  , "group", "selecttoggle "..i })
end

return bindings
