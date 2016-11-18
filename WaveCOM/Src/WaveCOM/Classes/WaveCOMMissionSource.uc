
class WaveCOMMissionSource extends X2StrategyElement
	config(GameData);

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> MissionSources;

	MissionSources.AddItem(CreateWaveCOMTemplate());
	return MissionSources;
}

// AVENGER DEFENSE
//---------------------------------------------------------------------------------------
static function X2DataTemplate CreateWaveCOMTemplate()
{
	local X2MissionSourceTemplate Template;

	`CREATE_X2TEMPLATE(class'X2MissionSourceTemplate', Template, 'MissionSource_WaveCOM');
	Template.DifficultyValue = 3;
	Template.bSkipRewardsRecap = true;
	Template.CustomMusicSet = 'Tutorial';
	Template.CustomLoadingMovieName_Intro = "1080_LoadingScreen5.bk2";
	Template.bRequiresSkyRangerTravel = false;
	Template.OnSuccessFn = AvengerDefenseOnSuccess;
	Template.OnFailureFn = AvengerDefenseOnFailure;
	Template.GetMissionDifficultyFn = GetMissionDifficultyFromTemplate;
	Template.WasMissionSuccessfulFn = OneStrategyObjectiveCompleted;

	return Template;
}

function AvengerDefenseOnSuccess(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
}
function AvengerDefenseOnFailure(XComGameState NewGameState, XComGameState_MissionSite MissionState)
{
}

function int GetMissionDifficultyFromTemplate(XComGameState_MissionSite MissionState)
{
	local int Difficulty;

	Difficulty = MissionState.GetMissionSource().DifficultyValue;

	Difficulty = Clamp(Difficulty, class'X2StrategyGameRulesetDataStructures'.default.MinMissionDifficulty,
					   class'X2StrategyGameRulesetDataStructures'.default.MaxMissionDifficulty);

	return Difficulty;
}

//---------------------------------------------------------------------------------------
function bool OneStrategyObjectiveCompleted(XComGameState_BattleData BattleDataState)
{
	// No objective to checki n WaveCOM
	return true;
}