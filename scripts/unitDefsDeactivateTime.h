/* unitDefsDeactivateTime.h
	requires: recoil_common_includes.h
	provides: deactivateTime (in milliseconds)
*/

static-var deactivateTime;

SetDeactivateTime(deactivateTime)
{
	deactivateTime = deactivateTime * MILLISECONDS_PER_FRAME;
}
