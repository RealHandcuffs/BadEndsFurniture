;
; Script for Gallows.
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
Container Property InvisibleContainer Auto Const Mandatory
RefCollectionAlias Property Victims Auto Const Mandatory
ObjectReference Property WorkshopHoldingCellMarker Auto Const Mandatory

Actor _victim
Bool _playerTeammateFlagRemoved
Int _lifeIdleIndex
ObjectReference _container

;
; Must be set to an array of idles that will play sequentially.
;
Idle[] Property LifeIdles Auto Mandatory

;
; Must contain the time for each idle in LifeIdles.
;
Float[] Property LifeIdleTimes Auto Mandatory

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

; advance to next state
Function Advance()
EndFunction

; cut the noose of a victim that is not yet dead, put it into bleedout, wait, then end bleedout
Function CutNooseOfLifeVictimAndWait(Actor akActor, Bool playerTeammateFlagRemoved, Float bleedOutTime, Action bleedoutStart, Action bleedoutStop, RefCollectionAlias vics) ; cannot be global!
    If (playerTeammateFlagRemoved)
        akActor.SetPlayerTeammate(true)
    EndIf
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

Int Property TimerAdvance = 1 AutoReadOnly

Event OnTimer(int aiTimerID)
    If (aiTimerID == TimerAdvance)
        Advance()
    EndIf
EndEvent


;
; Empty: Gallows is ready to be used.
;
State Empty

Event OnBeginState(string asOldState)
    ; setup members
    CancelTimer(TimerAdvance) ; may do nothing
    _victim = None
    _playerTeammateFlagRemoved = false
    _lifeIdleIndex = 0
    _container = None
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; show interaction or start a hanging scene
    Actor akActor = akActionRef as Actor
    If (akActor != None)
        If (akActionRef == Game.GetPlayer())
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
    While (GetState() == "SetupVictim")
        Utility.Wait(0.016)
    EndWhile
    Return CutNoose() ; call function in new state
EndFunction

Function Advance()
    If (_victim.IsPlayerTeammate())
        _playerTeammateFlagRemoved = true ; prevent drawing weapons when combat starts
        _victim.SetPlayerTeammate(false)
    EndIf
    _victim.SetRestrained(true)
    _victim.EvaluatePackage()
    GotoState("LifeVictim")
EndFunction

EndState


;
; LifeVictim: Victim is struggling on gallows.
;
State LifeVictim

Event OnBeginState(string asOldState)
    If (GetParentCell().IsAttached())
        OnCellAttach() ; animate victim
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
    Float targetX = X + DX
    Float targetY = Y + DY
    Float targetZ = Z + DZ
    Float targetAngleX = GetAngleX()
    Float targetAngleY = GetAngleY()
    Float targetAngleZ = GetAngleZ() + DAngleZ
    _victim.StopTranslation()
    _victim.MoveTo(Self, DX, DY, DZ, true)
    If (DAngleZ != 0)
        _victim.SetAngle(targetAngleX, targetAngleY, targetAngleZ)
    EndIf
    _victim.TranslateTo(targetX, targetY, targetZ + 0.1, targetAngleX, targetAngleY, targetAngleZ, 0.0001, 0.0001)
EndEvent

Event OnCellAttach()
    If (_victim.WaitFor3DLoad())
        Float targetX = X + DX
        Float targetY = Y + DY
        Float targetZ = Z + DZ
        Float targetAngleX = GetAngleX()
        Float targetAngleY = GetAngleY()
        Float targetAngleZ = GetAngleZ() + DAngleZ
        _victim.PlayIdle(LifeIdles[_lifeIdleIndex])
        _victim.MoveTo(Self, DX, DY, DZ, true)
        If (DAngleZ != 0)
            _victim.SetAngle(targetAngleX, targetAngleY, targetAngleZ)
        EndIf
        _victim.TranslateTo(targetX, targetY, targetZ + 0.1, targetAngleX, targetAngleY, targetAngleZ, 0.0001, 0.0001)
    EndIf
EndEvent

Event OnCellDetach()
    _victim.StopTranslation()
EndEvent

Int Function GetGallowsState()
    Return 1 + _lifeIdleIndex
EndFunction

Bool Function CutNoose()
    Var[] params = new Var[6]
    params[0] = _victim
    params[1] = _playerTeammateFlagRemoved
    params[2] = 8.0
    params[3] = ActionBleedoutStart
    params[4] = ActionBleedoutStop
    params[5] = Victims
    GotoState("Empty")
    CallFunctionNoWait("CutNooseOfLifeVictimAndWait", params)
    Return true
EndFunction

Function Advance()
    _lifeIdleIndex += 1
    If (_lifeIdleIndex < LifeIdles.Length)
        ; stay in state but advance to next animation
        If (GetParentCell().IsAttached())
            _victim.PlayIdle(LifeIdles[_lifeIdleIndex])
        EndIf
        StartTimer(LifeIdleTimes[_lifeIdleIndex], TimerAdvance)        
        Return
    EndIf
    GotoState("DyingVictim")
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
    While (GetState() == "Dying")
        Utility.Wait(0.016)
    EndWhile
    Return CutNoose() ; call function on new state
