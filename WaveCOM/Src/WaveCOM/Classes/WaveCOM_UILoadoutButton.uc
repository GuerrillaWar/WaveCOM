// This is an Unreal Script

class WaveCOM_UILoadoutButton extends UIPanel config(WaveCOM);  
// This event is triggered after a screen is initialized. This is called after  // the visuals (if any) are loaded in Flash.
var UIButton Button1, Button2, Button3, Button4, Button5, Button6, Button7, Button8;
var UIPanel ActionsPanel;
var UITacticalHUD TacHUDScreen;
var WaveCOM_UIArmory_FieldLoadout UIArmory_FieldLoad;
var WaveCOM_UIAvengerHUD AvengerHUD;

var const config array<int> WaveCOMDeployCosts;
var int CurrentDeployCost;

simulated function InitScreen(UIScreen ScreenParent)
{
	local Object ThisObj;
	local WaveCOM_MissionLogic_WaveCOM WaveLogic;

	CurrentDeployCost = 50;

	class'X2DownloadableContentInfo_WaveCOM'.static.UpdateResearchTemplates();
	class'X2DownloadableContentInfo_WaveCOM'.static.UpdateSchematicTemplates();

	TacHUDScreen = UITacticalHUD(ScreenParent);
	`log("Loading my button thing.");

	ActionsPanel = TacHUDScreen.Spawn(class'UIPanel', TacHUDScreen);
	ActionsPanel.InitPanel('WaveCOMActionsPanel');
	ActionsPanel.SetSize(450, 100);
	ActionsPanel.AnchorTopCenter();

	Button1 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button1.InitButton('LoadoutButton', "Loadout", OpenLoadout);
	Button1.SetY(ActionsPanel.Y);
	Button1.SetX(0);
	Button1.SetWidth(170);

	Button6 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button6.InitButton('DeploySoldier', "Deploy Soldier - " @CurrentDeployCost, OpenDeployMenu);
	Button6.SetY(ActionsPanel.Y + 30);
	Button6.SetX(0);
	Button6.SetWidth(170);

	Button2 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button2.InitButton('BuyButton', "Buy Equipment", OpenBuyMenu);
	Button2.SetY(ActionsPanel.Y);
	Button2.SetX(Button1.X + Button1.Width + 30);
	Button2.SetWidth(120);

	Button4 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button4.InitButton('ResearchButton', "Research", OpenResearchMenu);
	Button4.SetY(ActionsPanel.Y + 30);
	Button4.SetX(Button1.X + Button1.Width + 30);
	Button4.SetWidth(120);

	Button3 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button3.InitButton('Proving Grounds', "Proving Grounds", OpenProjectMenu);
	Button3.SetY(ActionsPanel.Y);
	Button3.SetX(Button4.X + Button4.Width + 30);
	Button3.SetWidth(120);

	Button5 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button5.InitButton('ViewInventory', "View Inventory", OpenStorage);
	Button5.SetY(ActionsPanel.Y + 30);
	Button5.SetX(Button4.X + Button4.Width + 30);
	Button5.SetWidth(120);

	Button7 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button7.InitButton('OTS', "Training School", OpenOTSMenu);
	Button7.SetY(ActionsPanel.Y);
	Button7.SetX(Button5.X + Button5.Width + 30);
	Button7.SetWidth(120);

	Button8 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button8.InitButton('BlackMarket', "Black Market", OpenBlackMarket);
	Button8.SetY(ActionsPanel.Y + 30);
	Button8.SetX(Button5.X + Button5.Width + 30);
	Button8.SetWidth(120);

	ActionsPanel.SetWidth(Button7.X + Button7.Width - ActionsPanel.X + 50);
	ActionsPanel.SetX(ActionsPanel.Width * -0.5);
	ActionsPanel.AnchorTopCenter();

	AvengerHUD = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIAvengerHUD', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(AvengerHUD, TacHUDScreen.Movie);
	AvengerHUD.HideResources();
	UpdateDeployCost();
	UpdateResources();

	WaveLogic = WaveCOM_MissionLogic_WaveCOM(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'WaveCOM_MissionLogic_WaveCOM'));
	if (WaveLogic != none && WaveLogic.WaveStatus != eWaveStatus_Preparation)
	{
		// When we load the game, check if we are still in combat phase, if so, don't show the panel.
		AvengerHUD.HideResources();
		ActionsPanel.Hide();
	}

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveStart', OnWaveStart, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveEnd', OnWaveEnd, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UnitDied', OnDeath, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UpdateDeployCost', OnDeath, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UpdateDeployCostDelayed', OnDeath, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'ResearchCompleted', UpdateResourceHUD, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'ItemConstructionCompleted', UpdateResourceHUD, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'PsiTrainingUpdate', UpdateResourceHUD, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'BlackMarketGoodsSold', UpdateResourceHUD, ELD_OnStateSubmitted);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'BlackMarketPurchase', UpdateResourceHUD, ELD_OnStateSubmitted);
}

public function XComGameState_Unit GetNonDeployedSoldier()
{
	local XComGameState_HeadquartersXCom XComHQ;	
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
			
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	if (XComHQ != none)
	{
		foreach XComHQ.Squad(UnitRef)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState != none && UnitState.IsAlive() && (UnitState.Abilities.Length == 0 || UnitState.bRemovedFromPlay)) // Uninitialized
			{
				return UnitState;
			}
		}
	}
	return none;
}

private function UpdateDeployCost ()
{
	local XComGameState_Unit UnitState;
	local int XComCount;

	`log("Updating deploy cost");
	XComCount = 0;
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		// Don't make summoned/MC'd units not count
		//Suggestion: Add units to XCOMHQ.Squad for better tracking
		if( (UnitState.GetTeam() == eTeam_XCom) && UnitState.IsAlive() && UnitState.IsASoldier())
		{
			`log("Found Unit:" @UnitState.GetFullName());
			++XComCount;
		}
	}
	`log("Count: " @XComCount);

	
	if (XComCount > WaveCOMDeployCosts.Length - 1)
	{
		CurrentDeployCost = WaveCOMDeployCosts[WaveCOMDeployCosts.Length - 1];
	}
	else
	{
		CurrentDeployCost = WaveCOMDeployCosts[XComCount];
	}

	if (GetNonDeployedSoldier() != none)
	{
		Button6.SetText("Deploy pending soldier");
	}
	else
	{
		Button6.SetText("Deploy Soldier - " @CurrentDeployCost);
	}

}

private function EventListenerReturn OnDeath(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	UpdateResources();
	UpdateDeployCost();
	return ELR_NoInterrupt;
}

private function EventListenerReturn OnWaveStart(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	AvengerHUD.HideResources();
	ActionsPanel.Hide();
	return ELR_NoInterrupt;
}

private function EventListenerReturn OnWaveEnd(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	UpdateResources();
	ActionsPanel.Show();
	return ELR_NoInterrupt;
}

private function EventListenerReturn UpdateResourceHUD(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
	UpdateResources();
	return ELR_NoInterrupt;
}

public function UpdateResources()
{
	AvengerHUD.ClearResources();
	AvengerHUD.ShowResources();
	AvengerHUD.UpdateSupplies();
	AvengerHUD.UpdateIntel();
	AvengerHUD.UpdateEleriumCores();
}

public function OpenLoadout(UIButton Button)
{
	local StateObjectReference ActiveUnitRef;

	ActiveUnitRef = XComTacticalController(TacHUDScreen.PC).GetActiveUnitStateRef();
	UIArmory_FieldLoad = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIArmory_FieldLoadout', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(UIArmory_FieldLoad); 
	UIArmory_FieldLoad.SetTacHUDScreen(TacHUDScreen);
	UIArmory_FieldLoad.InitArmory(ActiveUnitRef);
}

public function OpenBuyMenu(UIButton Button)
{
	local UIInventory_BuildItems LoadedScreen;
	UpdateResources();
	LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'UIInventory_BuildItems', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie); 
}

