Option Explicit
Dim word, doc, docx, pdf
docx = "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\documents\otzyv_nauchnogo_rukovoditelya.docx"
pdf = "c:\Grisha\mipt\asp\disser\dissertation\diplom_final\documents\otzyv_nauchnogo_rukovoditelya.pdf"
Set word = CreateObject("Word.Application")
word.Visible = False
word.DisplayAlerts = 0
Set doc = word.Documents.Open(docx, False, True)
doc.ExportAsFixedFormat pdf, 17
doc.Close False
word.Quit
WScript.Echo "OK"
