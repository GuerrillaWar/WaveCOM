// This is a combination of XComGameStateContext_EffectRemoved and XComGameStateContext_ChangeContainer
// So we can remove effects and do many other stuffs on the same game state context
//
class WaveCOMGameStateContext_UpdateUnit extends XComGameStateContext_ChangeContainer;

var array<StateObjectReference> RemovedEffects;
var private XComGameState AssociatedGameState;

static function WaveCOMGameStateContext_UpdateUnit CreateEmptyChangeContainerUU(optional string ChangeDescription)
{
	local WaveCOMGameStateContext_UpdateUnit container;
	container = WaveCOMGameStateContext_UpdateUnit(CreateXComGameStateContext());
	container.ChangeInfo = ChangeDescription;
	return container;
}

static function WaveCOMGameStateContext_UpdateUnit CreateChangeStateUU(optional string ChangeDescription, optional XComGameState_Unit UnitState, bool bSetVisualizationFence = false, float VisFenceTimeout=20.0f)
{
	local WaveCOMGameStateContext_UpdateUnit container;
	local StateObjectReference EffectRef;
	container = CreateEmptyChangeContainerUU(ChangeDescription);
	if (UnitState != none)
	{
		foreach UnitState.AppliedEffects(EffectRef)
		{
			container.RemovedEffects.AddItem(EffectRef);
		}
		foreach UnitState.AffectedByEffects(EffectRef)
		{
			container.RemovedEffects.AddItem(EffectRef);
		}
	}
	container.SetVisualizationFence(bSetVisualizationFence, VisFenceTimeout);
	container.AssociatedGameState = `XCOMHISTORY.CreateNewGameState(true, container);
	return container;
}

function XComGameState GetGameState()
{
	return AssociatedGameState;
}

function AddEffectRemoved(XComGameState_Effect EffectState)
{
	RemovedEffects.AddItem(EffectState.GetReference());
}

protected function ContextBuildVisualization(out array<VisualizationTrack> VisualizationTracks, out array<VisualizationTrackInsertedInfo> VisTrackInsertedInfoArray)
{
	local VisualizationTrack SourceTrack;
	local VisualizationTrack TargetTrack;
	local XComGameStateHistory History;
	local X2VisualizerInterface VisualizerInterface;
	local XComGameState_Effect EffectState;
	local XComGameState_BaseObject EffectTarget;
	local XComGameState_BaseObject EffectSource;
	local X2Effect_Persistent EffectTemplate;
	local int i;
	local int n;
	local bool FoundSourceTrack;
	local bool FoundTargetTrack;
	local int SourceTrackIndex;
	local int TargetTrackIndex;

	History = `XCOMHISTORY;
	
	`log( "WaveCOM UpdateUnit :: ====== Start building Visualization (" $ RemovedEffects.Length $ ") ======");

	if(BuildVisualizationFn != None)
	{
		`log( "WaveCOM UpdateUnit :: Custom visualization found, processing...");
		BuildVisualizationFn(AssociatedState, VisualizationTracks);
	}
	
	for (i = 0; i < RemovedEffects.Length; ++i)
	{
		`log( "WaveCOM UpdateUnit :: Effect removal visualization found, processing...");
		EffectState = XComGameState_Effect(History.GetGameStateForObjectID(RemovedEffects[i].ObjectID));
		if (EffectState != none)
		{
			EffectSource = History.GetGameStateForObjectID(EffectState.ApplyEffectParameters.SourceStateObjectRef.ObjectID);
			EffectTarget = History.GetGameStateForObjectID(EffectState.ApplyEffectParameters.TargetStateObjectRef.ObjectID);

			FoundSourceTrack = False;
			FoundTargetTrack = False;
			for (n = 0; n < VisualizationTracks.Length; ++n)
			{
				if (EffectSource.ObjectID == XGUnit(VisualizationTracks[n].TrackActor).ObjectID)
				{
					SourceTrack = VisualizationTracks[n];
					FoundSourceTrack = true;
					SourceTrackIndex = n;
				}

				if (EffectTarget.ObjectID == XGUnit(VisualizationTracks[n].TrackActor).ObjectID)
				{
					TargetTrack = VisualizationTracks[n];
					FoundTargetTrack = true;
					TargetTrackIndex = n;
				}
			}

			if (EffectTarget != none)
			{
				TargetTrack.TrackActor = History.GetVisualizer(EffectTarget.ObjectID);
				VisualizerInterface = X2VisualizerInterface(TargetTrack.TrackActor);
				if (TargetTrack.TrackActor != none)
				{
					History.GetCurrentAndPreviousGameStatesForObjectID(EffectTarget.ObjectID, TargetTrack.StateObject_OldState, TargetTrack.StateObject_NewState, eReturnType_Reference, AssociatedState.HistoryIndex);
					if (TargetTrack.StateObject_NewState == none)
						TargetTrack.StateObject_NewState = TargetTrack.StateObject_OldState;

					if (VisualizerInterface != none)
					{
						VisualizerInterface.BuildAbilityEffectsVisualization(AssociatedState, TargetTrack);
						`log( "WaveCOM UpdateUnit ::" @ EffectTarget.ToString() @ "updated unit effect visualization");
					}

					EffectTemplate = EffectState.GetX2Effect();
					EffectTemplate.AddX2ActionsForVisualization_Removed(AssociatedState, TargetTrack, 'AA_Success', EffectState);
					`log( "WaveCOM UpdateUnit :: Effect visualization of" @ EffectState.ToString() @ "removed from" @ EffectTarget.ToString());
					if (FoundTargetTrack)
					{
						VisualizationTracks[TargetTrackIndex] = TargetTrack;
					}
					else
					{
						TargetTrackIndex = VisualizationTracks.AddItem(TargetTrack);
					}
				}
				
				if (EffectTarget.ObjectID == EffectSource.ObjectID)
				{
					SourceTrack = TargetTrack;
					FoundSourceTrack = True;
					SourceTrackIndex = TargetTrackIndex;
				}

				SourceTrack.TrackActor = History.GetVisualizer(EffectSource.ObjectID);
				if (SourceTrack.TrackActor != none)
				{
					History.GetCurrentAndPreviousGameStatesForObjectID(EffectSource.ObjectID, SourceTrack.StateObject_OldState, SourceTrack.StateObject_NewState, eReturnType_Reference, AssociatedState.HistoryIndex);
					if (SourceTrack.StateObject_NewState == none)
						SourceTrack.StateObject_NewState = SourceTrack.StateObject_OldState;

					EffectTemplate.AddX2ActionsForVisualization_RemovedSource(AssociatedState, SourceTrack, 'AA_Success', EffectState);
					if (FoundSourceTrack)
					{
						VisualizationTracks[SourceTrackIndex] = SourceTrack;
					}
					else
					{
						SourceTrackIndex = VisualizationTracks.AddItem(SourceTrack);
					}
				}
			}
		}
	}
}