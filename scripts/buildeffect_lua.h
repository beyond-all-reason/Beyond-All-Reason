// These functions are what notify synced gadgets about actual construction taking place. 
// They are designed to minimize double-calling of stopbuilding from the engine (as its called on all commands) 

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
