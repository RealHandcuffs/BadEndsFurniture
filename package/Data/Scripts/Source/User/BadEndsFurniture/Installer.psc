;
; Script to install, maintain and update the mod.
;
Scriptname BadEndsFurniture:Installer extends ReferenceAlias

BadEndsFurniture:Library Property Library Auto Const Mandatory
Perk Property ActivationPerk Auto Const Mandatory

String Property DetailedVersion = "0.1 alpha 2" AutoReadOnly ; user version string, will change with every new version
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
    InstallerWorking = false
    If (notification != "")
        BadEndsFurniture:DebugWrapper.Notification(notification)
    EndIf
EndEvent


State V0

Event OnBeginState(string asOldState)
    Game.GetPlayer().AddPerk(ActivationPerk)
EndEvent

Event OnEndState(string asOldState)
    Game.GetPlayer().RemovePerk(ActivationPerk)
EndEvent

EndState
