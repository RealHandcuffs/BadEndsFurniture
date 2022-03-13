;
; TODO
;
Scriptname BadEndsFurniture:Gallows extends ObjectReference

Event OnActivate(ObjectReference akActionRef)
    BadEndsFurniture:DebugWrapper.Notification("OnActivate " + akActionRef.GetDisplayName())
EndEvent