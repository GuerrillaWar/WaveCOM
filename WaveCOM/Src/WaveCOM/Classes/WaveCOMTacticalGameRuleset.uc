// This is an Unreal Script

class WaveCOMTacticalGameRuleset extends X2TacticalGameRuleset config(WaveCOM);

struct MissionLogicBinding
{
	var string MissionType;
	var string MissionLogicClass;
};

var const config array<MissionLogicBinding> arrMissionLogicBindings;
var const config float WaveCOMResearchSupplyCostRatio;

/// <summary>
/// Called by the tactical game start up process when a new battle is starting
/// </summary>
simulated function StartNewGame()
{


	//Build a local cache of useful state object references
	BuildLocalStateObjectCache();


	GotoState('CreateTacticalGame');
}

simulated function LoadRelevantMissionLogic()
{
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	local X2MissionLogic MissionLogic;
	local MissionLogicBinding LogicBinding;
	local class<X2MissionLogic> MissionLogicClass;
	local string MissionType;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Setup Mission Logic");

	BattleData = XComGameState_BattleData(CachedHistory.GetGameStateForObjectID(CachedBattleDataRef.ObjectID));
	MissionType = BattleData.MapData.ActiveMission.sType;
	`log("Loading for:");
	`log(MissionType);
	foreach arrMissionLogicBindings(LogicBinding)
	{
		`log(LogicBinding.MissionType);
		`log(LogicBinding.MissionLogicClass);
		if (LogicBinding.MissionType == MissionType)
		{
			MissionLogicClass = class<X2MissionLogic>(DynamicLoadObject(LogicBinding.MissionLogicClass, class'Class'));
			MissionLogic = X2MissionLogic(NewGameState.CreateStateObject(MissionLogicClass));
			NewGameState.AddStateObject(MissionLogic);
			MissionLogic.RegisterEventHandlers();
		}
	}
	`log("SubmittingGameState");


	SubmitGameState(NewGameState);
}

function MakeAllTechInstant()
{
	local XComGameStateHistory History;
	local XComGameState_Tech TechState;
	local XComGameState NewGameState;

	UpdateResearchTemplates();
	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("MakeTechInstant");

	foreach History.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		TechState = XComGameState_Tech(NewGameState.CreateStateObject(class'XComGameState_Tech', TechState.ObjectID));
		TechState.bForceInstant = true;
		TechState.bSeenInstantPopup = true;
		NewGameState.AddStateObject(TechState);
	}
	SubmitGameState(NewGameState);
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
	`log("Scaling Research: " @Techs.Length);
	foreach Techs(TechTemplate)
	{
		Tech = X2TechTemplate(TechTemplate);
		`log("Scaling: " @Tech.DataName);
		BasePoints = Tech.PointsToComplete;
		Resources.ItemTemplateName = 'Supplies';
		Resources.Quantity = Round(BasePoints * default.WaveCOMResearchSupplyCostRatio);
		Tech.Cost.ResourceCosts.AddItem(Resources);
		Tech.bJumpToLabs = false;
		Tech.PointsToComplete = 0;
		Manager.AddStrategyElementTemplate(Tech, true);
		
		`log("Supply Cost: " @Round(BasePoints * default.WaveCOMResearchSupplyCostRatio));
	}
}

function ApplyStartOfMatchConditions()
{
	LoadRelevantMissionLogic();
	MakeAllTechInstant();
	Super(X2TacticalGameRuleset).ApplyStartOfMatchConditions();
	`log(`XEVENTMGR.AllEventListenersToString());
}


