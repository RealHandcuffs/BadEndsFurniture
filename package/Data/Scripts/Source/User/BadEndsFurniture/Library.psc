;
; Script with general functions.
;
Scriptname BadEndsFurniture:Library extends Quest

Action Property ActionBleedoutStart Auto Const Mandatory
Action Property ActionBleedoutStop Auto Const Mandatory
ActorBase Property CloneHumanGhoul Auto Const
Armor Property NooseCollarArmor Auto Const Mandatory
Armor[] Property WristRopeArmorArray Auto Const Mandatory
FormList Property RaceHumanGhoulList Auto Const Mandatory
Keyword Property ImmuneToHoldupKeyword Auto Const Mandatory
LeveledActor Property TemplateCloneHumanGhoul Auto Const
ObjectReference Property WorkshopHoldingCellMarker Auto Const Mandatory

Bool _cloneLock = false

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
    Actor clone = CreateInvisibleClone(akActor, refCollectionAliasToAdd)
    Return SetUpAdvancedClonePropertiesGlobal(akActor, clone, SoftDependencies, ImmuneToHoldupKeyword)
EndFunction

Actor Function CreateInvisibleClone(Actor akActor, RefCollectionAlias refCollectionAliasToAdd)
    Actor player = Game.GetPlayer()
    ActorBase leveledActorBase = akActor.GetLeveledActorBase()
    ActorBase cloneBase = leveledActorBase.GetTemplate(true)
    If (cloneBase == None)
        cloneBase = leveledActorBase
    EndIf
    Actor clone
    Bool releaseLock = false
    If (RaceHumanGhoulList.HasForm(cloneBase.GetRace()))
        ; prefer to use leveled actor base cloning procedure
        Int waitCount = 0
        While (_cloneLock && waitCount < 30)
            Utility.WaitMenuMode(0.1)
            waitCount += 1
        EndWhile
        _cloneLock = true
        releaseLock = true
        TemplateCloneHumanGhoul.Revert()
        TemplateCloneHumanGhoul.AddForm(cloneBase as Form, 1)
        clone = player.PlaceAtMe(CloneHumanGhoul, 1, false, true, false) as Actor
    Else
        ; fall back to direct cloning
        clone = player.PlaceAtMe(cloneBase, 1, false, true, false) as Actor
        clone.RemoveFromAllFactions()
        clone.SetValue(Game.GetAggressionAV(), 0)
    EndIf
    If (refCollectionAliasToAdd != None)
        refCollectionAliasToAdd.AddRef(clone) ; for AI package
    EndIf
    clone.SetGhost(true)
    clone.BlockActivation(true, true)
    clone.MoveTo(player, 0.0, 0.0, 3072.0, false)
    clone.EnableNoWait()
    If (releaseLock)
        _cloneLock = false ; only after clone has been enabled
    EndIf
    clone.WaitFor3DLoad()
    clone.SetAlpha(0.0)
    clone.MoveTo(player, 0.0, 0.0, 512.0, false)
    clone.TranslateTo(player.X, player.Y, player.Z + 3072.0, 0.0, 0.0, clone.GetAngleZ() + 3.1416, 10000, 0.0001)
    Return clone
EndFunction

Actor Function SetUpAdvancedClonePropertiesGlobal(Actor akActor, Actor clone, BadEndsFurniture:SoftDependencies sdeps, Keyword immuneToHoldupKeyword) Global
    clone.RemoveAllItems()
    sdeps.PrepareCloneForAnimation(akActor, clone)
    String actorDisplayName = akActor.GetDisplayName()
    If (clone.GetDisplayName() != actorDisplayName)
        LL_FourPlay.ObjectReferenceSetSimpleDisplayName(clone, actorDisplayName)
    EndIf
    clone.AddKeyword(immuneToHoldupKeyword)
    Return clone
EndFunction


; struct for worn equipment
Struct EquippedItem
    Form BaseItem = None
    ObjectReference Item = None
    Bool IsSpecialItem = False
EndStruct


; clone the worn armor of an actor and add it to another actor, usually a clone
EquippedItem[] Function CloneWornArmor(Actor akActor, Actor clone, Bool equipClonedArmor)
    Return CloneWornArmorGlobal(akActor, clone, SoftDependencies, equipClonedArmor, NooseCollarArmor)
