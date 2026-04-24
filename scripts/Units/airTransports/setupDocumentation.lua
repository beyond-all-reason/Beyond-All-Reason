return {
    cargo = {
        primarySlot = string pieceName, -- unused, will be dropped once I fully review
        terSeats      = number seats, -- total amount of seats available at once

        slots = { -- slot ~= seat; a slot is a specific position in the cargo, with a defined size
            { 
            name = string pieceName, -- name of the link piece of this slot
            size = number slotSize, -- size of the slot
            requires = {  -- piece that are required to be empty for this slot to be used; 
                string pieceName1, 
                string pieceName2, 
                ...,
                }    
            },

        },
    },
    loadMethod = {
        cegScaleFactor = number scale, -- multiplier for the size of the CEG, used to adjust the visual effect
        cegName        = string cegName, -- name of the CEG to use for the loading effect
        beams = { -- beam pieces to emit CEGs from, indexed by slot name
            [string slotName1]= { string beamEmmiterPieceName1, string beamEmmiterPieceName2, ...},
            [string slotName2]= { string beamEmmiterPieceName1, string beamEmmiterPieceName2, ...}, 
            ...,
        },
    },
    anim = {
        idleHover = { -- basic hovering effect
            piece = string pieceName, -- piece to apply the hover effect to (usually root piece)
            scale = number scale, -- multiplier for the amplitude
            speed = number speed, -- multiplier for the speed
        },
        thrusters = { -- list of thruster emitting pieces to show/hide when activated/deactivated
            string pieceName1,
            string pieceName2,
            ...,
        },
        jets = { -- list of the animated jet pieces; the animation is basic: rotate around X axis depending on moveRate
		    string pieceName1,
            string pieceName2,
            ...,
        },
        moveRate = { --X angles and speeds for the MoveRate animation; applied to all jet pieces; keyed by moveRate value (0=hover, 1=forward flight, etc)
            angles = { 
                [number moveRate1] = number angle1, 
                [number moveRate1] = number angle2,
                [number moveRate1]= number angle3, 
                [number moveRate1]= number angle4,
            },
            speeds = {
                [number moveRate1] = number speed1, 
                [number moveRate1]=number speed2, 
                [number moveRate1]=number speed3, 
                [number moveRate1]=number speed4,
            },
        },
        killed = {
            [1] = {
                maxSeverity = number severity, -- severity threshold for this tier, will move to the next tier if severity > maxSeverity
                wreck = number wreckLevel, 
                pieces = { -- list of pieces to explode and sfx types
                    [1] = { 
                        name = string pieceName,  
                        sfx = string sfxType, 
                        -- optional: ["useJets"] = bool useJets, if true, the explosion will be emitted from all pieces in the "jets" list instead
                    },
                    [2] = ...,
                }
            },
            [2] = {...}
        },
    },
    --[[optional:
	wpn = {
	    aimFromPiece = string pieceName, -- piece to use as the origin for aiming calculations
	    aimPiece = string pieceName, -- piece to use for aiming
	    firePiece = string pieceName, -- piece to use for firing
	},
    ]]--
}
