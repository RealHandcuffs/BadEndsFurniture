;
; Script for Gallows.
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Actor _victim = None

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
RefCollectionAlias Property Victims Auto Const Mandatory

Idle Property PhaseOneIdle Auto Mandatory

;
; Get the current victim, None if gallows is empty.
; Note that the victim can be dead, use GetGallowsState() to check state of victim. 
;
Actor Property Victim
    Actor Function Get()
        Return _victim
    EndFunction
EndProperty

;
; Returns the current state of the gallows:
; 0          gallows is empty
; 1, 2, ...  life victim is struggling on the gallows (number increases with animation phase)
; -1         dead victim  is hanging on the gallows
;
Int Function GetGallowsState()
    Return 0
EndFunction

;
; Try to start a hanging scene with the given actor as a victim.
; This will only work if the gallows is currently empty.
; Returns true on success, false on error.
;
Bool Function StartHangingScene(Actor akActor)
    Return false
EndFunction

;
; Try to cut the noose, removing the current victim from the gallows.
; This will only work if the gallows is not empty.
;
Bool Function CutNoose()
    Return false
EndFunction


; ---- internal functions -----

Function Advance()
EndFunction

; below function needs to be in base state as it is called after a state switch
Function CutNooseOfLifeVictimAndWait(Actor akActor, Float bleedOutTime, Action bleedoutStart, Action bleedoutStop, RefCollectionAlias vics)
    akActor.StopTranslation()
    akActor.SetRestrained(false)
    akActor.PlayIdleAction(bleedoutStart)
    Utility.Wait(bleedOutTime)
    akActor.PlayIdleAction(bleedoutStop)
    vics.RemoveRef(akActor)
    akActor.EvaluatePackage()
EndFunction

Event OnLoad()
    GotoState("Empty") ; initialize after construction
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Int Property TimerAdvance = 1 AutoReadOnly

Event OnTimer(int aiTimerID)
    If (aiTimerID == TimerAdvance)
        Advance()
    EndIf
EndEvent


;
; Empty state, gallows is ready to be used.
;
State Empty

Event OnBeginState(string asOldState)
    _victim = None
    CancelTimer(TimerAdvance) ; may do nothing
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    Actor akActor = akActionRef as Actor
    If (akActor != None)
        If (akActionRef == Game.GetPlayer())
            BadEndsFurniture:DebugWrapper.Notification("TODO")
        ElseIf (akActor.IsDoingFavor())
            StartHangingScene(akActor) ; player commanded NPC to interact with gallows, hang NPC
        EndIf
    EndIf
EndEvent

Bool Function StartHangingScene(Actor akActor)
    If (akActor == None || akActor == Game.GetPlayer())
        Return false
    EndIf
    If (_victim != None)
        Return false
    EndIf
    _victim = akActor
    If (Victims.Find(akActor) >= 0)
        _victim = None
        Return false
    EndIf
    Victims.AddRef(akActor)
    GotoState("SetupAnimation")
    Return true
EndFunction

EndState


;
; Short helper state for setting up the animation.
;
State SetupAnimation

Event OnBeginState(string asOldState)
    StartTimer(0.016, TimerAdvance)
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Int Function GetGallowsState()
    Return 1
EndFunction

Bool Function CutNoose()
    Actor lifeVictim = _victim
    GotoState("Empty")
    lifeVictim.SetRestrained(false)
    Victims.RemoveRef(lifeVictim)
    lifeVictim.EvaluatePackage()
    Return true
EndFunction

Function Advance()
    _victim.SetRestrained(1)
    _victim.EvaluatePackage()
    Utility.Wait(0.016)
    GotoState("LifeVictim")
EndFunction

EndState


;
; LifeVictim: Victim is struggling on gallows.
;
State LifeVictim

Event OnBeginState(string asOldState)
    If (GetParentCell().IsAttached())
        OnCellAttach()
    EndIf
    ; TODO setup timer for advancing animation
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnCellAttach()
    Float myX = X
    Float myY = Y
    Float myZ = Z
    Float myAngleX = GetAngleX()
    Float myAngleY = GetAngleY()
    Float myAngleZ = GetAngleZ()
    _victim.PlayIdle(PhaseOneIdle)
    _victim.MoveTo(Self, 0, 0, 0, true)
    _victim.TranslateTo(myX, myY, myZ + 0.1, myAngleX, myAngleY, myAngleZ, 0.0001, 0.0001) ; translate very slowly to effectively stay in place
EndEvent

Event OnCellDetach()
    _victim.StopTranslation()
EndEvent

Int Function GetGallowsState()
    Return 1
EndFunction

Bool Function CutNoose()
    Var[] params = new Var[5]
    params[0] = _victim
    params[1] = 8.0
    params[2] = ActionBleedoutStart
    params[3] = ActionBleedoutStop
    params[4] = Victims
    GotoState("Empty")
    CallFunctionNoWait("CutNooseOfLifeVictimAndWait", params)
    Return true
EndFunction

EndState
