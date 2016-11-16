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
		// Release pawn so it can get recreated whenI the screen receives focus
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
	case 6: // BECOME PSIONIC
		PsiPromoteDialog();
		break;
	}
	`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
}


simulated function OnSelectionChanged(UIList ContainerList, int ItemIndex)
{
	local XComGameState_Unit UnitState;
	local string Description, CustomizeDesc;
	
	// Index order matches order that elements get added in 'PopulateData'
	switch(ItemIndex)
	{
	case 0: // CUSTOMIZE
		UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
		CustomizeDesc = UnitState.GetMyTemplate().strCustomizeDesc;
		Description = CustomizeDesc != "" ? CustomizeDesc : m_strCustomizeSoldierDesc;
		break;
	case 1: // LOADOUT
		Description = m_strLoadoutDesc;
		break;
	case 2: // NEUROCHIP IMPLANTS
		Description = m_strImplantsDesc;
		break;
	case 3: // WEAPON UPGRADE
		Description = m_strCustomizeWeaponDesc;
		break;
	case 4: // PROMOTE
		Description = m_strPromoteDesc;
		break;
	case 5: // DISMISS
		Description = m_strDismissDesc;
		break;
	case 6: // Become PSI
		Description = "Pay" @ class'WaveCOM_UIPsiTraining'.static.GetNewPsiCost() @ "supplies to turn this rookie into a psi operative.";
		break;
	}

	MC.ChildSetString("descriptionText", "htmlText", class'UIUtilities_Text'.static.AddFontInfo(Description, bIsIn3D));
}

function UpdateActiveUnit()
{
	UpdateUnit(UnitReference.ObjectID);
}

static function int GetBonusWeaponAmmoFromAbilities(XComGameState_Item ItemState, XComGameState StartState, XComGameState_Unit UnitState)
{
	local array<SoldierClassAbilityType> SoldierAbilities;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2AbilityTemplate AbilityTemplate;
	local X2CharacterTemplate CharacterTemplate;
	local int Bonus, Idx;

	//  Note: This function is called prior to abilities being generated for the unit, so we only inspect
	//          1) the earned soldier abilities
	//          2) the abilities on the character template

	Bonus = 0;
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	SoldierAbilities = UnitState.GetEarnedSoldierAbilities();

	for (Idx = 0; Idx < SoldierAbilities.Length; ++Idx)
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(SoldierAbilities[Idx].AbilityName);
		if (AbilityTemplate != none && AbilityTemplate.GetBonusWeaponAmmoFn != none)
			Bonus += AbilityTemplate.GetBonusWeaponAmmoFn(UnitState, ItemState);
	}

	CharacterTemplate = UnitState.GetMyTemplate();
	
	for (Idx = 0; Idx < CharacterTemplate.Abilities.Length; ++Idx)
	{
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(CharacterTemplate.Abilities[Idx]);
		if (AbilityTemplate != none && AbilityTemplate.GetBonusWeaponAmmoFn != none)
			Bonus += AbilityTemplate.GetBonusWeaponAmmoFn(UnitState, ItemState);
	}

	return Bonus;
}

static function MergeAmmoAsNeeded(XComGameState StartState, XComGameState_Unit Unit)
{
	local XComGameState_Item ItemIter, ItemInnerIter;
	local X2WeaponTemplate MergeTemplate;
	local int Idx, InnerIdx, BonusAmmo;

	for (Idx = 0; Idx < Unit.InventoryItems.Length; ++Idx)
	{
		ItemIter = XComGameState_Item(StartState.GetGameStateForObjectID(Unit.InventoryItems[Idx].ObjectID));
		if (ItemIter != none && !ItemIter.bMergedOut)
		{
			MergeTemplate = X2WeaponTemplate(ItemIter.GetMyTemplate());
			if (MergeTemplate != none && MergeTemplate.bMergeAmmo)
			{
				BonusAmmo = GetBonusWeaponAmmoFromAbilities(ItemIter, StartState, Unit);

				ItemIter.MergedItemCount = 1;
				for (InnerIdx = Idx + 1; InnerIdx < Unit.InventoryItems.Length; ++InnerIdx)
				{
					ItemInnerIter = XComGameState_Item(StartState.GetGameStateForObjectID(Unit.InventoryItems[InnerIdx].ObjectID));
					if (ItemInnerIter != none && ItemInnerIter.GetMyTemplate() == MergeTemplate)
					{
						BonusAmmo += GetBonusWeaponAmmoFromAbilities(ItemInnerIter, StartState, Unit);
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

static function UnRegisterForCosmeticUnitEvents(XComGameState_Item ItemState, StateObjectReference CosmeticUnitRef)
{
	local X2EventManager EventManager;
	local Object ThisObj;

	EventManager = `XEVENTMGR;
	ThisObj = ItemState;
	if( CosmeticUnitRef.ObjectID > 0 )
	{
		EventManager.UnRegisterFromEvent( ThisObj, 'UnitMoveFinished' );
		EventManager.UnRegisterFromEvent( ThisObj, 'AbilityActivated' );
		EventManager.UnRegisterFromEvent( ThisObj, 'UnitDied' );
		EventManager.UnRegisterFromEvent( ThisObj, 'ItemRecalled' );
		EventManager.UnRegisterFromEvent( ThisObj, 'ForceItemRecalled' );
	}
}

