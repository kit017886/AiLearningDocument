Attribute VB_Name = "Module2"
Public refValue As Variant
Public cellRange As Range

Sub GetInternalRef()
    Dim ws As Worksheet
    Dim btnName As String
    Dim clickedRow As Long
    Dim targetHeader As String
    Dim colIndex As Variant
    Set ws = ActiveSheet
    
    ' 1. 獲取被點擊按鈕的名稱
    ' Application.Caller 會回傳觸發此巨集的控制項名稱
    On Error Resume Next
     btnName = Application.Caller
    Set cellRange = ws.Shapes(btnName).TopLeftCell
    refValue = ws.Cells(cellRange.Row, 5).Value

End Sub


Sub HighlightSpecificFields(wsTarget As Worksheet)
    Dim MyFields As Range
    
    ' 檢查工作表是否存在
    If wsTarget Is Nothing Then
        MsgBox "錯誤：找不到指定的工作表！", vbCritical
        Exit Sub
    End If
    
    ' 定義需要高亮的範圍 (使用你在名稱管理器設定的名稱)
    ' 注意：這裡假設這些名稱是在「活頁簿」範圍內定義的
    On Error Resume Next
    Set MyFields = wsTarget.Range("InternalRefNum, DocumentNum, QuoteDate, CompanyName, CoustomerName, Subject, TotalAmount")
    On Error GoTo 0
    
    ' 如果找到範圍，則填色
    If Not MyFields Is Nothing Then
        MyFields.Interior.ColorIndex = 36 ' 淺黃色
    Else
        MsgBox "在工作表 " & wsTarget.Name & " 中找不到定義的名稱範疇！", vbExclamation
    End If
End Sub
