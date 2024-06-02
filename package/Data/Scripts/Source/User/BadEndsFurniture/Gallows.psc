;
; Script for Gallows.
; This script is implemented as a state maching, the different states correspond to the progress of the hanging scene.
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

ActorValue Property Paralysis Auto Const Mandatory
BadEndsFurniture:Library Property Library Auto Const Mandatory
Keyword Property GallowsLink Auto Const Mandatory
Keyword Property PlayerSelectVictimLink Auto Const Mandatory
Keyword Property VATSRestrictedTargetKeyword Auto Const Mandatory
Keyword Property WeaponTypeExplosive Auto Const Mandatory
Message Property AbortingVictimSelection Auto Const Mandatory
Message Property HangYourself Auto Const Mandatory
Message Property PreparingHangingScene Auto Const Mandatory
Message Property SelectVictimToHang Auto Const Mandatory
RefCollectionAlias Property Victims Auto Const Mandatory
VoiceType Property NpcNoLines Auto Const Mandatory

Actor _victim
Actor _clone
Library:EquippedItem[] _cloneEquipment
Int _cloneWristRopesSlotIndex
Int _cloneNooseCollarSlotIndex
Int _lifeIdleIndex
Bool _handlingCellAttach
Bool _handlingDeferredKill
Int _version

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
; When set to true, the corpse of the original victim is teleported in when cutting down the corpse.
; Otherwise the corpse of the clone is kept but the equipment of the victim is moved to the clone.
;
Bool Property TeleportInOriginalVictimCorpse = False Auto

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
        Actor player = Game.GetPlayer()
        If (player.GetLinkedRef(PlayerSelectVictimLink) == Self)
            CancelTimer(TimerSelectVictimAbort)
            player.SetLinkedRef(None, PlayerSelectVictimLink)
        EndIf
        ; TODO verify that victim is valid
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
        clone.TranslateTo(targetX, targetY, targetZ, 0.0, 0.0, targetAngleZ + 0.0524, 10000, 0.0001)
    EndIf
EndFunction

Event OnLoad()
    GotoState("Empty") ; initialize after construction
EndEvent

Event Actor.OnDeferredKill(Actor sender, Actor akKiller)
    If (sender != _clone)
        UnregisterForRemoteEvent(sender, "OnDeferredKill") ; not expected but handle it
    EndIf
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
    ; do nothing
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
            AbortingVictimSelection.Show()
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
        UnregisterForAllHitEvents(_clone)                  ; may do nothing
        UnregisterForRemoteEvent(_clone, "OnDeferredKill") ; same
        Victims.RemoveRef(_clone)
        _clone.DisableNoWait(false)
        _clone.Delete()
        _clone = None
    EndIf
    _cloneEquipment = None
    _cloneWristRopesSlotIndex = -1
    _cloneNooseCollarSlotIndex = -1
    _lifeIdleIndex = 0
    _handlingCellAttach = false
    _handlingDeferredKill = false
    _version = 1
    BlockActivation(false)
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event Actor.OnDeferredKill(Actor sender, Actor akKiller)
    ; do nothing
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
    ; do nothing
EndEvent

Event OnActivate(ObjectReference akActionRef)
    ; show interaction or start a hanging scene
    Actor akActor = akActionRef as Actor
    If (akActor != None)
        Actor player = Game.GetPlayer()
        If (akActionRef == player)
            ObjectReference linked = akActor.GetLinkedRef(PlayerSelectVictimLink)
            If (linked == Self)
                If (HangYourself.Show() == 0)
                    SelectVictim(player)
                Else
                    CancelTimer(TimerSelectVictimAbort)
                    akActor.SetLinkedRef(None, PlayerSelectVictimLink)
                    AbortingVictimSelection.Show()
                EndIf
            Else
                akActor.SetLinkedRef(Self, PlayerSelectVictimLink)
                SelectVictimToHang.Show()
                StartTimer(15.0, TimerSelectVictimAbort)
            EndIf
        ElseIf (akActor.IsDoingFavor())
            SelectVictim(akActor)
        EndIf
    EndIf
EndEvent

Bool Function StartHangingScene(Actor akActor, Bool displayNotification = false)
    If (akActor == None)
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
        PreparingHangingScene.Show()
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

