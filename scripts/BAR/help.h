/* help.h -- Standard help scripts to display a unit in the help window */

Help()
{
	#ifdef HELP_VEHICLE

		spin body around y-axis speed <45>;

		#ifdef HELP_Y_MOVEMENT

			move body to y-axis HELP_Y_MOVEMENT	now;

		#endif

	#endif
	#ifdef HELP_BUILDING

		#ifdef HELP_Y_MOVEMENT

			move base to y-axis HELP_Y_MOVEMENT	now;

		#else

			move base to y-axis [-25] now;

		#endif

	#endif

	#ifdef HELP_CUSTOM

		HELP_CUSTOM

	#endif
}


HelpScale( scale )
{
	#ifdef HELP_SCALE

		scale = HELP_SCALE;

	#else

		scale = 1;

	#endif
}