public function OpenStorage(UIButton Button)
{
	local UIInventory_Storage LoadedScreen;
	UpdateResources();
	LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'UIInventory_Storage', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie); 
}

public function OpenBlackMarket(UIButton Button)
{
	local WaveCOM_UIBlackMarket LoadedScreen;
	local XComGameState NewGameState;
	local XComGameState_BlackMarket BlackMarket;
	`log("WaveCOM :: Setting Up State");
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Black Market Prices");
	BlackMarket = XComGameState_BlackMarket(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));
	BlackMarket = XComGameState_BlackMarket(NewGameState.CreateStateObject(class'XComGameState_BlackMarket', BlackMarket.ObjectID));
	NewGameState.AddStateObject(BlackMarket);
	BlackMarket.UpdateBuyPrices();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	UpdateResources();
	LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIBlackMarket', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie); 
}

public function OpenResearchMenu(UIButton Button)
{
	local UIChooseResearch LoadedScreen;
	UpdateResources();
	LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'UIChooseResearch', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie);
}

public function OpenProjectMenu(UIButton Button)
{
	local UIChooseProject LoadedScreen;
	UpdateResources();
	LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'UIChooseProject', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie);
}

public function OpenOTSMenu(UIButton Button)
{
	local WaveCOM_UIOfficerTrainingSchool LoadedScreen;
	local XComGameState_FacilityXCom FacilityState;
	local X2FacilityTemplate FacilityTemplate;
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local TDialogueBoxData  kDialogData;

	UpdateResources();

	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_FacilityXCom', FacilityState)
	{
		if (FacilityState.GetMyTemplateName() == 'OfficerTrainingSchool')
		{
			break;
		}
		else
		{
			FacilityState = none;
		}
	}

	if (FacilityState == none)
	{
		// Create new OTS Facility
		FacilityTemplate = X2FacilityTemplate(class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate('OfficerTrainingSchool'));
		if (FacilityTemplate != none)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding missing OTS");
			FacilityState = FacilityTemplate.CreateInstanceFromTemplate(NewGameState);
			NewGameState.AddStateObject(FacilityState);
			
			XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
			XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
			XComHQ.Facilities.AddItem(FacilityState.GetReference());
			NewGameState.AddStateObject(XComHQ);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			FacilityTemplate.OnFacilityBuiltFn(FacilityState.GetReference());
		}
	}
	
	if (FacilityState != none)
	{
		LoadedScreen = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIOfficerTrainingSchool', TacHUDScreen.Movie.Pres);
		LoadedScreen.FacilityRef = FacilityState.GetReference();
		TacHUDScreen.Movie.Stack.Push(LoadedScreen, TacHUDScreen.Movie);
	}
	else
	{
		kDialogData.eType = eDialog_Alert;
		kDialogData.strTitle = "Failed to spawn OTS Facility";
		kDialogData.strText = "Unable to spawn OTS facility, there may be a bug or you are using an older version.";

		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

		`PRES.UIRaiseDialog(kDialogData);
	}
}

