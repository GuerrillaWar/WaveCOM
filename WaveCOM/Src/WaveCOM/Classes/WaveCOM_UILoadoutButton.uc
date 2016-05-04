// This is an Unreal Script

class WaveCOM_UILoadoutButton extends UIScreenListener;  
// This event is triggered after a screen is initialized. This is called after  // the visuals (if any) are loaded in Flash.
var UIButton Button1, Button2, Button3, Button4, Button5;
var UIPanel ActionsPanel;
var UITacticalHUD TacHUDScreen;
var WaveCOM_UIArmory_FieldLoadout UIArmory_FieldLoad;
var WaveCOM_UIAvengerHUD AvengerHUD;
var XComGameState_HeadquartersXCom XComHQ;

event OnInit(UIScreen Screen)
{
	local Object ThisObj;

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

	Button2 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button2.InitButton('BuyButton', "Buy Equipment", OpenBuyMenu);
	Button2.SetY(ActionsPanel.Y);
	Button2.SetX(ActionsPanel.X + (ActionsPanel.Width / 2) - (Button2.Width / 2));

	Button4 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button4.InitButton('ResearchButton', "Research", OpenResearchMenu);
	Button4.SetY(ActionsPanel.Y + 30);
	Button4.SetX(ActionsPanel.X + (ActionsPanel.Width / 2) - (Button4.Width / 2));

	Button3 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button3.InitButton('DeploySoldier', "Deploy Soldier", OpenDeployMenu);
	Button3.SetY(ActionsPanel.Y);
	Button3.SetX(ActionsPanel.X + ActionsPanel.Width - Button3.Width);

	Button5 = ActionsPanel.Spawn(class'UIButton', ActionsPanel);
	Button5.InitButton('ViewInventory', "View Inventory", OpenStorage);
	Button5.SetY(ActionsPanel.Y + 30);
	Button5.SetX(ActionsPanel.X + ActionsPanel.Width - Button5.Width);

	AvengerHUD = TacHUDScreen.Movie.Pres.Spawn(class'WaveCOM_UIAvengerHUD', TacHUDScreen.Movie.Pres);
	TacHUDScreen.Movie.Stack.Push(AvengerHUD, TacHUDScreen.Movie);
	AvengerHUD.HideResources();
	UpdateResources();

	ThisObj = self;
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveStart', OnWaveStart, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(ThisObj, 'WaveCOM_WaveEnd', OnWaveEnd, ELD_Immediate);
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
	AvengerHUD.UpdateEleriumCrystals();
	AvengerHUD.UpdateAlienAlloys();
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

public function OpenDeployMenu(UIButton Button)
{

}


defaultproperties
{
	ScreenClass = class'UITacticalHUD';
}