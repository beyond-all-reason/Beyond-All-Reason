-- jethtrail
-- reactionalien4
-- nanoflame
-- surfacesplash
-- upwelling
-- reactionalien
-- jetmtrail
-- jetbtrail
-- nanoflamepurple
-- missilepoofs
-- reactionalien2
-- airfactoryhtrail
-- reactionalien3
-- ffmuzzle
-- jetstrail

return {
  ["jethtrail"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.9 0.8 0.7 0.01   0.9 0.5 0.2 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 25,
        sidetexture        = [[shot]],
        size               = 7,
        sizegrowth         = 2,
        ttl                = 2,
      },
    },
  },

  ["reactionalien4"] = {
    heatcloud = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        heat               = 20,
        heatfalloff        = 1,
        maxheat            = 25,
        pos                = [[0, 0, 0]],
        size               = 6,
        sizegrowth         = 0.125,
        sizemod            = 0,
        sizemodmod         = 0,
        speed              = [[r-0.65 r0.65, r-0.65 r0.65, r-0.65 r0.65]],
        texture            = [[PlasmaHeatDB]],
      },
    },
  },

  ["nanoflame"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.5 0.7 0.6 0.01   0.2 0.9 0.5 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 60,
        sidetexture        = [[flashside2]],
        size               = 3,
        sizegrowth         = 1.2,
        ttl                = 40,
      },
    },
  },

  ["surfacesplash"] = {
    dirtw1 = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true,
      properties = {
        airdrag            = 0.5,
        colormap           = [[0.9 0.9 0.9 1.0 0.5 0.5 0.9 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, -0.2, 0]],
        numparticles       = 6,
        particlelife       = 22,
        particlelifespread = 8,
        particlesize       = 3,
        particlesizespread = 2,
        particlespeed      = 1,
        particlespeedspread = 5,
        pos                = [[r-1 r1, 1, r-1 r1]],
        sizegrowth         = 0.2,
        sizemod            = 1.0,
        texture            = [[randomdots]],
        useairlos          = true,
      },
    },
    dirtw2 = {
      class              = [[CSimpleParticleSystem]],
      count              = 1,
      water              = true,
      properties = {
        airdrag            = 0.7,
        colormap           = [[1.0 1.0 1.0 1.0 0.5 0.5 0.8 0.0]],
        directional        = true,
        emitrot            = 90,
        emitrotspread      = 0,
        emitvector         = [[0, 1, 0]],
        gravity            = [[0, 0, 0]],
        numparticles       = 5,
        particlelife       = 15,
        particlelifespread = 5,
        particlesize       = 4,
        particlesizespread = 3,
        particlespeed      = 1,
        particlespeedspread = 4,
        pos                = [[r-1 r1, 1, r-1 r1]],
        sizegrowth         = 0.4,
        sizemod            = 1.0,
        texture            = [[dirt]],
        useairlos          = true,
      },
    },
  },

  ["upwelling"] = {
    pillar = {
      air                = true,
      class              = [[heatcloud]],
      count              = 7,
      ground             = true,
      water              = true,
      properties = {
        heat               = 15,
        heatfalloff        = 2.5,
        maxheat            = 15,
        pos                = [[0,-10 i5, 0]],
        size               = 10,
        sizegrowth         = -1,
        speed              = [[0, 5, 0]],
        texture            = [[LightningStrike]],
      },
    },
  },

  ["reactionalien"] = {
    heatcloud = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        heat               = 20,
        heatfalloff        = 1,
        maxheat            = 25,
        pos                = [[0, 0, 0]],
        size               = 1.5,
        sizegrowth         = 0.2,
        sizemod            = 0,
        sizemodmod         = 0,
        speed              = [[r-0.25 r0.25, r-0.25 r0.25, r-0.25 r0.25]],
        texture            = [[PlasmaHeatDB]],
      },
    },
  },

  ["jetmtrail"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.9 0.8 0.7 0.01   0.9 0.5 0.2 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 15,
        sidetexture        = [[shot]],
        size               = 7,
        sizegrowth         = 1,
        ttl                = 2,
      },
    },
  },

  ["jetbtrail"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.7 0.8 0.9 0.01   0.2 0.5 0.9 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 25,
        sidetexture        = [[shot]],
        size               = 7,
        sizegrowth         = 2,
        ttl                = 2,
      },
    },
  },

  ["nanoflamepurple"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.7 0.1 0.7 0.01   0.9 0.4 0.9 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 10,
        sidetexture        = [[flashside2]],
        size               = 3,
        sizegrowth         = 2,
        ttl                = 2,
      },
    },
  },

  ["missilepoofs"] = {
    smoke = {
      air                = true,
      count              = 10,
      ground             = true,
      water              = true,
      properties = {
        agespeed           = 0.15,
        color              = [[0.8 r0.2]],
        dir                = [[dir]],
        size               = 25,
        sizegrowth         = -1.5,
      },
    },
  },

  ["reactionalien2"] = {
    heatcloud = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        heat               = 20,
        heatfalloff        = 1,
        maxheat            = 25,
        pos                = [[0, 0, 0]],
        size               = 3.5,
        sizegrowth         = -0.2,
        sizemod            = 0,
        sizemodmod         = 0,
        speed              = [[r-0.1 r0.1, r-0.1 r0.1, r-0.1 r0.1]],
        texture            = [[PlasmaHeatDB]],
      },
    },
  },

  ["airfactoryhtrail"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.9 0.8 0.7 0.01   0.9 0.5 0.2 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 25,
        sidetexture        = [[shot]],
        size               = 15,
        sizegrowth         = 2,
        ttl                = 3,
      },
    },
  },

  ["reactionalien3"] = {
    heatcloud = {
      air                = true,
      count              = 3,
      ground             = true,
      water              = true,
      properties = {
        heat               = 20,
        heatfalloff        = 1,
        maxheat            = 25,
        pos                = [[0, 0, 0]],
        size               = 2.5,
        sizegrowth         = 0.125,
        sizemod            = 0,
        sizemodmod         = 0,
        speed              = [[r-1.25 r1.25, r-1.25 r1.25, r-1.25 r1.25]],
        texture            = [[PlasmaHeatDB]],
      },
    },
  },

  ["ffmuzzle"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        airlos             = 0,
        colormap           = [[1 1 0 0.01  1 0.5 0 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.1,
        fronttexture       = [[randomdots]],
        length             = 18,
        sidetexture        = [[shot]],
        size               = 12,
        sizegrowth         = 1,
        ttl                = 3,
      },
    },
  },

  ["jetstrail"] = {
    bitmapmuzzleflame = {
      air                = true,
      class              = [[CBitmapMuzzleFlame]],
      count              = 1,
      ground             = true,
      underwater         = 1,
      water              = true,
      properties = {
        colormap           = [[0.9 0.8 0.7 0.01   0.9 0.5 0.2 0.01   0 0 0 0.01]],
        dir                = [[dir]],
        frontoffset        = 0.05,
        fronttexture       = [[empty]],
        length             = 15,
        sidetexture        = [[shot]],
        size               = 7,
        sizegrowth         = 1,
        ttl                = 2,
      },
    },
  },

}

