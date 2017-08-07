class WaveCOMXComGameState_BlackMarket extends XComGameState_BlackMarket;

function array<XComGameState_Item> RollForBlackMarketLoot(XComGameState NewGameState)
{
	local X2ItemTemplateManager ItemMgr;
	local array<XComGameState_Item> ItemList;
	local XComGameState_Item ItemState;
	local X2ItemTemplate ItemTemplate;
	local X2LootTableManager LootManager;
	local LootResults Loot;
	local int LootIndex, idx;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	LootManager = class'X2LootTableManager'.static.GetLootTableManager();
	LootIndex = LootManager.FindGlobalLootCarrier('WaveCOMBlackMarket');

	if(LootIndex >= 0)
	{
		LootManager.RollForGlobalLootCarrier(LootIndex, Loot);
	}

	for(idx = 0; idx < Loot.LootToBeCreated.Length; idx++)
	{
		if(InterestTemplates.Find(Loot.LootToBeCreated[idx]) == INDEX_NONE)
		{
			// Modified to make all loot items different black market entries to prevent buying multiple items at low price
			ItemTemplate = ItemMgr.FindItemTemplate(Loot.LootToBeCreated[idx]);

			if(ItemTemplate != none)
			{
				ItemState = ItemTemplate.CreateInstanceFromTemplate(NewGameState);
				NewGameState.AddStateObject(ItemState);
				ItemList.AddItem(ItemState);
			}
		}
	}

	return ItemList;
}

function StrategyCost GetPersonnelForSaleItemCost(optional float CostScalar = 1.0f)
{
	local StrategyCost Cost;
	local ArtifactCost ResourceCost;
	local int IntelAmount, IntelVariance;
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

	IntelAmount = default.PersonnelItemIntelCost[`DIFFICULTYSETTING] + ((NumTimesAppeared - 1) * default.PersonnelItemIntelCostIncrease[`DIFFICULTYSETTING]);
	IntelVariance = Round((float(`SYNC_RAND(default.IntelCostVariance[`DIFFICULTYSETTING])) / 100.0)* float(IntelAmount));

	if(class'X2StrategyGameRulesetDataStructures'.static.Roll(50))
	{
		IntelVariance = -IntelVariance;
	}

	IntelAmount += IntelVariance;
	IntelAmount = Round(float(IntelAmount) * CostScalar);

	// Make it a multiple of 5
	IntelAmount = Round(float(IntelAmount) / 5.0) * 5;

	ResourceCost.ItemTemplateName = 'Intel';
	ResourceCost.Quantity = IntelAmount;
	Cost.ResourceCosts.AddItem(ResourceCost);

	ResourceCost.ItemTemplateName = 'Supplies';
	if (XComCount > class'WaveCOM_UILoadoutButton'.default.WaveCOMDeployCosts.Length - 1)
	{
		ResourceCost.Quantity = class'WaveCOM_UILoadoutButton'.default.WaveCOMDeployCosts[class'WaveCOM_UILoadoutButton'.default.WaveCOMDeployCosts.Length - 1];
	}
	else
	{
		ResourceCost.Quantity = class'WaveCOM_UILoadoutButton'.default.WaveCOMDeployCosts[XComCount];
	}

	ResourceCost.Quantity = Round(ResourceCost.Quantity * (100.0f / (100.0f - GoodsCostPercentDiscount))); // Counter Discount
	Cost.ResourceCosts.AddItem(ResourceCost);

	return Cost;
}

function UpdateForSaleItemDiscount()
{
	local int idx;

	for (idx = 0; idx < ForSaleItems.Length; idx++)
	{
		if (ForSaleItems[idx].Cost.ResourceCosts.Find('ItemTemplateName', 'Supplies') == INDEX_NONE) // Skip discount on supplies
		{
			ForSaleItems[idx].DiscountPercent = GoodsCostPercentDiscount;
		}
	}
}

