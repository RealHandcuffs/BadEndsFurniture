;
; Script for Gallows.
; This script is implemented as a state maching, the different states correspond to the progress of the hanging scene.
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Keyword Property GallowsLink Auto Const Mandatory
ActorValue Property Paralysis Auto Const Mandatory
Keyword Property PlayerSelectVictimLink Auto Const Mandatory
BadEndsFurniture:Library Property Library Auto Const Mandatory
RefCollectionAlias Property Victims Auto Const Mandatory

Actor _victim
Actor _clone
Library:EquippedItem[] _cloneEquipment
Int _lifeIdleIndex

;
; Must be set to an array of idles that will play sequentially.
;
Idle[] Property LifeIdles Auto Mandatory

;
; Must contain the time for each idle in LifeIdles.
;
Float[] Property LifeIdleTimes Auto Mandatory

;
; Must contain the idle to play for a dead victim.
;
Idle Property DeadIdle Auto Mandatory

;
; Offsets for the idle positions.
;
Float Property DX = 0.0 Auto
Float Property DY = 0.0 Auto
Float Property DZ = 0.0 Auto
Float Property DAngleZ = 0.0 Auto

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
; 1, 2, ...  life victim is struggling on the gallows (number increases with progressing state)
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
Bool Function StartHangingScene(Actor akActor, Bool displayNotification = false)
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

; select a victim for the gallows, called by activation and by perk
Function SelectVictim(Actor akActor)
    If (akActor != None)
        ; TODO verify
        Actor player = Game.GetPlayer()
        If (player.GetLinkedRef(PlayerSelectVictimLink) == Self)
            CancelTimer(TimerSelectVictimAbort)
            player.SetLinkedRef(None, PlayerSelectVictimLink)
        EndIf
        StartHangingScene(akActor, true)
    EndIf
EndFunction

; advance to next state
Function Advance()
    ; implemented in state
EndFunction

; fix position of the animated clone
Function FixClonePosition()
    Actor clone = _clone
    If (clone != None)
        Float targetX = X + DX
        Float targetY = Y + DY
        Float targetZ = Z + DZ
        Float targetAngleZ = GetAngleZ() + DAngleZ
        clone.StopTranslation()
        If (DAngleZ != 0)
            clone.SetAngle(0.0, 0.0, targetAngleZ)
        EndIf
        clone.MoveTo(Self, DX, DY, DZ, DAngleZ == 0)
        clone.TranslateTo(targetX, targetY, targetZ, 0.0, 0.0, targetAngleZ + 0.0524, 0.0001, 0.0001)
    EndIf
EndFunction

Event OnLoad()
    GotoState("Empty") ; initialize after construction
EndEvent

Int Property TimerAdvance = 1 AutoReadOnly
Int Property TimerFixClonePosition = 2 AutoReadOnly
Int Property TimerSelectVictimAbort = 3 AutoReadOnly

Event OnTimer(int aiTimerID)
    If (aiTimerID == TimerAdvance)
        Advance()
    ElseIf (aiTimerID == TimerFixClonePosition)
        If (GetParentCell().IsAttached() && _clone != None && Self.WaitFor3DLoad() && _clone.WaitFor3DLoad())
            FixClonePosition()
            StartTimer(300, TimerFixClonePosition)
        EndIf
    ElseIf (aiTimerID == TimerSelectVictimAbort)
        Actor player = Game.GetPlayer()
        If (player.GetLinkedRef(PlayerSelectVictimLink) == Self)
            player.SetLinkedRef(None, PlayerSelectVictimLink)
            BadEndsFurniture:DebugWrapper.Notification(GetDisplayName() + ": Aborting victim selection.")
        EndIf
    EndIf
EndEvent


;
; Empty: Gallows is ready to be used.
;
State Empty

