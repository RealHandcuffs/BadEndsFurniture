;
; TODO
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Event OnLoad()
    BadEndsFurniture:DebugWrapper.Notification("OnLoad")
EndEvent

Event OnActivate(ObjectReference akActionRef)
    BadEndsFurniture:DebugWrapper.Notification("OnActivate " + akActionRef.GetDisplayName())
EndEvent
