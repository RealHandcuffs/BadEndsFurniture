;
; Script handling soft dependencies.
;
Scriptname BadEndsFurniture:SoftDependencies extends Quest

Activator Property Gallows Auto Const Mandatory

Bool Property RealHandcuffsInstalled = False Auto
Bool Property DeviousDevicesInstalled = False Auto
Bool Property KziidFetishToolsetInstalled = False Auto

Group Plugins
    String Property RealHandcuffsEsp = "RealHandcuffs.esp" AutoReadOnly
    String Property DeviousDevicesEsm = "Devious Devices.esm" AutoReadOnly
    String Property KziidFetishToolset = "KziitdFetishToolset.esm" AutoReadOnly
EndGroup

Group RealHandcuffs
    Quest Property RH_MainQuest = None Auto
    Keyword Property RH_NoPackage = None Auto
    Keyword Property RH_Restraint = None Auto
    MiscObject Property RH_NpcToken = None Auto
EndGroup

Group DeviousDevices
    Keyword Property DD_kw_ItemType_WristCuffs = None Auto
EndGroup

Group KziidFetishToolset
    ScriptObject Property KZEB_API = None Auto
    Keyword Property KZEB_Device = None Auto
    Keyword Property KZEB_DeviceType_Boundhands = None Auto
EndGroup

;
; Clear soft dependencies - this will force Refresh() to do something in the next call.
;
Function Clear()
    RealHandcuffsInstalled = false
    DeviousDevicesInstalled = false
    KziidFetishToolsetInstalled = false
EndFunction

;
; Refresh soft dependencies.
;
Function Refresh()
    Bool oldRealHandcuffsInstalled = RealHandcuffsInstalled
    RealHandcuffsInstalled = Game.IsPluginInstalled(RealHandcuffsEsp)
    If (RealHandcuffsInstalled && !oldRealHandcuffsInstalled)
        UpdateRealHandcuffs()
    EndIf
    Bool oldDeviousDevicesInstalled = DeviousDevicesInstalled
    DeviousDevicesInstalled = Game.IsPluginInstalled(DeviousDevicesEsm)
    If (DeviousDevicesInstalled && !oldDeviousDevicesInstalled)
        UpdateDeviousDevices()
    EndIf
    Bool oldKziidFetishToolsetInstalled = KziidFetishToolsetInstalled
    KziidFetishToolsetInstalled = Game.IsPluginInstalled(KziidFetishToolset)
    If (KziidFetishToolsetInstalled && !oldKziidFetishToolsetInstalled)
        UpdateKziidFetishToolset()
    EndIf
EndFunction

Function UpdateRealHandcuffs()
    FormList boundHandsGenericFurnitureList = Game.GetFormFromFile(0x000858, RealHandcuffsEsp) as FormList
    If (!boundHandsGenericFurnitureList.HasForm(Gallows))
        boundHandsGenericFurnitureList.AddForm(Gallows)
    EndIf
    RH_MainQuest = Game.GetFormFromFile(0x000F99, RealHandcuffsEsp) as Quest
    RH_NoPackage = Game.GetFormFromFile(0x000860, RealHandcuffsEsp) as Keyword
    RH_Restraint = Game.GetFormFromFile(0x000009, RealHandcuffsEsp) as Keyword
    RH_NpcToken =  Game.GetFormFromFile(0x000803, RealHandcuffsEsp) as MiscObject
EndFunction

Function UpdateDeviousDevices()
    DD_kw_ItemType_WristCuffs = Game.GetFormFromFile(0x01196C, DeviousDevicesEsm) as Keyword
EndFunction

Function UpdateKziidFetishToolset()
    Quest KZEB_MainQuest = Game.GetFormFromFile(0x00924A, KziidFetishToolset) as Quest
    KZEB_API = KZEB_MainQuest.CastAs("KZEB:KZEB_API")
    KZEB_Device = KZEB_API.GetPropertyValue("KZEB_Device") as Keyword
    KZEB_DeviceType_Boundhands = KZEB_API.GetPropertyValue("KZEB_DeviceType_BoundHands") as Keyword
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
; Check if an item is a special item
;
Bool Function IsSpecialItem(Armor baseItem)
    If (RealHandcuffsInstalled && baseItem.HasKeyword(RH_Restraint))
        Return true
    EndIf
    If (KziidFetishToolsetInstalled && baseItem.HasKeyword(KZEB_Device))
        Return true
    EndIf
    Return false
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
    If (KziidFetishToolsetInstalled && baseItem.HasKeyword(KZEB_Device))
        Var[] args = new Var[4]
        args[0] = akActor
        If (item != None)
            args[1] = item
        Else
            args[1] = baseItem
        EndIf
        args[2] = true
        args[3] = true
        KZEB_API.CallFunction("EquipDevice", args)
        Return true
    EndIf
    Return False
EndFunction

;
; Try to unequip a special item from an actor.
;
Bool Function UnequipSpecialItem(Actor akActor, Form baseItem, ObjectReference item)
    If (RealHandcuffsInstalled && item != None)
        ScriptObject restraintBase = item.CastAs("RealHandcuffs:RestraintBase")
        If (restraintBase != None)
            restraintBase.CallFunction("ForceUnequip", new Var[0])
            Return true
        EndIf
    EndIf
    If (KziidFetishToolsetInstalled && baseItem.HasKeyword(KZEB_Device))
        Var[] args = new Var[3]
        args[0] = akActor
        args[1] = baseItem
        args[2] = false
        KZEB_API.CallFunction("UnequipDevice", args)
        Return true
    EndIf
    Return False
EndFunction

;
; Add items that need to be kept in the inventory to the array
;
Function AddItemsToKeep(Form[] itemsToKeep)
    If (RealHandcuffsInstalled)
        itemsToKeep.Add(RH_NpcToken)
    EndIf
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
    If (KziidFetishToolsetInstalled)
        If (akActor.WornHasKeyword(KZEB_DeviceType_Boundhands))
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