Event Actor.OnDeferredKill(Actor sender, Actor akKiller)
    ; do nothing
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
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
    If (_victim.IsInPowerArmor())
        _victim.SwitchToPowerArmor(None)
    EndIf
    Actor player = Game.GetPlayer()
    If (_victim == player)
        Game.SetPlayerAIDriven(true)
    EndIf
    _victim.BlockActivation(true, true)
    _victim.EvaluatePackage()
    If (_victim == player)
        If (!GetParentCell().IsAttached())
            Float angleZ = GetAngleZ() + DAngleZ
            player.MoveTo(Self, DX + Math.Sin(angleZ) * 192.0, DY + Math.Cos(angleZ) * 192.0, DZ, true)
            Int waitCount = 0
            While (waitCount < 30 && !GetParentCell().IsAttached())
                Utility.Wait(1.0)
                waitCount += 1
            EndWhile
        EndIf
    ElseIf (!_victim.GetParentCell().IsAttached())
        _victim.MoveTo(player, 0.0, 0.0, 512.0, false)
        _victim.TranslateTo(player.X, player.Y, player.Z + 512.0, 0.0, 0.0, _victim.GetAngleZ() + 3.1416, 10000, 0.0001)
        _victim.SetAlpha(0.0)
        Utility.Wait(3.0) ; heuristic
    EndIf
    _clone = Library.CreateNakedClone(_victim, Victims)
    _clone.PlayIdle(DeadIdle)
    _cloneEquipment = Library.CloneWornArmor(_victim, _clone, false)
    If (!Library.SoftDependencies.IsWearingWristRestraints(_victim))
        _cloneWristRopesSlotIndex = Library.AddWristRopesToEquipment(_clone, _cloneEquipment, false)
    EndIf
    _cloneNooseCollarSlotIndex = Library.AddNooseCollarRopeToEquipment(_clone, _cloneEquipment, false)
    Library.RestoreWornEquipment(_clone, _cloneEquipment, false)
    Utility.Wait(0.1)
    _clone.SetLinkedRef(Self, GallowsLink) ; for activation perk
    GotoState("LifeVictim")
EndFunction

EndState


;
; LifeVictim: Victim is struggling on gallows.
;
State LifeVictim

Event OnBeginState(string asOldState)
    Actor player = Game.GetPlayer()
    _victim.BlockActivation(false)
    RegisterForRemoteEvent(_clone, "OnDeferredKill")
    RegisterForHitEvent(_clone)
    _clone.StartDeferredKill()
    _clone.IgnoreFriendlyHits(true)
    If (_victim == player || GetParentCell().IsAttached())
        _clone.SetAlpha(1.0)
        _clone.EnableAI(false, true)
        FixClonePosition()
        If (_victim == player)
            Game.SetPlayerAIDriven(false)
            LL_FourPlay.SetFlyCam(true)
        Else
            _victim.StopTranslation()
            _victim.SetAlpha(1.0)
            _victim.MoveTo(Library.WorkshopHoldingCellMarker, 0.0, 0.0, 0.0, false)
        EndIf
        _clone.EnableAI(true)
        _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        StartTimer(300, TimerFixClonePosition)
    Else
        _victim.StopTranslation()
        _victim.SetAlpha(1.0)
        _victim.MoveTo(Library.WorkshopHoldingCellMarker, 0.0, 0.0, 0.0, false)
        _clone.SetAlpha(1.0)
        _clone.StopTranslation()
        _clone.MoveTo(Self, DX, DY, DZ, true)
    EndIf
    StartTimer(LifeIdleTimes[_lifeIdleIndex], TimerAdvance)
    BlockActivation(false)
    _clone.SetGhost(false)
    If (_victim.IsDead())
        _handlingDeferredKill = true
        Var[] args = new Var[1]
        args[0] = "DyingVictim"
        CallFunctionNoWait("GotoState", args)
    EndIf
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event Actor.OnDeferredKill(Actor sender, Actor akKiller)
    If (sender == _clone)
        If (!_handlingDeferredKill)
            _handlingDeferredKill = true
            GotoState("DyingVictim")
        EndIf
    Else
        UnregisterForRemoteEvent(sender, "OnDeferredKill") ; not expected but handle it
    EndIf
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
    If (akTarget == _clone)
        If (_handlingDeferredKill)
            _clone.PlayIdle(DeadIdle)
        Else
            _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
        EndIf
        If (akSource != None && akSource.HasKeyword(WeaponTypeExplosive))
            Utility.Wait(0.25)
            CutNoose()
        Else
            RegisterForHitEvent(_clone)
        EndIf
    EndIf
EndEvent

Event OnActivate(ObjectReference akActionRef)
    CutNoose()
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
    _handlingCellAttach = true
    If (WaitFor3DLoad() && _clone.WaitFor3DLoad())
        FixClonePosition()
        StartTimer(300, TimerFixClonePosition)
        Library.RestoreWornEquipment(_clone, _cloneEquipment, true)
        Utility.Wait(0.1)
        _clone.PlayIdle(LifeIdles[_lifeIdleIndex])
    EndIf
    _handlingCellAttach = false
