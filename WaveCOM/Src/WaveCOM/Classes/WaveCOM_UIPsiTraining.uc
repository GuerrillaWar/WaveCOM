class WaveCOM_UIPsiTraining extends UIArmory_Promotion config(WaveCOM);

var config array<int> InitialPsiCost;

var config array<int> PsiAbilityCost;
var config array<int> PsiAbilityRankCostIncrease;
var config int PsiAbilityCostIncreasePerTotalAbility;

static function int GetNewPsiCost()
{
	local XComGameState_HeadquartersXCom XComHQ;	
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local int NumPsi;
			
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	if (XComHQ != none)
	{
		foreach XComHQ.Squad(UnitRef)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState != none && UnitState.IsAlive() && UnitState.IsPsionic())
			{
				NumPsi++;
			}
		}
	}

	NumPsi = min(NumPsi, default.InitialPsiCost.Length - 1);
	return default.InitialPsiCost[NumPsi];
}

simulated function PopulateData()
{
	local int i, maxRank;
	local string AbilityIcon1, AbilityIcon2, AbilityName1, AbilityName2, HeaderString;
	local bool bHasAbility1, bHasAbility2;
	local XComGameState_Unit Unit;
	local X2SoldierClassTemplate ClassTemplate;
	local X2AbilityTemplate AbilityTemplate1, AbilityTemplate2;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<SoldierClassAbilityType> AbilityTree;
	local UIArmory_PromotionItem Item;

	local bool GotAllAbilities, bHasShownSoulfire;

	// We don't need to clear the list, or recreate the pawn here -sbatista
	//super.PopulateData();
	Unit = GetUnit();
	ClassTemplate = Unit.GetSoldierClassTemplate();
	AbilityTree = Unit.GetEarnedSoldierAbilities();

	HeaderString = m_strAbilityHeader;

	AS_SetTitle(ClassTemplate.IconImage, HeaderString, ClassTemplate.LeftAbilityTreeTitle, ClassTemplate.RightAbilityTreeTitle, Caps(ClassTemplate.DisplayName));
	
	maxRank = class'X2ExperienceConfig'.static.GetMaxRank();
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	if (ClassRowItem == none)
	{
		ClassRowItem = Spawn(class'UIArmory_PromotionItem', self);
		ClassRowItem.MCName = 'classRow';
		ClassRowItem.InitPromotionItem(0);
		ClassRowItem.OnMouseEventDelegate = OnClassRowMouseEvent;

		if (Unit.GetRank() == 1)
			ClassRowItem.OnReceiveFocus();
	}

	ClassRowItem.ClassName = ClassTemplate.DataName;
	ClassRowItem.SetRankData(class'UIUtilities_Image'.static.GetRankIcon(1, ClassTemplate.DataName), Caps(class'X2ExperienceConfig'.static.GetRankName(1, ClassTemplate.DataName)));
		
	AbilityTree = ClassTemplate.GetAbilityTree(0);
	AbilityTemplate1 = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[0].AbilityName);
	AbilityTemplate2 = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[1].AbilityName);

	bHasAbility1 = Unit.HasSoldierAbility(AbilityTemplate1.DataName);
	bHasAbility2 = Unit.HasSoldierAbility(AbilityTemplate2.DataName);
	GotAllAbilities = bHasAbility1 && bHasAbility2;
	if (bHasAbility1 && AbilityTemplate1 != none)
	{
		bHasShownSoulfire = true; // You already have soulfire, hide it from the menu so you can still learn it.
		ClassRowItem.AbilityName2 = AbilityTemplate2.DataName;
		AbilityName2 = Caps(AbilityTemplate2.LocFriendlyName);
		AbilityIcon2 = AbilityTemplate2.IconImage;
	}
	else if(bHasAbility2 && AbilityTemplate2 != none && !bHasShownSoulfire)
	{
		bHasShownSoulfire = true;
		AbilityTemplate2 = AbilityTemplateManager.FindAbilityTemplate('Soulfire');
		ClassRowItem.AbilityName2 = AbilityTemplate2.DataName;
		AbilityName2 = Caps(AbilityTemplate2.LocFriendlyName);
		AbilityIcon2 = AbilityTemplate2.IconImage;
	}
	else
	{
		ClassRowItem.AbilityName2 = AbilityTemplate2.DataName;
		AbilityName2 = Caps(AbilityTemplate2.LocFriendlyName);
		AbilityIcon2 = AbilityTemplate2.IconImage;
	}

	ClassRowItem.SetEquippedAbilities(true, true);
	ClassRowItem.SetAbilityData("", "", AbilityIcon2, AbilityName2);
	ClassRowItem.SetClassData(ClassTemplate.IconImage, Caps(ClassTemplate.DisplayName));
	ClassRowItem.SetPromote(!GotAllAbilities, !bHasAbility1, !bHasAbility2);

	for (i = 2; i < maxRank; ++i)
	{
		Item = UIArmory_PromotionItem(List.GetItem(i - 2));
		if (Item == none)
			Item = UIArmory_PromotionItem(List.CreateItem(class'UIArmory_PromotionItem')).InitPromotionItem(i - 1);

		Item.Rank = i - 1;
		Item.ClassName = ClassTemplate.DataName;
		Item.SetRankData(class'UIUtilities_Image'.static.GetRankIcon(i, ClassTemplate.DataName), Caps(class'X2ExperienceConfig'.static.GetRankName(i, ClassTemplate.DataName)));

		AbilityTree = ClassTemplate.GetAbilityTree(Item.Rank);
		AbilityTemplate1 = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[0].AbilityName);
		AbilityTemplate2 = AbilityTemplateManager.FindAbilityTemplate(AbilityTree[1].AbilityName);

		bHasAbility1 = Unit.HasSoldierAbility(AbilityTemplate1.DataName);
		bHasAbility2 = Unit.HasSoldierAbility(AbilityTemplate2.DataName);

		if (bHasAbility1 && !bHasShownSoulfire) // Replace the first skill we see with soulfire
		{
			AbilityTemplate1 = AbilityTemplateManager.FindAbilityTemplate('Soulfire');
			bHasShownSoulfire = true;
		}
		else if (bHasAbility2 && !bHasShownSoulfire)
		{
			AbilityTemplate2 = AbilityTemplateManager.FindAbilityTemplate('Soulfire');
			bHasShownSoulfire = true;
		}

		if (AbilityTemplate1 != none)
		{
			Item.AbilityName1 = AbilityTemplate1.DataName;
			AbilityName1 = Caps(AbilityTemplate1.LocFriendlyName);
			AbilityIcon1 = AbilityTemplate1.IconImage;
		}

		if (AbilityTemplate2 != none)
		{
			Item.AbilityName2 = AbilityTemplate2.DataName;
			AbilityName2 = Caps(AbilityTemplate2.LocFriendlyName);
			AbilityIcon2 = AbilityTemplate2.IconImage;
		}

		Item.SetAbilityData(AbilityIcon1, AbilityName1, AbilityIcon2, AbilityName2);
		Item.SetEquippedAbilities(bHasAbility1, bHasAbility2);

		Item.SetPromote(false);
		Item.SetDisabled(false);

		if (!bHasAbility1 || !bHasAbility2)
		{
			Item.SetPromote(true, !bHasAbility1, !bHasAbility2);
			GotAllAbilities = false;
		}

		Item.RealizeVisuals();
	}

	if (!GotAllAbilities)
	{
		HeaderString = "SELECT ABILITY:";
	}

	class'UIUtilities_Strategy'.static.PopulateAbilitySummary(self, Unit);
	List.SetSelectedIndex(-1);
	PreviewRow(List, -1);
	Navigator.SetSelected(ClassRowItem);
}

