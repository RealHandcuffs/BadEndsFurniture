;
; Script to install, maintain and update the mod.
;
Scriptname BadEndsFurniture:Installer extends ReferenceAlias

BadEndsFurniture:Library Property Library Auto Const Mandatory
Perk Property ActivationPerk Auto Const Mandatory
RefCollectionAlias Property Clones Auto Const Mandatory

String Property DetailedVersion = "0.1 beta 5" AutoReadOnly ; user version string, will change with every new version
String Property InstalledVersion = "" Auto
Bool Property InstallerWorking = false Auto

Event OnInit()
    OnPlayerLoadGame() ; because it will not fire the first time
EndEvent

Event OnPlayerLoadGame()
    Int waitCount = 60
    While (InstallerWorking && waitCount > 0)
        Utility.WaitMenuMode(1.0)
        waitCount -= 1
    EndWhile
    InstallerWorking = true
    String notification = ""
    If (InstalledVersion != DetailedVersion)
        If (InstalledVersion == "")
            notification = "Installed BadEndsFurniture " + DetailedVersion + "."
        Else
            notification = "Upgraded to BadEndsFurniture " + DetailedVersion + "."
        EndIf
        GotoState("")
        Library.SoftDependencies.Clear()
        GotoState("V0")
        InstalledVersion = DetailedVersion
    EndIf
    Library.SoftDependencies.Refresh()
    Int index = Clones.GetCount() - 1
    While (index >= 0)
        Actor clone = Clones.GetAt(index) as Actor
        If (clone != None && clone.GetParentCell().IsAttached())
            Var[] args = new Var[1]
            args[0] = clone
            Utility.CallGlobalFunctionNoWait("BadEndsFurniture:Installer", "FixExpressionsOnGameLoad", args)
        EndIf
        index -= 1
    EndWhile
    InstallerWorking = false
    If (notification != "")
        BadEndsFurniture:DebugWrapper.Notification(notification)
    EndIf
EndEvent

Function FixExpressionsOnGameLoad(Actor clone) Global
    clone.WaitFor3DLoad()
    utility.Wait(Utility.RandomFloat(1.0, 2.0))
    If (clone.GetParentCell().IsAttached() && !clone.IsDead() && clone.IsUnconscious())
        clone.SetUnconscious(false)
        Utility.Wait(0.1)
        clone.SetUnconscious(true)
        Utility.Wait(Utility.RandomFloat(4.0, 6.0))
        If (clone.GetParentCell().IsAttached() && !clone.IsDead() && clone.IsUnconscious())
            clone.SetUnconscious(false)
            Utility.Wait(0.1)
            clone.SetUnconscious(true)
        EndIf
    EndIf
EndFunction

State V0

Event OnBeginState(string asOldState)
    Game.GetPlayer().AddPerk(ActivationPerk)
EndEvent

Event OnEndState(string asOldState)
    Game.GetPlayer().RemovePerk(ActivationPerk)
EndEvent

EndState
