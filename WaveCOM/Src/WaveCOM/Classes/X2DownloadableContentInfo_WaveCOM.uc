//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_WaveCOM.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_WaveCOM extends X2DownloadableContentInfo config(WaveCOM);

var const config float WaveCOMResearchSupplyCostRatio;

static event OnPostTemplatesCreated()
{
	`log("WaveCOM :: Present And Correct");
}


/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{
	local XComMissionLogic_Listener MissionListener;
	MissionListener = XComMissionLogic_Listener(StartState.CreateStateObject(class'XComMissionLogic_Listener'));
	MissionListener.RegisterToListen();
	StartState.AddStateObject(MissionListener);

	`log("XComMissionLogic :: InstallNewCampaign");

	UpdateResearchTemplates();
	UpdateSchematicTemplates();
	MakeAllTechInstant(StartState);
}

static event OnLoadedSavedGame()
{	
	local XComMissionLogic_Listener MissionListener;
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Save Game Mission Logic Loader");
	MissionListener = XComMissionLogic_Listener(NewGameState.CreateStateObject(class'XComMissionLogic_Listener'));
	MissionListener.RegisterToListen();
	NewGameState.AddStateObject(MissionListener);

	UpdateResearchTemplates();
	UpdateSchematicTemplates();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	`log("XComMissionLogic :: OnLoadedSavedGame");
}

static function MakeAllTechInstant(XComGameState StartState)
{
	local XComGameStateHistory History;
	local XComGameState_Tech TechState;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		TechState = XComGameState_Tech(StartState.CreateStateObject(class'XComGameState_Tech', TechState.ObjectID));
		TechState.bForceInstant = true;
		TechState.bSeenInstantPopup = true;
		StartState.AddStateObject(TechState);
	}
}

static function UpdateResearchTemplates ()
{
	local X2StrategyElementTemplateManager Manager;
	local array<X2StrategyElementTemplate> Techs;
	local X2StrategyElementTemplate TechTemplate;
	local X2TechTemplate Tech;
	local int BasePoints;
	local ArtifactCost Resources;

	Manager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Techs = Manager.GetAllTemplatesOfClass(class'X2TechTemplate');
	foreach Techs(TechTemplate)
	{
		Tech = X2TechTemplate(TechTemplate);
		BasePoints = Tech.PointsToComplete;
		Resources.ItemTemplateName = 'Supplies';
		Resources.Quantity = Round(BasePoints * default.WaveCOMResearchSupplyCostRatio);
		Tech.Cost.ResourceCosts.AddItem(Resources);
		Tech.bJumpToLabs = false;
		Tech.PointsToComplete = 0;
		Manager.AddStrategyElementTemplate(Tech, true);
	}
}

static function UpdateSchematicTemplates ()
{
	local X2ItemTemplateManager Manager;
	local array<X2SchematicTemplate> Schematics;
	local X2SchematicTemplate Schematic;

	Manager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	Schematics = Manager.GetAllSchematicTemplates();
	foreach Schematics(Schematic)
	{
		`log("Updating: " @Schematic.DataName);
		Schematic.OnBuiltFn = UpgradeItems;

		Manager.AddItemTemplate(Schematic, true);
	}
}