public function OpenDeployMenu(UIButton Button)
{
	local XComGameStateHistory History;
	local XComGameState_Unit StrategyUnit;
	local XComGameState_HeadquartersXCom XComHQ;
	local ArtifactCost Resources;
	local StrategyCost DeployCost;
	local array<StrategyCostScalar> EmptyScalars;
	local XComGameState NewGameState;

	local TDialogueBoxData  kDialogData;

	History = `XCOMHISTORY;
	// grab the archived strategy state from the history and the headquarters object
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		
	StrategyUnit = GetNonDeployedSoldier();
	if (StrategyUnit != none)
	{
		StrategyUnit = AddStrategyUnitToBoard(StrategyUnit, History);
		if (StrategyUnit == none)
		{
			kDialogData.eType = eDialog_Alert;
			kDialogData.strTitle = "Failed to spawn unit";
			kDialogData.strText = "Unable to spawn the requested unit, there might be no room on the spawn zone.";

			kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

			`PRES.UIRaiseDialog(kDialogData);
		}
		UpdateDeployCost();
		return;
	}
	else if (XComHQ.GetSupplies() < CurrentDeployCost)
	{
		UpdateDeployCost();
		UpdateResources();
		
		kDialogData.eType = eDialog_Alert;
		kDialogData.strTitle = "Not enough supplies";
		kDialogData.strText = "You need" @ CurrentDeployCost @ "to deploy new soldier.";

		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

		`PRES.UIRaiseDialog(kDialogData);

		return;
	}

	// try to get a unit from the strategy game
	StrategyUnit = ChooseStrategyUnit(History);

	// Avenger runs out of unit???
	if (StrategyUnit == none)
	{
		// Create New Rookie
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Generate new soldier");
		StrategyUnit = `CHARACTERPOOLMGR.CreateCharacter(NewGameState, `XPROFILESETTINGS.Data.m_eCharPoolUsage);
		NewGameState.AddStateObject(StrategyUnit);
		StrategyUnit.ApplyBestGearLoadout(NewGameState);

		XComHQ.AddToCrew(NewGameState, StrategyUnit);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}

	// and add it to the board
	if (StrategyUnit != none)
	{
		StrategyUnit = AddStrategyUnitToBoard(StrategyUnit, History);

		if (StrategyUnit != none)
		{
			NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Pay for Soldier");
			XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

			Resources.ItemTemplateName = 'Supplies';
			Resources.Quantity = CurrentDeployCost;
			DeployCost.ResourceCosts.AddItem(Resources);
			XComHQ.PayStrategyCost(NewGameState, DeployCost, EmptyScalars);
			XComHQ.Squad.AddItem(StrategyUnit.GetReference());
			NewGameState.AddStateObject(XComHQ);
			`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			UpdateDeployCost();
			UpdateResources();
		}
		else
		{
			kDialogData.eType = eDialog_Alert;
			kDialogData.strTitle = "Failed to spawn unit";
			kDialogData.strText = "Unable to spawn the requested unit, there might be no room on the spawn zone.";

			kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

			`PRES.UIRaiseDialog(kDialogData);
		}
	}
	else
	{
		kDialogData.eType = eDialog_Alert;
		kDialogData.strTitle = "No more reserves";
		kDialogData.strText = "No more reserves in avenger.\nTODO: Refill avenger reserves (Crew count:" @ XComHQ.Crew.Length @ ", Squad count:" @ XComHQ.Squad.Length @ ")";

		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;

		`PRES.UIRaiseDialog(kDialogData);
	}
}

