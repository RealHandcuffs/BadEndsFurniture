;
; Script for Gallows.
; This script is implemented as a state maching, the different states correspond to the progress of the hanging scene.
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
Keyword Property GallowsLink Auto Const Mandatory
BadEndsFurniture:SoftDependencies Property SoftDependencies Auto Const Mandatory
RefCollectionAlias Property Victims Auto Const Mandatory
ObjectReference Property WorkshopHoldingCellMarker Auto Const Mandatory

Actor _victim
Actor _clone
Struct EquippedItem
    Form baseItem = None
    ObjectReference item = None
EndStruct
EquippedItem[] _cloneEquipment
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

; play the bleedout animation for an actor
Function PlayBleedOutAnimation(Actor akActor, Action bleedoutStart, Float bleedOutTime, Action bleedoutStop)
    akActor.PlayIdleAction(bleedoutStart)
    Utility.Wait(bleedOutTime)
    akActor.PlayIdleAction(bleedoutStop)
    akActor.EvaluatePackage()
EndFunction

; create a visual clone of an actor
Actor Function CloneActor(Actor akActor)
    ActorBase leveledActorBase = akActor.GetLeveledActorBase()
    ActorBase cloneBase = leveledActorBase.GetTemplate(true)
    If (cloneBase == None)
        cloneBase = leveledActorBase
    EndIf
    Actor player = Game.GetPlayer()
    Actor clone = player.PlaceAtMe(cloneBase, 1, false, true, false) as Actor ; initially disabled
    clone.RemoveFromAllFactions()
    clone.SetValue(Game.GetAggressionAV(), 0)
    Victims.AddRef(clone) ; for AI package
    clone.SetGhost(true)
    clone.BlockActivation(true, true)
    clone.MoveTo(player, 0.0, 0.0, 2048.0, false)
    clone.EnableNoWait()
    clone.WaitFor3DLoad()
    clone.TranslateTo(player.X, player.Y, player.Z + 2048.0, 0.0, 0.0, clone.GetAngleZ() + 3.1416, 0.0001, 0.0001) ; stay in positon
    clone.SetAlpha(0.0)
    clone.RemoveAllItems()
    SoftDependencies.PrepareCloneForAnimation(akActor, clone)
    clone.SetLinkedRef(Self, GallowsLink) ; for activation perk
    ; TODO set name
    Return clone
EndFunction

EquippedItem[] Function CloneWornArmor(Actor akActor, Actor clone)
    EquippedItem[] clonedArmor = new EquippedItem[32]
    Int slotIndex = 31
    While (slotIndex >= 0)
        Armor baseItem = akActor.GetWornItem(slotIndex).Item as Armor
        If (baseItem != None)
            ObjectReference item = clone.PlaceAtMe(baseItem, 1, false, true, false) ; initially disabled
            item.RemoveAllMods()
            ObjectMod[] objectMods = akActor.GetWornItemMods(slotIndex)
            Int modIndex = 0
            While (modIndex < objectMods.Length)
                item.AttachMod(objectMods[modIndex])
                modIndex += 1
            EndWhile
            clone.AddItem(item, 1, true)
            If (!SoftDependencies.EquipSpecialItem(_clone, item))
                clone.EquipItem(baseItem, true, true)
            EndIf
            EquippedItem e = new EquippedItem
            e.BaseItem = baseItem
            e.Item = item
            clonedArmor[slotIndex] = e
        EndIf
        slotIndex -= 1
    EndWhile
    Return clonedArmor
EndFunction

; restore the worn armor of the clone, necessary when the cell has been loaded
Function RestoreWornArmor(Actor akActor, EquippedItem[] wornEquipment)
    Int slotIndex = wornEquipment.Length - 1
    While (slotIndex >= 0)
        EquippedItem e = wornEquipment[slotIndex]
        If (e == None)
            akActor.UnequipItemSlot(slotIndex)
        Else
            Int count = akActor.GetItemCount(e.BaseItem)
            If (count > 1)
                e.Item.Drop()
                akActor.UnequipItemSlot(slotIndex)
                akActor.RemoveItem(e.BaseItem, count - 1, true, None)
                akActor.AddItem(e.Item, 1, true)
            EndIf
            akActor.EquipItem(e.BaseItem, true, true)
        EndIf
        slotIndex -= 1
    EndWhile
EndFunction

Event OnLoad()
    GotoState("Empty") ; initialize after construction
EndEvent

Int Property TimerAdvance = 1 AutoReadOnly
Int Property TimerFixClonePosition = 2 AutoReadOnly

Event OnTimer(int aiTimerID)
    If (aiTimerID == TimerAdvance)
        Advance()
    ElseIf (aiTimerID == TimerFixClonePosition)
        If (GetParentCell().IsAttached() && _clone != None && Self.WaitFor3DLoad() && _clone.WaitFor3DLoad())
            FixClonePosition()
            StartTimer(300, TimerFixClonePosition)
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
    _cloneEquipment.Clear()
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
            BadEndsFurniture:DebugWrapper.Notification("TODO HANDLE ACTIVATE")
        ElseIf (akActor.IsDoingFavor())
            StartHangingScene(akActor, true) ; player commanded NPC to interact with gallows, hang NPC
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
    While (GetState() == "SetupVictim")
        Utility.Wait(0.016)
    EndWhile
    Return CutNoose() ; call function in new state
EndFunction

Function Advance()
    _victim.BlockActivation(true, true)
    _victim.EvaluatePackage()
    _clone = CloneActor(_victim)
    _clone.PlayIdle(DeadIdle)
    _cloneEquipment = CloneWornArmor(_victim, _clone)
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
        _victim.MoveTo(WorkshopHoldingCellMarker, 0.0, 0.0, 0.0, false)
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
        RestoreWornArmor(_clone, _cloneEquipment)
        _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        FixClonePosition()
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
    Var[] params = new Var[4]
    params[0] = _victim
    params[1] = ActionBleedoutStart
    params[2] = 8.0
    params[3] = ActionBleedoutStop
    CallFunctionNoWait("PlayBleedOutAnimation", params)
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
        Var[] params = new Var[4]
        params[0] = _victim
        params[1] = ActionBleedoutStart
        params[2] = 8.0
        params[3] = ActionBleedoutStop
        CallFunctionNoWait("PlayBleedOutAnimation", params)
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
        RestoreWornArmor(_clone, _cloneEquipment)
        _clone.PlayIdle(DeadIdle)
        _clone.SetUnconscious(true)
        FixClonePosition()
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
    Actor player = Game.GetPlayer()
    _clone.EnableAI(false, true)
    _clone.StopTranslation()
    _clone.MoveTo(player, 0.0, 0.0, 2048.0, false)
    _clone.DisableNoWait()
    _victim.MoveTo(Self, DX, DY, DZ, true)
    GotoState("Empty")
    Return true
EndFunction

Function Advance()
EndFunction

EndState
