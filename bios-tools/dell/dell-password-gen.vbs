' Dell BIOS Master Password Generator - VBScript version
' Works in WinPE without PowerShell
' Based on research by Dogbert and Asyncritus (bios-pw.org algorithms)

Option Explicit

Dim ServiceTag, charset, i
Dim objShell, objFSO, outputFile, scriptPath

Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Get script directory for output file
scriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
outputFile = scriptPath & "\generated_passwords.txt"

' Character set for Dell passwords
charset = "0123456789ABCDEFGHJKLMNPQRSTUVWXYZ"

' Get service tag from command line or WMI
If WScript.Arguments.Count > 0 Then
    ServiceTag = UCase(WScript.Arguments(0))
Else
    ' Try to get from WMI
    On Error Resume Next
    Dim objWMI, colItems, objItem
    Set objWMI = GetObject("winmgmts:\\.\root\cimv2")
    Set colItems = objWMI.ExecQuery("Select SerialNumber from Win32_BIOS")
    For Each objItem in colItems
        ServiceTag = objItem.SerialNumber
    Next
    On Error Goto 0
    
    If ServiceTag = "" Or ServiceTag = "To Be Filled By O.E.M." Then
        WScript.Echo "ERROR: Could not detect service tag."
        WScript.Echo "Usage: cscript //nologo dell-password-gen.vbs SERVICETAG"
        WScript.Quit 1
    End If
End If

' Normalize service tag
ServiceTag = UCase(Replace(ServiceTag, "-", ""))
If Len(ServiceTag) < 7 Then
    ServiceTag = ServiceTag & String(7 - Len(ServiceTag), "0")
ElseIf Len(ServiceTag) > 7 Then
    ServiceTag = Left(ServiceTag, 7)
End If

WScript.Echo "Dell BIOS Master Password Generator"
WScript.Echo "Service Tag: " & ServiceTag
WScript.Echo ""
WScript.Echo "Possible master passwords:"
WScript.Echo "========================="
WScript.Echo ""

' Suffix codes and their encryption keys
Dim suffixes(7), suffixNames(7), keys(7)
suffixNames(0) = "595B" : keys(0) = Array(&H63, &H6C, &H52, &H34, &H4A, &H62, &H4B, &H7C)
suffixNames(1) = "D35B" : keys(1) = Array(&H4B, &H41, &H49, &H67, &H6E, &H51, &H55, &H61)
suffixNames(2) = "2A7B" : keys(2) = Array(&H54, &H4F, &H47, &H38, &H6E, &H53, &H57, &H6B)
suffixNames(3) = "1D3B" : keys(3) = Array(&H6E, &H53, &H75, &H4B, &H62, &H32, &H4B, &H79)
suffixNames(4) = "1F66" : keys(4) = Array(&H64, &H6B, &H32, &H31, &H58, &H74, &H4C, &H67)
suffixNames(5) = "6FF1" : keys(5) = Array(&H53, &H4A, &H62, &H6E, &H4B, &H4D, &H6C, &H32)
suffixNames(6) = "1F5A" : keys(6) = Array(&H33, &H5A, &H45, &H67, &H37, &H4E, &H55, &H39)
suffixNames(7) = "BF97" : keys(7) = Array(&H42, &H31, &H35, &H33, &H42, &H34, &H35, &H42)

Dim passwords, password, suffix
passwords = ""

WScript.Echo "Try these passwords (press Ctrl+Enter on some Dell systems):"
WScript.Echo ""

For i = 0 To 7
    password = GeneratePassword(ServiceTag, keys(i))
    WScript.Echo "  " & suffixNames(i) & " : " & password
    If passwords <> "" Then passwords = passwords & vbCrLf
    passwords = passwords & password
Next

' New algorithm for newer systems
password = GeneratePasswordNew(ServiceTag)
WScript.Echo ""
WScript.Echo "  New algo: " & password
passwords = passwords & vbCrLf & password

WScript.Echo ""
WScript.Echo "Note: On some Dell systems, press Ctrl+Enter instead of Enter."
WScript.Echo ""

' Save to file
Dim outFile
Set outFile = objFSO.CreateTextFile(outputFile, True)
outFile.Write passwords
outFile.Close
WScript.Echo "Passwords saved to: " & outputFile

' ============ Functions ============

Function GeneratePassword(tag, key)
    Dim result, idx, xorVal, charIdx, j
    result = ""
    
    For j = 0 To 7
        idx = j Mod Len(tag)
        xorVal = XorBytes(Asc(Mid(tag, idx + 1, 1)), key(j))
        charIdx = xorVal Mod Len(charset)
        result = result & Mid(charset, charIdx + 1, 1)
    Next
    
    GeneratePassword = result
End Function

Function GeneratePasswordNew(tag)
    Dim result, hash, j, charVal, idx
    hash = 0
    
    ' Simple hash
    For j = 1 To Len(tag)
        charVal = Asc(Mid(tag, j, 1))
        hash = ShiftLeft(hash, 5) - hash + charVal
        hash = hash And &HFFFFFFFF
        ' Handle overflow for VBScript
        If hash < 0 Then hash = hash + 4294967296
    Next
    
    result = ""
    For j = 0 To 7
        idx = ShiftRight(hash, j * 4) And &H1F
        result = result & Mid(charset, idx + 1, 1)
    Next
    
    GeneratePasswordNew = result
End Function

Function XorBytes(a, b)
    XorBytes = a Xor b
End Function

Function ShiftLeft(value, bits)
    ShiftLeft = value * (2 ^ bits)
End Function

Function ShiftRight(value, bits)
    ShiftRight = Int(value / (2 ^ bits))
End Function