EndFunction

EquippedItem[] Function CloneWornArmorGlobal(Actor akActor, Actor clone, BadEndsFurniture:SoftDependencies sdeps, Bool equipClonedArmor, Armor dummyArmor) Global
    EquippedItem[] clonedArmor = new EquippedItem[0]
    Int slotIndex = 0
    Armor[] foundArmor = new Armor[0]
    While (slotIndex <= 31) ; follow precedence low-to-high for detecting items
        Armor baseItem = akActor.GetWornItem(slotIndex).Item as Armor
        If (baseItem != None)
            While (clonedArmor.Length < slotIndex)
                clonedArmor.Add(new EquippedItem)
                foundArmor.Add(dummyArmor) ; because None is causing issues
            EndWhile
            EquippedItem e = new EquippedItem
            e.BaseItem = baseItem
            Int existingIndex = foundArmor.Find(baseItem)
            If (existingIndex < 0)
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
                e.IsSpecialItem = sdeps.IsSpecialItem(baseItem)
            Else
                e.Item = clonedArmor[existingIndex].Item
                e.IsSpecialItem = clonedArmor[existingIndex].IsSpecialItem
            EndIf
            clonedArmor.Add(e)
            foundArmor.Add(baseItem)
        EndIf
        slotIndex += 1
    EndWhile
    If (equipClonedArmor)
        RestoreWornEquipmentGlobal(akActor, clonedArmor, sdeps, false, None)
    EndIf
    Return clonedArmor
EndFunction


; Add wrist ropes the worn equipment of an actor
Int Function AddWristRopesToEquipment(Actor akActor, EquippedItem[] wornEquipment, Bool doEquip)
    Return AddWristRopesToEquipmentGlobal(akActor, wornEquipment, WristRopeArmorArray, doEquip)
EndFunction

Int Function AddWristRopesToEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, Armor[] armorArray, Bool doEquip) Global
    Int startSlotIndex = 32 - armorArray.Length
    Int slotIndex = startSlotIndex
    While (slotIndex <= 31) ; follow precedence low-to-high
        While (wornEquipment.Length <= slotIndex)
            wornEquipment.Add(new EquippedItem)
        EndWhile
        EquippedItem e = wornEquipment[slotIndex]
        If (e.BaseItem == None)
            e.BaseItem = armorArray[slotIndex - startSlotIndex]
            If (doEquip)
                akActor.EquipItem(e.BaseItem, true, true)
            EndIf
            Return slotIndex
        EndIf
        slotIndex += 1
    EndWhile
    Return -1
EndFunction


; Add noose collar rope to the worn equipment of an actor
Int Function AddNooseCollarRopeToEquipment(Actor akActor, EquippedItem[] wornEquipment, Bool doEquip)
    Return AddNooseCollarRopeToEquipmentGlobal(akActor, wornEquipment, NooseCollarArmor, doEquip)
EndFunction

Int Function AddNooseCollarRopeToEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, Armor nooseCollarArmor, Bool doEquip) Global
    Int slotIndex = 16
    While (wornEquipment.Length <= slotIndex)
        wornEquipment.Add(new EquippedItem)
    EndWhile
    EquippedItem e = wornEquipment[slotIndex]
    If (e.BaseItem == None)
        e.BaseItem = nooseCollarArmor
        If (doEquip)
            akActor.EquipItem(e.BaseItem, true, true)
        EndIf
        Return slotIndex
    EndIf
    Return -1
EndFunction


; restore the worn armor of an actor, necessary when the cell has been loaded or when it has not been restored when cloning worn armor
Function RestoreWornEquipment(Actor akActor, EquippedItem[] wornEquipment, Bool cleanUp, ObjectReference akOtherContainer = None)
    RestoreWornEquipmentGlobal(akActor, wornEquipment, SoftDependencies, akOtherContainer)
EndFunction

