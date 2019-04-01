# MWSE-QuickLoot
QuickLoot
by mort
Version 1.2

Adds a Fallout 4-style to Morrowind. Requires MWSE-lua.

1.2 update:
-allows looting from dead npcs / creatures
-added interop which allows external mwse-lua mods to disable the quickloot menu

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
PeteTheGoat - Extensive testing and all around big supporter also a good guy
Hrnchamd - MWSE-lua work, MGEXE, MCP, all of that great stuff
The Morrowind Modding Community Discord for all of its support
