class WaveCOM_UIBlackMarket extends UIBlackMarket;

simulated function OnBuyClicked(UIButton button)
{
	local UIBlackMarket_Buy kScreen;

	kScreen = `PRES.Spawn(class'UIBlackMarket_Buy', self);
	`PRES.ScreenStack.Push(kScreen);
}

simulated function OnSellClicked(UIButton button)
{
	local UIBlackMarket_Sell kScreen;
	local XComGameStateHistory History;
	local XComGameState_BlackMarket BlackMarketState;

	History = `XCOMHISTORY;
	BlackMarketState = XComGameState_BlackMarket(History.GetSingleGameStateObjectForClass(class'XComGameState_BlackMarket'));

	kScreen = `PRES.Spawn(class'UIBlackMarket_Sell', self);
	kScreen.BlackMarketReference = BlackMarketState.GetReference();
	`PRES.ScreenStack.Push(kScreen);
}

simulated function CloseScreen()
{
	super.CloseScreen();
	`XEVENTMGR.TriggerEvent('UpdateDeployCost');
}