function bool UpdateBuyPrices()
{
	local int idx, SupCost;
	local StrategyCost FakeCost;
	local bool b;
	b = super.UpdateBuyPrices();

	for (idx = 0; idx < ForSaleItems.Length; idx++) // Refresh supplies costs
	{
		SupCost = ForSaleItems[idx].Cost.ResourceCosts.Find('ItemTemplateName', 'Supplies');
		if (SupCost != INDEX_NONE)
		{
			FakeCost = GetPersonnelForSaleItemCost(PriceReductionScalar);
			ForSaleItems[idx].Cost.ResourceCosts.Remove(SupCost, 1); 
			ForSaleItems[idx].Cost.ResourceCosts.AddItem(FakeCost.ResourceCosts[1]);
		}
	}

	return b;
}

function SetUpForSaleItems(XComGameState NewGameState)
{
	local X2StrategyElementTemplateManager StratMgr;
	local XComGameState_Reward RewardState;
	local X2RewardTemplate RewardTemplate;
	local Commodity ForSaleItem, EmptyForSaleItem;
	local array<XComGameState_Item> ItemList;
	local int idx;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Item'));
	ItemList = RollForBlackMarketLoot(NewGameState);

	// Loot Table Rewards
	for(idx = 0; idx < ItemList.Length; idx++)
	{
		ForSaleItem = EmptyForSaleItem;
		RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
		NewGameState.AddStateObject(RewardState);
		RewardState.SetReward(ItemList[idx].GetReference());
		ForSaleItem.RewardRef = RewardState.GetReference();

		ForSaleItem.Title = RewardState.GetRewardString();

		if(X2WeaponUpgradeTemplate(ItemList[idx].GetMyTemplate()) != none)
		{
			ForSaleItem.Cost = GetForSaleItemCost(default.WeaponUpgradeCostScalar[`DIFFICULTYSETTING] * PriceReductionScalar);
		}
		else
		{
			ForSaleItem.Cost = GetForSaleItemCost(PriceReductionScalar);
		}
		
		ForSaleItem.Desc = RewardState.GetBlackMarketString();
		ForSaleItem.Image = RewardState.GetRewardImage();
		ForSaleItem.CostScalars = GoodsCostScalars;
		ForSaleItem.DiscountPercent = GoodsCostPercentDiscount;

		ForSaleItems.AddItem(ForSaleItem);
	}

	// Elerium Core Rewards
	ForSaleItem = EmptyForSaleItem;
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Item'));
	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);
	NewGameState.AddStateObject(RewardState);
	RewardState.GenerateReward(NewGameState);
	ForSaleItem.RewardRef = RewardState.GetReference();

	ForSaleItem.Title = RewardState.GetRewardString();
	ForSaleItem.Cost = GetForSaleItemCost(PriceReductionScalar);
	ForSaleItem.Desc = RewardState.GetBlackMarketString();
	ForSaleItem.Image = RewardState.GetRewardImage();
	ForSaleItem.CostScalars = GoodsCostScalars;
	ForSaleItem.DiscountPercent = GoodsCostPercentDiscount;

	ForSaleItems.AddItem(ForSaleItem);

	// Personnel Reward
	ForSaleItem = EmptyForSaleItem;
	RewardTemplate = X2RewardTemplate(StratMgr.FindStrategyElementTemplate('Reward_Soldier'));

	RewardState = RewardTemplate.CreateInstanceFromTemplate(NewGameState);

	NewGameState.AddStateObject(RewardState);
	RewardState.GenerateReward(NewGameState, , Region);
	ForSaleItem.RewardRef = RewardState.GetReference();

	ForSaleItem.Title = RewardState.GetRewardString();
	ForSaleItem.Cost = GetPersonnelForSaleItemCost(PriceReductionScalar);
	ForSaleItem.Desc = RewardState.GetBlackMarketString();
	ForSaleItem.Image = RewardState.GetRewardImage();
	ForSaleItem.CostScalars = GoodsCostScalars;
	ForSaleItem.DiscountPercent = GoodsCostPercentDiscount;

	// No Avenger to take photo
	//if (ForSaleItem.Image == "")
	//{
		//if (!Photo.HasPendingHeadshot(RewardState.RewardObjectReference, OnUnitHeadCaptureFinished))
		//{
			//Photo.AddHeadshotRequest(RewardState.RewardObjectReference, 'UIPawnLocation_ArmoryPhoto', 'SoldierPicture_Head_Armory', 512, 512, OnUnitHeadCaptureFinished);
		//}
	//}

	ForSaleItems.AddItem(ForSaleItem);
}