# MWSE-QuickLoot
QuickLoot
by mort
Version 1.7

Adds a Fallout 4-style loot menu to Morrowind. Requires MWSE-lua.
Mod of the Month January 2019

1.7 update:
-Press "loot all" on an empty npc or creature to dispose of their corpse
-Fixed empty window showing up on some plant containers

1.6 update:
-fixed spacebar resetting index (thanks Unappendixed)

1.5 update:
-fixed crash on specific trapped containers
-fixed not being able to type your alternate loot key in the console because it would autoclose the menu

1.4 update:
-Added an option to use spacebar to take items, and (default) z to open the regular container menu
-Arrow keys can now be used to scroll through items

1.3 update:
-full graphic herbalism lua support
-fixes dead actor tooltips
-adds support for a "quick enable/disable" key in case you can't decide whether you want to be quickly looting or not

1.2 update:
-Allows looting from dead npcs / creatures
-Added interop which allows external mwse-lua mods to disable the quickloot menu

1.1 update:
-Fixed bloat issue where containers viewed but not looted acted as though they were altered.
-Now hides container tooltips by default (configurable)
-Change hotkeys in game
-Container name and lock status now in quickloot box
-Fixed bug where the menu would still be visible if targetting item on container

About:
This adds a Quick Loot menu to Morrowind. Use the scroll wheel to navigate up and down, Z takes the highlighted item, X takes all.

There is a fairly robust Mod Configuration Menu included. 
In that you have the option to:
-Reposition the window
-Hide plant containers
-Hide trapped containers
-Show trapped containers. (If you take an item while its trapped it will trigger the trap)
-Change the number of default items displayed
-Display messageboxes on loot
-Show loot from containers with scripted OnActivate (if you don't know what this means leave it off.)

The keys are rebindable if you edit the config (in-game menu option coming soon)

Requirements:
-MGEXE
-MWSE-lua beta branch (available here: https://nullcascade.com/mwse/mwse-dev.zip )
-OpenMW is not supported and cannot be supported probably ever, sorry.

Installation:
-Drag and drop data files folder, merge if asked.
-If you want to change the default loot keys from Z and X, load the game first, 
then navigate to: data files\mwse\config\quick loot.json and open in a text editor. Change the config keys to what you wish.

Uninstallation:
-Remove or rename the main.lua file. There is also a mod configuration option to disable the mod as well.

Coming Soon:
-Key rebinding with mouse support

Special Thanks:
Nullcascade - MWSE-lua for which none of this would be possible, and for some fantastic code contributions
Sveng - contributed code and many fixes, inspired the quickdisable key
PeteTheGoat - Extensive testing and all around big supporter also a good guy
Hrnchamd - MWSE-lua work, MGEXE, MCP, all of that great stuff
The Morrowind Modding Community Discord for all of its support
