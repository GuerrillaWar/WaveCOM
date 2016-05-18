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
	local name EffectName;
	local XComGameState_Effect EffectState;
	local Vector SpawnLocation;
	local XGUnit Visualizer;
	local XComGameStateHistory History;
	local StateObjectReference ItemReference, AbilityReference;
	local XComGameState_Item ItemState;
	local XComGameState_Ability AbilityState;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComWorldData WorldData;
	local XComAISpawnManager SpawnManager;
	local int ix;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Update Abilities");

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	WorldData = `XWORLD;
	SpawnManager = `SPAWNMGR;

	`log("Cleaning and readding Abilities");
	foreach Unit.Abilities(AbilityReference)
	{
		NewGameState.RemoveStateObject(AbilityReference.ObjectID);
	}
	Unit.Abilities.Remove(0, Unit.Abilities.Length);

	for (ix = 0; ix < Unit.AppliedEffectNames.Length; ++ix)
	{
		EffectName = Unit.AppliedEffectNames[ix];
		EffectState = XComGameState_Effect( `XCOMHISTORY.GetGameStateForObjectID( Unit.AppliedEffects[ ix ].ObjectID ) );
		if (EffectState != None)
		{
			EffectState.GetX2Effect().UnitEndedTacticalPlay(EffectState, Unit);
		}
		EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
	}

	`log("Reintroducing Inventory");
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		`log("Adding " @ItemState.GetMyTemplateName());
		NewGameState.AddStateObject(ItemState);
	}

	Visualizer = XGUnit(Unit.FindOrCreateVisualizer());
	Unit.SyncVisualizer(NewGameState);
	Visualizer.ApplyLoadoutFromGameState(Unit, NewGameState);
	XComHumanPawn(Visualizer.GetPawn()).SetAppearance(Unit.kAppearance);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.GetGameStateForObjectID(ItemReference.ObjectID));
		if( ItemState.OwnerStateObject.ObjectID == Unit.ObjectID )
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
			if( EquipmentTemplate != none && EquipmentTemplate.CosmeticUnitTemplate != "" && ItemState.CosmeticUnitRef.ObjectID == 0)
			{
				SpawnLocation = WorldData.GetPositionFromTileCoordinates(Unit.TileLocation);
				ItemState.CosmeticUnitRef = SpawnManager.CreateUnit(SpawnLocation, name(EquipmentTemplate.CosmeticUnitTemplate), Unit.GetTeam(), true);
			}
		}
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Reinit Abilities");
	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitReference.ObjectID));

	`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}

	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

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
	TacHUDScreen.Movie.Pres.InitializeCustomizeManager(UnitRef);
	TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UICustomize_Menu', TacHUDScreen));
}

function Push_UIArmory_Implants(StateObjectReference UnitRef)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Trigger Event: View PCS");
	`XEVENTMGR.TriggerEvent('OnViewPCS', , , NewGameState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'WaveCOM_UIInventory_PCS'))
		TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UIInventory_PCS', TacHUDScreen));
}

function Push_UIArmory_WeaponUpgrade(StateObjectReference UnitOrWeaponRef)
{
	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'UIArmory_WeaponUpgrade'))
		UIArmory_WeaponUpgrade(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_WeaponUpgrade', TacHUDScreen))).InitArmory(UnitOrWeaponRef);
}

