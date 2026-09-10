#ifndef VARIABLE_ANIMATION_H
#define VARIABLE_ANIMATION_H

// Synchronous fractional animation timing for include-ready SuperSkeletor output.
//
// The owning .bos must declare:
//   static-var VA_frames, VA_sleepTime, VA_amplitude, VA_timeError, VA_useAmplitude;
// and define VA_TIME_PRECISION, VA_AMPLITUDE_BLEND, VA_MIN_SPEED_PERCENT,
// VA_MAX_SPEED_PERCENT, VA_MIN_AMPLITUDE, VA_MAX_AMPLITUDE, VA_MIN_FRAMES,
// and VA_MAX_FRAMES.  VA_useAmplitude is set by each generated Start<Action>.
//
// Limits: sourceFrameDelta is defensively capped at 120.  With the documented
// BAR bound MAX_SPEED <= 1310000 COB units, precision 1000, speed percentages
// 25..150, amplitude 50..125, all intermediates remain signed 32-bit values.
// Calls are synchronous: invoke VA_NextKeyframe immediately before the commands
// for an interval, divide their speeds by VA_frames, then sleep VA_sleepTime.

#define VA_SAFE_SOURCE_FRAMES 120

VA_Reset()
{
	VA_timeError = 0;
	VA_frames = VA_MIN_FRAMES;
	VA_sleepTime = (33 * VA_frames) - 1;
	VA_amplitude = 100;
}

VA_NextKeyframe(sourceFrameDelta)
{
	var currentSpeed, maximumSpeed, minimumSpeed, maximumAllowedSpeed;
	var speedPercent, ratioScaled, desiredScaledFrames;

	maximumSpeed = get MAX_SPEED;
	if (maximumSpeed < 1) maximumSpeed = 1;

	// These products are safe within the documented MAX_SPEED bound.  Clamp the
	// sampled speed before forming the fixed-point ratio or speed percentage.
	minimumSpeed = (maximumSpeed * VA_MIN_SPEED_PERCENT) / 100;
	maximumAllowedSpeed = (maximumSpeed * VA_MAX_SPEED_PERCENT) / 100;
	if (minimumSpeed < 1) minimumSpeed = 1;
	currentSpeed = get CURRENT_SPEED;
	if (currentSpeed < minimumSpeed) currentSpeed = minimumSpeed;
	if (currentSpeed > maximumAllowedSpeed) currentSpeed = maximumAllowedSpeed;

	// Quotient/remainder forms avoid multiplying unrestricted COB speed values.
	speedPercent = ((currentSpeed / maximumSpeed) * 100)
		+ (((currentSpeed % maximumSpeed) * 100) / maximumSpeed);
	if (VA_useAmplitude) {
		VA_amplitude = 100 + (((speedPercent - 100) * VA_AMPLITUDE_BLEND) / 100);
		if (VA_amplitude < VA_MIN_AMPLITUDE) VA_amplitude = VA_MIN_AMPLITUDE;
		if (VA_amplitude > VA_MAX_AMPLITUDE) VA_amplitude = VA_MAX_AMPLITUDE;
	} else {
		VA_amplitude = 100;
	}

	ratioScaled = ((maximumSpeed / currentSpeed) * VA_TIME_PRECISION)
		+ (((maximumSpeed % currentSpeed) * VA_TIME_PRECISION) / currentSpeed);
	if (sourceFrameDelta < 1) sourceFrameDelta = 1;
	if (sourceFrameDelta > VA_SAFE_SOURCE_FRAMES) sourceFrameDelta = VA_SAFE_SOURCE_FRAMES;
	desiredScaledFrames = (((sourceFrameDelta * VA_amplitude) * ratioScaled) / 100);

	VA_timeError = VA_timeError + desiredScaledFrames;
	VA_frames = VA_timeError / VA_TIME_PRECISION;
	VA_timeError = VA_timeError % VA_TIME_PRECISION;
	if (VA_frames < VA_MIN_FRAMES) {
		VA_frames = VA_MIN_FRAMES;
		VA_timeError = 0;
	}
	if (VA_frames > VA_MAX_FRAMES) {
		VA_frames = VA_MAX_FRAMES;
		VA_timeError = 0;
	}
	VA_sleepTime = (33 * VA_frames) - 1;
}

#endif
