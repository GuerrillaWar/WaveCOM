class WaveCOM_UISL_ListenForUnitReward extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local Object this;

	this = self;
	`XEVENTMGR.RegisterForEvent(this, 'ResearchCompleted', ResearchComplete, ELD_OnStateSubmitted);
}

function EventListenerReturn ResearchComplete(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	local XComGameState_Tech TechState;
	local XComGameState_Unit StrategyUnit;

	TechState = XComGameState_Tech(EventData);

	`log("Research Complete",, 'UnitProject');

	if (TechState != none && TechState.UnitRewardRef.ObjectID > 0)
	{
		`log("Tech contains unit",, 'UnitProject');
		StrategyUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(TechState.UnitRewardRef.ObjectID));
		if (StrategyUnit != none)
		{
			class'WaveCOM_UILoadoutButton'.static.AddStrategyUnitToBoard(StrategyUnit, `XCOMHISTORY);
		}
	}

	return ELR_NoInterrupt;
}

defaultproperties
{
	ScreenClass=class'UITacticalHUD';
}