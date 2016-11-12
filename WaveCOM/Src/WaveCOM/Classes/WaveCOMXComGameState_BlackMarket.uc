class WaveCOMXComGameState_BlackMarket extends XComGameState_BlackMarket;

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
}