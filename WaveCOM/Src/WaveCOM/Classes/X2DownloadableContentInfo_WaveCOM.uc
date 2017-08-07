//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_WaveCOM.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_WaveCOM extends X2DownloadableContentInfo config(WaveCOM) dependson(X2EventManager);

var const config float WaveCOMResearchSupplyCostRatio;
var config array<name> NonUpgradeSchematics;
var config array<name> ObsoleteOTSUpgrades;
var config array<name> CantSellResource;

struct DynamicUpgradeData
{
	var name UpgradeName;
	var array<StrategyCost> BaseCost;
	var int SupplyIncrement;
	var int SupplyMax;
	var int FirstIncrease;
	var bool ScaleWithSquadSize;
	var bool IgnoreDiscounts;
};

var config array<DynamicUpgradeData> RepeatableUpgradeCosts;

static event OnPostTemplatesCreated()
{
	`log("WaveCOM :: Present And Correct");
	PatchOutUselessOTS();
	MakeEleriumAlloyUnsellable();
	AddContinentsToOTS();
	PatchBlackMarketSoldierReward();
}

static function MakeEleriumAlloyUnsellable()
{
	local X2ItemTemplate ItemTemplate;
	local X2DataTemplate Template;
	local array<X2DataTemplate> ItemTemplates;
	local name ResName;
	
	foreach default.CantSellResource(ResName)
	{
		class'X2ItemTemplateManager'.static.GetItemTemplateManager().FindDataTemplateAllDifficulties(ResName, ItemTemplates);
		foreach ItemTemplates(Template)
		{
			ItemTemplate = X2ItemTemplate(Template);
			if (ItemTemplate != none)
			{
				ItemTemplate.TradingPostValue = 0;
			}
		}
	}
}

static function PatchOutUselessOTS()
{
	local X2FacilityTemplate FacilityTemplate;
	local X2DataTemplate Template;
	local array<X2DataTemplate> FacilityTemplates;
	local name OTSName;

	class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindDataTemplateAllDifficulties('OfficerTrainingSchool', FacilityTemplates);
	foreach FacilityTemplates(Template)
	{
		FacilityTemplate = X2FacilityTemplate(Template);
		if (FacilityTemplate != none)
		{
			foreach default.ObsoleteOTSUpgrades(OTSName)
			{
				FacilityTemplate.SoldierUnlockTemplates.RemoveItem(OTSName);
			}
		}
	}
}

static function AddContinentsToOTS()
{
	local X2FacilityTemplate FacilityTemplate;
	local X2DataTemplate Template;
	local array<X2DataTemplate> FacilityTemplates;

	class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindDataTemplateAllDifficulties('OfficerTrainingSchool', FacilityTemplates);
	foreach FacilityTemplates(Template)
	{
		FacilityTemplate = X2FacilityTemplate(Template);
		if (FacilityTemplate != none)
		{
			FacilityTemplate.SoldierUnlockTemplates.AddItem('WaveCOM_QuidUnlock');
			FacilityTemplate.SoldierUnlockTemplates.AddItem('WaveCOM_LockNLoadUnlock');
			FacilityTemplate.SoldierUnlockTemplates.AddItem('WaveCOM_SparePartsUnlock');
			FacilityTemplate.SoldierUnlockTemplates.AddItem('WaveCOM_ArmedToTeethUnlock');
		}
	}
}

static function PatchBlackMarketSoldierReward()
{
	local X2RewardTemplate RewardTemplate;
	RewardTemplate = X2RewardTemplate(class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('Reward_Soldier'));
	RewardTemplate.GiveRewardFn = GivePersonnelReward;
}

function GivePersonnelReward(XComGameState NewGameState, XComGameState_Reward RewardState, optional StateObjectReference AuxRef, optional bool bOrder = false, optional int OrderHours = -1)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;	
	local XComGameState_Unit UnitState;

	local TDialogueBoxData  kDialogData;

	History = `XCOMHISTORY;	

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	NewGameState.AddStateObject(XComHQ);	

	UnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(RewardState.RewardObjectReference.ObjectID));
	if(UnitState == none)
	{
		UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', RewardState.RewardObjectReference.ObjectID));
		NewGameState.AddStateObject(UnitState);
	}
		
	`assert(UnitState != none);

	if(UnitState.GetMyTemplate().bIsSoldier)
	{
		UnitState.ApplyBestGearLoadout(NewGameState);
	}

	XComHQ.AddToCrew(NewGameState, UnitState);

	NewGameState.AddStateObject(UnitState);

	XComHQ.Squad.AddItem(UnitState.GetReference());
	NewGameState.AddStateObject(XComHQ);

	kDialogData.eType = eDialog_Alert;
	kDialogData.strTitle = "Purchased black market unit";
	kDialogData.strText = "Click the deploy soldier button to spawn the purchased unit";

	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

	`PRES.UIRaiseDialog(kDialogData);

	`XEVENTMGR.TriggerEvent('UpdateDeployCost');
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

static function AddSupplyCost(out array<ArtifactCost> Resources, int SupplyDiff)
{
	local ArtifactCost Resource, NewResource;

	NewResource.ItemTemplateName = 'Supplies';

	foreach Resources(Resource)
	{
		if (Resource.ItemTemplateName == 'Supplies')
		{
			NewResource.Quantity = Resource.Quantity;
			Resources.RemoveItem(Resource);
			break;
		}
	}

	NewResource.Quantity += SupplyDiff;
	Resources.AddItem(NewResource);
}

static function UpdateResearchTemplates ()
{
	local X2StrategyElementTemplateManager Manager;
	local array<X2StrategyElementTemplate> Techs;
	local X2StrategyElementTemplate TechTemplate;
	local X2TechTemplate Tech;
	local int BasePoints;
	local int UpgradeIndex;
	local int DiffIndex;
	local DynamicUpgradeData CostData;

	Manager = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	Techs = Manager.GetAllTemplatesOfClass(class'X2TechTemplate');
	DiffIndex = class'XComGameState_CampaignSettings'.static.GetDifficultyFromSettings();


	foreach Techs(TechTemplate)
	{
		Tech = X2TechTemplate(TechTemplate);
		if (Tech.PointsToComplete > 0)
		{
			BasePoints = Tech.PointsToComplete;
			AddSupplyCost(Tech.Cost.ResourceCosts, Round(BasePoints * default.WaveCOMResearchSupplyCostRatio));
			Tech.bJumpToLabs = false;
			Tech.PointsToComplete = 0;
			Manager.AddStrategyElementTemplate(Tech, true);

			UpgradeIndex = default.RepeatableUpgradeCosts.Find('UpgradeName', Tech.DataName);

			if (UpgradeIndex != INDEX_NONE)
			{
				CostData = default.RepeatableUpgradeCosts[UpgradeIndex];

				while (CostData.BaseCost.Length < 4)
				{
					CostData.BaseCost.Add(1);
				}
				CostData.BaseCost[DiffIndex] = Tech.Cost;

				default.RepeatableUpgradeCosts.Remove(UpgradeIndex, 1);
				default.RepeatableUpgradeCosts.AddItem(CostData);
			}
		}
	}
}

static function UpdateResearchCostDynamic (int SquadSize, optional float ProvingGroundPercentDiscount = 0.00f)
{
	local XComGameState_Tech TechState;
	local int UpgradeIndex, StackCount, CostIncrease;
	local DynamicUpgradeData CostData;
	local X2TechTemplate Tech;
	local XComGameStateHistory History;
	local int DiffIndex;

	History = `XCOMHISTORY;
	DiffIndex = class'XComGameState_CampaignSettings'.static.GetDifficultyFromSettings();

	foreach History.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		UpgradeIndex = default.RepeatableUpgradeCosts.Find('UpgradeName', TechState.GetMyTemplateName());

		if (UpgradeIndex != INDEX_NONE)
		{
			Tech = TechState.GetMyTemplate();
			CostData = default.RepeatableUpgradeCosts[UpgradeIndex];

			if (CostData.BaseCost.Length > DiffIndex)
			{
				if (CostData.ScaleWithSquadSize)
					StackCount = SquadSize;
				else
					StackCount = TechState.TimesResearched;
				
				Tech.Cost = CostData.BaseCost[DiffIndex];
				if (StackCount > CostData.FirstIncrease)
				{
					StackCount = StackCount - CostData.FirstIncrease;
					CostIncrease = Min(Round(CostData.SupplyIncrement * StackCount), CostData.SupplyMax);
					if (CostData.IgnoreDiscounts && ProvingGroundPercentDiscount > 0)
					{
						if (Tech.bProvingGround)
						{
							CostIncrease *= (100.0f / (100.0f - ProvingGroundPercentDiscount));
						}
					}
					AddSupplyCost(Tech.Cost.ResourceCosts, CostIncrease);
				}
				class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().AddStrategyElementTemplate(Tech, true);
			}
		}
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
		if (default.NonUpgradeSchematics.Find(Schematic.DataName) == INDEX_NONE)
		{
			`log("Updating: " @Schematic.DataName,, 'WaveCOM');
			Schematic.OnBuiltFn = UpgradeItems;

			Manager.AddItemTemplate(Schematic, true);
		}
		else
		{
			`log("Skipping schematic: " @Schematic.DataName,, 'WaveCOM');
		}
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
	local XComGameState_Unit CosmeticUnit;
	local array<X2ItemTemplate> CreatedItems, ItemsToUpgrade;
	local array<X2WeaponUpgradeTemplate> WeaponUpgrades;
	local array<XComGameState_Item> InventoryItems;
	local array<XComGameState_Unit> Soldiers;
	local EInventorySlot InventorySlot;
	local XGItem ItemVisualizer;
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
						if (ItemVisualizer != none)
						{
							ItemVisualizer.Destroy();
							`XCOMHISTORY.SetVisualizer(InventoryItemState.GetReference().ObjectID, none);
						}
						WeaponUpgrades = InventoryItemState.GetMyWeaponUpgradeTemplates();
						foreach WeaponUpgrades(WeaponUpgradeTemplate)
						{
							UpgradedItemState.ApplyWeaponUpgradeTemplate(WeaponUpgradeTemplate);
						}
						
						if( InventoryItemState.CosmeticUnitRef.ObjectID > 0 )
						{
							CosmeticUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', InventoryItemState.CosmeticUnitRef.ObjectID));;
							CosmeticUnit.RemoveUnitFromPlay();
							class'WaveCOM_UIArmory_FieldLoadout'.static.UnRegisterForCosmeticUnitEvents(InventoryItemState, InventoryItemState.CosmeticUnitRef);
							NewGameState.AddStateObject(CosmeticUnit);
						}

						// Delete the old item
						NewGameState.RemoveStateObject(InventoryItemState.GetReference().ObjectID);

						// Then add the new item to the soldier in the same slot
						Soldiers[iSoldier].AddItemToInventory(UpgradedItemState, InventorySlot, NewGameState);
					}
				}
			}
		}

		// Remove narratives to prevent problems
		
		`XEVENTMGR.TriggerEvent('RequestRefreshAllUnits', , , NewGameState);
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

exec function RefreshOTS()
{
	local XComGameState_Player XComPlayer;
	local XComGameState_BattleData BattleData;
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update OTS Entries");
	
	BattleData = XComGameState_BattleData( `XCOMHISTORY.GetSingleGameStateObjectForClass( class'XComGameState_BattleData' ) );
	XComPlayer = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(BattleData.PlayerTurnOrder[0].ObjectID));
	XComPlayer = XComGameState_Player(NewGameState.CreateStateObject(class'XComGameState_Player', XComPlayer.ObjectID));
	XComPlayer.SoldierUnlockTemplates = `XCOMHQ.SoldierUnlockTemplates;
	NewGameState.AddStateObject(XComPlayer);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

static function StaticWaveCOMMissionTransfer()
{
	local XComPlayerController PlayerController;
	local string MissionType;
	local MissionDefinition MissionDef;
	local array<string> MissionTypes;
	local WaveCOM_MissionLogic_WaveCOM MissionLogic;
	local XComGameState NewGameState;
	local XComMissionLogic_Listener MissionListener;

	MissionLogic = WaveCOM_MissionLogic_WaveCOM(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'WaveCOM_MissionLogic_WaveCOM'));
	if (MissionLogic != none)
	{
		`log("=-=-=-=-=-=-= Preparing to transfer MissionLogic =-=-=-=-=-=-=",, 'WaveCOM');
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Preparing Mission Logic for transfer");
		MissionLogic = WaveCOM_MissionLogic_WaveCOM(NewGameState.CreateStateObject(class'WaveCOM_MissionLogic_WaveCOM', MissionLogic.ObjectID));
		MissionLogic.bIsBeingTransferred = true;
		// Reset to pre wave start
		MissionLogic.WaveStatus = eWaveStatus_Preparation;
		MissionLogic.CombatStartCountdown = 3;
		MissionLogic.UnregisterAllObservers();
		NewGameState.AddStateObject(MissionLogic);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	foreach class'XComTacticalMissionManager'.default.arrMissions(MissionDef)
	{
		if (MissionDef.MissionFamily == "WaveCOM")
			MissionTypes.AddItem(MissionDef.sType);
	}
	
	MissionType = MissionTypes[class'Engine'.static.GetEngine().SyncRand(MissionTypes.Length, "WaveCOMTransferMissionRoll")];

	`log("Transfering to new mission...",, 'WaveCOM');
	PlayerController = XComPlayerController(class'WorldInfo'.static.GetWorldInfo().GetALocalPlayerController());
	`XEVENTMGR.Clear(); // TEST: Clear ALL EVENTS

	`log("XComMissionLogic :: RegisterMissionLogicListener");

	// Re-register MissionLogicListener
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Loading Save Game Mission Logic Loader");
	MissionListener = XComMissionLogic_Listener(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComMissionLogic_Listener'));
	if (MissionListener == none)
		MissionListener = XComMissionLogic_Listener(NewGameState.CreateStateObject(class'XComMissionLogic_Listener'));
	else
		MissionListener = XComMissionLogic_Listener(NewGameState.CreateStateObject(class'XComMissionLogic_Listener', MissionListener.ObjectID));
	NewGameState.AddStateObject(MissionListener);
	MissionListener.RegisterToListen();
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);


	PlayerController.TransferToNewMission(MissionType);
}

exec function WaveCOMTransferToNewMission()
{
	StaticWaveCOMMissionTransfer();
}

exec function DebugMissionLogic()
{
	local WaveCOM_MissionLogic_WaveCOM WaveLogic;
	local TDialogueBoxData  kDialogData;
	local eWaveStatus DebugResult;

	WaveLogic = WaveCOM_MissionLogic_WaveCOM(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'WaveCOM_MissionLogic_WaveCOM'));
	if (WaveLogic != none)
	{
		kDialogData.eType = eDialog_Alert;
		kDialogData.strTitle = "Mission Logic status";
		DebugResult = eWaveStatus(WaveLogic.WaveStatus);
		kDialogData.strText = "Wave:" @ WaveLogic.WaveNumber $ ", status:" @ DebugResult $ ", countdown:" @ WaveLogic.CombatStartCountdown;
		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

		`PRES.UIRaiseDialog(kDialogData);
	}
	else
	{
		kDialogData.eType = eDialog_Alert;
		kDialogData.strTitle = "No mission logic found";
		kDialogData.strText = "Unable to find MissionLogic.";

		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

		`PRES.UIRaiseDialog(kDialogData);
	}
}

static event ModifyTacticalTransferStartState(XComGameState TransferStartState)
{
	local WaveCOM_MissionLogic_WaveCOM WaveLogic, MissionLogic;
	local XComGameState_BaseObject RemoveState;
	local XComGameState_LootDrop LootState;
	local int WaveID;
	`log("=*=*=*=*=*=*= Tactical Transfer code executed successfully! =*=*=*=*=*=*=",, 'WaveCOM');
	`log("Start state size" @ TransferStartState.GetNumGameStateObjects(),, 'WaveCOM');

	WaveLogic = WaveCOM_MissionLogic_WaveCOM(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'WaveCOM_MissionLogic_WaveCOM'));
	if (WaveLogic != none)
	{
		WaveID = WaveLogic.ObjectID;
		MissionLogic = WaveCOM_MissionLogic_WaveCOM(TransferStartState.GetGameStateForObjectID(WaveLogic.ObjectID));
		if (MissionLogic == none)
		{
			`log("Mission Logic not transferred, forcing one",, 'WaveCOM');
			MissionLogic = WaveCOM_MissionLogic_WaveCOM(TransferStartState.CreateStateObject(class'WaveCOM_MissionLogic_WaveCOM', WaveID));
		}
		MissionLogic.bIsBeingTransferred = true;
		// Reset to pre wave start
		MissionLogic.WaveStatus = eWaveStatus_Preparation;
		MissionLogic.CombatStartCountdown = 3;
		MissionLogic.UnregisterAllObservers();
	}
	else
	{
		foreach TransferStartState.IterateByClassType(class'WaveCOM_MissionLogic_WaveCOM', WaveLogic)
		{
			`log("Found transfering mission logic, turning on Being transferred flag",, 'WaveCOM');
			MissionLogic.bIsBeingTransferred = true;
			// Reset to pre wave start
			MissionLogic.WaveStatus = eWaveStatus_Preparation;
			MissionLogic.CombatStartCountdown = 3;
			MissionLogic.UnregisterAllObservers();
		}
	}
	RemoveState = `XCOMHISTORY.GetSingleGameStateObjectForClass(class 'XComGameState_UITimer', true);
	if (RemoveState != none)
	{
		// We will make a new UI Timer next round
		TransferStartState.RemoveStateObject(RemoveState.ObjectID);
	}
	foreach TransferStartState.IterateByClassType(class'XComGameState_LootDrop', LootState)
	{
		// We don't carry loot drops over
		TransferStartState.RemoveStateObject(LootState.ObjectID);
	}
}

exec function RemoveAllUnusedEnemyStateObjects()
{
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState;
	local int totalUnitState, totalAliens, removedStates;
	local StateObjectReference AbilityReference, ItemReference;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Spring cleaning");

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		totalUnitState++;
		if (UnitState.GetTeam() == eTeam_Alien)
		{
			totalAliens++;
			if (UnitState.bRemovedFromPlay)
			{
				removedStates++;
				// Remove all abilities
				foreach UnitState.Abilities(AbilityReference)
				{
					if (`XCOMHISTORY.GetGameStateForObjectID(AbilityReference.ObjectID) != none)
					{
						removedStates++;
						NewGameState.RemoveStateObject(AbilityReference.ObjectID);
					}
				}
				// Remove all items
				foreach UnitState.InventoryItems(ItemReference)
				{
					if (XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemReference.ObjectID)) != none &&
						XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemReference.ObjectID)).OwnerStateObject.ObjectID == UnitState.GetReference().ObjectID)
					{
						removedStates++;
						NewGameState.RemoveStateObject(ItemReference.ObjectID);
					}
				}
				NewGameState.RemoveStateObject(UnitState.ObjectID);
			}
		}
	}

	`log(" WaveCOM :: Total unit state:" @ totalUnitState $ ", total aliens:" @ totalAliens $", removed" @ removedStates);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

exec function DebugAllGameStateTypes()
{
	local XComGameState_BaseObject GameState;
	local int totalStates, destructibles, units, items, abilities, effects, loot;
	local TDialogueBoxData  kDialogData;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_BaseObject', GameState)
	{
		totalStates++;
		if (GameState.class == class'XComGameState_Destructible')
			destructibles++;
		if (GameState.class == class'XComGameState_Unit')
			units++;
		if (GameState.class == class'XComGameState_Item')
			items++;
		if (GameState.class == class'XComGameState_Ability')
			abilities++;
		if (GameState.class == class'XComGameState_Effect')
			effects++;
		if (GameState.class == class'XComGameState_LootDrop')
			loot++;
	}

	kDialogData.eType = eDialog_Alert;
	kDialogData.strTitle = "Total number of game states:" @ totalStates;

	kDialogData.strText = "Numbers:\n";
	kDialogData.strText $= "Units:" @ units $ "\n";
	kDialogData.strText $= "Items:" @ items $ "\n";
	kDialogData.strText $= "Abilities:" @ abilities $ "\n";
	kDialogData.strText $= "Effects:" @ effects $ "\n";
	kDialogData.strText $= "Loot drps:" @ loot $ "\n";
	kDialogData.strText $= "Destructibles:" @ destructibles $ "\n";

	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

	`PRES.UIRaiseDialog(kDialogData);
}

