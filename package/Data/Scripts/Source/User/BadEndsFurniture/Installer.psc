;
; Script to install, maintain and update the mod.
;
Scriptname BadEndsFurniture:Installer extends ReferenceAlias

BadEndsFurniture:SoftDependencies Property SoftDependencies Auto Const Mandatory

String Property DetailedVersion = "0.1" AutoReadOnly ; user version string, will change with every new version
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
        SoftDependencies.Clear()
        GotoState("V0")
        InstalledVersion = DetailedVersion
    EndIf
    SoftDependencies.Refresh()
    InstallerWorking = false
    If (notification != "")
        BadEndsFurniture:DebugWrapper.Notification(notification)
    EndIf
EndEvent


State V0
    ; nothing to do for now
EndState