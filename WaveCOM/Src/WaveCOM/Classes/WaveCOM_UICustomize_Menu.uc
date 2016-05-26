// This is an Unreal Script

class WaveCOM_UICustomize_Menu extends UICustomize_Menu;

simulated function UpdateData()
{
	local XGUnit Visualizer;

	super.UpdateData();

	Visualizer = XGUnit(Unit.FindOrCreateVisualizer());
	XComHumanPawn(Visualizer.GetPawn()).SetAppearance(Unit.kAppearance);
}

simulated function UpdateCustomizationManager()
{
	if (Movie.Pres.m_kCustomizeManager == none)
	{
		Unit = WaveCOM_UICustomize_Menu(Movie.Stack.GetScreen(class'WaveCOM_UICustomize_Menu')).Unit;
		UnitRef = WaveCOM_UICustomize_Menu(Movie.Stack.GetScreen(class'WaveCOM_UICustomize_Menu')).UnitRef;
		Movie.Pres.InitializeCustomizeManager(Unit);
	}
}

simulated function OnCustomizeInfo()
{
	CustomizeManager.UpdateCamera();

	Movie.Stack.Push(Spawn(Unit.GetMyTemplate().UICustomizationInfoClass, Movie.Pres), Movie);
}
// --------------------------------------------------------------------------
simulated function OnCustomizeProps()
{
	CustomizeManager.UpdateCamera();
	Movie.Stack.Push(Spawn(class'WaveCOM_UICustomize_Props', Movie.Pres), Movie);
}
// --------------------------------------------------------------------------
simulated function CustomizeFace()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strFace, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Face),
		ChangeFace, ChangeFace, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Face));
}
reliable client function ChangeFace(UIList _list, int itemIndex)
{
	CustomizeManager.OnCategoryValueChange( eUICustomizeCat_Face, 0, itemIndex ); 
}
// --------------------------------------------------------------------------
simulated function CustomizeHair()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strHair, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Hairstyle),
		ChangeHair, ChangeHair, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Hairstyle));
}
reliable client function ChangeHair(UIList _list, int itemIndex)
{
	CustomizeManager.OnCategoryValueChange( eUICustomizeCat_Hairstyle, 0, itemIndex ); 
}
// --------------------------------------------------------------------------
simulated function CustomizeFacialHair()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strFacialHair, "", CustomizeManager.GetCategoryList(eUICustomizeCat_FacialHair),
		ChangeFacialHair, ChangeFacialHair, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_FacialHair));
}
reliable client function ChangeFacialHair(UIList _list, int itemIndex)
{
	CustomizeManager.OnCategoryValueChange( eUICustomizeCat_FacialHair, 0, itemIndex ); 
}
// --------------------------------------------------------------------------
simulated function CustomizeRace()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strRace, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Race),
		ChangeRace, ChangeRace, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Race));
}

reliable client function CustomizeClass()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strCustomizeClass, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Class), 
		none, ChangeClass, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Voice));
}


simulated function CustomizeVoice()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strVoice, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Voice),
		none, ChangeVoice, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Voice), m_strPreviewVoice, ChangeVoice);
}

reliable client function CustomizePersonality()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strAttitude, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Personality),
		ChangePersonality, ChangePersonality, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Personality));
}

function UICustomize_Trait( string _Title, 
							string _Subtitle, 
							array<string> _Data, 
							delegate<UICustomize_Trait.OnItemSelectedCallback> _onSelectionChanged,
							delegate<UICustomize_Trait.OnItemSelectedCallback> _onItemClicked,
							optional delegate<UICustomize.IsSoldierEligible> _eligibilityCheck,
							optional int startingIndex = -1,
							optional string _ConfirmButtonLabel,
							optional delegate<UICustomize_Trait.OnItemSelectedCallback> _onConfirmButtonClicked )
{
	Movie.Stack.Push(Spawn(class'WaveCOM_UICustomize_Trait', Movie.Pres), Movie);
	WaveCOM_UICustomize_Trait(Movie.Stack.GetCurrentScreen()).UpdateTrait( _Title, _Subtitle, _Data, _onSelectionChanged, _onItemClicked, _eligibilityCheck, startingIndex, _ConfirmButtonLabel, _onConfirmButtonClicked );
}