Option Explicit
Dim fso, docsDir, docx, pdf, word, doc
Set fso = CreateObject("Scripting.FileSystemObject")
docsDir = "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\Documents\"
docx = docsDir & "Горбов_Индивидуальный_план_аспирант_2026.docx"
pdf = docsDir & "Горбов_Индивидуальный_план_аспирант_2026.pdf"

If Not fso.FileExists(docx) Then
    WScript.Echo "DOCX not found: " & docx
    WScript.Quit 1
End If

If fso.FileExists(pdf) Then
    fso.DeleteFile pdf, True
End If

Set word = CreateObject("Word.Application")
word.Visible = False
word.DisplayAlerts = 0
Set doc = word.Documents.Open(docx, False, True)
WScript.Sleep 3000
doc.ExportAsFixedFormat pdf, 17
doc.Close False
word.Quit
Set doc = Nothing
Set word = Nothing

If fso.FileExists(pdf) Then
    WScript.Echo "OK: " & pdf
Else
    WScript.Echo "PDF was not created"
    WScript.Quit 1
End If
