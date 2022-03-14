;
; Script handling soft dependencies.
;
Scriptname BadEndsFurniture:SoftDependencies extends Quest

Activator Property Gallows Auto Const Mandatory

Bool Property RealHandcuffsInstalled = False Auto

String Property RealHandcuffsEsp = "RealHandcuffs.esp" AutoReadOnly

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
EndFunction
