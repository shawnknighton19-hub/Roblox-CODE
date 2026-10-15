-- INSTRUCTIONS FOR ANIMATIONS --After placing everything in the correct locations (for example, copy everything 
--inside the ReplicatedStorage folder and paste it directly into your game's ReplicatedStorage), 
	--open the dummy located in the Anims > R6 folder.

	--Import the animations from the dummy and replace the animation IDs where needed.

	--The reason animations were not working before was
    --because the Animate script was originally reading the IDs from the Animation objects, 
	--not from the code. A lot of people changed the animation IDs inside the script 
	--and wondered why nothing changed, because the script was still using the IDs stored inside the Animation objects.
	--However, I updated the Animate script for you beginners. 
	--The script now reads the animation IDs directly from the code, 
	--so you only need to change the IDs inside the Animate script code.

		--For movement animations, update the IDs inside:

		--Animate script
		--Fall System script
		--Crouching script

		--Disclaimer: The Crouching script still uses Animation objects to load animations,
		--so make sure you update the animation IDs inside the Animation objects used by the crouching system.

		--Make sure all IDs match the animations you imported from the dummy so everything works correctly.