SET wshell = CreateObject("WScript.Shell")
writeLocation = wshell.ExpandEnvironmentStrings("%VB_ZIP_LOCATION%")
extract = wshell.ExpandEnvironmentStrings("%VB_EXTRACT_LOCATION%")
SET app = CreateObject("Shell.Application")
app.NameSpace(extract).CopyHere app.NameSpace(writeLocation).Items(), 256