;
; Script handling soft dependencies.
;
Scriptname BadEndsFurniture:SoftDependencies extends Quest

Activator Property Gallows Auto Const Mandatory

Bool Property RealHandcuffsInstalled = False Auto
Bool Property DeviousDevicesInstalled = False Auto

Group Plugins
    String Property RealHandcuffsEsp = "RealHandcuffs.esp" AutoReadOnly
    String Property DeviousDevicesEsm = "Devious Devices.esm" AutoReadOnly
EndGroup

Group RealHandcuffs
    Quest Property RH_MainQuest = None Auto
    Keyword Property RH_NoPackage = None Auto
EndGroup

Group DeviousDevices
    Keyword Property DD_kw_ItemType_WristCuffs = None Auto
EndGroup

;
; Clear soft dependencies - this will force Refresh() to do something in the next call.
;
Function Clear()
    RealHandcuffsInstalled = false
    DeviousDevicesInstalled = false
EndFunction

;
; Refresh soft dependencies.
;
Function Refresh()
    Bool oldRealHandcuffsInstalled = RealHandcuffsInstalled
    RealHandcuffsInstalled = Game.IsPluginInstalled(RealHandcuffsEsp)
    If (RealHandcuffsInstalled && !oldRealHandcuffsInstalled)
        UpdateRealHandcufs()
    EndIf
    Bool oldDeviousDevicesInstalled = DeviousDevicesInstalled
    DeviousDevicesInstalled = Game.IsPluginInstalled(DeviousDevicesEsm)
    If (DeviousDevicesInstalled && !oldDeviousDevicesInstalled)
        UpdateDeviousDevices()
    EndIf
EndFunction

Function UpdateRealHandcufs()
    FormList boundHandsGenericFurnitureList = Game.GetFormFromFile(0x000858, RealHandcuffsEsp) as FormList
    If (!boundHandsGenericFurnitureList.HasForm(Gallows))
        boundHandsGenericFurnitureList.AddForm(Gallows)
    EndIf
    RH_MainQuest = Game.GetFormFromFile(0x000F99, RealHandcuffsEsp) as Quest
    RH_NoPackage = Game.GetFormFromFile(0x000860, RealHandcuffsEsp) as Keyword
EndFunction

Function UpdateDeviousDevices()
    DD_kw_ItemType_WristCuffs = Game.GetFormFromFile(0x01196C, DeviousDevicesEsm) as Keyword
EndFunction


;
; Prepare a visual clone.
;
Function PrepareCloneForAnimation(Actor akActor, Actor clone)
    If (RealHandcuffsInstalled)
        clone.AddKeyword(RH_NoPackage)
    EndIf
EndFunction

;
; Try to equip a special item on an actor.
;
Bool Function EquipSpecialItem(Actor akActor, Form baseItem, ObjectReference item)
    If (RealHandcuffsInstalled && item != None)
        ScriptObject restraintBase = item.CastAs("RealHandcuffs:RestraintBase")
        If (restraintBase != None)
            Var[] args = new Var[2]
            args[0] = false
            args[1] = true
            restraintBase.CallFunction("ForceEquip", args)
            Return true
        EndIf
    EndIf
    Return False
EndFunction

;
; Check if an actor is wearing wrist restraints.
;
Bool Function IsWearingWristRestraints(Actor akActor)
    If (RealHandcuffsInstalled)
        If (AreWristsBoundRealHandcuffsGlobal(akActor, RH_MainQuest))
            Return true
        EndIf
    EndIf
    If (DeviousDevicesInstalled)
        If (akActor.WornHasKeyword(DD_kw_ItemType_WristCuffs))
            Return true
        EndIf
    EndIf
    Return false
EndFunction

Bool Function AreWristsBoundRealHandcuffsGlobal(Actor akActor, Quest thirdPartyApiQuest) Global
    RealHandcuffs:ThirdPartyApi api = thirdPartyApiQuest as RealHandcuffs:ThirdPartyApi
    If (api.ApiVersion() >= 6)
        Return api.HasHandsBoundBehindBack(akActor)
    EndIf
    Return false
EndFunction
