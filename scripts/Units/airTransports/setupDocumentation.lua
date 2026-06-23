return {
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