simulated function PreviewRow(UIList ContainerList, int ItemIndex)
{
	local int i, Rank, TempRank, RealRank;
	local string TmpStr;
	local X2AbilityTemplate AbilityTemplate;
	local array<SoldierClassAbilityType> AbilityTree;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local X2SoldierClassTemplate ClassTemplate;
	local XComGameState_Unit Unit;
	local SoldierClassAbilityType RankAbility;

	Unit = GetUnit();

	if (ItemIndex == INDEX_NONE)
		Rank = 0;
	else
		Rank = UIArmory_PromotionItem(List.GetItem(ItemIndex)).Rank;

	MC.BeginFunctionOp("setAbilityPreview");

	ClassTemplate = Unit.GetSoldierClassTemplate();
	AbilityTree = ClassTemplate.GetAbilityTree(Rank);
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	
	for (i = 0; i < NUM_ABILITIES_PER_RANK; ++i)
	{
		// Left icon is the class icon for the first item, show class icon plus class desc.
		if (i == 0 && Rank == 0)
		{
			MC.QueueString(ClassTemplate.IconImage); // icon
			MC.QueueString(Caps(ClassTemplate.DisplayName)); // name
			MC.QueueString(ClassTemplate.ClassSummary); // description
			MC.QueueBoolean(true); // isClassIcon
		}
		else
		{
			// Right icon is the first ability the Psi Op learned on the first row item
			if (i == 1 && Rank == 0)
			{
				AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(ClassRowItem.AbilityName2);
			}
			else if (i == 0)
			{
				AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(UIArmory_PromotionItem(List.GetItem(ItemIndex)).AbilityName1);
			}
			else
				AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(UIArmory_PromotionItem(List.GetItem(ItemIndex)).AbilityName2);
			
			if (AbilityTemplate != none)
			{
				MC.QueueString(AbilityTemplate.IconImage); // icon

				TmpStr = AbilityTemplate.LocFriendlyName != "" ? AbilityTemplate.LocFriendlyName : ("Missing 'LocFriendlyName' for " $ AbilityTemplate.DataName);
				MC.QueueString(Caps(TmpStr)); // name

				TmpStr = AbilityTemplate.HasLongDescription() ? AbilityTemplate.GetMyLongDescription(, Unit) : ("Missing 'LocLongDescription' for " $ AbilityTemplate.DataName);
				if (!GetUnit().HasSoldierAbility(AbilityTemplate.DataName))
				{
					for (TempRank = 0; TempRank < ClassTemplate.GetMaxConfiguredRank(); TempRank++)
					{
						AbilityTree = ClassTemplate.GetAbilityTree(TempRank);
						foreach AbilityTree(RankAbility)
						{
							if (RankAbility.AbilityName == AbilityTemplate.DataName)
							{
								RealRank = TempRank;
							}
						}
					}
					TmpStr = "Learn cost:" @ GetAbilityPrice(RealRank) $ "\n" $ TmpStr;
				}
				MC.QueueString(TmpStr); // description
				MC.QueueBoolean(false); // isClassIcon
			}
			else
			{
				MC.QueueString(""); // icon
				MC.QueueString(string(AbilityTree[i].AbilityName)); // name
				MC.QueueString("Missing template for ability '" $ AbilityTree[i].AbilityName $ "'"); // description
				MC.QueueBoolean(false); // isClassIcon
			}
		}
	}

	MC.EndOp();
	
	if (Rank == 0)
	{
		ClassRowItem.SetSelectedAbility(1);
	}
	else
	{
		UIArmory_PromotionItem(List.GetItem(ItemIndex)).SetSelectedAbility(SelectedAbilityIndex);
	}
}