static function RegisterForCosmeticUnitEvents(XComGameState_Item ItemState, StateObjectReference CosmeticUnitRef)
{
	local X2EventManager EventManager;
	local Object ThisObj;

	if( CosmeticUnitRef.ObjectID > 0 )
	{	
	//Only items with cosmetic units need to listen for these. If you expand this conditional, make sure you need to as
	//having too many items respond to these events would be costly.
	EventManager = `XEVENTMGR;
	ThisObj = ItemState;	

		EventManager.RegisterForEvent( ThisObj, 'AbilityActivated', ItemState.OnAbilityActivated, ELD_OnStateSubmitted,,); //Move if we're ordered to
		EventManager.RegisterForEvent( ThisObj, 'UnitDied', ItemState.OnUnitDied, ELD_OnStateSubmitted,,); //Return to owner if target unit dies or play death anim if owner dies
		EventManager.RegisterForEvent( ThisObj, 'UnitEvacuated', ItemState.OnUnitEvacuated, ELD_OnStateSubmitted,,); //For gremlin, to evacuate with its owner
		EventManager.RegisterForEvent( ThisObj, 'ItemRecalled', ItemState.OnItemRecalled, ELD_OnStateSubmitted,,); //Return to owner when specifically requested 
		EventManager.RegisterForEvent( ThisObj, 'ForceItemRecalled', ItemState.OnForceItemRecalled, ELD_OnStateSubmitted,,); //Return to owner when specifically told
		EventManager.RegisterForEvent( ThisObj, 'UnitIcarusJumped', ItemState.OnUnitIcarusJumped, ELD_OnStateSubmitted, , ); //Return to owner when specifically told
	}
}

static function UpdateUnit(int UnitID)
{
	local XComGameState NewGameState;
	local XComGameState_Unit Unit, CosmeticUnit;
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

				if (Unit.GetMyTemplate().OnCosmeticUnitCreatedFn != None)
				{
					CosmeticUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', CosmeticUnitRef.ObjectID));
					Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitID));
					Unit.GetMyTemplate().OnCosmeticUnitCreatedFn(CosmeticUnit, Unit, ItemState, NewGameState);
					NewGameState.AddStateObject(Unit);
				}

				RegisterForCosmeticUnitEvents(ItemState, CosmeticUnitRef);

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
	if (XComGameStateContext_TacticalGameRule(NewGameState.GetContext()) != none)
		XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();

	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

static function UpdateUnitState(int UnitID, XComGameState NewGameState)
{
	local XComGameState_Unit Unit;
	local StateObjectReference AbilityReference;

	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitID));

	`log("Cleaning Abilities");
	foreach Unit.Abilities(AbilityReference)
	{
		NewGameState.RemoveStateObject(AbilityReference.ObjectID);
	}
	Unit.Abilities.Length = 0;

	CleanUpStats(NewGameState, Unit);

	MergeAmmoAsNeeded(NewGameState, Unit);

	`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);
	if (Unit.FindAbility('Phantom').ObjectID > 0)
	{
		Unit.EnterConcealmentNewGameState(NewGameState);
	}

	NewGameState.AddStateObject(Unit);
	if (XComGameStateContext_TacticalGameRule(NewGameState.GetContext()) != none)
		XComGameStateContext_TacticalGameRule(NewGameState.GetContext()).UnitRef = Unit.GetReference();
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
	if(TacHUDScreen.Movie.Stack.IsNotInStack(class'WaveCOM_UIArmory_WeaponUpgrade'))
		UIArmory_WeaponUpgrade(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UIArmory_WeaponUpgrade', TacHUDScreen))).InitArmory(UnitOrWeaponRef);
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
	local XComGameState_Item InventoryItem;
	local array<XComGameState_Item> InventoryItems;
	local XGItem ItemVisualizer;

	local XComGameState NewGameState;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("RankUp");
	UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitRef.ObjectID));

	if (GetUnit().CanRankUpSoldier())
	{
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		CleanUpStats(NewGameState, UnitState);
		UnitState.RankUpSoldier(NewGameState, XComHQ.SelectNextSoldierClass());	
		if (UnitState.GetRank() == 1)
		{
			InventoryItems = UnitState.GetAllInventoryItems(NewGameState);
			foreach InventoryItems(InventoryItem)
			{
				XComHQ.PutItemInInventory(NewGameState, InventoryItem);
				UnitState.RemoveItemFromInventory(InventoryItem, NewGameState);
				ItemVisualizer = XGItem(`XCOMHISTORY.GetVisualizer(InventoryItem.GetReference().ObjectID));
				ItemVisualizer.Destroy();
				`XCOMHISTORY.SetVisualizer(InventoryItem.GetReference().ObjectID, none);
			}
			UnitState.ApplySquaddieLoadout(NewGameState, XComHQ);
			UnitState.ApplyBestGearLoadout(NewGameState); // Make sure the squaddie has the best gear available
		}
		UnitState.ValidateLoadout(NewGameState);
	}
	NewGameState.AddStateObject(UnitState);
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

	if (UnitState.GetSoldierClassTemplateName() == 'PsiOperative')
		PromotionUI = WaveCOM_UIPsiTraining(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UIPsiTraining', TacHUDScreen)));
	else
		PromotionUI = WaveCOM_UIArmory_Promotion(TacHUDScreen.Movie.Stack.Push(TacHUDScreen.Spawn(class'WaveCOM_UIArmory_Promotion', TacHUDScreen)));
	
	PromotionUI.InitPromotion(UnitRef, bInstantTransition);
}


simulated function PsiPromoteDialog()
{
	local XGParamTag LocTag;
	local TDialogueBoxData DialogData;
	local UICallbackData_StateObjectReference CallbackData;
	local XComGameState_Unit Unit;

	Unit = GetUnit();

	LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
	LocTag.StrValue0 = Unit.GetName(eNameType_RankFull);

	CallbackData = new class'UICallbackData_StateObjectReference';
	CallbackData.ObjectRef = Unit.GetReference();
	DialogData.xUserData = CallbackData;
	DialogData.fnCallbackEx = PsiPromoteDialogCallback;

	DialogData.eType = eDialog_Alert;
	DialogData.strTitle = "BECOME PSI OPERATIVE";
	DialogData.strText = `XEXPAND.ExpandString("<XGParam:StrValue0/!UnitName/> can undergo specialized training to unlock their psionic potential and become a Psi Operative, but they will not be able earn other classes' abilities and use their specialized weapons. This will cost" @ class'WaveCOM_UIPsiTraining'.static.GetNewPsiCost() @ "Do you want to proceed?");
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNo;

	Movie.Pres.UIRaiseDialog(DialogData);
}

