class WaveCOMSoldierContinentBonusUnlockTemplate extends X2SoldierUnlockTemplate;

var name ContinentBonus;

function OnSoldierUnlockPurchased(XComGameState NewGameState)
{
	local XComGameState_HeadquartersXCom XComHQ;
	local XComGameStateHistory History;
	local X2GameplayMutatorTemplate ContinentTemplate;

	ContinentTemplate = X2GameplayMutatorTemplate(class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager().FindStrategyElementTemplate(ContinentBonus));

	if (ContinentTemplate == none)
		return;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.CreateStateObject(class'XComGameState_HeadquartersXCom', XComHQ.ObjectID));

	ContinentTemplate.OnActivatedFn(NewGameState, XComHQ.GetReference(), false);

	NewGameState.AddStateObject(XComHQ);
}

DefaultProperties
{
	bAllClasses = true
}