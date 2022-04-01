;
; Script handling soft dependencies.
;
Scriptname BadEndsFurniture:SoftDependencies extends Quest

Activator Property Gallows Auto Const Mandatory

Bool Property RealHandcuffsInstalled = False Auto

Group Plugins
    String Property RealHandcuffsEsp = "RealHandcuffs.esp" AutoReadOnly
EndGroup

Group RealHandcuffs
    Keyword Property NoPackage = None Auto
EndGroup

;
; Clear soft dependencies - this will force Refresh() to do something in the next call.
;
Function Clear()
    RealHandcuffsInstalled = false
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
EndFunction

Function UpdateRealHandcufs()
    FormList boundHandsGenericFurnitureList = Game.GetFormFromFile(0x000858, RealHandcuffsEsp) as FormList
    If (!boundHandsGenericFurnitureList.HasForm(Gallows))
        boundHandsGenericFurnitureList.AddForm(Gallows)
    EndIf
    NoPackage = Game.GetFormFromFile(0x000860, RealHandcuffsEsp) as Keyword
EndFunction


;
; Prepare a visual clone.
;
Function PrepareCloneForAnimation(Actor akActor, Actor clone)
    If (RealHandcuffsInstalled)
        clone.AddKeyword(NoPackage)
    EndIf
EndFunction

;
; Try to equip a special item on an actor.
;
Bool Function EquipSpecialItem(Actor akActor, Form baseItem, ObjectReference item)
    If (item != None && RealHandcuffsInstalled)
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
