class WaveCOM_MissionLogic_WaveCOM extends X2MissionLogic config(WaveCOM);

enum eWaveStatus
{
	eWaveStatus_Preparation,
	eWaveStatus_Combat,
};

var eWaveStatus WaveStatus;
var int CombatStartCountdown;
var int WaveNumber;

var const config float WaveCOMKillSupplyBonusMultiplier;
var const config array<int> WaveCOMPodCount;

delegate EventListenerReturn OnEventDelegate(Object EventData, Object EventSource, XComGameState GameState, Name EventID);

function RegisterEventHandlers()
{	
	OnAlienTurnBegin(Countdown);
	OnNoPlayableUnitsRemaining(HandleTeamDead);
}

function UpdateCombatCountdown()
{
	if (WaveStatus == eWaveStatus_Preparation)
	{
		ModifyMissionTimer(true, CombatStartCountdown, "Prepare", "Next Wave in", Bad_Red);
	}
	else
	{
		ModifyMissionTimer(true, WaveNumber, "Wave Number", "In Progress"); // hide timer
	}
}

function EventListenerReturn Countdown(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	if (WaveStatus == eWaveStatus_Preparation)
	{
		CombatStartCountdown = CombatStartCountdown - 1;
		if (CombatStartCountdown == 0)
		{
			InitiateWave();
		}

		UpdateCombatCountdown();
	}
	return ELR_NoInterrupt;
}

function InitiateWave()
{
	local XComGameStateHistory History;
	local XComGameState_BattleData BattleData;
	local XComGameState NewGameState;
	local int Pods;
	local Vector ObjectiveLocation;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Collect Wave Loot");

	WaveStatus = eWaveStatus_Combat;
	WaveNumber = WaveNumber + 1;

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	ObjectiveLocation = BattleData.MapData.ObjectiveLocation;
	BattleData = XComGameState_BattleData(NewGameState.CreateStateObject(class'XComGameState_BattleData', BattleData.ObjectID));

	BattleData.SetForceLevel(Clamp(WaveNumber, 1, 20));
	NewGameState.AddStateObject(BattleData);
	
	if (WaveNumber > WaveCOMPodCount.Length - 1)
	{
		Pods = WaveCOMPodCount[WaveCOMPodCount.Length - 1];
	}
	else
	{
		Pods = WaveCOMPodCount[WaveNumber];
	}

	while (Pods > 0 )
	{
		class'XComGameState_AIReinforcementSpawner'.static.InitiateReinforcements(
			'WaveCOM_ADVx3_Standard',
			1, // FlareTimer
			true, // bUseOverrideTargetLocation,
			ObjectiveLocation, // OverrideTargetLocation, 
			20 // Spawn tiles offset
		);
		--Pods;
	}

	`XEVENTMGR.TriggerEvent('WaveCOM_WaveStart');
}

function HandleTeamDead(XGPlayer LosingPlayer)
{
	if (LosingPlayer.m_eTeam == eTeam_Alien)
	{
		BeginPreparationRound();
	}
	else
	{
	}
}

function CollectLootToHQ()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local int LootIndex, KillSupplies;
	local X2ItemTemplateManager ItemTemplateManager;
	local XComGameState_Item ItemState;
	local X2ItemTemplate ItemTemplate;
	local XComGameState_Unit UnitState;

	local LootResults PendingAutoLoot;
	local Name LootTemplateName;
	local array<Name> RolledLoot;

	History = `XCOMHISTORY;
	
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
		if( UnitState.GetTeam() == eTeam_XCom)
		{
			UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
			UnitState.bRankedUp = false; // reset ranking to prevent blocking of future promotions
			NewGameState.AddStateObject(UnitState);
		}

		if( UnitState.IsAdvent() || UnitState.IsAlien() )
		{
			if ( !UnitState.bBodyRecovered ) {
				class'X2LootTableManager'.static.GetLootTableManager().RollForLootCarrier(UnitState.GetMyTemplate().Loot, PendingAutoLoot);

				// repurpose bBodyRecovered as a way to determine whether we got the loot yet
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				UnitState.bBodyRecovered = true;
				NewGameState.AddStateObject(UnitState);

				if( PendingAutoLoot.LootToBeCreated.Length > 0 )
				{
					`log("This body was recovered");
					foreach PendingAutoLoot.LootToBeCreated(LootTemplateName)
					{
						ItemTemplate = ItemTemplateManager.FindItemTemplate(LootTemplateName);
						KillSupplies = KillSupplies + ItemTemplate.TradingPostValue;
						RolledLoot.AddItem(ItemTemplate.DataName);
					}

				}
				PendingAutoLoot.LootToBeCreated.Remove(0, PendingAutoLoot.LootToBeCreated.Length);
				PendingAutoLoot.AvailableLoot.Remove(0, PendingAutoLoot.AvailableLoot.Length);
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

	ItemTemplate = ItemTemplateManager.FindItemTemplate('Supplies');
	ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
	ItemState.Quantity = Round(KillSupplies * WaveCOMKillSupplyBonusMultiplier);
	NewGameState.AddStateObject(ItemState);
	XComHQ.PutItemInInventory(NewGameState, ItemState, false);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

function BeginPreparationRound()
{
	WaveStatus = eWaveStatus_Preparation;
	CombatStartCountdown = 3;
	CollectLootToHQ();
	UpdateCombatCountdown();
	`XEVENTMGR.TriggerEvent('WaveCOM_WaveEnd');
}

defaultproperties
{
	WaveStatus = eWaveStatus_Preparation
	CombatStartCountdown = 3
	WaveNumber = 0
}