// Scans the strategy game and chooses a unit to place on the game board
private static function XComGameState_Unit ChooseStrategyUnit(XComGameStateHistory History)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local StateObjectReference HQCrew;
	local XComGameState_Unit StrategyUnit;

	foreach History.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		break;
	}

	if(XComHQ == none)
	{
		`Redscreen("SeqAct_SpawnUnitFromAvenger: Could not find an XComGameState_HeadquartersXCom state in the archive!");
	}

	// and find a unit in the strategy state that is not on the board
	foreach XComHQ.Crew(HQCrew)
	{
		StrategyUnit = XComGameState_Unit(History.GetGameStateForObjectID(HQCrew.ObjectID));

		if (StrategyUnit == none)
		{	
			`log("UnitState not found in avenger",, 'WaveCOM');
			continue;
		}
		// only living soldier units please
		if (StrategyUnit.IsDead() || !StrategyUnit.IsSoldier() || StrategyUnit.IsTraining() || StrategyUnit.Abilities.Length > 0)
		{
			continue;
		}

		// only if not already on the board
		if(XComHQ.Squad.Find('ObjectID', StrategyUnit.ObjectID) != INDEX_NONE || StrategyUnit.bRemovedFromPlay)
		{
			`log("UnitState already part of squad",, 'WaveCOM');
			continue;
		}

		return StrategyUnit;
	}

	return none;
}

// chooses a location for the unit to spawn in the spawn zone
private static function bool ChooseSpawnLocation(out Vector SpawnLocation)
{
	local XComParcelManager ParcelManager;
	local XComGroupSpawn SoldierSpawn;
	local array<Vector> FloorPoints;

	// attempt to find a place in the spawn zone for this unit to spawn in
	ParcelManager = `PARCELMGR;
	SoldierSpawn = ParcelManager.SoldierSpawn;

	if(SoldierSpawn == none) // check for test maps, just grab any spawn
	{
		foreach `XComGRI.AllActors(class'XComGroupSpawn', SoldierSpawn)
		{
			break;
		}
	}

	SoldierSpawn.GetValidFloorLocations(FloorPoints);
	if(FloorPoints.Length == 0)
	{
		return false;
	}
	else
	{
		SpawnLocation = FloorPoints[0];
		return true;
	}
}

// Places the given strategy unit on the game board
static function XComGameState_Unit AddStrategyUnitToBoard(XComGameState_Unit Unit, XComGameStateHistory History)
{
	local X2TacticalGameRuleset Rules;
	local Vector SpawnLocation;
	local XComGameStateContext_TacticalGameRule NewGameStateContext, CheatContext;
	local XComGameState NewGameState;
	local XComGameState_Player PlayerState;
	local StateObjectReference ItemReference;
	local XComGameState_Item ItemState;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComWorldData WorldData;
	local XComAISpawnManager SpawnManager;

	if(Unit == none)
	{
		return none;
	}

	// pick a floor point at random to spawn the unit at
	if(!ChooseSpawnLocation(SpawnLocation))
	{
		return none;
	}

	// create the history frame with the new tactical unit state
	NewGameStateContext = class'XComGameStateContext_TacticalGameRule'.static.BuildContextFromGameRule(eGameRule_UnitAdded);
	NewGameState = History.CreateNewGameState(true, NewGameStateContext);
	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Unit.ObjectID));
	Unit.bSpawnedFromAvenger = true;
	Unit.ClearRemovedFromPlayFlag();
	Unit.SetVisibilityLocationFromVector(SpawnLocation);

	// assign the new unit to the human team
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if(PlayerState.GetTeam() == eTeam_XCom)
		{
			Unit.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}

	WorldData = `XWORLD;
	SpawnManager = `SPAWNMGR;

	// add item states. This needs to be done so that the visualizer sync picks up the IDs and
	// creates their visualizers
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		NewGameState.AddStateObject(ItemState);

		// add the gremlin to Specialists
		if( ItemState.OwnerStateObject.ObjectID == Unit.ObjectID )
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
			if( EquipmentTemplate != none && EquipmentTemplate.CosmeticUnitTemplate != "" )
			{
				SpawnLocation = WorldData.GetPositionFromTileCoordinates(Unit.TileLocation);
				ItemState.CosmeticUnitRef = SpawnManager.CreateUnit(SpawnLocation, name(EquipmentTemplate.CosmeticUnitTemplate), Unit.GetTeam(), true);
			}
		}
	}

	Rules = `TACTICALRULES;

	// submit it
	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	Rules.SubmitGameState(NewGameState);

	// Do Proper teleport to update visualization
	CheatContext = XComGameStateContext_TacticalGameRule(class'XComGameStateContext_TacticalGameRule'.static.CreateXComGameStateContext());
	CheatContext.GameRuleType = eGameRule_ReplaySync;
	NewGameState = History.CreateNewGameState(true, CheatContext);
	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', Unit.ObjectID));
	Unit.SetVisibilityLocationFromVector(SpawnLocation);
	
	// add abilities
	// Must happen after items are added, to do ammo merging properly.
	Rules.InitializeUnitAbilities(NewGameState, Unit);

	// make the unit concealed, if they have Phantom
	// (special-case code, but this is how it works when starting a game normally)
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}
	NewGameState.AddStateObject(Unit);

	`TACTICALRULES.SubmitGameState(NewGameState);

	return Unit;
}