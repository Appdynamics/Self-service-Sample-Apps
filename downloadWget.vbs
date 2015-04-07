SET wshell = CreateObject("WScript.Shell")

writeLocation = wshell.ExpandEnvironmentStrings("%VB_ZIP_LOCATION%")
SET httpRequest = CreateObject("MSXML2.ServerXMLHTTP")
url = wshell.ExpandEnvironmentStrings("%VB_DOWNLOAD_URL%")
url = MID(url, 2, LEN(url) - 2)
httpRequest.open "GET", url, false
httpRequest.send()
SET wshell = Nothing

If httpRequest.Status = 200 Then
  Set stream = CreateObject("ADODB.Stream")
  stream.Open
  stream.Type = 1
  stream.Write httpRequest.ResponseBody
  stream.Position = 0
  Set fso = Createobject("Scripting.FileSystemObject")
  If fso.Fileexists(writeLocation) Then fso.DeleteFile writeLocation
  Set fso = Nothing
  Wscript.echo "Writing to " & writeLocation
  stream.SaveToFile writeLocation
  stream.Close
  Set stream = Nothing
End if
SET httpRequest = Nothing