

----------------------------------------------------------------------------
-- BURSTS ------------------------------------------------------------------
----------------------------------------------------------------------------

shieldBursts550 = {
  layer      = -35,
  life       = math.huge,
  piece      = "base",
  rotSpeed   = 0.90,
  rotSpread  = 0,
  arc        = 32,
  arcSpread  = 8,
  size       = 525,
  sizeSpread = 50,
  texture    = "bitmaps/GPL/Lups/shieldbursts5.png",
  --colormap   = { {1, 0.6, 1, 0.8} },
  colormap   = { {1, 1, 1, 0.06} },
  directional= true,
  repeatEffect = true,
  count      = 4,
}

shieldBursts600 = {
  layer      = -35,
  life       = math.huge,
  piece      = "base",
  rotSpeed   = 0.85,
  rotSpread  = 0,
  arc        = 32,
  arcSpread  = 8,
  size       = 575,
  sizeSpread = 50,
  texture    = "bitmaps/GPL/Lups/shieldbursts5.png",
  --colormap   = { {1, 0.6, 1, 0.8} },
  colormap   = { {1, 1, 1, 0.06} },
  directional= true,
  repeatEffect = true,
  count      = 4,
}

  ----------------------------------------------------------------------------
  -- Colorspheres ------------------------------------------------------------
  ----------------------------------------------------------------------------

  corafusShieldSphere = {
    layer=-35,
    life=20,
    pos={0,60,0},
    size=32,
    light = 2.5,
    --colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    --colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
    repeatEffect=true
  }

  armafusShieldSphere = {
    layer=-35,
    life=20,
    pos={0,60,0},
    size=28,
    light = 2.5,
    --colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    --colormap2 = { {0.2, 0.2, 1, 0.7},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.75},{0.2, 0.2, 1, 0.7} },
    repeatEffect=true
  }

  corfusShieldSphere = {
    layer=-35,
    life=20,
    pos = {0,51,0},
    size=23,
    light = 2.5,
    --colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    --colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
    repeatEffect=true
  }

  corgateShieldSphere = {
    layer=-35,
    life=20,
    pos = {0,42,0},
    size= 11,
    light = 2,
    colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
    repeatEffect=true
  }

  armjunoShieldSphere = {
    layer=-35,
    life=20,
    pos = {0,72,0},
    size=13,
    light = 2,
    colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    colormap2 = { {0.8, 0.2, 0.2, 0.4},{0.8, 0.2, 0.2, 0.45},{0.9, 0.2, 0.2, 0.45},{0.9, 0.1, 0.2, 0.4} },
    repeatEffect=true
  }

  corjunoShieldSphere = {
    layer=-35,
    life=20,
    pos = {0,72,0},
    size=13,
    light = 2,
    colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    colormap2 = { {0.8, 0.2, 0.2, 0.4},{0.8, 0.2, 0.2, 0.45},{0.9, 0.2, 0.2, 0.45},{0.9, 0.1, 0.2, 0.4} },
    repeatEffect=true
  }

  armgateShieldSphere = {
    layer=-35,
    life=20,
    pos = {0,23.5,-5},
    size=14.5,
    light = 2,
    colormap1 = { {0.9, 0.9, 1, 0.75},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 1.0},{0.9, 0.9, 1, 0.75} },
    colormap2 = { {0.2, 0.6, 0.2, 0.4},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.45},{0.2, 0.6, 0.2, 0.4} },
    repeatEffect=true
  }

  ----------------------------------------------------------------------------
  -- Lights ------------------------------------------------------------------
  ----------------------------------------------------------------------------

  cormakrEffect = {
    life       = math.huge,
    pos        = {0,24,0},
    size       = 26,
    sizeSpread = 7,
    colormap   = { {0.8, 0.8, 0.5, 0.01} },
    onActive   = true,
    texture    = 'bitmaps/flare.TGA',
  }

