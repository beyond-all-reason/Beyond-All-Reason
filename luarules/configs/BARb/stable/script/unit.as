namespace Unit {

namespace Role {
TypeMask BUILDER = aiRoleMasker.GetTypeMask("builder");
TypeMask SCOUT   = aiRoleMasker.GetTypeMask("scout");
TypeMask RAIDER  = aiRoleMasker.GetTypeMask("raider");
TypeMask RIOT    = aiRoleMasker.GetTypeMask("riot");
TypeMask ASSAULT = aiRoleMasker.GetTypeMask("assault");
TypeMask SKIRM   = aiRoleMasker.GetTypeMask("skirmish");
TypeMask ARTY    = aiRoleMasker.GetTypeMask("artillery");
TypeMask AA      = aiRoleMasker.GetTypeMask("anti_air");
TypeMask AS      = aiRoleMasker.GetTypeMask("anti_sub");
TypeMask AH      = aiRoleMasker.GetTypeMask("anti_heavy");
TypeMask BOMBER  = aiRoleMasker.GetTypeMask("bomber");
TypeMask SUPPORT = aiRoleMasker.GetTypeMask("support");
TypeMask MINE    = aiRoleMasker.GetTypeMask("mine");
TypeMask TRANS   = aiRoleMasker.GetTypeMask("transport");
TypeMask AIR     = aiRoleMasker.GetTypeMask("air");
TypeMask SUB     = aiRoleMasker.GetTypeMask("sub");
TypeMask STATIC  = aiRoleMasker.GetTypeMask("static");
TypeMask HEAVY   = aiRoleMasker.GetTypeMask("heavy");
TypeMask SUPER   = aiRoleMasker.GetTypeMask("super");
TypeMask COMM    = aiRoleMasker.GetTypeMask("commander");
// Custom roles
TypeMask ROLE0    = AiAddRole("cloaked_raider",  ASSAULT.type);
TypeMask ROLE1    = AiAddRole("snipe_target",    ASSAULT.type);
TypeMask ROLE2    = AiAddRole("bullshit_raider", ASSAULT.type);
TypeMask ROLE3    = AiAddRole("disarm_target",   ASSAULT.type);
TypeMask ROLE4    = AiAddRole("shieldball",      ASSAULT.type);
TypeMask ROLE5    = AiAddRole("missileskirm",    ASSAULT.type);
TypeMask ROLE6    = AiAddRole("turtle",          ASSAULT.type);
TypeMask ROLE7    = AiAddRole("role7",           ASSAULT.type);
TypeMask ROLE8    = AiAddRole("role8",           ASSAULT.type);
TypeMask REZZER   = AiAddRole("rezzer",          SUPPORT.type);
TypeMask AHA      = AiAddRole("anti_heavy_ass",  SUPPORT.type);
TypeMask BUILDER2 = AiAddRole("builderT2",       BUILDER.type);
}  // namespace Role

namespace Attr {
TypeMask MELEE     = aiAttrMasker.GetTypeMask("melee");
TypeMask BOOST     = aiAttrMasker.GetTypeMask("boost");
TypeMask NO_JUMP   = aiAttrMasker.GetTypeMask("no_jump");
TypeMask NO_STRAFE = aiAttrMasker.GetTypeMask("no_strafe");
TypeMask STOCK     = aiAttrMasker.GetTypeMask("stockpile");
TypeMask SIEGE     = aiAttrMasker.GetTypeMask("siege");
TypeMask RET_HOLD  = aiAttrMasker.GetTypeMask("ret_hold");
TypeMask RET_FIGHT = aiAttrMasker.GetTypeMask("ret_fight");
TypeMask SOLO      = aiAttrMasker.GetTypeMask("solo");
TypeMask BASE      = aiAttrMasker.GetTypeMask("base");
TypeMask DG_COST   = aiAttrMasker.GetTypeMask("dg_cost");
TypeMask DG_STILL  = aiAttrMasker.GetTypeMask("dg_still");
TypeMask JUMP      = aiAttrMasker.GetTypeMask("jump");
TypeMask ONOFF     = aiAttrMasker.GetTypeMask("onoff");
TypeMask VAMPIRE   = aiAttrMasker.GetTypeMask("vampire");
TypeMask RARE      = aiAttrMasker.GetTypeMask("rare");
TypeMask FENCE     = aiAttrMasker.GetTypeMask("fence");
TypeMask REARM     = aiAttrMasker.GetTypeMask("rearm");
TypeMask NO_DGUN   = aiAttrMasker.GetTypeMask("no_dgun");
TypeMask ANTI_STAT = aiAttrMasker.GetTypeMask("anti_stat");
}  // namespace Attr

enum UseAs {
	COMBAT = 0, FENCE, SUPER, STOCK,  // military
	BUILDER, REZZER,  // builder
	FACTORY, ASSIST  // factory
}

}  // namespace Unit

namespace RT {
Type BUILDER = Unit::Role::BUILDER.type;
Type SCOUT   = Unit::Role::SCOUT.type;
Type RAIDER  = Unit::Role::RAIDER.type;
Type RIOT    = Unit::Role::RIOT.type;
Type ASSAULT = Unit::Role::ASSAULT.type;
Type SKIRM   = Unit::Role::SKIRM.type;
Type ARTY    = Unit::Role::ARTY.type;
Type AA      = Unit::Role::AA.type;
Type AS      = Unit::Role::AS.type;
Type AH      = Unit::Role::AH.type;
Type BOMBER  = Unit::Role::BOMBER.type;
Type SUPPORT = Unit::Role::SUPPORT.type;
Type MINE    = Unit::Role::MINE.type;
Type TRANS   = Unit::Role::TRANS.type;
Type AIR     = Unit::Role::AIR.type;
Type SUB     = Unit::Role::SUB.type;
Type STATIC  = Unit::Role::STATIC.type;
Type HEAVY   = Unit::Role::HEAVY.type;
Type SUPER   = Unit::Role::SUPER.type;
Type COMM    = Unit::Role::COMM.type;
// Custom roles
Type AHA      = Unit::Role::AHA.type;
Type BUILDER2 = Unit::Role::BUILDER2.type;
}  // namespace RT
