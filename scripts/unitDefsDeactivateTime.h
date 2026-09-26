/* unitDefsDeactivateTime.h
	requires: recoil_common_includes.h
	provides: deactivateTime (in milliseconds)
*/

static-var deactivateTime;

SetDeactivateTime(var1)
{
	deactivateTime = var1 * MILLISECONDS_PER_FRAME;
}