Event OnBeginState(string asOldState)
    CancelTimer(TimerAdvance)          ; may do nothing
    CancelTimer(TimerFixClonePosition) ; same
    If (_victim != None)
        Victims.RemoveRef(_victim)
        _victim = None
    EndIf
    If (_clone != None)
        Victims.RemoveRef(_clone)
        _clone.DisableNoWait(false)
        _clone.Delete()
        _clone = None
    EndIf
    _cloneEquipment = None
    _lifeIdleIndex = 0
    BlockActivation(false)
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; show interaction or start a hanging scene
    Actor akActor = akActionRef as Actor
    If (akActor != None)
        If (akActionRef == Game.GetPlayer())
            ObjectReference linked = akActor.GetLinkedRef(PlayerSelectVictimLink)
            If (linked == Self)
                CancelTimer(TimerSelectVictimAbort)
                akActor.SetLinkedRef(None, PlayerSelectVictimLink)
                BadEndsFurniture:DebugWrapper.Notification(GetDisplayName() + ": Aborting victim selection.")
            Else
                akActor.SetLinkedRef(Self, PlayerSelectVictimLink)
                BadEndsFurniture:DebugWrapper.Notification(GetDisplayName() + ": Select a victim.")
                StartTimer(15.0, TimerSelectVictimAbort)
            EndIf
        ElseIf (akActor.IsDoingFavor())
            SelectVictim(akActor)
        EndIf
    EndIf
EndEvent

Bool Function StartHangingScene(Actor akActor, Bool displayNotification = false)
    If (akActor == None || akActor == Game.GetPlayer()) ; TODO support player
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
    BlockActivation(true, true)
    If (displayNotification)
        BadEndsFurniture:DebugWrapper.Notification(GetDisplayName() + ": Preparing to hang " + _victim.GetDisplayName())
    EndIf
    GotoState("SetupVictim")
    Return true
EndFunction

EndState


;
; SetupVictim: Transitional helper state for setting up the victim.
;
State SetupVictim

Event OnBeginState(string asOldState)
    ; just advance to the next state
    CallFunctionNoWait("Advance", new Var[0])
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Int Function GetGallowsState()
    Return 1
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink) ; disable activation perk
    While (GetState() == "SetupVictim")
        Utility.Wait(0.016)
    EndWhile
    Return CutNoose() ; call function in new state
EndFunction

Function Advance()
    _victim.BlockActivation(true, true)
    _victim.EvaluatePackage()
    _clone = Library.CreateNakedClone(_victim, Victims)
    _clone.PlayIdle(DeadIdle)
    _cloneEquipment = Library.CloneWornArmor(_victim, _clone)
    Library.AddNooseToEquipment(_clone, _cloneEquipment) ; ignore returned armor
    _clone.SetLinkedRef(Self, GallowsLink) ; for activation perk
    GotoState("LifeVictim")
EndFunction

EndState


;
; LifeVictim: Victim is struggling on gallows.
;
State LifeVictim

Event OnBeginState(string asOldState)
    _victim.BlockActivation(false)
    If (GetParentCell().IsAttached())
        _clone.SetAlpha(1.0)
        _clone.EnableAI(false, true)
        FixClonePosition()
        _victim.MoveTo(Library.WorkshopHoldingCellMarker, 0.0, 0.0, 0.0, false)
        _clone.EnableAI(true)
        _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        StartTimer(300, TimerFixClonePosition)
    Else
        _clone.SetAlpha(1.0)
        _clone.StopTranslation()
        _clone.MoveTo(Self, DX, DY, DZ, true)
    EndIf
    StartTimer(LifeIdleTimes[_lifeIdleIndex], TimerAdvance)
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Event OnWorkshopObjectMoved(ObjectReference akReference)
    CancelTimer(TimerFixClonePosition)
    FixClonePosition()
    StartTimer(300, TimerFixClonePosition)
EndEvent

Event OnCellAttach()
    If (WaitFor3DLoad() && _clone.WaitFor3DLoad())
        _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        FixClonePosition()
        Library.RestoreWornEquipment(_clone, _cloneEquipment)
        StartTimer(300, TimerFixClonePosition)
    EndIf
EndEvent

Event OnCellDetach()
    CancelTimer(TimerFixClonePosition)
EndEvent

Int Function GetGallowsState()
    Return 1 + _lifeIdleIndex
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink)
    Actor player = Game.GetPlayer()
    _victim.MoveTo(player, 0.0, 0.0, 3072.0, false)
    _victim.WaitFor3DLoad()
    _victim.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, _victim.GetAngleZ() + 3.1416, 0.0001, 0.0001)
    _clone.EnableAI(false, true)
    _clone.StopTranslation()
    _clone.MoveTo(player, 0.0, 0.0, 2048.0, false)
    _victim.StopTranslation()
    If (DAngleZ != 0)
        _victim.SetAngle(0.0, 0.0, GetAngleZ() + DAngleZ)
    EndIf
    _victim.MoveTo(Self, DX, DY, DZ, DAngleZ == 0)
    _clone.DisableNoWait()
    Library.PlayBleedOutAnimationNoWait(_victim, 8.0)
    GotoState("Empty")
    Return true
