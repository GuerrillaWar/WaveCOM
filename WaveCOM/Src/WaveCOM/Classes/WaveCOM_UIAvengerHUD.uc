// This is an Unreal Script

class WaveCOM_UIAvengerHUD extends UIAvengerHUD;

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	super.InitScreen(InitController, InitMovie, InitName);
	EventQueue.Hide();
	Links.Hide();
	Objectives.Hide();
	Shortcuts.Hide();
	Shortcuts.DoHide();
	ToDoWidget.Hide();
	UpdateDefaultResources(); 
	ShowResources();
}