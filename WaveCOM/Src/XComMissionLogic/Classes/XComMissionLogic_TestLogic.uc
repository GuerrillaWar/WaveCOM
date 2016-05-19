// This is an Unreal Script

class XComMissionLogic_TestLogic extends XComGameState_MissionLogic;

delegate EventListenerReturn OnEventDelegate(Object EventData, Object EventSource, XComGameState GameState, Name EventID);

function SetupMissionStartState(XComGameState StartState)
{
	`log("XComMissionLogic_TestLogic :: SetupMissionStartState");
}

function RegisterEventHandlers()
{	
	OnAlienTurnBegin(TestOnAlienTurnBegin);
	`log("XComMissionLogic_TestLogic :: RegisterEventHandlers");
}

function EventListenerReturn TestOnAlienTurnBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID)
{
	`log("XComMissionLogic_TestLogic :: OnAlienTurnBegin");
	return ELR_NoInterrupt;
}