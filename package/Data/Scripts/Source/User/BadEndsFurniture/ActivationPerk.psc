;
; Perk for activations of mod.
;
Scriptname BadEndsFurniture:ActivationPerk extends Perk

Keyword Property GallowsLink Auto Const Mandatory

Event OnEntryRun(int auiEntryID, ObjectReference akTarget, Actor akOwner)
    If (akOwner == Game.GetPlayer())
        BadEndsFurniture:Gallows linkedGallows = akTarget.GetLinkedRef(GallowsLink) as BadEndsFurniture:Gallows
        If (linkedGallows != None)
            linkedGallows.CutNoose()
        EndIf
    EndIf
EndEvent
