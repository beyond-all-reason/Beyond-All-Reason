// These functions are what notify synced gadgets about actual construction taking place. 
// They are designed to minimize double-calling of stopbuilding from the engine (as its called on all commands) 
// NOTE:
// INBUILDSTANCE is only obeyed on construction start, see:
// NOTE:
//   technically this block of code should be guarded by
//   "if (inBuildStance)", but doing so can create zombie
//   guarders because scripts might not set inBuildStance
//   to true when guard or repair orders are executed and
//   SetRepairTarget does not check for it
//
//   StartBuild *does* ensure construction will not start
//   until inBuildStance is set to true by the builder's
//   script, and there are no cases during construction
//   when inBuildStance can become false yet the buildee
//   should be kept from decaying, so this is free from
//   serious side-effects (when repairing, a builder might
//   start adding build-power before having fully finished
//   its opening animation)
//if (!(inBuildStance || true))
//	return true;

#define ENABLED 0

#if ENABLED == 1
	
	// We assume luaBuildEffectOn is initialized to 0
	static-var luaBuildEffectOn;
	
	// I dont think the body of any lua_ func is actually executed
	lua_UnitScriptBuildStartStop(onOff, p1, p2, p3)
	{
		return (0); 
	}

	// Only call this when actually changed
	// lua_UnitScriptBuildStartStop(onOff, p1, p2, p3){ 
	// luaBuildEffectOn = onOff; 
	// return (0);}


	#define LUASTARTBUILD if (!luaBuildEffectOn){\
		luaBuildEffectOn = !luaBuildEffectOn; \
		call-script lua_UnitScriptBuildStartStop(1);}

	#define LUASTOPBUILD if (luaBuildEffectOn) {\
		luaBuildEffectOn = !luaBuildEffectOn; \
		call-script lua_UnitScriptBuildStartStop(0);}

#else
	#define LUASTARTBUILD
	#define LUASTOPBUILD
#endif