static function CleanupTacticalMission(optional bool bSimCombat = false)
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local XComGameState_BattleData BattleData;
	local XComGameState_HeadquartersXCom XComHQ;
	local int LootIndex, ObjectiveIndex;
	local X2ItemTemplateManager ItemTemplateManager;
	local XComGameState_Item ItemState;
	local X2ItemTemplate ItemTemplate;
	local XComGameState_Unit UnitState;
	local XComGameState_LootDrop LootDropState;
	local Name ObjectiveLootTableName;
	local X2LootTableManager LootManager;
	local LootResults PendingAutoLoot;
	local Name LootTemplateName;
	local array<Name> RolledLoot;
	local XComGameState_XpManager XpManager, NewXpManager;
	local int MissionIndex;
	local MissionDefinition RefMission;

	History = `XCOMHISTORY;
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Cleanup Tactical Mission");
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
	NewGameState.AddStateObject(XComHQ);
	XComHQ.bReturningFromMission = true;
	XComHQ.PlayedTacticalNarrativeMomentsCurrentMapOnly.Remove(0, XComHQ.PlayedTacticalNarrativeMomentsCurrentMapOnly.Length);

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	BattleData = XComGameState_BattleData(NewGameState.CreateStateObject(class'XComGameState_BattleData', BattleData.ObjectID));
	NewGameState.AddStateObject(BattleData);

	// Sweep objective resolution:
	// if all tactical mission objectives completed, all bodies and loot are recovered
	if( BattleData.AllTacticalObjectivesCompleted() )
	{
		// recover all dead soldiers, remove all other soldiers from play/clear deathly ailments
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if( XComHQ.IsUnitInSquad(UnitState.GetReference()) )
			{
				UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
				NewGameState.AddStateObject(UnitState);
				UnitState.RemoveUnitFromPlay();
				UnitState.bBleedingOut = false;
				UnitState.bUnconscious = false;

				if( UnitState.IsDead() )
				{
					UnitState.bBodyRecovered = true;
				}
			}
		}

		foreach History.IterateByClassType(class'XComGameState_LootDrop', LootDropState)
		{
			for( LootIndex = 0; LootIndex < LootDropState.LootableItemRefs.Length; ++LootIndex )
			{
				ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', LootDropState.LootableItemRefs[LootIndex].ObjectID));
				NewGameState.AddStateObject(ItemState);

				ItemState.OwnerStateObject = XComHQ.GetReference();
				XComHQ.PutItemInInventory(NewGameState, ItemState, true);

				BattleData.CarriedOutLootBucket.AddItem(ItemState.GetMyTemplateName());
			}
		}

		// 7/29/15 Non-explicitly-picked-up loot is now once again only recovered if the sweep objective was completed
		RolledLoot = BattleData.AutoLootBucket;
	}
	else
	{
		// recover all dead aliens & advent that were evacced

		ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if( UnitState.IsAdvent() || UnitState.IsAlien() )
			{
				if ( UnitState.bBodyRecovered ) {
					class'X2LootTableManager'.static.GetLootTableManager().RollForLootCarrier(UnitState.GetMyTemplate().Loot, PendingAutoLoot);
					if( PendingAutoLoot.LootToBeCreated.Length > 0 )
					{
						`log("This body was recovered");
						foreach PendingAutoLoot.LootToBeCreated(LootTemplateName)
						{
							ItemTemplate = ItemTemplateManager.FindItemTemplate(LootTemplateName);
							RolledLoot.AddItem(ItemTemplate.DataName);
						}

					}
					PendingAutoLoot.LootToBeCreated.Remove(0, PendingAutoLoot.LootToBeCreated.Length);
					PendingAutoLoot.AvailableLoot.Remove(0, PendingAutoLoot.AvailableLoot.Length);
				}
			}
		}
	
		//RolledLoot = BattleData.AutoLootBucket;

		//It may be the case that the user lost as a result of their remaining units being mind-controlled. Consider them captured (before the mind-control effect gets wiped).
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
		{
			if (XComHQ.IsUnitInSquad(UnitState.GetReference()))
			{
				if (UnitState.IsMindControlled())
				{
					UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
					UnitState.bCaptured = true;
					NewGameState.AddStateObject(UnitState);
				}
			}
		}
	}

	//Backwards compatibility support for campaigns started when mission objectives could only have one loot table
	MissionIndex = class'XComTacticalMissionManager'.default.arrMissions.Find('MissionName', BattleData.MapData.ActiveMission.MissionName);
	if ( MissionIndex > -1)
	{
		RefMission = class'XComTacticalMissionManager'.default.arrMissions[MissionIndex];
	}
	
	// add loot for each successful Mission Objective
	LootManager = class'X2LootTableManager'.static.GetLootTableManager();
	for( ObjectiveIndex = 0; ObjectiveIndex < BattleData.MapData.ActiveMission.MissionObjectives.Length; ++ObjectiveIndex )
	{
		if( BattleData.MapData.ActiveMission.MissionObjectives[ObjectiveIndex].bCompleted )
		{
			ObjectiveLootTableName = GetObjectiveLootTable(BattleData.MapData.ActiveMission.MissionObjectives[ObjectiveIndex]);
			if (ObjectiveLootTableName == '' && RefMission.MissionObjectives[ObjectiveIndex].SuccessLootTables.Length > 0)
			{
				//Try again with the ref mission, backwards compatibility support
				ObjectiveLootTableName = GetObjectiveLootTable(RefMission.MissionObjectives[ObjectiveIndex]);
			}

			if( ObjectiveLootTableName != '' )
			{
				LootManager.RollForLootTable(ObjectiveLootTableName, RolledLoot);
			}
		}
	}

	ItemTemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	for( LootIndex = 0; LootIndex < RolledLoot.Length; ++LootIndex )
	{
		`log(String(RolledLoot[LootIndex]));
		// create the loot item
		ItemState = ItemTemplateManager.FindItemTemplate(
			RolledLoot[LootIndex]).CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(ItemState);

		// assign the XComHQ as the new owner of the item
		ItemState.OwnerStateObject = XComHQ.GetReference();

		// add the item to the HQ's inventory of loot items
		XComHQ.PutItemInInventory(NewGameState, ItemState, true);
	}

	//  Distribute XP
	if( !bSimCombat )
	{
		XpManager = XComGameState_XpManager(History.GetSingleGameStateObjectForClass(class'XComGameState_XpManager', true)); //Allow null for sim combat / cheat start
		NewXpManager = XComGameState_XpManager(NewGameState.CreateStateObject(class'XComGameState_XpManager', XpManager == none ? -1 : XpManager.ObjectID));
		NewXpManager.DistributeTacticalGameEndXp(NewGameState);
		NewGameState.AddStateObject(NewXpManager);
	}

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