EndFunction

Function Advance()
    If (_lifeIdleIndex + 1 < LifeIdles.Length)
        ; stay in state but advance to next animation
        _lifeIdleIndex += 1
        If (GetParentCell().IsAttached())
            _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        EndIf
        StartTimer(LifeIdleTimes[_lifeIdleIndex], TimerAdvance)
    Else
        If (GetParentCell().IsAttached())
            _clone.PlayIdle(DeadIdle)
        EndIf
        GotoState("DyingVictim")
    EndIf
EndFunction

EndState


;
; DyingVictim: Transitional helper state for dying victim.
;
State DyingVictim
    
Event OnBeginState(string asOldState)
    ; just advance to the next state
    CallFunctionNoWait("Advance", new Var[0])
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Int Function GetGallowsState()
    Return 2 + _lifeIdleIndex 
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink)
    While (GetState() == "Dying")
        Utility.Wait(0.016)
    EndWhile
    Return CutNoose() ; call function on new state
EndFunction

Function Advance()
    _victim.KillEssential(None)
    If (_victim.IsDead())
        GotoState("DeadVictim")
    Else
        ; unable to kill victim, cut noose to free victim instead
        Actor player = Game.GetPlayer()
        _victim.MoveTo(player, 0.0, 0.0, 3072.0, false)
        _victim.WaitFor3DLoad()
        _victim.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, _victim.GetAngleZ() + 3.1416, 0.0001, 0.0001)
        _clone.EnableAI(false, true)
        _clone.StopTranslation()
        _clone.MoveTo(player, 0.0, 0.0, 2048.0, false)
        _victim.StopTranslation()
        If (DAngleZ != 0)
            _victim.SetAngle(0.0, 0.0, GetAngleZ() + DAngleZ)
        EndIf
        _victim.MoveTo(Self, DX, DY, DZ, true)
        _clone.DisableNoWait()
        Library.PlayBleedOutAnimationNoWait(_victim, 8.0)
        GotoState("Empty")
    EndIf
EndFunction

EndState


;
; DeadVictim: Corpse is hanging on gallows
;
State DeadVictim

Event OnBeginState(string asOldState)
    If (GetParentCell().IsAttached())
        _clone.SetUnconscious(true)
    Else
        _clone.StopTranslation()
        _clone.MoveTo(Self, DX, DY, DZ, false)
    EndIf
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Event OnWorkshopObjectMoved(ObjectReference akReference)
    CancelTimer(TimerFixClonePosition)
    FixClonePosition()
    StartTimer(300, TimerFixClonePosition)
EndEvent

Event OnCellAttach()
    If (WaitFor3DLoad() && _clone.WaitFor3DLoad())
        _clone.PlayIdle(DeadIdle)
        _clone.SetUnconscious(true)
        FixClonePosition()
        Library.RestoreWornEquipment(_clone, _cloneEquipment)
        StartTimer(300, TimerFixClonePosition)
    EndIf
EndEvent

Event OnCellDetach()
    CancelTimer(TimerFixClonePosition)
EndEvent

Int Function GetGallowsState()
    Return -1
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink)
    Actor player = Game.GetPlayer()
    If (GetParentCell().IsAttached())
        Float currentZ = _clone.Z
        Float lastZ = _clone.Z + 1 ; initialize to value > currentZ
        _clone.StopTranslation()
        _clone.SetValue(Paralysis, 1)
        Int waitCount = 0
        While (lastZ > currentZ && waitCount < 180)
            Utility.Wait(0.016)
            lastZ = currentZ
            currentZ = _clone.Z
            waitCount += 1
        EndWhile
        PushActorAway(_clone, 0) ; wait for ground hit to start ragdolling
        Utility.Wait(3.0) ; heuristic time to finish ragdolling
        _clone.DisableNoWait()
        _victim.MoveTo(_clone, 0, 0, 0, true)
    Else
        _clone.DisableNoWait()
        _victim.MoveTo(Self, DX, DY, DZ, true)
    EndIf
    GotoState("Empty")
    Return true
EndFunction

Function Advance()
EndFunction

EndState
