;
; Script with general functions.
;
Scriptname BadEndsFurniture:Library extends Quest

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
Armor[] Property WristRopeArmorArray Auto Const Mandatory
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
    clone.MoveTo(player, 0.0, 0.0, 3072.0, false)
    clone.EnableNoWait()
    clone.WaitFor3DLoad()
    clone.SetAlpha(0.0)
    clone.MoveTo(player, 0.0, 0.0, 512.0, false)
    clone.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, clone.GetAngleZ() + 3.1416, 10000, 0.0001)
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


; Add wrist ropes the worn equipment of an actor
Int Function AddWristRopesToEquipment(Actor akActor, EquippedItem[] wornEquipment)
    If (!SoftDependencies.DeviousDevicesInstalled)
        Return -1 ; wrist ropes model is from devious devices
    EndIf
    Return AddWristRopesToEquipmentGlobal(akActor, wornEquipment, WristRopeArmorArray)
EndFunction

Int Function AddWristRopesToEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, Armor[] armorArray) Global
    Int startSlotIndex = 32 - armorArray.Length
    Int slotIndex = startSlotIndex
    While (slotIndex <= 31) ; follow precedence low-to-high
        While (wornEquipment.Length <= slotIndex)
            wornEquipment.Add(new EquippedItem)
        EndWhile
        EquippedItem e = wornEquipment[slotIndex]
        If (e.BaseItem == None)
            e.BaseItem = armorArray[slotIndex - startSlotIndex]
            akActor.EquipItem(e.BaseItem, true, true)
            Return slotIndex
        EndIf
        slotIndex += 1
    EndWhile
    Return -1
EndFunction


; restore the worn armor of an actor, necessary when the cell has been loaded
Function RestoreWornEquipment(Actor akActor, EquippedItem[] wornEquipment, ObjectReference akOtherContainer = None)
    RestoreWornEquipmentGlobal(akActor, wornEquipment, SoftDependencies, akOtherContainer)
EndFunction

Function RestoreWornEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, BadEndsFurniture:SoftDependencies sdeps, ObjectReference akOtherContainer = None) Global
    Form[] baseItemsToKeep = new Form[0]
    sdeps.AddItemsToKeep(baseItemsToKeep)
    Int slotIndex = wornEquipment.Length - 1
    While (slotIndex >= 0) ; use reverse precedence high-to-low for equipping items
        EquippedItem e = wornEquipment[slotIndex]
        If (e.BaseItem != None)
            Int count = akActor.GetItemCount(e.BaseItem)
            If (count > 1)
                If (e.Item != None)
                    akActor.UnequipItem(e.BaseItem, true, true)
                    e.Item.Drop()
                    akActor.RemoveItem(e.BaseItem, -1, true, akOtherContainer)
                    akActor.AddItem(e.Item, 1, true)
                Else
                    akActor.RemoveItem(e.BaseItem, count - 1, true, akOtherContainer)
                EndIf
            EndIf
            akActor.EquipItem(e.BaseItem, true, true)
            baseItemsToKeep.Add(e.BaseItem)
        EndIf
        slotIndex -= 1
    EndWhile
    Form[] inventory = akActor.GetInventoryItems()
    Int index = 0
    While (index < inventory.Length)
        Form baseItem = inventory[index]
        If (baseItemsToKeep.Find(baseItem) < 0)
            If ((baseItem as Armor) != None || (baseItem as Weapon) != None)
                akActor.UnequipItem(baseItem, true, true)
            EndIf
            akActor.RemoveItem(baseItem, -1, true, akOtherContainer)
        EndIf
        index += 1
    EndWhile
EndFunction


; transfer non-worn equipment from corpse of actor to corpse of clone
Function TransferNonWornEquipmentAfterDeath(Actor akActor, Actor clone, EquippedItem[] cloneWornEquipment)
    TransferNonWornEquipmentAfterDeathGlobal(akActor, clone, cloneWornEquipment)
EndFunction

Function TransferNonWornEquipmentAfterDeathGlobal(Actor akActor, Actor clone, EquippedItem[] cloneWornEquipment) Global
    Int slotIndex = cloneWornEquipment.Length - 1
    While (slotIndex >= 0) ; use reverse precedence high-to-low for removing items
        EquippedItem e = cloneWornEquipment[slotIndex]
        If (e.BaseItem != None)
            akActor.RemoveItem(e.BaseItem, 1, true, None)
        EndIf
        slotIndex -= 1
    EndWhile
    akActor.RemoveAllItems(clone, true)
EndFunction
