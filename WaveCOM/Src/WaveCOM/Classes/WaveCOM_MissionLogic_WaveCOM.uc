class WaveCOM_MissionLogic_WaveCOM extends XComGameState_MissionLogic config(WaveCOM);

var config bool REFILL_ITEM_CHARGES;

enum eWaveStatus
{
	eWaveStatus_Preparation,
	eWaveStatus_Combat,
};

var eWaveStatus WaveStatus;
var int CombatStartCountdown;
var int WaveNumber;

struct WaveEncounter {
	var name EncounterID;
	var int Earliest;
	var int Latest;
	var int Weighting;

	structdefaultproperties
	{
		Earliest = 0
		Latest = 1000
		Weighting = 1
	}
};

var const config int WaveCOMKillSupplyBonusBase;
var const config float WaveCOMKillSupplyBonusMultiplier;
var const config int WaveCOMWaveSupplyBonusBase;
var const config float WaveCOMWaveSupplyBonusMultiplier;
var const config int WaveCOMIntelBonusBase;
var const config float WaveCOMKillIntelBonusBase;
var const config int WaveCOMPassiveXPPerKill;
var const config array<int> WaveCOMPodCount;
var const config array<int> WaveCOMForceLevel;
var const config array<WaveEncounter> WaveEncounters;

delegate EventListenerReturn OnEventDelegate(Object EventData, Object EventSource, XComGameState GameState, Name EventID);