EndEvent

Event OnCellDetach()
    CancelTimer(TimerFixClonePosition)
    Library.UnequipWornEquipment(_clone, _cloneEquipment, true)
EndEvent

Int Function GetGallowsState()
    Return 1 + _lifeIdleIndex
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink)
    CancelTimer(TimerAdvance)
    Actor player = Game.GetPlayer()
    If (_victim == player)
        Float currentZ = _clone.Z
        Float lastZ = _clone.Z + 1 ; initialize to value > currentZ
        Float previousLastZ = lastZ
        _clone.StopTranslation()
        Utility.Wait(0.1)
        Int waitCount = 0
        While ((lastZ > currentZ || previousLastZ > lastZ) && waitCount < 600)
            Utility.Wait(0.016)
            previousLastZ = lastZ
            lastZ = currentZ
            currentZ = _clone.Z
            waitCount += 1
        EndWhile
        If (!_handlingDeferredKill)
            Library.PlayBleedOutAnimation(_clone, 8.0)
            Utility.Wait(1.9)
            player.TranslateToRef(_clone, 10000, 10000)
            Utility.Wait(0.1)
            LL_FourPlay.SetFlyCam(false)
            _clone.DisableNoWait()
        EndIf
    Else
        _victim.MoveTo(player, 0.0, 0.0, 3072.0, false)
        _victim.WaitFor3DLoad()
        _victim.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, _victim.GetAngleZ() + 3.1416, 0.0001, 0.0001)
        _clone.EnableAI(false, true)
        _clone.StopTranslation()
        _clone.MoveTo(player, 0.0, 0.0, 4096.0, false)
        _victim.StopTranslation()
        If (DAngleZ != 0)
            _victim.SetAngle(0.0, 0.0, GetAngleZ() + DAngleZ)
        EndIf
        _victim.MoveTo(Self, DX, DY, DZ, DAngleZ == 0)
        _clone.DisableNoWait()
        Library.PlayBleedOutAnimationNoWait(_victim, 8.0)
    EndIf
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
    CancelTimer(TimerAdvance)
    CallFunctionNoWait("Advance", new Var[0])
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
    If (akTarget == _clone)
        _clone.PlayIdle(DeadIdle)
        If (akSource != None && akSource.HasKeyword(WeaponTypeExplosive))
            CutNoose()
        Else
            RegisterForHitEvent(_clone)
        EndIf
    EndIf
EndEvent

Event OnActivate(ObjectReference akActionRef)
    CutNoose()
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
    Actor player = Game.GetPlayer()
    If (_victim == player)
        player.TranslateToRef(_clone, 10000, 10000)
        Utility.Wait(0.2)
        player.SetAlpha(0.0)
    EndIf
    _victim.EndDeferredKill()
    _victim.KillEssential(None)
    If (_victim.IsDead())
        GotoState("DeadVictim")
    Else
        ; unable to kill victim, cut noose to free victim instead
        _victim.MoveTo(player, 0.0, 0.0, 3072.0, false)
        _victim.WaitFor3DLoad()
        _victim.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, _victim.GetAngleZ() + 3.1416, 0.0001, 0.0001)
        _clone.EnableAI(false, true)
        _clone.StopTranslation()
        _clone.MoveTo(player, 0.0, 0.0, 4096.0, false)
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
    _clone.AddKeyword(VATSRestrictedTargetKeyword)
    _clone.SetOverrideVoiceType(NpcNoLines)
    If (GetParentCell().IsAttached())
        _clone.PlayIdle(DeadIdle)
        Utility.Wait(0.25)
        _clone.SetUnconscious(true)
    Else
        _clone.StopTranslation()
        _clone.MoveTo(Self, DX, DY, DZ, false)
    EndIf
    BlockActivation(false)
    UnregisterForRemoteEvent(_clone, "OnDeferredKill")
    If (_clone.IsDismembered("Head1"))
        CallFunctionNoWait("CutNoose", new Var[0])
    EndIf
EndEvent

Event OnLoad()
    ; do nothing
EndEvent

Event OnHit(ObjectReference akTarget, ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked, String apMaterial)
    If (akTarget == _clone)
        _clone.PlayIdle(DeadIdle)
        If (akSource != None && akSource.HasKeyword(WeaponTypeExplosive))
            CutNoose()
        Else
            RegisterForHitEvent(_clone)
        EndIf
    EndIf
EndEvent