exec function DebugEvents(optional name EventID='', optional string ObjectName="XComGameState_BaseObject", optional int Mode=0)
{
	local TDialogueBoxData  kDialogData;

	kDialogData.eType = eDialog_Alert;
	kDialogData.strTitle = "Tallying events:";

	if (Mode == 0)
		kDialogData.strText = "Events:" @ `XEVENTMGR.AllEventListenersToString(EventID, ObjectName);
	else
		kDialogData.strText = "Debug:" @ `XEVENTMGR.EventManagerDebugString(EventID, ObjectName);

	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

	`PRES.UIRaiseDialog(kDialogData);
}

exec function DumpEvents()
{
	`log(`XEVENTMGR.EventManagerDebugString());
}

exec function GetObjectIDStatus(int ID)
{
	local TDialogueBoxData  kDialogData;
	local XComGameState_BaseObject StateObject;
	kDialogData.eType = eDialog_Alert;
	kDialogData.strTitle = "Tallying events:";

	StateObject = `XCOMHISTORY.GetGameStateForObjectID(ID);



	if (StateObject == none)
		kDialogData.strText = ID @ "not found.";
	else
	{
		kDialogData.strText = ID @ "found:";
		if (StateObject.bInPlay)
			kDialogData.strText $= "In play. ";
		else
			kDialogData.strText $= "Not in play. ";
		if (StateObject.bRemoved)
			kDialogData.strText $= "Active. ";
		else
			kDialogData.strText $= "Removed. ";
		kDialogData.strText $= "\n" $ StateObject.ToString();
		
	}

	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

	`PRES.UIRaiseDialog(kDialogData);
}

exec function ReviveAll()
{
	local WaveCOMGameStateContext_UpdateUnit EffectContext;
	local StateObjectReference AbilityReference, UnitRef;
	local XComGameState NewGameState;
	local XGUnit Visualizer;
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersXCom XComHQ;

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom)
		{
			EffectContext = class'WaveCOMGameStateContext_UpdateUnit'.static.CreateChangeStateUU("Clean Unit State", UnitState);
			NewGameState = EffectContext.GetGameState();
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			NewGameState.AddStateObject(UnitState);
			`log("Cleaning and readding Abilities");
			foreach UnitState.Abilities(AbilityReference)
			{
				NewGameState.RemoveStateObject(AbilityReference.ObjectID);
			}
			UnitState.Abilities.Length = 0;
			Visualizer = XGUnit(UnitState.FindOrCreateVisualizer());
			Visualizer.GetPawn().StopPersistentPawnPerkFX(); // Remove all abilities visualizers

			class'WaveCOM_UIArmory_FieldLoadout'.static.CleanUpStats(NewGameState, UnitState, EffectContext);
			class'WaveCOM_UIArmory_FieldLoadout'.static.RefillInventory(NewGameState, UnitState);

			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			
			XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
			UnitRef = UnitState.GetReference();
			if (UnitState.IsAlive() && XComHQ.Squad.Find('ObjectID', UnitRef.ObjectID) != INDEX_NONE && !UnitState.bRemovedFromPlay)
			{
				class'WaveCOM_UIArmory_FieldLoadout'.static.UpdateUnit(UnitRef.ObjectID);
			}
		}
	}
}