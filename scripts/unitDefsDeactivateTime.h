/* unitDefsDeactivateTime.h
	requires: recoil_common_includes.h
	provides: deactivateTime (in milliseconds)
*/

static-var deactivateTime;

SetDeactivateTime(frames)
{
	deactivateTime = frames * MILLISECONDS_PER_FRAME;
}
