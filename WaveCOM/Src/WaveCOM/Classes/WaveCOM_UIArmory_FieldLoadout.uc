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
	UpdateUnit(UnitReference.ObjectID);
}

static function MergeAmmoAsNeeded(XComGameState StartState, XComGameState_Unit Unit)
{
	local XComGameState_Item ItemIter, ItemInnerIter;
	local X2WeaponTemplate MergeTemplate;
	local int Idx, InnerIdx, BonusAmmo;
	local bool bFieldMedic, bHeavyOrdnance;

	bFieldMedic = Unit.HasSoldierAbility('FieldMedic');
	bHeavyOrdnance = Unit.HasSoldierAbility('HeavyOrdnance');

	for (Idx = 0; Idx < Unit.InventoryItems.Length; ++Idx)
	{
		ItemIter = XComGameState_Item(StartState.GetGameStateForObjectID(Unit.InventoryItems[Idx].ObjectID));
		if (ItemIter != none && !ItemIter.bMergedOut)
		{
			MergeTemplate = X2WeaponTemplate(ItemIter.GetMyTemplate());
			if (MergeTemplate != none && MergeTemplate.bMergeAmmo)
			{
				BonusAmmo = 0;

				if (bFieldMedic && ItemIter.GetWeaponCategory() == class'X2Item_DefaultUtilityItems'.default.MedikitCat)
					BonusAmmo += class'X2Ability_SpecialistAbilitySet'.default.FIELD_MEDIC_BONUS;
				if (bHeavyOrdnance && ItemIter.InventorySlot == eInvSlot_GrenadePocket)
					BonusAmmo += class'X2Ability_GrenadierAbilitySet'.default.ORDNANCE_BONUS;

				ItemIter.MergedItemCount = 1;
				for (InnerIdx = Idx + 1; InnerIdx < Unit.InventoryItems.Length; ++InnerIdx)
				{
					ItemInnerIter = XComGameState_Item(StartState.GetGameStateForObjectID(Unit.InventoryItems[InnerIdx].ObjectID));
					if (ItemInnerIter != none && ItemInnerIter.GetMyTemplate() == MergeTemplate)
					{
						if (bFieldMedic && ItemInnerIter.GetWeaponCategory() == class'X2Item_DefaultUtilityItems'.default.MedikitCat)
							BonusAmmo += class'X2Ability_SpecialistAbilitySet'.default.FIELD_MEDIC_BONUS;
						if (bHeavyOrdnance && ItemInnerIter.InventorySlot == eInvSlot_GrenadePocket)
							BonusAmmo += class'X2Ability_GrenadierAbilitySet'.default.ORDNANCE_BONUS;
						ItemInnerIter.bMergedOut = true;
						ItemInnerIter.Ammo = 0;
						ItemIter.MergedItemCount++;
					}
				}
				ItemIter.Ammo = ItemIter.GetClipSize() * ItemIter.MergedItemCount + BonusAmmo;
			}
		}
	}
}

static function UpdateUnit(int UnitID)
{
	local XComGameState_Unit Unit, CosmeticUnit;
	local XComGameState NewGameState;
	local Vector SpawnLocation;
	local XGUnit Visualizer;
	local StateObjectReference ItemReference, CosmeticUnitRef;
	local StateObjectReference AbilityReference;
	local XComGameState_Item ItemState;
	local X2EquipmentTemplate EquipmentTemplate;
	local XComWorldData WorldData;
	local XComAISpawnManager SpawnManager;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Refresh Inventory");
	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitID));

	`log("Cleaning Abilities");
	foreach Unit.Abilities(AbilityReference)
	{
		NewGameState.RemoveStateObject(AbilityReference.ObjectID);
	}
	Unit.Abilities.Length = 0;

	`log("Reintroducing Inventory");
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		`log("Adding " @ItemState.GetMyTemplateName());
		NewGameState.AddStateObject(ItemState);
	}
	


	MergeAmmoAsNeeded(NewGameState, Unit);

	WorldData = `XWORLD;
	SpawnManager = `SPAWNMGR;

	Visualizer = XGUnit(Unit.FindOrCreateVisualizer());
	Unit.SyncVisualizer(NewGameState);
	Visualizer.ApplyLoadoutFromGameState(Unit, NewGameState);
	XComHumanPawn(Visualizer.GetPawn()).SetAppearance(Unit.kAppearance);

	NewGameState.AddStateObject(Unit);
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
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
				CosmeticUnitRef = SpawnManager.CreateUnit(SpawnLocation, name(EquipmentTemplate.CosmeticUnitTemplate), Unit.GetTeam(), false);

				CosmeticUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(CosmeticUnitRef.ObjectID));
				CosmeticUnit.kAppearance.nmPatterns = Unit.kAppearance.nmWeaponPattern;
				CosmeticUnit.kAppearance.iArmorTint = Unit.kAppearance.iWeaponTint;
				CosmeticUnit.kAppearance.iArmorTintSecondary = Unit.kAppearance.iArmorTintSecondary;
				XGUnit(CosmeticUnit.GetVisualizer()).GetPawn().SetAppearance(CosmeticUnit.kAppearance);

				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Attach Gremlin");
				ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
				ItemState.CosmeticUnitRef = CosmeticUnitRef;
				ItemState.OwnerStateObject = Unit.GetReference();
				ItemState.AttachedUnitRef = Unit.GetReference();
				NewGameState.AddStateObject(ItemState);
				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
			}
		}
	}
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Rinit Abilities");

	`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}

	// Remove rupture effect and unshred armor
	Unit.Ruptured = 0;
	Unit.Shredded = 0;

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
	TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UICustomize_Menu', TacHUDScreen));
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
		CleanUpStats(NewGameState, UnitState);
		UnitState.RankUpSoldier(NewGameState, XComHQ.SelectNextSoldierClass());
		UnitState.ValidateLoadout(NewGameState);
	}
	NewGameState.AddStateObject(UnitState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if (UnitState.GetSoldierClassTemplateName() == 'PsiOperative')
		PromotionUI = UIArmory_PromotionPsiOp(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_PromotionPsiOp', TacHUDScreen)));
	else
		PromotionUI = UIArmory_Promotion(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'UIArmory_Promotion', TacHUDScreen)));
	
	PromotionUI.InitPromotion(UnitRef, bInstantTransition);
}