static function UpgradeItems(XComGameState NewGameState, XComGameState_Item ItemState)
{
	local XComGameStateHistory History;
	local XComGameState_HeadquartersXCom XComHQ;
	local X2ItemTemplateManager ItemTemplateManager;
	local X2ItemTemplate BaseItemTemplate, UpgradeItemTemplate;
	local X2WeaponUpgradeTemplate WeaponUpgradeTemplate;
	local XComGameState_Item InventoryItemState, BaseItemState, UpgradedItemState;
	local array<X2ItemTemplate> CreatedItems, ItemsToUpgrade;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local array<XComGameState_Item> InventoryItems;
	local array<XComGameState_Unit> Soldiers;
	local EInventorySlot InventorySlot;
	local XGItem ItemVisualizer;
	local XComNarrativeMoment EquipNarrativeMoment;
	local XComGameState_Unit HighestRankSoldier;
	local int idx, iSoldier, iItems;
	local name CreatorTemplateName;

	CreatorTemplateName = ItemState.GetMyTemplateName();

	History = `XCOMHISTORY;
	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	foreach NewGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}

	if (XComHQ == none)
	{
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(XComHQ);
	}

	CreatedItems = ItemTemplateManager.GetAllItemsCreatedByTemplate(CreatorTemplateName);

	for (idx = 0; idx < CreatedItems.Length; idx++)
	{
		UpgradeItemTemplate = CreatedItems[idx];

		ItemsToUpgrade.Length = 0; // Reset ItemsToUpgrade for this upgrade item iteration
		GetItemsToUpgrade(UpgradeItemTemplate, ItemsToUpgrade);

		// If the new item is infinite, just add it directly to the inventory
		if (UpgradeItemTemplate.bInfiniteItem)
		{
			// But only add the infinite item if it isn't already in the inventory
			if (!XComHQ.HasItem(UpgradeItemTemplate))
			{
				UpgradedItemState = UpgradeItemTemplate.CreateInstanceFromTemplate(NewGameState);
				NewGameState.AddStateObject(UpgradedItemState);
				XComHQ.AddItemToHQInventory(UpgradedItemState);
			}
		}
		else
		{
			// Otherwise cycle through each of the base item templates
			foreach ItemsToUpgrade(BaseItemTemplate)
			{
				// Check if the base item is in the XComHQ inventory
				BaseItemState = XComHQ.GetItemByName(BaseItemTemplate.DataName);

				// If it is not, we have nothing to replace, so move on
				if (BaseItemState != none)
				{
					// Otherwise match the base items quantity
					UpgradedItemState = UpgradeItemTemplate.CreateInstanceFromTemplate(NewGameState);
					NewGameState.AddStateObject(UpgradedItemState);
					UpgradedItemState.Quantity = BaseItemState.Quantity;

					// Then add the upgrade item and remove all of the base items from the inventory
					XComHQ.PutItemInInventory(NewGameState, UpgradedItemState);
					XComHQ.RemoveItemFromInventory(NewGameState, BaseItemState.GetReference(), BaseItemState.Quantity);
					
					NewGameState.RemoveStateObject(BaseItemState.GetReference().ObjectID);
				}
			}
		}

		// Check the inventory for any unequipped items with weapon upgrades attached, make sure they get updated
		for (iItems = 0; iItems < XComHQ.Inventory.Length; iItems++)
		{
			InventoryItemState = XComGameState_Item(History.GetGameStateForObjectID(XComHQ.Inventory[iItems].ObjectID));
			foreach ItemsToUpgrade(BaseItemTemplate)
			{
				if (InventoryItemState.GetMyTemplateName() == BaseItemTemplate.DataName && InventoryItemState.GetMyWeaponUpgradeTemplates().Length > 0)
				{
					UpgradedItemState = UpgradeItemTemplate.CreateInstanceFromTemplate(NewGameState);
					NewGameState.AddStateObject(UpgradedItemState);
					UpgradedItemState.WeaponAppearance = InventoryItemState.WeaponAppearance;
					UpgradedItemState.Nickname = InventoryItemState.Nickname;

					// Transfer over all weapon upgrades to the new item
					WeaponUpgrades = InventoryItemState.GetMyWeaponUpgradeTemplates();
					foreach WeaponUpgrades(WeaponUpgradeTemplate)
					{
						UpgradedItemState.ApplyWeaponUpgradeTemplate(WeaponUpgradeTemplate);
					}

					// Delete the old item, and add the new item to the inventory
					NewGameState.RemoveStateObject(InventoryItemState.GetReference().ObjectID);
					XComHQ.Inventory.RemoveItem(InventoryItemState.GetReference());
					XComHQ.PutItemInInventory(NewGameState, UpgradedItemState);
				}
			}
		}

		// Then check every soldier's inventory and replace the old item with a new one
		Soldiers = XComHQ.GetSoldiers();
		for (iSoldier = 0; iSoldier < Soldiers.Length; iSoldier++)
		{
			InventoryItems = Soldiers[iSoldier].GetAllInventoryItems(NewGameState, false);

			foreach InventoryItems(InventoryItemState)
			{
				foreach ItemsToUpgrade(BaseItemTemplate)
				{
					if (InventoryItemState.GetMyTemplateName() == BaseItemTemplate.DataName)
					{
						UpgradedItemState = UpgradeItemTemplate.CreateInstanceFromTemplate(NewGameState);
						NewGameState.AddStateObject(UpgradedItemState);
						UpgradedItemState.WeaponAppearance = InventoryItemState.WeaponAppearance;
						UpgradedItemState.Nickname = InventoryItemState.Nickname;
						InventorySlot = InventoryItemState.InventorySlot; // save the slot location for the new item

						// Remove the old item from the soldier and transfer over all weapon upgrades to the new item
						Soldiers[iSoldier].RemoveItemFromInventory(InventoryItemState, NewGameState);
						ItemVisualizer = XGItem(`XCOMHISTORY.GetVisualizer(InventoryItemState.GetReference().ObjectID));
						ItemVisualizer.Destroy();
						`XCOMHISTORY.SetVisualizer(InventoryItemState.GetReference().ObjectID, none);
						WeaponUpgrades = InventoryItemState.GetMyWeaponUpgradeTemplates();
						foreach WeaponUpgrades(WeaponUpgradeTemplate)
						{
							UpgradedItemState.ApplyWeaponUpgradeTemplate(WeaponUpgradeTemplate);
						}

						// Delete the old item
						NewGameState.RemoveStateObject(InventoryItemState.GetReference().ObjectID);

						// Then add the new item to the soldier in the same slot
						Soldiers[iSoldier].AddItemToInventory(UpgradedItemState, InventorySlot, NewGameState);

						// Store the highest ranking soldier to get the upgraded item
						if (HighestRankSoldier == none || Soldiers[iSoldier].GetRank() > HighestRankSoldier.GetRank())
						{
							HighestRankSoldier = Soldiers[iSoldier];
						}
					}
				}
			}
		}

		// Play a narrative if there is one and there is a valid soldier
		if (HighestRankSoldier != none && X2EquipmentTemplate(UpgradeItemTemplate).EquipNarrative != "")
		{
			EquipNarrativeMoment = XComNarrativeMoment(`CONTENT.RequestGameArchetype(X2EquipmentTemplate(UpgradeItemTemplate).EquipNarrative));
			if (EquipNarrativeMoment != None && XComHQ.CanPlayArmorIntroNarrativeMoment(EquipNarrativeMoment))
			{
				XComHQ.UpdatePlayedArmorIntroNarrativeMoments(EquipNarrativeMoment);
				`HQPRES.UIArmorIntroCinematic(EquipNarrativeMoment.nmRemoteEvent, 'CIN_ArmorIntro_Done', HighestRankSoldier.GetReference());
			}
		}
	}
}

// Recursively calculates the list of items to upgrade based on the final upgraded item template
private static function GetItemsToUpgrade(X2ItemTemplate UpgradeItemTemplate, out array<X2ItemTemplate> ItemsToUpgrade)
{
	local X2ItemTemplateManager ItemTemplateManager;
	local X2ItemTemplate BaseItemTemplate, AdditionalBaseItemTemplate;
	local array<X2ItemTemplate> BaseItems;

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();

	// Search for any base items which specify this item as their upgrade. This accounts for the old version of schematics, mainly for Day 0 DLC
	BaseItems = ItemTemplateManager.GetAllBaseItemTemplatesFromUpgrade(UpgradeItemTemplate.DataName);
	foreach BaseItems(AdditionalBaseItemTemplate)
	{
		if (ItemsToUpgrade.Find(AdditionalBaseItemTemplate) == INDEX_NONE)
		{
			ItemsToUpgrade.AddItem(AdditionalBaseItemTemplate);
		}
	}
	
	// If the base item was also the result of an upgrade, we need to save that base item as well to ensure the entire chain is upgraded
	BaseItemTemplate = ItemTemplateManager.FindItemTemplate(UpgradeItemTemplate.BaseItem);
	if (BaseItemTemplate != none)
	{
		ItemsToUpgrade.AddItem(BaseItemTemplate);
		GetItemsToUpgrade(BaseItemTemplate, ItemsToUpgrade);
	}
}

exec function AddItemWaveCom(string strItemTemplate, optional int Quantity = 1, optional bool bLoot = false)
{
	local X2ItemTemplateManager ItemManager;
	local X2ItemTemplate ItemTemplate;
	local XComGameState NewGameState;
	local XComGameState_Item ItemState;
	local XComGameState_HeadquartersXCom HQState;
	local XComGameStateHistory History;

	ItemManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	ItemTemplate = ItemManager.FindItemTemplate(name(strItemTemplate));
	if (ItemTemplate == none)
	{
		`log("No item template named" @ strItemTemplate @ "was found.");
		return;
	}
	History = `XCOMHISTORY;
	HQState = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	`assert(HQState != none);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add Item Cheat: Create Item");
	ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
	NewGameState.AddStateObject(ItemState);
	if (Quantity > 0)
		ItemState.Quantity = Quantity;
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Add Item Cheat: Complete");
	HQState = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', HQState.ObjectID));
	HQState.PutItemInInventory(NewGameState, ItemState, bLoot);
	NewGameState.AddStateObject(HQState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	`log("Added item" @ strItemTemplate @ "object id" @ ItemState.ObjectID);
}