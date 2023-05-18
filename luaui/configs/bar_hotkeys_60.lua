-- BAR hotkey config file: optimized for use with grid build menu and 60% keyboards.
-- remaps F-keys to use meta+ (spacebar) and moves commands from ` to sc_q with modifiers.
	local bindings = {
		{            "esc", "select", "AllMap++_ClearSelection_SelectNum_0+" },
		{            "esc", "quitmessage"                },
		{      "Shift+esc", "quitmenu"                   },
		{ "Ctrl+Shift+esc", "quitforce"                  },
		{  "Alt+Shift+esc", "reloadforce"                },
		{     "Any+escape", "edit_escape"                },
		{      "Any+pause", "pause"                      },
		{            "esc", "teamstatus_close"           },
		{            "esc", "customgameinfo_close"       },
		{            "esc", "buildmenu_pregame_deselect" },
--		{        "Any+alt", "mobile_waypoint_modifier"   }, --use this for badosu's mobile waypoint widget

		{  "Any+sc_z", "selectbox_same"     }, -- select only units that share type with current selection modifier | Smart Select Widget
		{ "Any+space", "selectbox_idle"     }, -- select only idle units modifier | Smart Select Widget
		{ "Any+shift", "selectbox_all"      }, -- select all units modifier | Smart Select Widget
		{  "Any+ctrl", "selectbox_deselect" }, -- remove units from current selection modifier | Smart Select Widget
		{   "Any+alt", "selectbox_mobile"   }, -- select only mobile units modifier | Smart Select Widget

		{      "Any+space", "selectloop"        }, -- activate select shape | Loop Select Widget
		{       "Any+ctrl", "selectloop_invert" }, -- select units not present in current selection modifier | Loop Select Widget
		{      "Any+shift", "selectloop_add"    }, -- add to selection modifier | Loop Select Widget

		{           "sc_z", "gridmenu_category 1" },
		{           "sc_x", "gridmenu_category 2" },
		{           "sc_c", "gridmenu_category 3" },
		{           "sc_v", "gridmenu_category 4" },
		{     "Shift+sc_z", "gridmenu_category 1" },
		{     "Shift+sc_x", "gridmenu_category 2" },
		{     "Shift+sc_c", "gridmenu_category 3" },
		{     "Shift+sc_v", "gridmenu_category 4" },
		{       "Any+sc_z", "gridmenu_key 1 1"    },
		{       "Any+sc_x", "gridmenu_key 1 2"    },
		{       "Any+sc_c", "gridmenu_key 1 3"    },
		{       "Any+sc_v", "gridmenu_key 1 4"    },
		{       "Any+sc_a", "gridmenu_key 2 1"    },
		{       "Any+sc_s", "gridmenu_key 2 2"    },
		{       "Any+sc_d", "gridmenu_key 2 3"    },
		{       "Any+sc_f", "gridmenu_key 2 4"    },
		{       "Any+sc_q", "gridmenu_key 3 1"    },
		{       "Any+sc_w", "gridmenu_key 3 2"    },
		{       "Any+sc_e", "gridmenu_key 3 3"    },
		{       "Any+sc_r", "gridmenu_key 3 4"    },
		{           "sc_b", "gridmenu_next_page"  },

		{      "Any+enter", "chat"           },
		{  "Alt+ctrl+sc_a", "chatswitchally" },
		{  "Alt+ctrl+sc_s", "chatswitchspec" },

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

		{ "Alt+sc_=",    "increasespeed" },
		{ "Alt+sc_-",    "decreasespeed" },
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
		{            "sc_a", "attack"          },
		{      "Shift+sc_a", "attack"          },
		{       "Ctrl+sc_a", "areaattack"      },
		{ "Ctrl+Shift+sc_a", "areaattack"      },
		{       "sc_b,sc_b", "onoff", "0"           },
		{            "sc_b", "onoff", "1"           },
		{ "Shift+sc_b,Shift+sc_b", "onoff", "0"     },
		{      "Shift+sc_b", "onoff", "1"           },
		{       "Ctrl+sc_b", "selfd"           },
		{ "Ctrl+Shift+sc_b", "selfd", "queued" },
		{            "sc_d", "manualfire"      },
		{      "Shift+sc_d", "manualfire"      },
		{            "sc_d", "manuallaunch"    },
		{      "Shift+sc_d", "manuallaunch"    },
		{            "sc_e", "reclaim"         },
		{      "Shift+sc_e", "reclaim"         },
		{            "sc_f", "fight"           },
		{      "Shift+sc_f", "fight"           },
		{        "Alt+sc_f", "forcestart"      },
		{            "sc_g", "stopproduction"  },
		{      "Shift+sc_g", "stopproduction"  },
		{            "sc_g", "stop"            },
		{      "Shift+sc_g", "stop"            },
		{            "sc_h", "patrol"          },
		{      "Shift+sc_h", "patrol"          },
		{            "sc_i", "unit_stats"      },
		{       "Ctrl+sc_i", "customgameinfo"  },
		{            "sc_j", "loadunits"       },
		{      "Shift+sc_j", "loadunits"       },		
		{            "sc_k", "cloak"           },
		{      "Shift+sc_k", "cloak"           },
		{            "sc_k", "wantcloak"       },
		{        "Any+sc_k", "wantcloak"       },
		{       "sc_l,sc_l,sc_l", "firestate", "1"  },
		{       "sc_l,sc_l", "firestate", "0"  },
		{            "sc_l", "firestate", "2"  },
		{ "Shift+sc_l,Shift+sc_l,Shift+sc_l", "firestate", "1"  },
		{ "Shift+sc_l,Shift+sc_l", "firestate", "0"  },
		{      "Shift+sc_l", "firestate", "2"  },
		{  "sc_;,sc_;,sc_;", "movestate", "1"  }, 
		{       "sc_;,sc_;", "movestate", "0"  },
		{            "sc_;", "movestate", "2"  },
	    {       "Shift+sc_;,Shift+sc_;,Shift+sc_;", "movestate", "1"  },	
		{ "Shift+sc_;,Shift+sc_;", "movestate", "0"  },
		{      "Shift+sc_;", "movestate", "2"  }, 
		{            "sc_m", "restore"         },
		{      "Shift+sc_m", "restore"         },
		{            "sc_n", "command_skip_current" }, 
		{       "Ctrl+sc_n", "command_cancel_last"  }, 
		{            "sc_o", "guard"           },
		{      "Shift+sc_o", "guard"           },
		{        "Alt+sc_o", "cameraflip"      },
		{            "sc_p", "gatherwait"      },
		{      "Shift+sc_p", "gatherwait"      },
--		{       "sc_r,sc_r", "prioritise"      }, --use with Lexon's prioritise widget
		{            "sc_r", "repair"          },
		{      "Shift+sc_r", "repair"          },
		{            "sc_s", "settarget"       },
		{       "Ctrl+sc_s", "canceltarget"    },
		{       "sc_t,sc_t", "repeat", "0"     },
		{            "sc_t", "repeat", "1"     },
		{ "Shift+sc_t,Shift+sc_t", "repeat", "0"     }, 
		{      "Shift+sc_t", "repeat", "1"     },
		{       "Ctrl+sc_t", "toggleoverview"  },
		{            "sc_u", "unloadunits"     },
		{      "Shift+sc_u", "unloadunits"     },
		{            "sc_w", "resurrect"       },
		{      "Shift+sc_w", "resurrect"       },
		{            "sc_w", "capture"         },
		{      "Shift+sc_w", "capture"         },
		{            "sc_y", "wait"            },
		{      "Shift+sc_y", "wait", "queued"  },
		{       "Ctrl+sc_z", "areamex"         },

		{ "Any+sc_'", "togglelos"             },
--		{ "Any+sc_'", "losradar"              },

		{ "Ctrl+meta+5", "viewta"             },
		{ "Ctrl+meta+6", "viewspring"         },
		{ "Ctrl+meta+7", "HideInterface"      },
		{ "meta+5" , "LastMsgPos"             },
		{ "meta+6" , "ShowPathTraversability" },
		{ "meta+7" , "ShowMetalMap"           },
		{ "meta+8" , "ShowElevation"          },

		{    "f11" , "luaui selector"         },
		{ "Any+f12", "screenshot"     , "png" },
		{ "Alt+backspace", "fullscreen"       },

		{      "Ctrl+meta+sc_q", "group unset"           },
		{            "Alt+sc_q", "remove_from_autogroup" },
		{ "meta+sc_q,meta+sc_q", "drawlabel"             },
		{           "meta+sc_q", "drawinmap"             },

		{ "Any+up",       "moveforward"  },
		{ "Any+down",     "moveback"     },
		{ "Any+right",    "moveright"    },
		{ "Any+left",     "moveleft"     },
		{ "Any+pageup",   "moveup"       },
		{ "Any+pagedown", "movedown"     },
--		{ "Any+home", "weapon_range_toggle"  }, --added for gui_selected_weapon_range.lua
--		{ "Any+pageup",   "weapon_range_cycle_color_mode"       }, --added for gui_selected_weapon_range.lua
--		{ "Any+pagedown", "weapon_range_cycle_display_mode"     }, --added for gui_selected_weapon_range.lua

		{ "Any+alt",   "movereset"  }, -- fast camera reset on mousewheel
		{ "Any+alt",   "moverotate" }, -- rotate on x,y with mmb hold + move (Spring Camera)
		{ "Any+ctrl",  "movetilt"   }, -- rotate on x with mousewheel

		{ "Ctrl+sc_e",    "select", "AllMap++_ClearSelection_SelectAll+"                                                                                       },
		{  "Ctrl+tab",    "select", "AllMap+_Builder_Idle+_ClearSelection_SelectOne+"                                                                          },
		{       "tab",    "select", "AllMap+_ManualFireUnit_Not_IdMatches_cordecom_Not_IdMatches_armdecom_Not_IdMatches_armthor+_ClearSelection_SelectOne+"    },
		{      "sc_q",    "select", "Visible+_InPrevSel+_ClearSelection_SelectAll+"                                                                            },
		{ "Ctrl+sc_q",    "select", "PrevSelection++_ClearSelection_SelectPart_50+"                                                                            },		
		{ "Ctrl+sc_w",    "select", "AllMap+_InPrevSel+_ClearSelection_SelectAll+"                                                                             },
		{ "Ctrl+sc_r",    "select", "AllMap+_Transport_Idle+_ClearSelection_SelectAll+"                                                                        }, 
        { "Ctrl+sc_y",    "select", "Visible+_Waiting+_ClearSelection_SelectAll+"                                                                              }, 

		-- numpad movement
		{ "numpad2", "moveback"    },
		{ "numpad6", "moveright"   },
		{ "numpad4", "moveleft"    },
		{ "numpad8", "moveforward" },
		{ "numpad9", "moveup"      },
		{ "numpad3", "movedown"    },
		{ "numpad1", "movefast"    },

		-- snd_volume_osd
		{ "backspace", "MuteSound" },
		{ "numpad+", "snd_volume_increase" },
		{ "   sc_=", "snd_volume_increase" },
		{ "   sc_-", "snd_volume_decrease" },
		{ "numpad-", "snd_volume_decrease" },
	}

--	Loops that define group hotkeys, autogroups, and camera anchors. 
	for i = 0, 9 do
		table.insert(bindings, { 'Alt+'..i , "add_to_autogroup", i })

		table.insert(bindings, { i               , "group", i                  })
		table.insert(bindings, { 'Ctrl+'..i      , "group", "set "..i          })
		table.insert(bindings, { 'Shift+'..i     , "group", "add "..i    })
		table.insert(bindings, { 'Ctrl+Shift+'..i, "group", "selectadd "..i          })
		table.insert(bindings, { 'Ctrl+Alt+'..i  , "group", "selecttoggle "..i })

	end

	for i = 1, 4 do
		table.insert(bindings, { 'Ctrl+meta+'..i , "set_camera_anchor", i })
		table.insert(bindings, { 'meta+'..i , "focus_camera_anchor", i })

	end

return bindings
