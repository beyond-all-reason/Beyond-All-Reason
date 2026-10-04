// This function is for managing complete back and forth transitions, especially 
// for units that have complex open-close animations.
// This ensures that any open/close anim executes fully, and then finally ends up in the wanted status

// Ensure that this function isnt terminated by signals
// Might make sense to set-signal-mask 0 it

// When using this function, you should have an Open and Close function defined.



Static-var TT_intransition_wanted;
//2 bits
// 0 0 not in transition and is closed
// 0 1 not in transition and opened
// 1 0 in transition to closed
// 1 1 in transition to open
TransitionTo(wanted)
{
    // If we are already transitioning, then just store what we want to be in the end
    if( TT_intransition_wanted >=2)
    {
   	 TT_intransition_wanted = wanted | 0x02;
   	 return (0);
    }

    // Store the wanted target
    var current;
    current = TT_intransition_wanted & 0x01;
    TT_intransition_wanted = wanted | 0x02;

    while((TT_intransition_wanted & 0x01) != current)
    {
   	 if( TT_intransition_wanted & 0x01)
   	 {
   		 call-script Open();
            current = 1;
   	 }
   	 else
   	 {
   		 call-script Close();
            current = 0;
   	 }
    }
    TT_intransition = current;
}
