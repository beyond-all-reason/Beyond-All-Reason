#include "side.as"
#include "role.as"


namespace Init {

void Init(dictionary@ data)
{
	aiLog("AngelScript Rules!");

	dictionary category;
	category["air"]   = "VTOL NOTSUB";
	category["land"]  = "SURFACE NOTSUB";
	category["water"] = "UNDERWATER NOTHOVER";
	category["bad"]   = "TERRAFORM STUPIDTARGET MINE";
	category["good"]  = "TURRET FLOAT";

	data["category"] = @category;
}

}
