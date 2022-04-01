;
; Script with general functions.
;
Scriptname BadEndsFurniture:Library extends Quest

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
Armor[] Property NooseArmor Auto Const Mandatory
ObjectReference Property WorkshopHoldingCellMarker Auto Const Mandatory

BadEndsFurniture:SoftDependencies Property SoftDependencies
    BadEndsFurniture:SoftDependencies Function Get()
        Return (Self as Quest) as BadEndsFurniture:SoftDependencies
    EndFunction
EndProperty


; play the bleedout animation for an actor, do not wait
Function PlayBleedOutAnimationNoWait(Actor akActor, Float bleedoutTime)
    Var[] args = new Var[2]
    args[0] = akActor
    args[1] = bleedoutTime
    CallFunctionNoWait("PlayBleedOutAnimation", args)
EndFunction

; play the bleedout animation for an actor, wait until it is complete
Function PlayBleedOutAnimation(Actor akActor, Float bleedoutTime)
    PlayBleedOutAnimationGlobal(akActor, bleedoutTime, ActionBleedoutStart, ActionBleedoutStop)
EndFunction

Function PlayBleedOutAnimationGlobal(Actor akActor, Float bleedoutTime, Action bleedoutStart, Action bleedoutStop) Global
    akActor.PlayIdleAction(bleedoutStart)
    Utility.Wait(bleedoutTime)
    akActor.PlayIdleAction(bleedoutStop)
EndFunction


; create a naked clone of an actor, the clone will end up as an invisible (alpha = 0.0) ghost in a translation
Actor Function CreateNakedClone(Actor akActor, RefCollectionAlias refCollectionAliasToAdd = None)
    Return CreateNakedCloneGlobal(akActor, refCollectionAliasToAdd, SoftDependencies)
EndFunction

Actor Function CreateNakedCloneGlobal(Actor akActor, RefCollectionAlias refCollectionAliasToAdd, BadEndsFurniture:SoftDependencies sdeps) Global
    ActorBase leveledActorBase = akActor.GetLeveledActorBase()
    ActorBase cloneBase = leveledActorBase.GetTemplate(true)
    If (cloneBase == None)
        cloneBase = leveledActorBase
    EndIf
    Actor player = Game.GetPlayer()
    Actor clone = player.PlaceAtMe(cloneBase, 1, false, true, false) as Actor ; initially disabled
    clone.RemoveFromAllFactions()
    clone.SetValue(Game.GetAggressionAV(), 0)
    If (refCollectionAliasToAdd != None)
        refCollectionAliasToAdd.AddRef(clone) ; for AI package
    EndIf
    clone.SetGhost(true)
    clone.BlockActivation(true, true)
    clone.MoveTo(player, 0.0, 0.0, 2048.0, false)
    clone.EnableNoWait()
    clone.WaitFor3DLoad()
    clone.TranslateTo(player.X, player.Y, player.Z + 2048.0, 0.0, 0.0, clone.GetAngleZ() + 3.1416, 0.0001, 0.0001) ; stay in positon
    clone.SetAlpha(0.0)
    clone.RemoveAllItems()
    sdeps.PrepareCloneForAnimation(akActor, clone)
    String actorDisplayName = akActor.GetDisplayName()
    If (clone.GetDisplayName() != actorDisplayName)
        LL_FourPlay.ObjectReferenceSetSimpleDisplayName(clone, actorDisplayName)
    EndIf
    Return clone
EndFunction


; struct for worn equipment
Struct EquippedItem
    Form baseItem = None
    ObjectReference item = None
EndStruct


; clone the worn armor of an actor and equip it on another actor, usually a clone
EquippedItem[] Function CloneWornArmor(Actor akActor, Actor clone)
    Return CloneWornArmorGlobal(akActor, clone, SoftDependencies)
EndFunction

EquippedItem[] Function CloneWornArmorGlobal(Actor akActor, Actor clone, BadEndsFurniture:SoftDependencies sdeps) Global
    EquippedItem[] clonedArmor = new EquippedItem[0]
    Int slotIndex = 0
    While (slotIndex <= 31) ; follow precedence low-to-high for detecting items
        Armor baseItem = akActor.GetWornItem(slotIndex).Item as Armor
        If (baseItem != None)
            While (clonedArmor.Length < slotIndex)
                clonedArmor.Add(new EquippedItem)
            EndWhile
            EquippedItem e = new EquippedItem
            e.BaseItem = baseItem
            ObjectMod[] objectMods = akActor.GetWornItemMods(slotIndex)
            If (objectMods.Length > 0)
                ObjectReference item = clone.PlaceAtMe(baseItem, 1, false, true, false) ; initially disabled
                item.RemoveAllMods()
                Int modIndex = 0
                While (modIndex < objectMods.Length)
                    item.AttachMod(objectMods[modIndex])
                    modIndex += 1
                EndWhile
                clone.AddItem(item, 1, true)
                e.Item = item
            EndIf
            clonedArmor.Add(e)
        EndIf
        slotIndex += 1
    EndWhile
    slotIndex = clonedArmor.Length - 1;
    While (slotIndex >= 0) ; use reverse precedence high-to-low for equipping items
        EquippedItem e = clonedArmor[slotIndex]
        If (e.BaseItem != None)
            If (!sdeps.EquipSpecialItem(clone, e.BaseItem, e.Item))
                clone.EquipItem(e.BaseItem, true, true)
            EndIf
        EndIf
        slotIndex -= 1
    EndWhile
    Return clonedArmor
EndFunction


; restore the worn armor of an actor, necessary when the cell has been loaded
Function RestoreWornEquipment(Actor akActor, EquippedItem[] wornEquipment)
    RestoreWornEquipmentGlobal(akActor, wornEquipment)
EndFunction

Function RestoreWornEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment) Global
    Int slotIndex = 31
    While (slotIndex >= 0) ; use reverse precedence high-to-low for equipping items
        If (slotIndex >= wornEquipment.Length)
            akActor.UnequipItemSlot(slotIndex)
        Else
            EquippedItem e = wornEquipment[slotIndex]
            If (e.BaseItem == None)
                akActor.UnequipItemSlot(slotIndex)
            Else
                If (e.Item != None)
                    Int count = akActor.GetItemCount(e.BaseItem)
                    If (count > 1)
                        e.Item.Drop()
                        akActor.UnequipItemSlot(slotIndex)
                        akActor.RemoveItem(e.BaseItem, count - 1, true, None)
                        akActor.AddItem(e.Item, 1, true)
                    EndIf
                EndIf
                akActor.EquipItem(e.BaseItem, true, true)
            EndIf
        EndIf
        slotIndex -= 1
    EndWhile
EndFunction


; Add a noose to the worn equipment of an actor
Armor Function AddNooseToEquipment(Actor akActor, EquippedItem[] wornEquipment)
    Return AddNooseToEquipmentGlobal(akActor, wornEquipment, NooseArmor)
EndFunction

Armor Function AddNooseToEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, Armor[] nArmor) Global
    Int startSlotIndex = 32 - nArmor.Length
    Int slotIndex = startSlotIndex
    While (slotIndex <= 31) ; follow precedence low-to-high
        While (wornEquipment.Length <= slotIndex)
            wornEquipment.Add(new EquippedItem)
        EndWhile
        EquippedItem e = wornEquipment[slotIndex]
        If (e.BaseItem == None)
            e.BaseItem = nArmor[slotIndex - startSlotIndex]
            akActor.EquipItem(e.BaseItem, true, true)
            Return e.BaseItem as Armor
        EndIf
        slotIndex += 1
    EndWhile
    Return None
EndFunction