simulated function ConfirmAbilitySelection(int Rank, int Branch)
{
	local XGParamTag LocTag;
	local TDialogueBoxData DialogData;
	local X2SoldierClassTemplate ClassTemplate;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityTemplateManager AbilityTemplateManager;
	local array<SoldierClassAbilityType> AbilityTree;
	local SoldierClassAbilityType Ranks;
	local int RealRank, SupplyCost;
	local XComGameState_HeadquartersXCom XComHQ;
	local UIArmory_PromotionItem ItemSelected;

	Movie.Pres.PlayUISound(eSUISound_MenuSelect);

	DialogData.eType = eDialog_Alert;
	DialogData.bMuteAcceptSound = true;
	DialogData.strTitle = m_strConfirmAbilityTitle;
	DialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericYes;
	DialogData.strCancel = class'UIUtilities_Text'.default.m_strGenericNO;
	DialogData.fnCallback = ComfirmAbilityCallback;
	
	ClassTemplate = GetUnit().GetSoldierClassTemplate();
	AbilityTemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	if (Rank > 0)
		ItemSelected = UIArmory_PromotionItem(List.GetItem(Rank - 1));
	else
		ItemSelected = ClassRowItem;
	if (Branch == 0 && Rank > 0)
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(ItemSelected.AbilityName1);
	else
		AbilityTemplate = AbilityTemplateManager.FindAbilityTemplate(ItemSelected.AbilityName2);

	if (GetUnit().HasSoldierAbility(AbilityTemplate.DataName))
		return; // Already learned

	PendingRank = -1;
	PendingBranch = -1;

	if (AbilityTemplate != none)
	{
		for (RealRank = 0; RealRank < ClassTemplate.GetMaxConfiguredRank(); RealRank++)
		{
			AbilityTree = ClassTemplate.GetAbilityTree(RealRank);
			foreach AbilityTree(Ranks)
			{
				if (Ranks.AbilityName == AbilityTemplate.DataName)
				{
					PendingRank = RealRank;
					PendingBranch = AbilityTree.Find('AbilityName', AbilityTemplate.DataName);
				}
			}
		}

		// Check ability price
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		SupplyCost = GetAbilityPrice(PendingRank);
		if (XComHQ != none && XComHQ.GetSupplies() < SupplyCost)
		{
			DialogData.strCancel = "";
			DialogData.fnCallback = "";
			DialogData.strText = "Not enough supplies to learn this ability (Need" @ SupplyCost $ ")";
		}
		else
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = AbilityTemplate.LocFriendlyName;
			DialogData.strText = `XEXPAND.ExpandString(m_strConfirmAbilityText) @ "\n This will cost you" @ SupplyCost @ "supplies.";
		}
		Movie.Pres.UIRaiseDialog(DialogData);
	}
}

simulated function int GetAbilityPrice(int Rank)
{
	local int self_ability_count, other_ability_count;
	local XComGameState_HeadquartersXCom XComHQ;	
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
			
	XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	if (XComHQ != none)
	{
		foreach XComHQ.Squad(UnitRef)
		{
			UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
			if (UnitState != none && UnitState.IsAlive() && UnitState.IsPsionic()) // Unit is on board
			{
				other_ability_count += UnitState.m_SoldierProgressionAbilties.Length;
			}
		}
	}
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitReference.ObjectID));
	
	self_ability_count = UnitState.m_SoldierProgressionAbilties.Length;

	return PsiAbilityCost[min(self_ability_count, PsiAbilityCost.Length - 1)] + (other_ability_count * PsiAbilityCostIncreasePerTotalAbility) + PsiAbilityRankCostIncrease[min(Rank, PsiAbilityRankCostIncrease.Length - 1)];
}

simulated function ComfirmAbilityCallback(EUIAction Action)
{
	local XComGameStateHistory History;
	local bool bSuccess;
	local XComGameState UpdateState;
	local XComGameState_Unit UpdatedUnit;
	local XComGameStateContext_ChangeContainer ChangeContainer;
	local XComGameState_HeadquartersXCom XComHQ;
	local ArtifactCost Resources;
	local StrategyCost DeployCost;
	local array<StrategyCostScalar> EmptyScalars;

	if(Action == eUIAction_Accept)
	{
		History = `XCOMHISTORY;
		ChangeContainer = class'XComGameStateContext_ChangeContainer'.static.CreateEmptyChangeContainer("Soldier Promotion");
		UpdateState = History.CreateNewGameState(true, ChangeContainer);
		
		XComHQ = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
		UpdatedUnit = XComGameState_Unit(UpdateState.CreateStateObject(class'XComGameState_Unit', GetUnit().ObjectID));
		XComHQ = XComGameState_HeadquartersXCom(UpdateState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));
		bSuccess = UpdatedUnit.BuySoldierProgressionAbility(UpdateState, PendingRank, PendingBranch);

		if(bSuccess)
		{
			UpdatedUnit.RankUpSoldier(UpdateState, 'PsiOperative');
			UpdateState.AddStateObject(UpdatedUnit);
			Resources.ItemTemplateName = 'Supplies';
			Resources.Quantity = GetAbilityPrice(PendingRank);
			DeployCost.ResourceCosts.AddItem(Resources);
			XComHQ.PayStrategyCost(UpdateState, DeployCost, EmptyScalars);
			UpdateState.AddStateObject(XComHQ);
			`XEVENTMGR.TriggerEvent('PsiTrainingUpdate',,, UpdateState);

			`GAMERULES.SubmitGameState(UpdateState);

			Header.PopulateData();
			PopulateData();
		}
		else
			History.CleanupPendingGameState(UpdateState);

		Movie.Pres.PlayUISound(eSUISound_SoldierPromotion);
	}
	else 	// if we got here it means we were going to upgrade an ability, but then we decided to cancel
	{
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
		List.SetSelectedIndex(previousSelectedIndexOnFocusLost, true);
		UIArmory_PromotionItem(List.GetSelectedItem()).SetSelectedAbility(SelectedAbilityIndex);
	}
}

simulated function RequestPawn(optional Rotator DesiredRotation)
{
}

simulated function PrevSoldier()
{
	// Do not switch soldiers in this screen
}

simulated function NextSoldier()
{
	// Do not switch soldiers in this screen
}
