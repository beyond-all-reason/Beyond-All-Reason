// Author Beherith mysterme@gmail.com. License: GNU GPL v2.

// This is header is for an uninterruptible open-close animation
// Where you want the animation to complete fully before reversing
// It will always end up in the wantOpen state eventually
// False/0 means closed, True/1 means Open
// Usage:
// 1. include this header
// 2. Define the Open() and Close() functions in your script
// 3. When you want the unit to open, like in Activate, always start-script Open();
//		- dont use call-script, as that could block for too long
// 4. This scrips assumes the unit is in a default closed position. 
// 	- Try to use wait-for-turns instead of sleeps in your animation
// 5. If you want to be default open, then do OCA_intransition_wantOpen = 1; in Create()
// 	- Or just call it in create via start-script OpenCloseAnim(1);
// 6. You can check if the unit is open or closed via IsOpen and IsClosed booleans
// 	- both of these are FALSE while the unit is in transition


static-var OCA_intransition_wantOpen;
//2 bits
// 0 0 not in transition and is closed
// 0 1 not in transition and opened
// 1 0 in transition to closed
// 1 1 in transition to open

#define IsOpen   (OCA_intransition_wantOpen == 0x01)
#define IsClosed (OCA_intransition_wantOpen == 0x00)
#define IsInTransition (OCA_intransition_wantOpen >= 2)

OpenCloseAnim(wantOpen)
{
	// If we are already transitioning, then just store what we want to be in the end
	if( OCA_intransition_wantOpen >=2)
	{
		OCA_intransition_wantOpen = wantOpen | 0x02;
		return (0);
	}

	// Store the wantOpen target
	var currentlyOpen;
	currentlyOpen = OCA_intransition_wantOpen & 0x01;
	OCA_intransition_wantOpen = wantOpen | 0x02;

	while((OCA_intransition_wantOpen & 0x01) != currentlyOpen)
	{
		//Do not allow this to be interrupted, ever?
		set-signal-mask 0;
		if( OCA_intransition_wantOpen & 0x01)
		{
			call-script Open();
			currentlyOpen = 1;
		}
		else
		{
			call-script Close();
			currentlyOpen = 0;
		}
	}
	OCA_intransition_wantOpen = currentlyOpen;
}
