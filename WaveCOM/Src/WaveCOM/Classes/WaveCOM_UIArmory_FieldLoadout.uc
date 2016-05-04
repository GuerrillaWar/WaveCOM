class WaveCOM_UIArmory_FieldLoadout extends UIArmory_MainMenu;

var UITacticalHUD TacHUDScreen;

simulated function OnAccept()
{
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersXCom XComHQ;

	if( UIListItemString(List.GetSelectedItem()).bDisabled )
	{
		`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");
		return;
	}

	XComHQ = class'UIUtilities_Strategy'.static.GetXComHQ();

	// Index order matches order that elements get added in 'PopulateData'
	switch( List.selectedIndex )
	{
	case 0: // CUSTOMIZE
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
		Push_UICustomize_Menu(UnitState, ActorPawn);
		break;
	case 1: // LOADOUT    
		Push_UIArmory_Loadout(UnitReference);
		break;
	case 2: // NEUROCHIP IMPLANTS
		if( XComHQ.HasCombatSimsInInventory() )		
			Push_UIArmory_Implants(UnitReference);
		break;
	case 3: // WEAPON UPGRADE
		// Release pawn so it can get recreated when the screen receives focus
		ReleasePawn();
		if( XComHQ.bModularWeapons )
			Push_UIArmory_WeaponUpgrade(UnitReference);
		break;
	case 4: // PROMOTE
		if( GetUnit().GetRank() >= 1 || GetUnit().CanRankUpSoldier() || GetUnit().HasAvailablePerksToAssign() )

			Push_UIArmory_Promotion(UnitReference);
		break;
	case 5: // DISMISS
		OnDismissUnit();
		break;
	}
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}

function UpdateActiveUnit()
{
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;
	local Vector SpawnLocation;
	local XComGameStateHistory History;
	local StateObjectReference ItemReference;
	local XComGameState_Item ItemState;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComWorldData WorldData;
	local XComAISpawnManager SpawnManager;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Abilities");

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	Unit.Abilities.Remove(0, Unit.Abilities.Length);

	WorldData = `XWORLD;
	SpawnManager = `SPAWNMGR;

	foreach History.IterateByClassType(class'XComGameState_Item', ItemState)
	{
		if( ItemState.OwnerStateObject.ObjectID == Unit.ObjectID )
		{
			NewGameState.RemoveStateObject(ItemState.ObjectID);
		}
	}

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

	`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}

	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	Unit.SyncVisualizer(NewGameState);
}

simulated function OnCancel()
{
	`log("Cancelling");
	super.OnCancel();
	UpdateActiveUnit();
}

function SetTacHUDScreen(UITacticalHUD Screenie)
{
	TacHUDScreen = Screenie;
}

function Push_UICustomize_Menu(XComGameState_Unit UnitRef, Actor ActorPawnA)
{
	//InitializeCustomizeManager(UnitRef);
	TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UICustomize_Menu', TacHUDScreen));
}

function Push_UIArmory_Implants(StateObjectReference UnitRef)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Event: View PCS");
	`XEVENTMGR.TriggerEvent('OnViewPCS', , , NewGameState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'UIArmory_Implants'))
		UIArmory_Implants(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_Implants', TacHUDScreen))).InitImplants(UnitRef);
}

function Push_UIArmory_WeaponUpgrade(StateObjectReference UnitOrWeaponRef)
{
	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'UIArmory_WeaponUpgrade'))
		UIArmory_WeaponUpgrade(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_WeaponUpgrade', TacHUDScreen))).InitArmory(UnitOrWeaponRef);
}

function Push_UIArmory_Loadout(StateObjectReference UnitRef)
{
	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'UIArmory_Loadout'))
		UIArmory_Loadout(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_Loadout', TacHUDScreen))).InitArmory(UnitRef);
}

function Push_UIArmory_Promotion(StateObjectReference UnitRef, optional bool bInstantTransition)
{
	local UIArmory_Promotion PromotionUI;
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersXCom XComHQ;

	local XComGameState NewGameState;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("RankUp");
	UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));

	if (GetUnit().CanRankUpSoldier())
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
		UnitState.RankUpSoldier(NewGameState, XComHQ.SelectNextSoldierClass());
	}
	NewGameState.AddStateObject(UnitState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if (UnitState.GetSoldierClassTemplateName() == 'PsiOperative')
		PromotionUI = UIArmory_PromotionPsiOp(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_PromotionPsiOp', TacHUDScreen)));
	else
		PromotionUI = UIArmory_Promotion(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_Promotion', TacHUDScreen)));
	
	PromotionUI.InitPromotion(UnitRef, bInstantTransition);
}


defaultproperties
{
	bUseNavHelp = false;
}