function Push_UIArmory_Loadout(StateObjectReference UnitRef)
{
	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'WaveCOM_UIArmory_Loadout'))
		UIArmory_Loadout(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UIArmory_Loadout', TacHUDScreen))).InitArmory(UnitRef);
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


simulated function PopulateData()
{
	local XComGameState_Unit Unit;
	local XComGameState_Item ItemState, NewItemState, NewBaseItemState, BaseItem;
	local XComGameState NewGameState;
	local XComGameStateHistory History;
	local array<name> UtilityItemTypes;
	local name ItemTemplateName;
	local array<XComGameState_Item> UtilityItems, GrenadeItems, MergableItems;
	local int BaseAmmo; 

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Refresh unit consumables");

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	NewGameState.AddStateObject(Unit);

	UtilityItems = Unit.GetAllItemsInSlot(eInvSlot_Utility);
	GrenadeItems = Unit.GetAllItemsInSlot(eInvSlot_GrenadePocket);

	`log("=====Initializing refillable items=====",, 'Refill items');

	// Combine utility slots and grenade slots
	foreach GrenadeItems(ItemState)
	{
		UtilityItems.AddItem(ItemState);
	}

	// Acquring unique items
	foreach UtilityItems(ItemState)
	{
		if (UtilityItemTypes.Find(ItemState.GetMyTemplateName()) == INDEX_NONE)
		{
			UtilityItemTypes.AddItem(ItemState.GetMyTemplateName());
			`log("Item in inventory:" @ ItemState.GetMyTemplateName(),, 'Refill items');
		}
	}

	// Unmerge items
	foreach UtilityItemTypes(ItemTemplateName)
	{
		MergableItems.Length = 0;
		BaseItem = none;
		BaseAmmo = 0;
		foreach UtilityItems(ItemState)
		{
			if (ItemState.GetMyTemplateName() == ItemTemplateName)
			{
				MergableItems.AddItem(ItemState);
				if (!ItemState.bMergedOut && BaseItem == none)
				{
					`log("Base item found:" @ ItemTemplateName,, 'Refill items');
					BaseItem = ItemState;
					if (X2WeaponTemplate(ItemState.GetMyTemplate()) != none)
					{
						BaseAmmo = X2WeaponTemplate(ItemState.GetMyTemplate()).iClipSize;
						`log(ItemTemplateName @ "ammo is" @ BaseAmmo,, 'Refill items');
					}
				}
			}
		}

		if (BaseAmmo > 0 && BaseItem != none)
		{
			MergableItems.RemoveItem(BaseItem);
			NewBaseItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', BaseItem.ObjectID));
			NewGameState.AddStateObject(NewBaseItemState);
			`log("Beginning separating item for base item" @ ItemTemplateName @ "with ammo" @ BaseItem.Ammo,, 'Refill items');
			foreach MergableItems(ItemState)
			{
				if (class'WaveCOMTacticalGameRuleset'.default.REFILL_ITEM_CHARGES)
				{
						NewItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemState.ObjectID));
						NewGameState.AddStateObject(NewItemState);
						NewItemState.Ammo = BaseAmmo;
						NewItemState.bMergedOut = false;
						`log("Refilled" @ ItemState.GetReference().ObjectID @ "to" @ BaseAmmo,, 'Refill items');
				}
				else
				{
					if (NewBaseItemState.Ammo > BaseAmmo - ItemState.Ammo)
					{
						NewItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemState.ObjectID));
						NewGameState.AddStateObject(NewItemState);
						NewBaseItemState.Ammo -= BaseAmmo - NewItemState.Ammo;
						NewItemState.Ammo = BaseAmmo;
						NewItemState.bMergedOut = false;
						`log("Refilled" @ ItemState.GetReference().ObjectID @ "to" @ BaseAmmo $", base item ammo remaining:" @ BaseItem.Ammo,, 'Refill items');
					}
					else if (ItemState.Ammo == 0)
					{
						// Item charge exhausted, remove item
						Unit.RemoveItemFromInventory(ItemState, NewGameState);
						`log(ItemState.GetReference().ObjectID @ "exhausted",, 'Refill items');
					}
				}
			}
			if (NewBaseItemState.Ammo > BaseAmmo || class'WaveCOMTacticalGameRuleset'.default.REFILL_ITEM_CHARGES)
			{
				// Remove bonus ammo, they will be reinitialized
				NewBaseItemState.Ammo = BaseAmmo;
				`log("Base ammo replenished to max",, 'Refill items');
			}
			else if (NewBaseItemState.Ammo == 0)
			{
				Unit.RemoveItemFromInventory(NewBaseItemState, NewGameState);
				`log(NewBaseItemState.GetReference().ObjectID @ "exhausted",, 'Refill items');
			}
			NewBaseItemState.MergedItemCount = 1;
		}
	}

	// Also refresh heavy weapons
	ItemState = Unit.GetItemInSlot(eInvSlot_HeavyWeapon);

	if (ItemState != none)
	{
		// It's indeed a heavy weapon with ammo
		if (X2WeaponTemplate(ItemState.GetMyTemplate()) != none)
		{			
			if (class'WaveCOMTacticalGameRuleset'.default.REFILL_ITEM_CHARGES)
			{
				// Remove bonus ammo, they will be reinitialized
				NewItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemState.ObjectID));
				NewGameState.AddStateObject(NewItemState);
				NewItemState.Ammo = X2WeaponTemplate(ItemState.GetMyTemplate()).iClipSize;
				`log("Base ammo replenished to max",, 'Refill items');
			}
			else if (NewItemState.Ammo == 0)
			{
				Unit.RemoveItemFromInventory(ItemState, NewGameState);
				`log(NewBaseItemState.GetReference().ObjectID @ "exhausted",, 'Refill items');
			}
		}
	}
	
	Unit.ValidateLoadout(NewGameState);

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	super.PopulateData();
}


defaultproperties
{
	bUseNavHelp = false;
}