function EventListenerReturn RemoveExcessUnits(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local StateObjectReference AbilityReference, ItemReference, BlankReference;
	local XComGameState_Unit UnitState, CosmeticUnit;
	local XComGameState_Item ItemState;
	local XComGameState NewGameState;
	local TTile NextTile;
	local Vector NextSpawn;
	local X2EquipmentTemplate EquipmentTemplate;
	local Object this;

	class'WaveCOM_UILoadoutButton'.static.ChooseSpawnLocation(NextSpawn);
	NextTile = `XWORLD.GetTileCoordinatesFromPosition(NextSpawn);

	`log(" WaveCOM MissionLogic :: Begin clearing excess units. Coordinates:" @ NextTile.X $ "," $ NextTile.Y $ "," $ NextTile.Z);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing Excess Units");

	// Remove excess Units
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (`XCOMHQ.Squad.Find('ObjectID', UnitState.GetReference().ObjectID) != INDEX_NONE)
		{
			if (UnitState.TileLocation == NextTile) // If a new tile chosen is occupied, that means any unit on that tile are extras
			{
				`log("Cleaning Abilities");
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				foreach UnitState.Abilities(AbilityReference)
				{
					NewGameState.RemoveStateObject(AbilityReference.ObjectID);
				}
				UnitState.Abilities.Length = 0;

				foreach UnitState.InventoryItems(ItemReference)
				{
					ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemReference.ObjectID));
					if( ItemState.OwnerStateObject.ObjectID == UnitState.ObjectID )
					{
						EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
						if( EquipmentTemplate != none && EquipmentTemplate.CosmeticUnitTemplate != "" && ItemState.CosmeticUnitRef.ObjectID != 0)
						{
							`log("Murdering a gremlin");
							CosmeticUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', ItemState.CosmeticUnitRef.ObjectID));
							CosmeticUnit.RemoveUnitFromPlay();
							NewGameState.AddStateObject(CosmeticUnit);
							ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
							class'WaveCOM_UIArmory_FieldLoadout'.static.UnRegisterForCosmeticUnitEvents(ItemState, ItemState.CosmeticUnitRef);
							ItemState.CosmeticUnitRef = BlankReference;
							NewGameState.AddStateObject(ItemState);
						}
					}
				}
				class'WaveCOM_UIArmory_FieldLoadout'.static.CleanUpStats(NewGameState, UnitState);
				UnitState.RemoveUnitFromPlay();
				NewGameState.AddStateObject(UnitState);
				`XWORLD.ClearTileBlockedByUnitFlag(UnitState);
				`XEVENTMGR.TriggerEvent('UpdateDeployCostDelayed',,, NewGameState);
			}
		}
	}
	if(NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
	}

	this = self;

	`XEVENTMGR.UnRegisterFromEvent(this, 'HACK_RemoveExcessSoldiers');

	return ELR_NoInterrupt;
}

function SetupMissionStartState(XComGameState StartState)
{
	local XComGameState_BlackMarket BlackMarket;
	local Object ThisObj;

	`log("WaveCOM :: Setting Up State - Refresh Black Market and Remove extra units");
	
	BlackMarket = XComGameState_BlackMarket(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));
	BlackMarket = XComGameState_BlackMarket(StartState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
	StartState.AddStateObject(BlackMarket);
	BlackMarket.ResetBlackMarketGoods(StartState);

	UpdateCombatCountdown(StartState);

	ThisObj = self;

	`XEVENTMGR.RegisterForEvent(ThisObj, 'HACK_RemoveExcessSoldiers', RemoveExcessUnits, ELD_OnStateSubmitted,, StartState);
	`XEVENTMGR.TriggerEvent('HACK_RemoveExcessSoldiers', StartState, StartState, StartState);
}

function RegisterEventHandlers()
{	
	`log("WaveCOM :: Setting Up Event Handlers");

	OnAlienTurnBegin(Countdown);
	OnNoPlayableUnitsRemaining(HandleTeamDead);
}

function UpdateCombatCountdown(optional XComGameState NewGameState)
{
	if (WaveStatus == eWaveStatus_Preparation)
	{
		if (NewGameState != none)
			ModifyMissionTimerInState(true, CombatStartCountdown, "Prepare", "Next Wave in", Bad_Red, NewGameState);
		else
			ModifyMissionTimer(true, CombatStartCountdown, "Prepare", "Next Wave in", Bad_Red);
	}
	else
	{
		if (NewGameState != none)
			ModifyMissionTimerInState(true, WaveNumber, "Wave Number", "In Progress",, NewGameState); // hide timer
		else
			ModifyMissionTimer(true, WaveNumber, "Wave Number", "In Progress"); // hide timer
	}
}

function EventListenerReturn Countdown(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local WaveCOM_MissionLogic_WaveCOM NewMissionState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Item ItemState;
	local array<XComGameState_Item> ItemStates;
	local XComGameState_Unit UnitState;

	if (WaveStatus == eWaveStatus_Preparation)
	{

		CombatStartCountdown = CombatStartCountdown - 1;
		`log("WaveCOM :: Counting Down - " @ CombatStartCountdown);

		History = `XCOMHISTORY;
	
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Collect Wave Loot during Preparation");
		NewMissionState = WaveCOM_MissionLogic_WaveCOM(NewGameState.CreateStateObject(class'WaveCOM_MissionLogic_WaveCOM', ObjectID));
		NewMissionState.CombatStartCountdown = CombatStartCountdown;
		XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		NewGameState.AddStateObject(NewMissionState);
		NewGameState.AddStateObject(XComHQ);

		// recover loot collected during preparation turns
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if( UnitState.GetTeam() == eTeam_XCom)
			{
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				NewGameState.AddStateObject(UnitState);
				ItemStates = UnitState.GetAllItemsInSlot(eInvSlot_Backpack, NewGameState);
				foreach ItemStates(ItemState)
				{
					ItemState.OwnerStateObject = XComHQ.GetReference();
					UnitState.RemoveItemFromInventory(ItemState, NewGameState);
					XComHQ.PutItemInInventory(NewGameState, ItemState, false);
				}
			}
		}
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		if (CombatStartCountdown == 0)
		{
			InitiateWave();
		}
	}

	UpdateCombatCountdown();
	return ELR_NoInterrupt;
}

function InitiateWave()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersAlien AlienHQ;
	local XComGameState NewGameState;
	local WaveCOM_MissionLogic_WaveCOM NewMissionState;
	local array<WaveEncounter> WeightedStack;
	local XComGameState_NonstackingReinforcements Spawner;
	local WaveEncounter Encounter;
	local int Pods, Weighting, ForceLevel;
	local Vector ObjectiveLocation;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Force Level");

	WaveStatus = eWaveStatus_Combat;
	WaveNumber = WaveNumber + 1;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	ObjectiveLocation = BattleData.MapData.ObjectiveLocation;
	BattleData = XComGameState_BattleData(NewGameState.CreateStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	if (WaveNumber > WaveCOMForceLevel.Length - 1)
	{
		ForceLevel = WaveCOMForceLevel[WaveCOMForceLevel.Length - 1];
	}
	else
	{
		ForceLevel = WaveCOMForceLevel[WaveNumber];
	}
	ForceLevel = Clamp(ForceLevel, 1, 20);

	AlienHQ = XComGameState_HeadquartersAlien(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien'));
	AlienHQ.ForceLevel = ForceLevel;
	NewGameState.AddStateObject(AlienHQ);

	BattleData.SetForceLevel(ForceLevel);
	`SPAWNMGR.ForceLevel = ForceLevel;
	NewGameState.AddStateObject(BattleData);

	NewMissionState = WaveCOM_MissionLogic_WaveCOM(NewGameState.CreateStateObject(class'WaveCOM_MissionLogic_WaveCOM', ObjectID));
	NewMissionState.WaveStatus = WaveStatus;
	NewMissionState.WaveNumber = WaveNumber;
	NewGameState.AddStateObject(NewMissionState);
	
	if (WaveNumber > WaveCOMPodCount.Length - 1)
	{
		Pods = WaveCOMPodCount[WaveCOMPodCount.Length - 1];
	}
	else
	{
		Pods = WaveCOMPodCount[WaveNumber];
	}

	foreach WaveEncounters(Encounter)
	{
		if (Encounter.Earliest <= WaveNumber && Encounter.Latest >= WaveNumber && Encounter.Weighting > 0)
		{
			Weighting = Encounter.Weighting;
			while (Weighting > 0 )
			{
				WeightedStack.AddItem(Encounter);
				--Weighting;
			}
		}
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	while (Pods > 0 )
	{
		Encounter = WeightedStack[Rand(WeightedStack.Length)];
		class'XComGameState_NonstackingReinforcements'.static.InitiateReinforcements(
			Encounter.EncounterID,
			1, // FlareTimer
			true, // bUseOverrideTargetLocation,
			ObjectiveLocation, // OverrideTargetLocation, 
			40 // Spawn tiles offset
		);
		--Pods;
	}

	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Force Reinforcement ForceLevel");
	foreach History.IterateByClassType(class'XComGameState_NonstackingReinforcements', Spawner)
	{
		Spawner = XComGameState_NonstackingReinforcements(NewGameState.CreateStateObject(class'XComGameState_AIReinforcementSpawner', Spawner.ObjectID));

		// Pod Selection is hidden inside native code, however this function seems to do the trick, so we'll go with this
		`SPAWNMGR.SelectPodAtLocation(Spawner.SpawnInfo, ForceLevel, 1);
		NewGameState.AddStateObject(Spawner);
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	`XEVENTMGR.TriggerEvent('WaveCOM_WaveStart');
}

function HandleTeamDead(XGPlayer LosingPlayer)
{
	if (LosingPlayer.m_eTeam == eTeam_Alien)
	{
		BeginPreparationRound();
	}
	else if (LosingPlayer.m_eTeam == eTeam_XCom)
	{
		`TACTICALRULES.EndBattle(LosingPlayer, eUICombatLose_UnfailableGeneric, false);
	}
}

function CollectLootToHQ()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_Effect EffectState;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local float FloatingIntel;
	local int LootIndex, SupplyReward, IntelReward, KillCount;
	local X2ItemTemplateManager ItemTemplateManager;
	local XComGameState_Item ItemState;
	local StateObjectReference AbilityReference, UnitRef;
	local array<XComGameState_Item> ItemStates;
	local X2ItemTemplate ItemTemplate;
	local XComGameState_Unit UnitState;

	local LootResults PendingAutoLoot;
	local Name LootTemplateName;
	local array<Name> RolledLoot;

	History = `XCOMHISTORY;
	
	KillCount = 0;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Collect Wave Loot");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	NewGameState.AddStateObject(XComHQ);

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.CreateStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	NewGameState.AddStateObject(BattleData);

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{

		if( UnitState.IsAdvent() || UnitState.IsAlien() )
		{
			if ( !UnitState.bBodyRecovered ) {
				class'X2LootTableManager'.static.GetLootTableManager().RollForLootCarrier(UnitState.GetMyTemplate().Loot, PendingAutoLoot);

				// repurpose bBodyRecovered as a way to determine whether we got the loot yet
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UnitState.bBodyRecovered = true;
				UnitState.RemoveUnitFromPlay(); // must be done in the name of performance
				UnitState.OnEndTacticalPlay(); // Release all event handlers to improve performance
				NewGameState.AddStateObject(UnitState);
				++KillCount;

				if( PendingAutoLoot.LootToBeCreated.Length > 0 )
				{
					foreach PendingAutoLoot.LootToBeCreated(LootTemplateName)
					{
						ItemTemplate = ItemTemplateManager.FindItemTemplate(LootTemplateName);
						SupplyReward = SupplyReward + Round(ItemTemplate.TradingPostValue * WaveCOMKillSupplyBonusMultiplier);
						SupplyReward = SupplyReward + WaveCOMKillSupplyBonusBase;
						FloatingIntel += WaveCOMKillIntelBonusBase;
						RolledLoot.AddItem(ItemTemplate.DataName);
					}

				}
				PendingAutoLoot.LootToBeCreated.Remove(0, PendingAutoLoot.LootToBeCreated.Length);
				PendingAutoLoot.AvailableLoot.Remove(0, PendingAutoLoot.AvailableLoot.Length);
			}
		}
	}

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			UnitState.AddXp(KillCount * WaveCOMPassiveXPPerKill);
			UnitState.bRankedUp = false; // reset ranking to prevent blocking of future promotions
			NewGameState.AddStateObject(UnitState);

			ItemStates = UnitState.GetAllItemsInSlot(eInvSlot_Backpack, NewGameState);
			foreach ItemStates(ItemState)
			{
				ItemState.OwnerStateObject = XComHQ.GetReference();
				UnitState.RemoveItemFromInventory(ItemState, NewGameState);
				XComHQ.PutItemInInventory(NewGameState, ItemState, false);
			}

			// Recover all dead soldier's items.
			if (UnitState.IsDead())
			{
				ItemStates = UnitState.GetAllInventoryItems(NewGameState, true);
				foreach ItemStates(ItemState)
				{
					ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemState.ObjectID));
					NewGameState.AddStateObject(ItemState);

					if (UnitState.RemoveItemFromInventory(ItemState, NewGameState)) //  possible we'll have some items that cannot be removed, so don't recover them
					{
						ItemState.OwnerStateObject = XComHQ.GetReference();
						XComHQ.PutItemInInventory(NewGameState, ItemState, false);
					}
				}
				
				XComHQ.Squad.RemoveItem(UnitState.GetReference()); // Remove from squad
				UnitState.RemoveUnitFromPlay(); // RIP
				UnitState.OnEndTacticalPlay(); // Release all event handlers to improve performance
			}
		}
	}

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	for( LootIndex = 0; LootIndex < RolledLoot.Length; ++LootIndex )
	{
		// create the loot item
		`log("Added Loot: " @RolledLoot[LootIndex]);
		ItemState = ItemTemplateManager.FindItemTemplate(
			RolledLoot[LootIndex]
		).CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(ItemState);

		// assign the XComHQ as the new owner of the item
		ItemState.OwnerStateObject = XComHQ.GetReference();

		// add the item to the HQ's inventory (false so it automatically goes to stack)
		XComHQ.PutItemInInventory(NewGameState, ItemState, false);
	}

	SupplyReward = SupplyReward + WaveCOMWaveSupplyBonusBase;
	SupplyReward = SupplyReward + Round(WaveNumber * WaveCOMWaveSupplyBonusMultiplier);

	ItemTemplate = ItemTemplateManager.FindItemTemplate('Supplies');
	ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
	ItemState.Quantity = Round(SupplyReward);
	NewGameState.AddStateObject(ItemState);
	XComHQ.PutItemInInventory(NewGameState, ItemState, false);

	IntelReward = WaveCOMIntelBonusBase;
	IntelReward += Round(FloatingIntel);

	ItemTemplate = ItemTemplateManager.FindItemTemplate('Intel');
	ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
	ItemState.Quantity = IntelReward;
	NewGameState.AddStateObject(ItemState);
	XComHQ.PutItemInInventory(NewGameState, ItemState, false);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	// Reset Unit Abilities
	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if( UnitState.GetTeam() == eTeam_XCom)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clean Unit State");
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			NewGameState.AddStateObject(UnitState);
			`log("Cleaning and readding Abilities");
			foreach UnitState.Abilities(AbilityReference)
			{
				NewGameState.RemoveStateObject(AbilityReference.ObjectID);
			}

			while (UnitState.AppliedEffectNames.Length > 0)
			{
				EffectState = XComGameState_Effect( `XCOMHISTORY.GetGameStateForObjectID( UnitState.AppliedEffects[ 0 ].ObjectID ) );
				if (EffectState != None)
				{
					EffectState.GetX2Effect().UnitEndedTacticalPlay(EffectState, UnitState);
				}
				EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
			}

			class'WaveCOM_UIArmory_FieldLoadout'.static.RefillInventory(NewGameState, UnitState);

			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			
			UnitRef = UnitState.GetReference();
			if (UnitState.IsAlive() && XComHQ.Squad.Find('ObjectID', UnitRef.ObjectID) != INDEX_NONE && !UnitState.bRemovedFromPlay)
			{
				class'WaveCOM_UIArmory_FieldLoadout'.static.UpdateUnit(UnitRef.ObjectID);
			}
		}
	}
}