Event OnActivate(ObjectReference akActionRef)
    CutNoose()
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
        _handlingCellAttach = true
        If (_version < 1) ; upgrade gallows on cell attach if necessary
            Int slotIndex = 0
            Armor[] foundArmor = new Armor[0]
            While (slotIndex < _cloneEquipment.Length)
                Library:EquippedItem e = _cloneEquipment[slotIndex]
                Armor baseArmor = e.BaseItem as Armor
                If (baseArmor != None)
                    Int existingIndex = foundArmor.Find(baseArmor)
                    If (existingIndex < 0)
                        If (baseArmor != None && Library.SoftDependencies.IsSpecialItem(baseArmor))
                            e.IsSpecialitem = true
                        EndIf
                    Else
                        e.Item = _cloneEquipment[existingIndex].Item
                        e.IsSpecialItem = _cloneEquipment[existingIndex].IsSpecialItem
                    EndIf
                    foundArmor.Add(baseArmor)
                Else
                    foundArmor.Add(Library.NooseCollarArmor) ; because None is causing issues
                EndIf
                slotIndex += 1
            EndWhile
            If (_cloneWristRopesSlotIndex < 0 && !Library.SoftDependencies.IsWearingWristRestraints(_clone))
                _cloneWristRopesSlotIndex = Library.AddWristRopesToEquipment(_clone, _cloneEquipment, false)
            EndIf
            If (_cloneNooseCollarSlotIndex == 0)
                _cloneNooseCollarSlotIndex = Library.AddNooseCollarRopeToEquipment(_clone, _cloneEquipment, false)
            EndIf
            Library.UnequipWornEquipment(_clone, _cloneEquipment, true)
            _version = 1
        EndIf
        If (WaitFor3DLoad() && _clone.WaitFor3DLoad())
            _clone.SetOverrideVoiceType(NpcNoLines)
            _clone.SetUnconscious(false)
            FixClonePosition()
            StartTimer(300, TimerFixClonePosition)
            Library.RestoreWornEquipment(_clone, _cloneEquipment, true)
            Utility.Wait(0.1)
            _clone.PlayIdle(DeadIdle)
            Utility.Wait(0.25)
            _clone.SetUnconscious(true)
        EndIf
        _handlingCellAttach = false
EndEvent

Event OnCellDetach()
    CancelTimer(TimerFixClonePosition)
    Library.UnequipWornEquipment(_clone, _cloneEquipment, true)
EndEvent

Int Function GetGallowsState()
    Return -1
EndFunction

Bool Function CutNoose()
    _clone.SetLinkedRef(None, GallowsLink)
    Int waitCount = 0
    While (_handlingCellAttach && waitCount < 180)
        Utility.Wait(0.016)
        waitCount += 1
    EndWhile
    Bool isAttached = GetParentCell().IsAttached()
    If (isAttached)
        Float currentZ = _clone.Z
        Float lastZ = _clone.Z + 1 ; initialize to value > currentZ
        Float previousLastZ = lastZ
        _clone.StopTranslation()
        _clone.SetValue(Paralysis, 1)
        Utility.Wait(0.1)
        waitCount = 0
        While ((lastZ > currentZ || previousLastZ > lastZ) && waitCount < 600)
            Utility.Wait(0.016)
            previousLastZ = lastZ
            lastZ = currentZ
            currentZ = _clone.Z
            waitCount += 1
        EndWhile
        PushActorAway(_clone, 0) ; wait for ground hit to start ragdolling, this prevents a bug where the victim sinks into the ground
    EndIf
    _clone.EndDeferredKill()
    If (TeleportInOriginalVictimCorpse)
        _clone.DisableNoWait()
        _victim.MoveTo(_clone, 0, 0, 0, true)
    Else
        _clone.KillEssential()
        If (_cloneWristRopesSlotIndex >= 0)
            Library:EquippedItem e = _cloneEquipment[_cloneWristRopesSlotIndex]
            _clone.UnequipItem(e.BaseItem, true, true)
            _clone.RemoveItem(e.BaseItem, 1, true, None)
            e.BaseItem = None
        EndIf
        If (_cloneNooseCollarSlotIndex >= 0)
            Library:EquippedItem e = _cloneEquipment[_cloneNooseCollarSlotIndex]
            _clone.UnequipItem(e.BaseItem, true, true)
            _clone.RemoveItem(e.BaseItem, 1, true, None)
            e.BaseItem = None
        EndIf
        Library.TransferNonWornEquipmentAfterDeath(_victim, _clone, _cloneEquipment)
        _clone.BlockActivation(false)
        _clone.SetGhost(false)
        Victims.RemoveRef(_clone)
        _clone = None
    EndIf
    GotoState("Empty")
    Return true
EndFunction

Function Advance()
EndFunction

EndState
