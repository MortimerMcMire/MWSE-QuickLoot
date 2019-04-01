--[[
	Mod Initialization: Morrowind Quick Loot
	Author: mort, NullCascade

	This file enables Fallout 4-style quick looting, the default key is Z, default take all is X.
]] --

local interop = require("QuickLoot.interop")

-- Ensure that the player has the necessary MWSE version.
if (mwse.buildDate == nil or mwse.buildDate < 20190207) then
	mwse.log("[QuickLoot] Build date of %s does not meet minimum build date of 2019-02-07.", mwse.buildDate)
	event.register(
		"initialized",
		function()
			tes3.messageBox("Morrowind Quick Loot requires a newer version of MWSE. Please run MWSE-Update.exe.")
		end
	)
	return
end

-- The default configuration values.
local defaultConfig = {
	modDisabled = false,
	hideTrapped = true,
	hideLocked = false,
	hideTooltip = true,
	showScripted = false,
	showMessageBox = false,
	showPlants = true,
	maxItemDisplaySize = 10,
	menuX = 6,
	menuY = 4,
	takeKey = "z",
	takeAllKey = "x"
}

-- Load our config file, and fill in default values for missing elements.
local config = mwse.loadConfig("Quick Loot")
if (config == nil) then
	config = defaultConfig
else
	for k, v in pairs(defaultConfig) do
		if (config[k] == nil) then
			config[k] = v
		end
	end
end

-- State for the currently targetted reference and item.
local currentTarget = nil
local currentIndex = nil

-- Keep track of the current inventory size.
local currentInventorySize = nil

-- Keep easy access to the menu.
local quickLootGUI = nil

-- Toggle if you're waiting for a key rebind
local rebindTake = false
local rebindTakeAll = false

-- Keep track of all the GUI IDs we care about.
local GUIID_MenuContents = nil
local GUIID_QuickLoot_ContentBlock = nil
local GUIID_QuickLoot_DotBlock = nil
local GUIID_QuickLoot_NameLabel = nil
local GUIID_QuickLoot_DenyLabel = nil
local GUIID_QuickLoot_ContentBlock_ItemIcon = nil
local GUIID_QuickLoot_ContentBlock_ItemLabel = nil
local GUIID_QuickLoot_Menu = nil
local GUIID_ModConfig_Menu = nil
local GUIID_ModConfig_TakeKey = nil
local GUIID_ModConfig_TakeAllKey = nil

-- Changes the selection to a new index. Enforces bounds to [1, currentInventorySize].
local function setSelectionIndex(index)
	if (index == currentIndex or index < 1 or index > currentInventorySize) then
		return
	end

	local contentBlock = quickLootGUI:findChild(GUIID_QuickLoot_ContentBlock)
	local dotBlock = quickLootGUI:findChild(GUIID_QuickLoot_DotBlock)
	local children = contentBlock.children
	
	--fixes inventory display on menu open/close
	local container = currentTarget.object
	currentInventorySize = #container.inventory
	
	local range = config.maxItemDisplaySize
	local firstIndex = math.clamp(index - range, 0, index)
	local lastIndex = math.clamp(index + range, index, currentInventorySize)
	
	for i, block in pairs(children) do
		if (i == index) then
			-- If this is the new index, set it to the active color.
			local label = block:findChild(GUIID_QuickLoot_ContentBlock_ItemLabel)
			label.color = tes3ui.getPalette("active_color")
		elseif (i == currentIndex) then
			-- If this is the old index, change the color back to normal.
			local label = block:findChild(GUIID_QuickLoot_ContentBlock_ItemLabel)
			label.color = tes3ui.getPalette("normal_color")
		end
		
		--show or hide items
		--tes3.messageBox("%d %d", firstIndex, lastIndex)
		if ( i < firstIndex or i > (lastIndex)) then
			block.visible = false
		else
			block.visible = true
		end
	end

	if ( lastIndex < currentInventorySize ) then
		local label = contentBlock:createLabel({text = "..."})
		label.absolutePosAlignX = 0.5
	end
	
	if ( firstIndex > 1 ) then
		dotBlock.visible = true
	else
		dotBlock.visible = false
	end

	currentIndex = index

	contentBlock:updateLayout()