static function CleanUpStats(XComGameState NewGameState, XComGameState_Unit UnitState)
{
	local XComGameState_Effect EffectState;

	while ( UnitState.AppliedEffectNames.Length > 0)
	{
		EffectState = XComGameState_Effect( `XCOMHISTORY.GetGameStateForObjectID( UnitState.AppliedEffects[ 0 ].ObjectID ) );
		if (EffectState != None)
		{
			EffectState.GetX2Effect().UnitEndedTacticalPlay(EffectState, UnitState);
		}
		EffectState.RemoveEffect(NewGameState, NewGameState, true); //Cleansed
	}
}

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	UnitReference = UnitRef;
	ResetUnitState();
	super.InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);
}

simulated function ResetUnitState()
{
	local XComGameState_Unit Unit, CosmeticUnit;
	local XComGameState_Item ItemState, NewItemState, NewBaseItemState, BaseItem;
	local XComGameState NewGameState;
	local array<name> UtilityItemTypes;
	local name ItemTemplateName;
	local StateObjectReference ItemReference, BlankReference;
	local array<XComGameState_Item> UtilityItems, GrenadeItems, MergableItems;
	local X2EquipmentTemplate EquipmentTemplate;
	local int BaseAmmo; 
	local object ThisObj;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Refresh unit consumables");

	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitReference.ObjectID));
	NewGameState.AddStateObject(Unit);

	CleanUpStats(NewGameState, Unit);

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
				if (class'WaveCOM_MissionLogic_WaveCOM'.default.REFILL_ITEM_CHARGES)
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
			if (NewBaseItemState.Ammo > BaseAmmo || class'WaveCOM_MissionLogic_WaveCOM'.default.REFILL_ITEM_CHARGES)
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
			if (class'WaveCOM_MissionLogic_WaveCOM'.default.REFILL_ITEM_CHARGES)
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

	//
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(`XCOMHISTORY.GetGameStateForObjectID(ItemReference.ObjectID));
		if( ItemState.OwnerStateObject.ObjectID == Unit.ObjectID )
		{
			EquipmentTemplate = X2EquipmentTemplate(ItemState.GetMyTemplate());
			if( EquipmentTemplate != none && EquipmentTemplate.CosmeticUnitTemplate != "" && ItemState.CosmeticUnitRef.ObjectID != 0)
			{
				`log("Murdering a gremlin",, 'Refill items');
				CosmeticUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', ItemState.CosmeticUnitRef.ObjectID));
				CosmeticUnit.RemoveUnitFromPlay();
				NewGameState.AddStateObject(CosmeticUnit);
				ItemState = XComGameState_Item(NewGameState.CreateStateObject(class'XComGameState_Item', ItemReference.ObjectID));
				ItemState.CosmeticUnitRef = BlankReference;
				NewGameState.AddStateObject(ItemState);
			}
		}
	}
	
	
	Unit.ValidateLoadout(NewGameState);
	
	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'HACK_OnGameStateSubmittedFieldLoadout', OnGameStateSubmitted, ELD_OnStateSubmitted);
	`XEVENTMGR.TriggerEvent('HACK_OnGameStateSubmittedFieldLoadout');
	
	XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

function EventListenerReturn OnGameStateSubmitted(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Unit UnitState;
	local object ThisObj;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));

	XComTacticalController(PC).bManuallySwitchedUnitsWhileVisualizerBusy = true;
	XComTacticalController(PC).Visualizer_SelectUnit(UnitState);

	ThisObj = self;
	`XEVENTMGR.UnRegisterFromEvent(ThisObj, 'HACK_OnGameStateSubmittedFieldLoadout');

	return ELR_NoInterrupt;
}

simulated function PrevSoldier()
{
	// Do not switch soldiers in this screen
}

simulated function NextSoldier()
{
	// Do not switch soldiers in this screen
}

defaultproperties
{
	bUseNavHelp = false;
}