EndFunction

Function Advance()
    If (GetParentCell().IsAttached())
        ; this is very tricky, killing the victim will cause it to ragdoll
        ; this can be prevented by disabling AI but doing so will not register the death until AI is enabled again
        _victim.EnableAI(false, true)
        _victim.StopTranslation()
        _victim.KillEssential(None)
    Else
        ; cell is not attached, just kill victim
        _victim.StopTranslation()
        _victim.KillEssential(None)
    EndIf
    If (_victim.IsDead())
        ; done, switch state
        _victim.StopTranslation()
        GotoState("DeadVictim")
    Else
        ; failed to kill victim, free victim and go to empty state
        If (!_victim.IsAIEnabled())
            _victim.EnableAI(true)
        EndIf
        Var[] params = new Var[6]
        params[0] = _victim
        params[1] = _playerTeammateFlagRemoved
        params[2] = 8.0
        params[3] = ActionBleedoutStart
        params[4] = ActionBleedoutStop
        params[5] = Victims
        GotoState("Empty")
        CallFunctionNoWait("CutNooseOfLifeVictimAndWait", params)
    EndIf
EndFunction

EndState


;
; DeadVictim: Victim is dead
;
State DeadVictim

Event OnBeginState(string asOldState)
    If (!GetParentCell().IsAttached())
        OnCellDetach()
    EndIf
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnWorkshopObjectDestroyed(ObjectReference akActionRef)
    CutNoose()
EndEvent

Event OnWorkshopObjectMoved(ObjectReference akReference)
    OnCellDetach()
    OnCellAttach()
EndEvent

Event OnCellAttach()
    ; victim should already be resurrected, hang it and kill it again
    If (_victim.WaitFor3DLoad())
        _victim.QueueUpdate(false, 0)
        Float targetX = X + DX
        Float targetY = Y + DY
        Float targetZ = Z + DZ
        Float targetAngleX = GetAngleX()
        Float targetAngleY = GetAngleY()
        Float targetAngleZ = GetAngleZ() + DAngleZ
        _victim.PlayIdle(LifeIdles[_lifeIdleIndex - 1])
        _victim.MoveTo(Self, DX, DY, DZ, true)
        If (DAngleZ != 0)
            _victim.SetAngle(targetAngleX, targetAngleY, targetAngleZ)
        EndIf
        _victim.TranslateTo(targetX, targetY, targetZ + 0.1, targetAngleX, targetAngleY, targetAngleZ, 0.0001, 0.0001)
        Utility.Wait(1)
        _victim.EnableAI(false, true)
        _victim.StopTranslation()
        _victim.KillEssential(None)
    EndIf
EndEvent

Event OnCellDetach()
    ; resurrect victim to prepare it for OnCellAttach
    _victim.EnableAI(true)
    Armor[] wornArmors = new Armor[0]
    Int slotIndex = 0
    While (slotIndex < 32)
        Armor wornArmor = _victim.GetWornItem(slotIndex).Item as Armor
        If (wornArmor != None)
            wornArmors.Add(wornArmor)
        EndIf
        slotIndex += 1
    EndWhile
    If (_container == None)
        _container = PlaceAtMe(InvisibleContainer, 1, false, true, true)
    EndIf
    _victim.RemoveAllItems(_container)
    _victim.Resurrect()
    _victim.SetRestrained(true)
    _victim.EvaluatePackage()
    _victim.RemoveAllItems(None)
    _container.RemoveAllItems(_victim)
    Int armorIndex = 0
    While (armorIndex < wornArmors.Length)
        _victim.EquipItem(wornArmors[armorIndex], true, false)
        armorIndex += 1
    EndWhile
    ; move victim into loaded area for a quick moment to allow events to fire
    _victim.SetGhost(true)
    _victim.MoveTo(Game.GetPlayer(), 0, 0, 1024, true)
    _victim.TranslateTo(_victim.X, _victim.Y, _victim.Z, _victim.GetAngleX(), _victim.GetAngleY(), _victim.GetAngleZ(), 0.0001, 0.0001)
    _victim.WaitFor3DLoad()
    Utility.Wait(0.016)
    _victim.StopTranslation()
    _victim.MoveTo(Self)
    _victim.SetGhost(false)
EndEvent

Int Function GetGallowsState()
    Return -1
EndFunction

Bool Function CutNoose()
    If (_victim.IsDead())
        _victim.EnableAI(true)
        
    Else
        _victim.StopTranslation()
        _victim.KillEssential()
    EndIf
    _victim.MoveTo(WorkshopHoldingCellMarker)
    _victim.MoveTo(Self, 0, 0, 96 + DZ)
    If (_container != None)
        _container.Delete()
    EndIf
    GotoState("Empty")
EndFunction

EndState
