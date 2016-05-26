// This is an Unreal Script

class WaveCOM_UICustomize_Props extends UICustomize_Props;

simulated function UpdateData()
{
	local XGUnit Visualizer;

	super.UpdateData();

	Visualizer = XGUnit(Unit.FindOrCreateVisualizer());
	XComHumanPawn(Visualizer.GetPawn()).SetAppearance(Unit.kAppearance);
}

simulated function CustomizeHelmet()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strHelmet, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Helmet),
		ChangeHelmet, ChangeHelmet, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Helmet));
}

simulated function CustomizeArmorPattern()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strArmorPattern, "", CustomizeManager.GetCategoryList(eUICustomizeCat_ArmorPatterns),
		ChangeArmorPattern, ChangeArmorPattern, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_ArmorPatterns));
}

simulated function CustomizeWeaponPattern()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strWeaponPattern, "", CustomizeManager.GetCategoryList(eUICustomizeCat_WeaponPatterns),
		ChangeWeaponPattern, ChangeWeaponPattern, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_WeaponPatterns));
}

simulated function CustomizeFacePaint()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strFacePaint, "", CustomizeManager.GetCategoryList(eUICustomizeCat_FacePaint),
								 ChangeFacePaint, ChangeFacePaint, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_FacePaint));
}

simulated function CustomizeLeftArmTattoos()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strTattoosLeft, "", CustomizeManager.GetCategoryList(eUICustomizeCat_LeftArmTattoos),
		ChangeTattoosLeftArm, ChangeTattoosLeftArm, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_LeftArmTattoos));
}

simulated function CustomizeRightArmTattoos()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strTattoosRight, "", CustomizeManager.GetCategoryList(eUICustomizeCat_RightArmTattoos),
		ChangeTattoosRightArm, ChangeTattoosRightArm, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_RightArmTattoos));
}

simulated function CustomizeScars()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strScars, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Scars),
		ChangeScars, ChangeScars, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Scars));
}

simulated function CustomizeArms()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strArms, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Arms),
		ChangeArms, ChangeArms, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Arms));
}

simulated function CustomizeLeftArm()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strLeftArm, "", CustomizeManager.GetCategoryList(eUICustomizeCat_LeftArm),
		ChangeLeftArm, ChangeLeftArm, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_LeftArm));
}

simulated function CustomizeRightArm()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strRightArm, "", CustomizeManager.GetCategoryList(eUICustomizeCat_RightArm),
								 ChangeRightArm, ChangeRightArm, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_RightArm));
}

simulated function CustomizeLeftArmDeco()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strLeftArmDeco, "", CustomizeManager.GetCategoryList(eUICustomizeCat_LeftArmDeco),
								 ChangeLeftArmDeco, ChangeLeftArmDeco, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_LeftArmDeco));
}

simulated function CustomizeRightArmDeco()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strRightArmDeco, "", CustomizeManager.GetCategoryList(eUICustomizeCat_RightArmDeco),
								 ChangeRightArmDeco, ChangeRightArmDeco, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_RightArmDeco));
}

simulated function CustomizeTorso()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strTorso, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Torso),
		ChangeTorso, ChangeTorso, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Torso));
}

simulated function CustomizeLegs()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strLegs, "", CustomizeManager.GetCategoryList(eUICustomizeCat_Legs),
		ChangeLegs, ChangeLegs, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_Legs)); 
}

simulated function CustomizeUpperFaceProps()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strUpperFaceProps, "", CustomizeManager.GetCategoryList(eUICustomizeCat_FaceDecorationUpper),
		ChangeFaceUpperProps, ChangeFaceUpperProps, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_FaceDecorationUpper));
}

simulated function CustomizeLowerFaceProps()
{
	CustomizeManager.UpdateCamera();
	UICustomize_Trait(m_strLowerFaceProps, "", CustomizeManager.GetCategoryList(eUICustomizeCat_FaceDecorationLower),
		ChangeFaceLowerProps, ChangeFaceLowerProps, CanCycleTo, CustomizeManager.GetCategoryIndex(eUICustomizeCat_FaceDecorationLower));
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