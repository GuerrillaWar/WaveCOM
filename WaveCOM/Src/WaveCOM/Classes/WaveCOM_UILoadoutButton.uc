// This is an Unreal Script

class WaveCOM_UILoadoutButton extends UIScreenListener config(WaveCOM);  
// This event is triggered after a screen is initialized. This is called after  // the visuals (if any) are loaded in Flash.
var UIButton Button1, Button2, Button3, Button4, Button5, Button6;
var UIPanel ActionsPanel;
var UITacticalHUD TacHUDScreen;
var WaveCOM_UIArmory_FieldLoadout UIArmory_FieldLoad;
var WaveCOM_UIAvengerHUD AvengerHUD;

var const config array<int> WaveCOMDeployCosts;
var int CurrentDeployCost;

event OnInit(UIScreen Screen)
{
	local Object ThisObj;

	CurrentDeployCost = 50;

	TacHUDScreen = UITacticalHUD(Screen);
	`log("Loading my button thing.");

	ActionsPanel = TacHUDScreen.Spawn(class'UIPanel', TacHUDScreen);
	ActionsPanel.InitPanel('WaveCOMActionsPanel');
	ActionsPanel.SetSize(450, 100);
	ActionsPanel.AnchorTopCenter();
	ActionsPanel.SetX(ActionsPanel.Width * -0.25);

	Button1 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button1.InitButton('LoadoutButton', "Loadout", OpenLoadout);
	Button1.SetY(ActionsPanel.Y);
	Button1.SetX(ActionsPanel.X);

	Button6 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button6.InitButton('DeploySoldier', "Deploy Soldier - " @CurrentDeployCost, OpenDeployMenu);
	Button6.SetY(ActionsPanel.Y + 30);
	Button6.SetX(ActionsPanel.X);

	Button2 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button2.InitButton('BuyButton', "Buy Equipment", OpenBuyMenu);
	Button2.SetY(ActionsPanel.Y);
	Button2.SetX(ActionsPanel.X + (ActionsPanel.Width / 2) - (Button2.Width / 2));

	Button4 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button4.InitButton('ResearchButton', "Research", OpenResearchMenu);
	Button4.SetY(ActionsPanel.Y + 30);
	Button4.SetX(ActionsPanel.X + (ActionsPanel.Width / 2) - (Button4.Width / 2));

	Button3 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button3.InitButton('Proving Grounds', "Proving Grounds", OpenProjectMenu);
	Button3.SetY(ActionsPanel.Y);
	Button3.SetX(ActionsPanel.X + ActionsPanel.Width - Button3.Width);

	Button5 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button5.InitButton('ViewInventory', "View Inventory", OpenStorage);
	Button5.SetY(ActionsPanel.Y + 30);
	Button5.SetX(ActionsPanel.X + ActionsPanel.Width - Button5.Width);

	AvengerHUD = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIAvengerHUD', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(AvengerHUD, TacHUDScreen.Movie);
	AvengerHUD.HideResources();
	UpdateDeployCost();
	UpdateResources();

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveStart', OnWaveStart, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveEnd', OnWaveEnd, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'UnitDied', OnDeath, ELD_OnStateSubmitted);
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

	Button6.SetText("Deploy Soldier - " @CurrentDeployCost);

}

private function EventListenerReturn OnDeath(Object EventData, Object EventSource, XComGameState NewGameState, Name InEventID)
{
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

public function UpdateResources()
{
	AvengerHUD.ClearResources();
	AvengerHUD.ShowResources();
	AvengerHUD.UpdateSupplies();
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

public function OpenDeployMenu(UIButton Button)
{
	local XComGameStateHistory History;
	local XComGameState_Unit StrategyUnit;
	local XComGameState_HeadquartersXCom XComHQ;
	local ArtifactCost Resources;
	local int LastStrategyStateIndex;
	local StrategyCost DeployCost;
	local array<StrategyCostScalar> EmptyScalars;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
	// grab the archived strategy state from the history and the headquarters object
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		
	if (XComHQ.GetSupplies() < CurrentDeployCost)
	{
		UpdateDeployCost();
		UpdateResources();
		return;
	}

	// try to get a unit from the strategy game
	StrategyUnit = ChooseStrategyUnit(History);

	// and add it to the board
	if (StrategyUnit != none)
	{
		AddStrategyUnitToBoard(StrategyUnit, History);

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Pay for Soldier");
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

		Resources.ItemTemplateName = 'Supplies';
		Resources.Quantity = CurrentDeployCost;
		DeployCost.ResourceCosts.AddItem(Resources);
		XComHQ.PayStrategyCost(NewGameState, DeployCost, EmptyScalars);
		NewGameState.AddStateObject(XComHQ);
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
		UpdateDeployCost();
		UpdateResources();
	}
}

// Scans the strategy game and chooses a unit to place on the game board
private static function XComGameState_Unit ChooseStrategyUnit(XComGameStateHistory History)
{
	local array<StateObjectReference> UnitsInPlay;
	local XComGameState_Unit UnitInPlay;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState StrategyState;
	local int LastStrategyStateIndex;
	local XComGameState_Unit StrategyUnit;

	LastStrategyStateIndex = History.FindStartStateIndex() - 1;
	if(LastStrategyStateIndex > 0)
	{
		// build a list of all units currently on the board, we will exclude them from consideration. Add non-xcom units as well
		// in case they are mind controlled or otherwise under the control of the enemy team
		foreach History.IterateByClassType(class'XComGameState_Unit', UnitInPlay)
		{
			UnitsInPlay.AddItem(UnitInPlay.GetReference());
		}

		// grab the archived strategy state from the history and the headquarters object
		StrategyState = History.GetGameStateFromHistory(LastStrategyStateIndex, eReturnType_Copy, false);
		foreach StrategyState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
		{
			break;
		}

		if(XComHQ == none)
		{
			`Redscreen("SeqAct_SpawnUnitFromAvenger: Could not find an XComGameState_HeadquartersXCom state in the archive!");
		}

		// and find a unit in the strategy state that is not on the board
		foreach StrategyState.IterateByClassType(class'XComGameState_Unit', StrategyUnit)
		{
			// only living soldier units please
			if (StrategyUnit.IsDead() || !StrategyUnit.IsSoldier() 	|| StrategyUnit.IsTraining())
			{
				continue;
			}

			// only if we have already recruited this soldier
			if(XComHQ != none && XComHQ.Crew.Find('ObjectID', StrategyUnit.ObjectID) == INDEX_NONE)
			{
				continue;
			}

			// only if not already on the board
			if(UnitsInPlay.Find('ObjectID', StrategyUnit.ObjectID) != INDEX_NONE)
			{
				continue;
			}

			return StrategyUnit;
		}
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
private static function XComGameState_Unit AddStrategyUnitToBoard(XComGameState_Unit Unit, XComGameStateHistory History)
{
	local X2TacticalGameRuleset Rules;
	local Vector SpawnLocation;
	local XComGameStateContext_TacticalGameRule NewGameStateContext;
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
	Unit.SetVisibilityLocationFromVector(SpawnLocation);
	Unit.bSpawnedFromAvenger = true;

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

	// add abilities
	// Must happen after items are added, to do ammo merging properly.
	Rules = `TACTICALRULES;
	Rules.InitializeUnitAbilities(NewGameState, Unit);

	// make the unit concealed, if they have Phantom
	// (special-case code, but this is how it works when starting a game normally)
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}

	// submit it
	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	Rules.SubmitGameState(NewGameState);

	return Unit;
}


defaultproperties
{
	ScreenClass = class'UITacticalHUD';
}