function BeginPreparationRound()
{
	local XComGameState NewGameState;
	local WaveCOM_MissionLogic_WaveCOM NewMissionState;
	local XComGameState_BlackMarket BlackMarket;

	WaveStatus = eWaveStatus_Preparation;
	CombatStartCountdown = 3;
	CollectLootToHQ();

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Collect Wave Loot during Preparation");
	NewMissionState = WaveCOM_MissionLogic_WaveCOM(NewGameState.CreateStateObject(class'WaveCOM_MissionLogic_WaveCOM', ObjectID));
	NewMissionState.CombatStartCountdown = CombatStartCountdown;
	NewMissionState.WaveStatus = WaveStatus;
	NewGameState.AddStateObject(NewMissionState);

	BlackMarket = XComGameState_BlackMarket(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));
	BlackMarket = XComGameState_BlackMarket(NewGameState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
	NewGameState.AddStateObject(BlackMarket);
	BlackMarket.ResetBlackMarketGoods(NewGameState);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	//`XCOMHISTORY.ArchiveHistory("Wave" @ NewMissionState.WaveNumber);

	UpdateCombatCountdown();
	`XEVENTMGR.TriggerEvent('WaveCOM_WaveEnd');
}

defaultproperties
{
	WaveStatus = eWaveStatus_Preparation
	CombatStartCountdown = 3
	WaveNumber = 0
}