simulated function PsiPromoteDialogCallback(eUIAction eAction, UICallbackData xUserData)
{	
	local XComGameState NewGameState;
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameState_Unit UnitState;
	local UICallbackData_StateObjectReference CallbackData;
	local StaffUnitInfo UnitInfo;
	local ArtifactCost Resources;
	local StrategyCost DeployCost;
	local array<StrategyCostScalar> EmptyScalars;
	local XComGameState_Item InventoryItem;
	local array<XComGameState_Item> InventoryItems;
	local XGItem ItemVisualizer;

	CallbackData = UICallbackData_StateObjectReference(xUserData);

	if(eAction == eUIAction_Accept)
	{	
		UnitInfo.UnitRef = CallbackData.ObjectRef;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Turning rookie into psi operative");
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitInfo.UnitRef.ObjectID));
		
		UnitState.RankUpSoldier(NewGameState, 'PsiOperative');
		UnitState.BuySoldierProgressionAbility(NewGameState, `SYNC_RAND(2), `SYNC_RAND(2));

		if (UnitState.GetRank() == 1) // They were just promoted to Initiate
		{
			InventoryItems = UnitState.GetAllInventoryItems(NewGameState);
			foreach InventoryItems(InventoryItem)
			{
				XComHQ.PutItemInInventory(NewGameState, InventoryItem);
				UnitState.RemoveItemFromInventory(InventoryItem, NewGameState);
				ItemVisualizer = XGItem(`XCOMHISTORY.GetVisualizer(InventoryItem.GetReference().ObjectID));
				ItemVisualizer.Destroy();
				`XCOMHISTORY.SetVisualizer(InventoryItem.GetReference().ObjectID, none);
			}
			UnitState.ApplySquaddieLoadout(NewGameState, XComHQ);
			UnitState.ApplyBestGearLoadout(NewGameState); // Make sure the squaddie has the best gear available
		}

		Resources.ItemTemplateName = 'Supplies';
		Resources.Quantity = class'WaveCOM_UIPsiTraining'.static.GetNewPsiCost();
		DeployCost.ResourceCosts.AddItem(Resources);
		XComHQ.PayStrategyCost(NewGameState, DeployCost, EmptyScalars);
		NewGameState.AddStateObject(UnitState);
		NewGameState.AddStateObject(XComHQ);

		`XEVENTMGR.TriggerEvent('PsiTrainingUpdate',,, NewGameState);

		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);

		OnReceiveFocus();
	}
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

	UnitState.bUnconscious = false; // Wake up when unconcious state is removed
}

simulated function OnReceiveFocus()
{
	super(UIArmory).OnReceiveFocus();
	PopulateData();
	UpdatePromoteItem();
	Header.PopulateData();
}

simulated function PopulateData()
{
	local XComGameState_Unit Unit;
	local UIListItemString PsiButton;
	super.PopulateData();

	// Add Become Psionic Button
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	PsiButton = Spawn(class'UIListItemString', List.ItemContainer).InitListItem("Become Psionic");
	if (Unit.GetRank() >= 1 || Unit.CanRankUpSoldier()) // Only rookies can become psionic
	{
		if (Unit.IsPsionic())
			PsiButton.SetDisabled(true, "Already a psionic, use soldier abilities button to learn new abilities.");
		else
			PsiButton.SetDisabled(true, "Too late to become psionic");
	}

}

simulated function InitArmory(StateObjectReference UnitRef, optional name DispEvent, optional name SoldSpawnEvent, optional name NavBackEvent, optional name HideEvent, optional name RemoveEvent, optional bool bInstant = false, optional XComGameState InitCheckGameState)
{
	UnitReference = UnitRef;
	ResetUnitState();	
	bUseNavHelp = class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M2_WelcomeToArmory');
	super(UIArmory).InitArmory(UnitRef, DispEvent, SoldSpawnEvent, NavBackEvent, HideEvent, RemoveEvent, bInstant, InitCheckGameState);

	List = Spawn(class'UIList', self).InitList('armoryMenuList');
	List.OnItemClicked = OnItemClicked;
	List.OnSelectionChanged = OnSelectionChanged;

	PopulateData();

	CheckForCustomizationPopup();
}

static function RefillInventory(XComGameState NewGameState, XComGameState_Unit Unit)
{
	local array<name> UtilityItemTypes;
	local name ItemTemplateName;
	local StateObjectReference ItemReference, BlankReference;
	local array<XComGameState_Item> UtilityItems, GrenadeItems, MergableItems;
	local X2EquipmentTemplate EquipmentTemplate;
	local int BaseAmmo; 
	local XComGameState_Item ItemState, NewItemState, NewBaseItemState, BaseItem;
	local XComGameState_Unit CosmeticUnit;

	UtilityItems = Unit.GetAllItemsInSlot(eInvSlot_Utility);
	GrenadeItems = Unit.GetAllItemsInSlot(eInvSlot_GrenadePocket);

	`log("=====Initializing refillable items=====",, 'Refill items');

	// Combine utility slots and grenade slots
	foreach GrenadeItems(ItemState)
	{
		UtilityItems.AddItem(ItemState);
	}
	// For hunter's axe
	GrenadeItems = Unit.GetAllItemsInSlot(eInvSlot_TertiaryWeapon);
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
				UnRegisterForCosmeticUnitEvents(ItemState, ItemState.CosmeticUnitRef);
				ItemState.CosmeticUnitRef = BlankReference;
				NewGameState.AddStateObject(ItemState);
			}
		}
	}
	
	
	Unit.ValidateLoadout(NewGameState);
}

simulated function ResetUnitState()
{
	local XComGameState_Unit Unit;
	local XComGameState NewGameState;
	local object ThisObj;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Refresh unit consumables");

	Unit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitReference.ObjectID));
	NewGameState.AddStateObject(Unit);

	CleanUpStats(NewGameState, Unit);

	// Remerge Inventory
	RefillInventory(NewGameState, Unit);

	// Every new wave should act as if it's a new mission
	Unit.CleanupUnitValues(eCleanup_BeginTactical);
	
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