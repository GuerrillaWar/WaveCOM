class WaveCOMStrategyElement_AcademyUnlocks extends X2StrategyElement;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
		
	Templates.AddItem(ArmedToTheTeethUnlock());
	Templates.AddItem(SparePartsUnlock());
	Templates.AddItem(LockAndLoadUnlock());
	Templates.AddItem(QuidUnlock());

	return Templates;
}

static function X2SoldierUnlockTemplate ArmedToTheTeethUnlock()
{
	local WaveCOMSoldierContinentBonusUnlockTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'WaveCOMSoldierContinentBonusUnlockTemplate', Template, 'WaveCOM_ArmedToTeethUnlock');

	Template.bAllClasses = true;
	Template.strImage = "img:///UILibrary_StrategyImages.GTS.GTS_FNG";

	// Requirements
	Template.Requirements.RequiredHighestSoldierRank = 6;
	Template.Requirements.bVisibleIfSoldierRankGatesNotMet = true;

	Template.ContinentBonus = 'ContinentBonus_ArmedToTheTeeth';

	// Cost
	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 1500;
	Template.Cost.ResourceCosts.AddItem(Resources);
	Resources.ItemTemplateName = 'EleriumCore';
	Resources.Quantity = 5;
	Template.Cost.ArtifactCosts.AddItem(Resources);

	return Template;
}

static function X2SoldierUnlockTemplate SparePartsUnlock()
{
	local WaveCOMSoldierContinentBonusUnlockTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'WaveCOMSoldierContinentBonusUnlockTemplate', Template, 'WaveCOM_SparePartsUnlock');

	Template.bAllClasses = true;
	Template.strImage = "img:///UILibrary_StrategyImages.GTS.GTS_FNG";

	// Requirements
	Template.Requirements.RequiredHighestSoldierRank = 4;
	Template.Requirements.bVisibleIfSoldierRankGatesNotMet = true;

	Template.ContinentBonus = 'ContinentBonus_SpareParts';

	// Cost
	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 1000;
	Template.Cost.ResourceCosts.AddItem(Resources);
	Resources.ItemTemplateName = 'EleriumCore';
	Resources.Quantity = 3;
	Template.Cost.ArtifactCosts.AddItem(Resources);

	return Template;
}

static function X2SoldierUnlockTemplate LockAndLoadUnlock()
{
	local WaveCOMSoldierContinentBonusUnlockTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'WaveCOMSoldierContinentBonusUnlockTemplate', Template, 'WaveCOM_LockNLoadUnlock');

	Template.bAllClasses = true;
	Template.strImage = "img:///UILibrary_StrategyImages.GTS.GTS_FNG";

	// Requirements
	Template.Requirements.RequiredHighestSoldierRank = 5;
	Template.Requirements.bVisibleIfSoldierRankGatesNotMet = true;

	Template.ContinentBonus = 'ContinentBonus_LockAndLoad';

	// Cost
	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 500;
	Template.Cost.ResourceCosts.AddItem(Resources);

	return Template;
}

static function X2SoldierUnlockTemplate QuidUnlock()
{
	local WaveCOMSoldierContinentBonusUnlockTemplate Template;
	local ArtifactCost Resources;

	`CREATE_X2TEMPLATE(class'WaveCOMSoldierContinentBonusUnlockTemplate', Template, 'WaveCOM_QuidUnlock');

	Template.bAllClasses = true;
	Template.strImage = "img:///UILibrary_StrategyImages.GTS.GTS_FNG";

	// Requirements
	Template.Requirements.RequiredHighestSoldierRank = 3;
	Template.Requirements.bVisibleIfSoldierRankGatesNotMet = true;

	Template.ContinentBonus = 'ContinentBonus_QuidProQuo';

	// Cost
	Resources.ItemTemplateName = 'Supplies';
	Resources.Quantity = 400;
	Template.Cost.ResourceCosts.AddItem(Resources);

	return Template;
}