end

local function canLootObject()
	if (currentTarget == nil) then
		return false
	end

	-- Check for locked/trapped state. If it is either, hide the contents.
	local lockNode = currentTarget.lockNode
	if (lockNode) then
		-- If the container is locked, display lock level.
		if (lockNode.locked) then
			return false, "Lock Level: " .. lockNode.level
		end
		
		if ( config.hideLocked == true ) then
			quickLootGUI.visible = false
		end

		-- If it's trapped, show that.
		if (lockNode.trap ~= nil and config.hideTrapped == true) then
			return false, tes3.findGMST(tes3.gmst.sTrapped).value
		end
	end

	-- If the chest has an onActivate, don't allow the player to peek inside because it might break the scripts.
	if (currentTarget:testActionFlag(1) == false and config.showScripted == false) then
		return false, "You can't see inside this container."
	end

	-- Tell if the container is empty.
	local container = currentTarget.object
	currentInventorySize = #container.inventory
	if (currentInventorySize == 0) then
		return false, "Empty"

	end
	return true
end

-- Refresh the GUI with the currently available items.
local function refreshItemsList()
	-- Kill all our children.
	local contentBlock = quickLootGUI:findChild(GUIID_QuickLoot_ContentBlock)
	contentBlock:destroyChildren()
	
	local nameLabel = quickLootGUI:findChild(GUIID_QuickLoot_NameLabel)
	nameLabel.text = currentTarget.object.name

	local denyLabel = quickLootGUI:findChild(GUIID_QuickLoot_DenyLabel)

	-- Check to see if we can loot the inventory.
	local canLoot, cantLootReason = canLootObject()
	if (not canLoot) then
		denyLabel.visible = true
		denyLabel.text = cantLootReason
		--contentBlock:createLabel({text = cantLootReason})
		quickLootGUI:updateLayout()
		return
	else
		denyLabel.visible = false
	end
	
	quickLootGUI.visible = true

	-- Clone the object if necessary.
	currentTarget:clone()
	
	-- Start going over the items in the object's inventory and making elements for them.
	currentIndex = nil
	local container = currentTarget.object
	
	--backup print for loaded inventories
	if (#container.inventory == 0) then
		contentBlock:createLabel({text = "Empty"})
		quickLootGUI:updateLayout()
		return
	end
	
	--hide plant containers if the config says to
	if config.showPlants == false then
		if (container.organic == true) then
			quickLootGUI.visible = false
		end
	end

	for _, stack in pairs(container.inventory) do
		--
		
		local item = stack.object
			
		-- Our container block for this item.
		local block = contentBlock:createBlock({})
		block.flowDirection = "left_to_right"
		block.autoWidth = true
		block.autoHeight = true
		block.paddingAllSides = 3

		-- Store the item/count on the block for later logic.
		block:setPropertyObject("QuickLoot:Item", item)
		block:setPropertyInt("QuickLoot:Count", math.abs(stack.count))
		block:setPropertyInt("QuickLoot:Value", item.value)
		

		-- Item icon.
		local icon = block:createImage({id = GUIID_QuickLoot_ContentBlock_ItemIcon, path = "icons\\" .. item.icon})
		icon.borderRight = 5

		-- Label text
		local labelText = item.name
		if (math.abs(stack.count) > 1) then
			labelText = labelText .. " (" .. math.abs(stack.count) .. ")"
		end
		
		local label = block:createLabel({id = GUIID_QuickLoot_ContentBlock_ItemLabel, text = labelText})
		label.absolutePosAlignY = 0.5
	
	end

	setSelectionIndex(1)
	
	quickLootGUI:updateLayout()
end

-- Creates the GUI and populates it.
local function createQuickLootGUI()

	if (tes3ui.findMenu(GUIID_QuickLoot_Menu)) then
		refreshItemsList()
		return
	end

	--
	quickLootGUI = tes3ui.createMenu({id = GUIID_QuickLoot_Menu, fixedFrame = true})
	quickLootGUI.absolutePosAlignX = 0.1 * config.menuX
	quickLootGUI.absolutePosAlignY = 0.1 * config.menuY
	
	--
	
	local nameBlock = quickLootGUI:createBlock({})
	nameBlock.autoHeight = true
	nameBlock.autoWidth = true
	nameBlock.paddingAllSides = 1
	nameBlock.childAlignX = 0.5
	local nameLabel = nameBlock:createLabel({id = GUIID_QuickLoot_NameLabel, text = nil})
	nameLabel.color = tes3ui.getPalette("header_color")
	nameBlock:updateLayout()
    nameBlock.widthProportional = 1.0
	quickLootGUI.minWidth = nameLabel.width
	
	local denyBlock = quickLootGUI:createBlock({})
	denyBlock.autoHeight = true
	denyBlock.autoWidth = true
	denyBlock.paddingAllSides = 1
	denyBlock.childAlignX = 0.5
	denyBlock:createLabel({id = GUIID_QuickLoot_DenyLabel, text = nil})
	denyBlock:updateLayout()
	denyBlock.widthProportional = 1.0
	
	local dotBlock = quickLootGUI:createBlock({id = GUIID_QuickLoot_DotBlock})
	dotBlock.flowDirection = "top_to_bottom"
	dotBlock.widthProportional = 1.0
	dotBlock.autoHeight = true
	dotBlock.paddingAllSides = 3
	local dotLabel = dotBlock:createLabel({text = "..."})
	dotLabel.absolutePosAlignX = 0.5
	dotBlock.visible = false

	--
	local contentBlock = quickLootGUI:createBlock({id = GUIID_QuickLoot_ContentBlock})
	contentBlock.flowDirection = "top_to_bottom"
	contentBlock.autoHeight = true
	contentBlock.autoWidth = true

	-- This is needed or things get weird.
	quickLootGUI:updateLayout()

	refreshItemsList()
end

-- Clears the current menu.
local function clearQuickLootMenu(destroyMenu)
	if (destroyMenu == nil) then
		destroyMenu = true
	end

	-- Clear the current target.
	currentTarget = nil
	currentInventorySize = nil

	if (destroyMenu and quickLootGUI) then
		quickLootGUI:destroy()
		quickLootGUI = nil
	end
end

-- Called when the player looks at a new object that would show a tooltip, or transfers off of such an object.
local function onActivationTargetChanged(e)
	-- Bail if we don't have a target or the mod is disabled.
	if config.modDisabled == true then
		return
	end
	
	local contentsMenu = tes3ui.findMenu(GUIID_MenuContents)
	
	-- Declone the inventory if they aren't opening the inventory
	if ( currentTarget ~= nil and contentsMenu == nil ) then
		currentTarget.object:onInventoryClose(currentTarget)
	end
	
	local newTarget = e.current

	local targetNil = (newTarget == nil)
	clearQuickLootMenu(targetNil)
	if (targetNil) then
		return
	end

	-- We only care about containers (or npcs or creatures)
	if (newTarget.object.objectType ~= tes3.objectType.container) then
		if (newTarget.object.objectType ~= tes3.objectType.npc) then
			if (newTarget.object.objectType ~= tes3.objectType.creature) then
				clearQuickLootMenu(true)
				return
			end
		end
	end
	
	-- Don't loot alive actors
	if (newTarget.mobile ~= nil) then
		if (newTarget.mobile.health.current ~= nil) then
			if (newTarget.mobile.health.current > 0) then
				clearQuickLootMenu(true)
				return
			end
		end
	end
	
	--Don't activate quickloot if told otherwise
	if interop.skipNextTarget == true then
		clearQuickLootMenu(true)
		interop.skipNextTarget = false
		return
	end
	
	
	-- Don't loot containers if your hands are disabled
	if (tes3.mobilePlayer.attackDisabled) then
		return
	end
	
	currentTarget = newTarget
	createQuickLootGUI(newTarget)
end

-- Called when the mouse wheel scroll is used. Changes the selection.
local function onMouseWheelChanged(e)
	if (currentTarget) then
		if (e.delta < 0) then
			setSelectionIndex(currentIndex + 1)
		else
			setSelectionIndex(currentIndex - 1)
		end
	end
end

--makes NPCs react to quicklooting
local function crimeCheck(itemValue)
	local owner = tes3.getOwner(currentTarget)
	
	if (owner) then
		if owner.playerJoined then
			if currentTarget.attachments["variables"].requirement <= owner.playerRank then
				return
			end
		end
		tes3.triggerCrime({
			type = 5,
			victim = owner,
			value = itemValue
		})
	end
end

--triggers traps if you try quicklooting a trapped container
local function triggerTrap()
	local playerRef = tes3.getPlayerRef()
	if currentTarget.lockNode ~= nil then
		if currentTarget.lockNode.trap ~= nil then
			playerRef:activate(currentTarget)
			return
		end
	end
end

-- Takes all of the currently selected item.
local function takeItem(e)
	
	if ( e.keyCode ~= tes3.scanCode[config.takeKey] ) then
		return
	end
	
	if (not canLootObject()) then
		return
	end
	
	if config.modDisabled == true then
		return
	end
	
	if currentTarget == nil then
		return
	end
	
	triggerTrap()
	
	local crimeValue = 0
	local block = quickLootGUI:findChild(GUIID_QuickLoot_ContentBlock).children[currentIndex]
	
	crimeValue = crimeValue + (block:getPropertyInt("QuickLoot:Value") * block:getPropertyInt("QuickLoot:Count"))
	tes3.transferItem({
		from = currentTarget,
		to = tes3.player,
		item = block:getPropertyObject("QuickLoot:Item"),
		count = block:getPropertyInt("QuickLoot:Count"),
	})
	
	crimeCheck(crimeValue)
	
	if config.showMessageBox == true then
		tes3.messageBox({ message = "Looted " .. block:getPropertyInt("QuickLoot:Count") .. " "
		.. block:getPropertyObject("QuickLoot:Item").name })
	end

	local preservedIndex = currentIndex
	refreshItemsList()
	setSelectionIndex(math.clamp(preservedIndex, 1, currentInventorySize))
end

-- Takes all items from the current target.
local function takeAllItems(e)

	if ( e.keyCode ~= tes3.scanCode[config.takeAllKey] ) then
		return
	end
	
	if (not canLootObject()) then
		return
	end
	
	if config.modDisabled == true then
		return
	end
	
	if currentTarget == nil then
		return
	end
	
	triggerTrap()
	
	local inventory = currentTarget.object.inventory
	local crimeValue = 0
	
	tes3.playItemPickupSound({ item = inventory.iterator.head.nodeData.object.id, pickup = true })
	
	while (#inventory > 0) do
		local firstStack = inventory.iterator.head.nodeData
		crimeValue = crimeValue + (firstStack.object.value * firstStack.count)
		tes3.transferItem({
			from = currentTarget,
			to = tes3.player,
			item = firstStack.object,
			playSound = false,
			count = math.abs(firstStack.count),
			updateGUI = false,
		})
	end
	
	crimeCheck(crimeValue)
	
	if config.showMessageBox == true then
		tes3.messageBox({ message = "Looted all items." })
	end
	tes3ui.forcePlayerInventoryUpdate()

	refreshItemsList()
end

local function onUIObjectTooltip(e)
	if config.modDisabled == true then
		--ensure your tooltips are back in place
		e.tooltip.absolutePosAlignX = nil
		e.tooltip.absolutePosAlignY = nil
		return
	end
	
	if (e.object.objectType ~= tes3.objectType.container) then
		e.tooltip.absolutePosAlignX = nil
		e.tooltip.absolutePosAlignY = nil
	else
		if (config.hideTooltip == true) then
		--send the tooltip into the stratosphere
			e.tooltip.absolutePosAlignX = 4
			e.tooltip.absolutePosAlignY = 4
		end
	end
end

local function rebindKey(e)
	if ( rebindTake == true ) then
		local keyName = table.find(tes3.scanCode,e.keyCode)
		config.takeKey = keyName
		rebindTake = false
		local modMenu = tes3ui.findMenu(GUIID_ModConfig_Menu)
		local button = modMenu:findChild(GUIID_ModConfig_TakeKey)
		button.text = config.takeKey
	elseif ( rebindTakeAll == true ) then
		local keyName = table.find(tes3.scanCode,e.keyCode)
		config.takeAllKey = keyName
		rebindTakeAll = false
		local modMenu = tes3ui.findMenu(GUIID_ModConfig_Menu)
		local button = modMenu:findChild(GUIID_ModConfig_TakeAllKey)
		button.text = config.takeAllKey
	end
end

local function onInitialized()
	-- Make sure that we have valid keys.
	local lootKey = tes3.scanCode[config.takeKey]
	local lootAllKey = tes3.scanCode[config.takeAllKey]
	if (lootKey == nil and lootAllKey == nil) then
		mwse.log("[Morrowind Quick Loot] Invalid configuration. Invalid")
		return
	end

	-- Register necessary GUI element IDs.
	GUIID_MenuContents = tes3ui.registerID("MenuContents")
	GUIID_QuickLoot_ContentBlock = tes3ui.registerID("QuickLoot:ContentBlock")
	GUIID_QuickLoot_DotBlock = tes3ui.registerID("QuickLoot:DotBlock")
	GUIID_QuickLoot_NameLabel = tes3ui.registerID("QuickLoot:NameLabel")
	GUIID_QuickLoot_DenyLabel = tes3ui.registerID(("QuickLoot:DenyLabel"))
	GUIID_QuickLoot_ContentBlock_ItemIcon = tes3ui.registerID("QuickLoot:ContentBlock:ItemIcon")
	GUIID_QuickLoot_ContentBlock_ItemLabel = tes3ui.registerID("QuickLoot:ContentBlock:ItemLabel")
	GUIID_QuickLoot_Menu = tes3ui.registerID("QuickLoot:Menu")
	GUIID_ModConfig_Menu = tes3ui.registerID("MWSE:ModConfigMenu")
	GUIID_ModConfig_TakeKey = tes3ui.registerID("MWSE:ModConfigMenu:mainBlock:hBlockTakeItemKey:buttonTakeItemKey")
	GUIID_ModConfig_TakeAllKey = tes3ui.registerID("MWSE:ModConfigMenu:mainBlock:hBlockTakeAllItemsKey:buttonTakeAllItemsKey")

	-- Register the necessary events to get going.
	event.register("activationTargetChanged", onActivationTargetChanged)
	event.register("uiObjectTooltip", onUIObjectTooltip)
	event.register("keyDown", takeAllItems)
	event.register("keyDown", takeItem)
	event.register("keyDown", rebindKey)
	event.register("mouseWheel", onMouseWheelChanged)
	event.register("menuEnter", clearQuickLootMenu)
	
	mwse.log("[Morrowind Quick Loot] Initialized. Loot Key: %s; Loot All Key: %s", config.takeKey, config.takeAllKey)
end
event.register("initialized", onInitialized)



---
--- Mod Config
---
local modConfig = {}

local function toggleMessageBox(e)
	config.showMessageBox = not config.showMessageBox
	local button = e.source
	button.text = config.showMessageBox and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function toggleHideTrapped(e)
	config.hideTrapped = not config.hideTrapped
	local button = e.source
	button.text = config.hideTrapped and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function toggleShowPlants(e)
	config.showPlants = not config.showPlants
	local button = e.source
	button.text = config.showPlants and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function toggleScriptedContainers(e)
	config.showScripted = not config.showScripted
	local button = e.source
	button.text = config.showScripted and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function toggleConfirmLock(e)
	config.hideLocked = not config.hideLocked
	local button = e.source
	button.text = config.hideLocked and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function toggleHideTooltip(e)
	config.hideTooltip = not config.hideTooltip
	local button = e.source
	button.text = config.hideTooltip and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value
end

local function rebindTakeKey(e)
	rebindTake = true
	local button = e.source
	button.text = "Press any key"
end

local function rebindTakeAllKey(e)
	rebindTakeAll = true
	local button = e.source
	button.text = "Press any key"
end


function modConfig.onCreate(container)
	local mainBlock = container:createThinBorder({})
	mainBlock.flowDirection = "top_to_bottom"
	mainBlock.layoutWidthFraction = 1.0
	mainBlock.layoutHeightFraction = 1.0
	mainBlock.paddingAllSides = 6
	
	do
		local hBlockMessageBox = mainBlock:createBlock({})
		hBlockMessageBox.flowDirection = "left_to_right"
		hBlockMessageBox.layoutWidthFraction = 1.0
		hBlockMessageBox.autoHeight = true
	
		local labelMessageBox = hBlockMessageBox:createLabel({ text = "Display messagebox on loot?" })
		labelMessageBox.layoutOriginFractionX = 0.0

		local buttonMessageBox = hBlockMessageBox:createButton({ text = (config.showMessageBox and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonMessageBox.layoutOriginFractionX = 1.0
		buttonMessageBox.paddingTop = 3
		buttonMessageBox:register("mouseClick", toggleMessageBox)
	end
	do
		local hBlockTrapped = mainBlock:createBlock({})
		hBlockTrapped.flowDirection = "left_to_right"
		hBlockTrapped.layoutWidthFraction = 1.0
		hBlockTrapped.autoHeight = true
	
		local labelTrapped = hBlockTrapped:createLabel({ text = "Hide trapped containers items? (False will show you the items but trigger the trap if you attempt to take one) " })
		labelTrapped.layoutOriginFractionX = 0.0

		local buttonTrapped = hBlockTrapped:createButton({ text = (config.hideTrapped and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonTrapped.layoutOriginFractionX = 1.0
		buttonTrapped.paddingTop = 3
		buttonTrapped:register("mouseClick", toggleHideTrapped)
	end
	do
		local hBlockLocked = mainBlock:createBlock({})
		hBlockLocked.flowDirection = "left_to_right"
		hBlockLocked.layoutWidthFraction = 1.0
		hBlockLocked.autoHeight = true
	
		local labelLocked = hBlockLocked:createLabel({ text = "Hide lock status? (False will display Locked when chests are locked and nothing when set to true) " })
		labelLocked.layoutOriginFractionX = 0.0

		local buttonLocked = hBlockLocked:createButton({ text = (config.hideLocked and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonLocked.layoutOriginFractionX = 1.0
		buttonLocked.paddingTop = 3
		buttonLocked:register("mouseClick", toggleConfirmLock)
	end
	do
		local hBlockPlant = mainBlock:createBlock({})
		hBlockPlant.flowDirection = "left_to_right"
		hBlockPlant.layoutWidthFraction = 1.0
		hBlockPlant.autoHeight = true
	
		local labelPlant = hBlockPlant:createLabel({ text = "Show quickloot menu on plant / organic containers? " })
		labelPlant.layoutOriginFractionX = 0.0

		local buttonPlant = hBlockPlant:createButton({ text = (config.showPlants and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonPlant.layoutOriginFractionX = 1.0
		buttonPlant.paddingTop = 3
		buttonPlant:register("mouseClick", toggleShowPlants)
	end
	do
		local hBlockOnActivate = mainBlock:createBlock({})
		hBlockOnActivate.flowDirection = "left_to_right"
		hBlockOnActivate.layoutWidthFraction = 1.0
		hBlockOnActivate.autoHeight = true
	
		local labelOnActivate = hBlockOnActivate:createLabel({ text = "Show containers with scripted onActivate? (Can break some container scripts) " })
		labelOnActivate.layoutOriginFractionX = 0.0

		local buttonOnActivate = hBlockOnActivate:createButton({ text = (config.showScripted and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonOnActivate.layoutOriginFractionX = 1.0
		buttonOnActivate.paddingTop = 3
		buttonOnActivate:register("mouseClick", toggleScriptedContainers)
	end
	do
		local hBlockTooltip = mainBlock:createBlock({})
		hBlockTooltip.flowDirection = "left_to_right"
		hBlockTooltip.layoutWidthFraction = 1.0
		hBlockTooltip.autoHeight = true
	
		local labelTooltip = hBlockTooltip:createLabel({ text = "Hide container tooltips " })
		labelTooltip.layoutOriginFractionX = 0.0

		local buttonTooltip = hBlockTooltip:createButton({ text = (config.hideTooltip and tes3.findGMST(tes3.gmst.sYes).value or tes3.findGMST(tes3.gmst.sNo).value) })
		buttonTooltip.layoutOriginFractionX = 1.0
		buttonTooltip.paddingTop = 3
		buttonTooltip:register("mouseClick", toggleHideTooltip)
	end
	do
		local hBlockTakeItemKey = mainBlock:createBlock({})
		hBlockTakeItemKey.flowDirection = "left_to_right"
		hBlockTakeItemKey.layoutWidthFraction = 1.0
		hBlockTakeItemKey.autoHeight = true
	
		local labelTakeItemKey = hBlockTakeItemKey:createLabel({ text = "Current Take Single Item Key: " })
		labelTakeItemKey.layoutOriginFractionX = 0.0

		local buttonTakeItemKey = hBlockTakeItemKey:createButton({ id = GUIID_ModConfig_TakeKey, text = config.takeKey })
		buttonTakeItemKey.layoutOriginFractionX = 1.0
		buttonTakeItemKey.paddingTop = 3
		buttonTakeItemKey:register("mouseClick", rebindTakeKey)
	end
	do
		local hBlockTakeAllItemsKey = mainBlock:createBlock({})
		hBlockTakeAllItemsKey.flowDirection = "left_to_right"
		hBlockTakeAllItemsKey.layoutWidthFraction = 1.0
		hBlockTakeAllItemsKey.autoHeight = true
	
		local labelTakeAllItemsKey = hBlockTakeAllItemsKey:createLabel({ text = "Current Take All Items Key: " })
		labelTakeAllItemsKey.layoutOriginFractionX = 0.0

		local buttonTakeAllItemsKey = hBlockTakeAllItemsKey:createButton({ id = GUIID_ModConfig_TakeAllKey, text = config.takeAllKey })
		buttonTakeAllItemsKey.layoutOriginFractionX = 1.0
		buttonTakeAllItemsKey.paddingTop = 3
		buttonTakeAllItemsKey:register("mouseClick", rebindTakeAllKey)
	end
	do
		local hBlockNumberDisplayed = mainBlock:createBlock({})
		hBlockNumberDisplayed.flowDirection = "left_to_right"
		hBlockNumberDisplayed.layoutWidthFraction = 1.0
		hBlockNumberDisplayed.autoHeight = true
	
		local labelNumberDisplayed = hBlockNumberDisplayed:createLabel({ text = "Number of items displayed by default: " .. tostring(config.maxItemDisplaySize+1) })
		labelNumberDisplayed.layoutOriginFractionX = 0.0
		
		local sliderNumberDisplayed = hBlockNumberDisplayed:createSlider({ current = config.maxItemDisplaySize-4, max = 25, min = 4, jump = 2})
		sliderNumberDisplayed.layoutOriginFractionX = 1.0
		sliderNumberDisplayed.width = 300
		sliderNumberDisplayed:register("PartScrollBar_changed", function(e)
			local slider = e.source
			config.maxItemDisplaySize = (slider.widget.current + 4)
			labelNumberDisplayed.text = "Number of items displayed by default: " .. tostring(config.maxItemDisplaySize+1)
			end)
	end
	do
		local hBlockMenuXPos = mainBlock:createBlock({})
		hBlockMenuXPos.flowDirection = "left_to_right"
		hBlockMenuXPos.layoutWidthFraction = 1.0
		hBlockMenuXPos.autoHeight = true
	
		local labelXPosition = hBlockMenuXPos:createLabel({ text = "Menu X position (higher = right): " .. tostring(config.menuX) })
		labelXPosition.layoutOriginFractionX = 0.0
		
		local sliderXPosition = hBlockMenuXPos:createSlider({ current = config.menuX, max = 10, jump = 1 })
		sliderXPosition.layoutOriginFractionX = 1.0
		sliderXPosition.width = 300
		sliderXPosition:register("PartScrollBar_changed", function(e)
			local slider = e.source
			config.menuX = slider.widget.current
			labelXPosition.text = "Menu X position (higher = right): " .. tostring(config.menuX)
			end)
	end
	do
		local hBlockMenuYPos = mainBlock:createBlock({})
		hBlockMenuYPos.flowDirection = "left_to_right"
		hBlockMenuYPos.layoutWidthFraction = 1.0
		hBlockMenuYPos.autoHeight = true
	
		local labelYPosition = hBlockMenuYPos:createLabel({ text = "Menu Y position (higher = down): " .. tostring(config.menuY) })
		labelYPosition.layoutOriginFractionX = 0.0
		
		local sliderYPosition = hBlockMenuYPos:createSlider({ current = config.menuY, max = 10, jump = 1 })
		sliderYPosition.layoutOriginFractionX = 1.0
		sliderYPosition.width = 300
		sliderYPosition:register("PartScrollBar_changed", function(e)
			local slider = e.source
			config.menuY = slider.widget.current
			labelYPosition.text = "Menu Y position (higher = down): " .. tostring(config.menuY)
			end)
	end
	do
		local spacerBlock = mainBlock:createBlock({})
		spacerBlock.layoutWidthFraction = 1.0
		spacerBlock.paddingAllSides = 10
		spacerBlock.layoutHeightFraction = 1.0
		spacerBlock.flowDirection = "top_to_bottom"

		local buttonRestoreDefaults = spacerBlock:createButton({ text = "Restore Defaults" })
		buttonRestoreDefaults.layoutOriginFractionX = 0.2
		buttonRestoreDefaults.layoutOriginFractionY = 0.1
		buttonRestoreDefaults.paddingTop = 3
		buttonRestoreDefaults:register("mouseClick", function()
		
		for k, _ in pairs(defaultConfig) do
			config[k] = defaultConfig[k]
		end
		mainBlock:destroy()
		modConfig.onCreate(container)
		end)
		
		local buttonEnableQuickloot = spacerBlock:createButton()
		if config.modDisabled == true then
			buttonEnableQuickloot.text = "Enable QuickLoot Menu? Current: No"
		else
			buttonEnableQuickloot.text = "Enable QuickLoot Menu? Current: Yes"
		end
		buttonEnableQuickloot.layoutOriginFractionX = 0.7
		buttonEnableQuickloot.layoutOriginFractionY = 0.1
		buttonEnableQuickloot.paddingTop = 3
		buttonEnableQuickloot:register("mouseClick", function()
			if config.modDisabled == true then
				buttonEnableQuickloot.text = "Enable QuickLoot Menu? Current: Yes"
				config.modDisabled = false
			else
				buttonEnableQuickloot.text = "Enable QuickLoot Menu? Current: No"
				config.modDisabled = true
			end
		end)
	end
end

function modConfig.onClose()
	mwse.log("[Morrowind Quick Loot] Saving mod configuration")
	mwse.saveConfig("Quick Loot", config)
end

local function registerModConfig()
    mwse.registerModConfig("Quick Loot", modConfig)
end
event.register("modConfigReady", registerModConfig)