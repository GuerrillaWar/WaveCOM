// This is an Unreal Script

class WaveCOM_UICustomize_Trait extends UICustomize_Trait;

simulated function UpdateData()
{
	local XGUnit Visualizer;

	super.UpdateData();

	Visualizer = XGUnit(Unit.FindOrCreateVisualizer());
	XComHumanPawn(Visualizer.GetPawn()).SetAppearance(Unit.kAppearance);
}
