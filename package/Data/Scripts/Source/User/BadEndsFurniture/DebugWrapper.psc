;
; A wrapper script for Debug functionality. This wrapper allows all other scripts to be compiled in release mode.
;
Scriptname BadEndsFurniture:DebugWrapper Const Hidden

Function Notification(string asNotificationText) Global
    Debug.Notification(asNotificationText)
EndFunction

Function Trace(string asTextToPrint, int aiSeverity = 0) Global
    Debug.Trace(asTextToPrint, aiSeverity)
EndFunction

Function TraceStack(string asTextToPrint, int aiSeverity = 0) Global
    Debug.TraceStack(asTextToPrint, aiSeverity)
EndFunction
