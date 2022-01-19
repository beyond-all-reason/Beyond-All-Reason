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

TypeMask ROLE0   = AiAddRole("cloaked_raider",  ASSAULT.type);
TypeMask ROLE1   = AiAddRole("snipe_target",    ASSAULT.type);
TypeMask ROLE2   = AiAddRole("bullshit_raider", ASSAULT.type);
TypeMask ROLE3   = AiAddRole("disarm_target",   ASSAULT.type);
TypeMask ROLE4   = AiAddRole("shieldball",      ASSAULT.type);
TypeMask ROLE5   = AiAddRole("missileskirm",    ASSAULT.type);
TypeMask ROLE6   = AiAddRole("turtle",          ASSAULT.type);
TypeMask ROLE7   = AiAddRole("role7",           ASSAULT.type);
TypeMask ROLE8   = AiAddRole("role8",           ASSAULT.type);
TypeMask ROLE9   = AiAddRole("role9",           ASSAULT.type);
TypeMask ROLE10  = AiAddRole("anti_heavy_ass",  SUPPORT.type);
TypeMask ROLE11  = AiAddRole("builderT2",       BUILDER.type);
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
TypeMask VAMPIRE   = aiAttrMasker.GetTypeMask("vampire");
}  // namespace Attr

}  // namespace Unit
