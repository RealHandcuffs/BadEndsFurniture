;
; Perk for activations of mod.
;
Scriptname BadEndsFurniture:ActivationPerk extends Perk

Keyword Property GallowsLink Auto Const Mandatory
Keyword Property PlayerSelectVictimLink Auto Const Mandatory

Event OnEntryRun(int auiEntryID, ObjectReference akTarget, Actor akOwner)
    If (akOwner == Game.GetPlayer())
        If (auiEntryID == 0) ; cut noose
            BadEndsFurniture:Gallows linkedGallows = akTarget.GetLinkedRef(GallowsLink) as BadEndsFurniture:Gallows
            If (linkedGallows != None)
                linkedGallows.CutNoose()
            EndIf
        ElseIf (auiEntryID == 1) ; choose as victim
            BadEndsFurniture:Gallows gallows = akOwner.GetLinkedRef(PlayerSelectVictimLink) as BadEndsFurniture:Gallows
            If (gallows == None) ; not expected but handle it
                akOwner.SetLinkedRef(None, PlayerSelectVictimLink)
            Else
                gallows.SelectVictim(akTarget as Actor)
            EndIf
        EndIf
    EndIf
EndEvent