Function RestoreWornEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, BadEndsFurniture:SoftDependencies sdeps, Bool cleanUp, ObjectReference akOtherContainer = None) Global
    Form[] baseItemsToKeep = new Form[0]
    If (cleanUp)
        sdeps.AddItemsToKeep(baseItemsToKeep)
    Endif
    Int pass = 0 ; first pass: regular items, second pass: special items
    Bool hasSpecialItems = false
    Form[] processedItems = new Form[0]
    While (pass == 0 || pass == 1 && hasSpecialItems)
        If (hasSpecialItems)
            Utility.Wait(0.1) ; allow time for pending events to finish
        EndIf
        Int slotIndex = wornEquipment.Length - 1
        While (slotIndex >= 0) ; use reverse precedence high-to-low for equipping items
            EquippedItem e = wornEquipment[slotIndex]
            If (e.BaseItem != None)
                Bool isSpecialItem = e.IsSpecialItem
                hasSpecialItems = hasSpecialItems || isSpecialItem
                If ((pass == 0 && !isSpecialItem || pass == 1 && isSpecialItem) && processedItems.Find(e.BaseItem) < 0)
                    If (cleanUp)
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
                        baseItemsToKeep.Add(e.BaseItem)
                    Endif
                    If (!isSpecialItem || !sdeps.EquipSpecialItem(akActor, e.BaseItem, e.Item))
                        akActor.EquipItem(e.BaseItem, true, true)
                    EndIf
                    processedItems.Add(e.BaseItem)
                EndIf
            EndIf
            slotIndex -= 1
        EndWhile
        pass += 1
    EndWhile
    If (cleanUp)
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
    EndIf
EndFunction


; unequip worn armor of an actor
Function UnequipWornEquipment(Actor akActor, EquippedItem[] wornEquipment, Bool specialItemsOnly)
    UnequipWornEquipmentGlobal(akActor, wornEquipment, SoftDependencies, specialitemsOnly)
EndFunction

Function UnequipWornEquipmentGlobal(Actor akActor, EquippedItem[] wornEquipment, BadEndsFurniture:SoftDependencies sdeps, Bool specialitemsOnly) Global
    Int pass = 0 ; first pass: special items, second pass: regular items
    Bool hasRegularItems = false
    Form[] processedItems = new Form[0]
    While (pass == 0 || pass == 1 && hasRegularItems && !specialItemsOnly)
        If (hasRegularItems)
            Utility.Wait(0.1) ; allow time for pending events to finish
        EndIf
        Int slotIndex = 0
        While (slotIndex < wornEquipment.Length) ; use precedence low-to-high for unequipping items
            EquippedItem e = wornEquipment[slotIndex]
            If (e.BaseItem != None)
                Bool isSpecialItem = e.IsSpecialItem
                hasRegularItems = hasRegularItems || !isSpecialItem
                If ((pass == 0 && isSpecialItem || pass == 1 && !isSpecialItem) && processedItems.Find(e.BaseItem) < 0)
                    If (!isSpecialItem || !sdeps.UnequipSpecialItem(akActor, e.BaseItem, e.Item))
                        akActor.UnequipItem(e.BaseItem, true, true)
                    EndIf
                    processedItems.Add(e.BaseItem)
                EndIf
            EndIf
            slotIndex += 1
        EndWhile
        pass += 1
    EndWhile
EndFunction


; transfer non-worn equipment from corpse of actor to corpse of clone
Function TransferNonWornEquipmentAfterDeath(Actor akActor, Actor clone, EquippedItem[] cloneWornEquipment)
    TransferNonWornEquipmentAfterDeathGlobal(akActor, clone, cloneWornEquipment)
EndFunction

Function TransferNonWornEquipmentAfterDeathGlobal(Actor akActor, Actor clone, EquippedItem[] cloneWornEquipment) Global
    Int slotIndex = cloneWornEquipment.Length - 1
    Form[] processedItems = new Form[0]
    While (slotIndex >= 0) ; use reverse precedence high-to-low for removing items
        EquippedItem e = cloneWornEquipment[slotIndex]
        If (e.BaseItem != None && processedItems.Find(e.BaseItem) < 0)
            akActor.RemoveItem(e.BaseItem, 1, true, None)
            processedItems.Add(e.BaseItem)
        EndIf
        slotIndex -= 1
    EndWhile
    akActor.RemoveAllItems(clone, true)
EndFunction
