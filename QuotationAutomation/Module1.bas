Attribute VB_Name = "Module1"
' --- 全域常數設定，方便統一管理 ---
Private Function GetHeaderNames() As Variant
    GetHeaderNames = Array("ClientCode", "CompanyName", "CoustomerName", "DocumentNum", _
                          "EstimatedDays", "ExternalRefNum", "InternalRefNum", "LeadTime", _
                          "LogisticTerms", "PaymentTerms", "PerparedBy", "QuoteDate", _
                          "Subject", "TotalAmount", "Validity", "WorkingHour", "Discount")
End Function

Private Function GetItemNames() As Variant
    GetItemNames = Array("Description", "QTY", "UnitPrice", "UOM", "Sum")
End Function

' --- 共用 1：計算報價單明細行數 ---
Private Function GetNumItems(ws1 As Worksheet) As Long
    Dim n As Long
    On Error Resume Next
    n = ws1.Range("Description").Offset(1, 0).End(xlDown).Row - ws1.Range("Description").Row
    ' 防錯處理
    If n < 1 Or n > 1000 Then
        If ws1.Range("Description").Offset(1, 0).Value <> "" Then n = 1 Else n = 0
    End If
    On Error GoTo 0
    GetNumItems = n
End Function

' --- 共用 2：寫入或更新 Summary 表的一行資料 ---
Private Sub WriteToSummaryRow(ws1 As Worksheet, ws3 As Worksheet, rowIdx As Long, id As Long)
    With ws3
        .Cells(rowIdx, 3).Value = id
        .Cells(rowIdx, 4).Value = ws1.Range("QuoteDate").Value
        .Cells(rowIdx, 5).Value = ws1.Range("InternalRefNum").Value
        .Cells(rowIdx, 6).Value = ws1.Range("CompanyName").Value
        .Cells(rowIdx, 7).Value = ws1.Range("CoustomerName").Value
        .Cells(rowIdx, 8).Value = ws1.Range("Subject").Value
        .Cells(rowIdx, 9).Value = ws1.Range("TotalAmount").Value
    End With
End Sub

' --- 共用 3：寫入 Detail 表的多行明細 ---
Private Sub WriteToDetailRows(ws1 As Worksheet, ws2 As Worksheet, startRow As Long, id As Long, numItems As Long)
    Dim r As Long, i As Integer
    Dim hNames As Variant, itNames As Variant
    Dim writeRow As Long
    
    hNames = GetHeaderNames()
    itNames = GetItemNames()
    writeRow = startRow
    
    For r = 1 To numItems
        ' 1. 寫入 DocumentType 與 ID
        On Error Resume Next
        ws2.Cells(writeRow, ws2.Range("DocumentType").Column).Value = "報價單"
        ws2.Cells(writeRow, ws2.Range("Id").Column).Value = id
        ws2.Cells(writeRow, ws2.Range("Item").Column).Value = r
        
        ' 2. 寫入整單固定資訊 (Header)
        For i = LBound(hNames) To UBound(hNames)
            ws2.Cells(writeRow, ws2.Range(hNames(i)).Column).Value = ws1.Range(hNames(i)).Value
        Next i
        
        ' 3. 寫入逐行明細資訊 (Items)
        For i = LBound(itNames) To UBound(itNames)
            ws2.Cells(writeRow, ws2.Range(itNames(i)).Column).Value = ws1.Range(itNames(i)).Offset(r, 0).Value
        Next i
        On Error GoTo 0
        
        writeRow = writeRow + 1
    Next r
End Sub

' =========================================================
' 主要功能 1：新增報價資料
' =========================================================
Sub Copy_Data_to_Summary_Fixed()
    Dim ws1 As Worksheet, ws2 As Worksheet, ws3 As Worksheet
    Dim numItems As Long, rowWs3 As Long, id As Long, startRowDetail As Long
    
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    Set ws2 = ThisWorkbook.Sheets("QuoteDetail報價詳細")
    Set ws3 = ThisWorkbook.Sheets("Summary匯總")
    
    numItems = GetNumItems(ws1)
    If numItems = 0 Then MsgBox "無明細資料！": Exit Sub
    
    ' Summary 處理
    rowWs3 = ws3.Cells(ws3.Rows.Count, 3).End(xlUp).Row + 1
    id = rowWs3 - 2
    Call WriteToSummaryRow(ws1, ws3, rowWs3, id)
    
    ' Detail 處理
    startRowDetail = ws2.Cells(ws2.Rows.Count, ws2.Range("Id").Column).End(xlUp).Row + 1
    Call WriteToDetailRows(ws1, ws2, startRowDetail, id, numItems)
    
    ' 生成按鈕
    Dim btn As Shape, targetCell As Range
    Set targetCell = ws3.Cells(rowWs3, 2)
    Set btn = ws3.Shapes.AddFormControl(xlOptionButton, targetCell.Left + 5, targetCell.Top, 20, 15)
    With btn
        .DrawingObject.Caption = ""
        .Name = "OptBtn_" & id
        .OnAction = "GetInternalRef"
    End With

    MsgBox "數據新增完成！ID: " & id, vbInformation
End Sub

' =========================================================
' 主要功能 2：修改現有資料 (原位插入)
' =========================================================
Sub Update_Existing_Data_At_Original_Position()
    Dim ws1 As Worksheet, ws2 As Worksheet, ws3 As Worksheet
    Dim selectedID As Long, opt As OptionButton, foundID As Boolean
    
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    Set ws2 = ThisWorkbook.Sheets("QuoteDetail報價詳細") ' 確保名稱與新增時一致
    Set ws3 = ThisWorkbook.Sheets("Summary匯總")
    
    ' 1. 獲取 ID
    foundID = False
    For Each opt In ws3.OptionButtons
        If opt.Value = 1 Then
            selectedID = CLng(Replace(opt.Name, "OptBtn_", ""))
            foundID = True: Exit For
        End If
    Next opt
    If Not foundID Then MsgBox "請先勾選單據！": Exit Sub

    ' 2. 更新 Summary
    Dim r3 As Long, foundRow3 As Long
    For r3 = 2 To ws3.Cells(ws3.Rows.Count, 3).End(xlUp).Row
        If ws3.Cells(r3, 3).Value = selectedID Then
            foundRow3 = r3: Exit For
        End If
    Next r3
    If foundRow3 > 0 Then Call WriteToSummaryRow(ws1, ws3, foundRow3, selectedID)

    ' 3. 更新 Detail (原位替換)
    Dim idCol As Integer, r2 As Long, firstFoundRow As Long, oldItemsCount As Long
    idCol = ws2.Range("Id").Column
    For r2 = 2 To ws2.Cells(ws2.Rows.Count, idCol).End(xlUp).Row
        If ws2.Cells(r2, idCol).Value = selectedID Then
            If firstFoundRow = 0 Then firstFoundRow = r2
            oldItemsCount = oldItemsCount + 1
        End If
    Next r2
    
    If firstFoundRow > 0 Then
        ws2.Rows(firstFoundRow & ":" & (firstFoundRow + oldItemsCount - 1)).Delete
    Else
        firstFoundRow = ws2.Cells(ws2.Rows.Count, idCol).End(xlUp).Row + 1
    End If
    
    Dim numItems As Long
    numItems = GetNumItems(ws1)
    If numItems > 0 Then
        ws2.Rows(firstFoundRow & ":" & (firstFoundRow + numItems - 1)).Insert Shift:=xlDown
        Call WriteToDetailRows(ws1, ws2, firstFoundRow, selectedID, numItems)
    End If

    MsgBox "單據 ID: " & selectedID & " 修改成功！", vbInformation
End Sub

