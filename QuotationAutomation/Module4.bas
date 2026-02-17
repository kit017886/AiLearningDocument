Attribute VB_Name = "Module4"
Sub ClearQuotationForm()
    Dim ws1 As Worksheet
    Dim headerNames As Variant
    Dim i As Integer
    Dim detailStartRow As Long
    Dim subtotalRow As Long
    
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    
    ' 1. 定義要清空的表頭命名範圍
    headerNames = Array("ClientCode", "CompanyName", "CoustomerName", "DocumentNum", _
                        "EstimatedDays", "ExternalRefNum", "InternalRefNum", "LeadTime", _
                        "LogisticTerms", "PaymentTerms", "PerparedBy", "QuoteDate", _
                        "Subject", "Validity", "Discount")
    
    ' 關閉螢幕更新
    Application.ScreenUpdating = False
    
    ' 2. 開始清空表頭
    For i = LBound(headerNames) To UBound(headerNames)
        On Error Resume Next
        ws1.Range(headerNames(i)).ClearContents
        On Error GoTo 0
    Next i
    
    ' 3. 【動態清空明細區域】
    ' 取得明細起始行（假設從第 22 行開始）
    detailStartRow = 22
    
    ' 取得「小計」所在的行號
    On Error Resume Next
    subtotalRow = ws1.Range("Subtotal").Row
    On Error GoTo 0
    
    ' 如果找到了小計標籤，且它在起始行之後
    If subtotalRow > detailStartRow Then
        ' 清空從 22 行開始，到小計前一行 (subtotalRow - 1) 的資料
        ' 我們清空 A 到 I 欄（保留 J 欄的 Sum 公式，或一併清空依你需求）
        ' 這裡建議清空 A 到 I，因為 J 欄通常是公式
        ws1.Range("A" & detailStartRow & ":I" & (subtotalRow - 1)).ClearContents
        
        ' 如果你也想清空 J 欄的公式（讓它徹底乾淨）：
        ' ws1.Range("J" & detailStartRow & ":J" & (subtotalRow - 1)).ClearContents
    End If
    
    ' 4. 設定預設值 (選填)
    On Error Resume Next
    ws1.Range("QuoteDate").Value = Date
    ws1.Range("NoOfPage").Value = 1 ' 假設有頁數欄位
    On Error GoTo 0
    
    ' 5. 重新觸發高亮提醒
    Call HighlightRequiredFields
    
    Application.ScreenUpdating = True
    
    MsgBox "報價單內容已清空 (22 行至小計上方)，並已恢復高亮提醒。", vbInformation
End Sub

Sub HighlightRequiredFields()
    Dim ws1 As Worksheet
    Dim mandatoryHeader As Range
    Dim detailRange As Range
    Dim detailStartRow As Long
    Dim subtotalRow As Long
    Dim detailEndRow As Long
    
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    detailStartRow = 22 ' 明細起始行
    
    ' 1. 高亮表頭命名範圍
    On Error Resume Next
    Set mandatoryHeader = ws1.Range("ClientCode, CompanyName, CoustomerName, " & _
                                    "QuoteDate, Subject, InternalRefNum, " & _
                                    "EstimatedDays, Discount")
    On Error GoTo 0
    
    If Not mandatoryHeader Is Nothing Then
        mandatoryHeader.Interior.ColorIndex = 36 ' 淺黃色
    End If
    
    ' 2. 高亮明細區域 (從 22 行到小計上方)
    On Error Resume Next
    subtotalRow = ws1.Range("Subtotal").Row
    On Error GoTo 0
    
    If subtotalRow > detailStartRow Then
        detailEndRow = subtotalRow - 1
        
        ' 定義明細中需要填寫的列：
        ' C欄(Description), G欄(QTY), H欄(UOM), I欄(Unit Price)
        ' 我們排除 J 欄(Sum)，因為那是公式
        Set detailRange = ws1.Range("C" & detailStartRow & ":C" & detailEndRow & "," & _
                                   "G" & detailStartRow & ":I" & detailEndRow)
        
        If Not detailRange Is Nothing Then
            detailRange.Interior.ColorIndex = 36 ' 淺黃色
        End If
    End If
    
    ' 3. 如果有 Item 序號列 (A 欄) 也可以一併高亮
    ws1.Range("B" & detailStartRow & ":B" & detailEndRow).Interior.ColorIndex = 36
End Sub


Sub RetrieveDetailToQuotation_Fixed()
    Dim ws1 As Worksheet, ws2 As Worksheet, ws3 As Worksheet
    Dim selectedID As Long
    Dim opt As OptionButton
    Dim foundID As Boolean
    Dim r2 As Long, lastRow2 As Long
    Dim targetRow1 As Long
    Dim headerNames As Variant, itemNames As Variant
    Dim i As Integer
    
    ' 定義欄位英文字母用來寫公式
    Dim qtyColLet As String, priceColLet As String
    
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    Set ws2 = ThisWorkbook.Sheets("Detail詳細")
    Set ws3 = ThisWorkbook.Sheets("Summary匯總")
    
    ' 1. 查找 Summary 中選中的 ID
    foundID = False
    For Each opt In ws3.OptionButtons
        If opt.Value = 1 Then
            selectedID = CLng(Replace(opt.Name, "OptBtn_", ""))
            foundID = True
            Exit For
        End If
    Next opt
    
    If Not foundID Then
        MsgBox "請先在 Summary 匯總表中勾選一個單據！", vbExclamation
        Exit Sub
    End If

    ' 2. 定義名稱陣列 (注意：itemNames 移除了 "Sum"，因為我們要單獨處理公式)
    headerNames = Array("ClientCode", "CompanyName", "CoustomerName", _
                        "EstimatedDays", "ExternalRefNum", "InternalRefNum", "LeadTime", _
                        "LogisticTerms", "PaymentTerms", "PerparedBy", "QuoteDate", _
                        "Subject", "Validity", "WorkingHour", "Discount")
                        
    itemNames = Array("Item", "Description", "QTY", "UnitPrice", "UOM")

    ' 獲取 QTY 和 UnitPrice 的欄位字母 (供公式使用)
    qtyColLet = Split(ws1.Cells(1, ws1.Range("QTY").Column).Address, "$")(1)
    priceColLet = Split(ws1.Cells(1, ws1.Range("UnitPrice").Column).Address, "$")(1)

    ' 3. 精確清理明細區域 (第 22 至 25 行)
    ws1.Range("A22:J25").ClearContents

    ' 4. 從 Detail 表提取數據
    lastRow2 = ws2.Cells(ws2.Rows.Count, ws2.Range("Id").Column).End(xlUp).Row
    targetRow1 = 22
    
    Dim isHeaderFilled As Boolean
    isHeaderFilled = False
    
    For r2 = 2 To lastRow2
        If ws2.Cells(r2, ws2.Range("Id").Column).Value = selectedID Then
            
            ' --- A. 填入整單資訊 ---
            If Not isHeaderFilled Then
                For i = LBound(headerNames) To UBound(headerNames)
                    On Error Resume Next
                    ws1.Range(headerNames(i)).Value = _
                        ws2.Cells(r2, ws2.Range(headerNames(i)).Column).Value
                    On Error GoTo 0
                Next i
                isHeaderFilled = True
            End If
            
            ' --- B. 填入明細行 (22-25行) ---
            If targetRow1 <= 25 Then
                ' 填入 Description, QTY, UnitPrice, UOM
                For i = LBound(itemNames) To UBound(itemNames)
                    ws1.Cells(targetRow1, ws1.Range(itemNames(i)).Column).Value = _
                        ws2.Cells(r2, ws2.Range(itemNames(i)).Column).Value
                Next i
                
                ' --- 【關鍵修改】不再搬運 Sum 資料，而是設定公式 ---
                ' 公式效果例如：=G22*I22
                ws1.Cells(targetRow1, ws1.Range("Sum").Column).Formula = _
                    "=" & qtyColLet & targetRow1 & "*" & priceColLet & targetRow1
                
                targetRow1 = targetRow1 + 1
            End If
            
        End If
    Next r2

    ' 5. 完成後的處理
    ws1.Activate
    ws1.Calculate
    
    Call HighlightRequiredFields
    
    Application.ScreenUpdating = True
    
    MsgBox "單據 ID: " & selectedID & " 已載入。" & vbCrLf & _
           "明細總額已設定為 QTY * UnitPrice 公式。", vbInformation
End Sub

Sub SetQuoteDateToToday()
    Dim ws1 As Worksheet
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    
    ' 1. 將命名範圍 "QuoteDate" 的值設定為今天
    On Error Resume Next
    ws1.Range("QuoteDate").Value = Date
    
    ' 2. 因為日期已經填寫了，自動取消該格的高亮顏色
    ws1.Range("QuoteDate").Interior.ColorIndex = xlNone
    On Error GoTo 0
    
End Sub

Sub SaveAndGenerateDeliveryNote()
    Dim ws1 As Worksheet, ws2 As Worksheet, ws3 As Worksheet, ws4 As Worksheet
    Dim r As Long, i As Integer
    Dim headerNames As Variant, itemNames As Variant
    Dim numItems As Long, rowWs3 As Long, id As Long
    Dim startRowDetail As Long
    
    ' 1. 設定工作表
    Set ws1 = ThisWorkbook.Sheets("Quotation報價")
    Set ws2 = ThisWorkbook.Sheets("Detail詳細")
    Set ws3 = ThisWorkbook.Sheets("Summary匯總")
    Set ws4 = ThisWorkbook.Sheets("Delivery Note 送貨單") ' 假設送貨單頁面名稱
    
    ' 2. 定義名稱與計算明細行數
    headerNames = Array("ClientCode", "CompanyName", "CoustomerName", "DocumentNum", _
                        "InternalRefNum", "QuoteDate", "Subject")
    itemNames = Array("Description", "QTY", "UOM")
    
    numItems = ws1.Range("Description").Offset(1, 0).End(xlDown).Row - ws1.Range("Description").Row
    If numItems < 1 Or numItems > 1000 Then
        If ws1.Range("Description").Offset(1, 0).Value <> "" Then numItems = 1 Else Exit Sub
    End If

    ' ---------------------------------------------------------
    ' 3. 儲存至 Summary 與 Detail (維持原本邏輯)
    ' ---------------------------------------------------------
    rowWs3 = ws3.Cells(ws3.Rows.Count, 3).End(xlUp).Row + 1
    id = rowWs3 - 2
    
    ws3.Cells(rowWs3, 3).Value = id
    ws3.Cells(rowWs3, 4).Value = ws1.Range("QuoteDate").Value
    ws3.Cells(rowWs3, 5).Value = ws1.Range("InternalRefNum").Value
    ws3.Cells(rowWs3, 6).Value = ws1.Range("CompanyName").Value
    ws3.Cells(rowWs3, 7).Value = ws1.Range("CoustomerName").Value
    ws3.Cells(rowWs3, 9).Value = ws1.Range("TotalAmount").Value
    
    startRowDetail = ws2.Cells(ws2.Rows.Count, ws2.Range("Id").Column).End(xlUp).Row + 1
    For r = 1 To numItems
        ws2.Cells(startRowDetail, ws2.Range("Id").Column).Value = id
        ws2.Cells(startRowDetail, ws2.Range("InternalRefNum").Column).Value = ws1.Range("InternalRefNum").Value
        ws2.Cells(startRowDetail, ws2.Range("Description").Column).Value = ws1.Range("Description").Offset(r, 0).Value
        ws2.Cells(startRowDetail, ws2.Range("QTY").Column).Value = ws1.Range("QTY").Offset(r, 0).Value
        startRowDetail = startRowDetail + 1
    Next r

    ' ---------------------------------------------------------
    ' 4. 傳送資料至 Delivery Note 送貨單 (關鍵新增)
    ' ---------------------------------------------------------
    ' A. 清空送貨單舊明細 (假設明細從 21 行開始到 25 行)
    ws4.Range("A20:L22").ClearContents
    
    ' B. 填入送貨單表頭 (根據截圖位置設定，請依實際單元格調整)
    With ws4
        .Range("C10").Value = ws1.Range("CompanyName").Value     ' Company Name
        .Range("C11").Value = ws1.Range("CoustomerName").Value   ' Receipent Name
        .Range("C12").Value = ws1.Range("PerparedBy").Value      ' Salesman Name
        
        .Range("J10").Value = ws1.Range("DocumentNum").Value     ' DN# (同報價單號)
        .Range("J11").Value = Date                               ' Date (送貨日期，預設今天)
        .Range("J14").Value = ws1.Range("InternalRefNum").Value  ' Internal Ref#
        .Range("J16").Value = ws1.Range("ClientCode").Value      ' Customer ID
    End With
    
    ' C. 填入送貨證明中的客戶簽名預設文字
    ' ws4.Range("G26").Value = ws1.Range("CompanyName").Value ' 簽名處公司名
    ' ws4.Range("G27").Value = ws1.Range("CoustomerName").Value ' 簽名處收貨人
    
    ' D. 填入送貨單明細
    Dim targetDnRow As Long
    targetDnRow = 21 ' 送貨單明細起始行
    
    For r = 1 To numItems
        With ws4
            .Cells(targetDnRow, 1).Value = r ' Item 序號
            .Cells(targetDnRow, 2).Value = ws1.Range("Description").Offset(r, 0).Value ' Description
            .Cells(targetDnRow, 9).Value = ws1.Range("QTY").Offset(r, 0).Value         ' Order QTY
            .Cells(targetDnRow, 10).Value = ws1.Range("QTY").Offset(r, 0).Value        ' Dely. QTY (預設全送)
            .Cells(targetDnRow, 11).Value = 0                                          ' O/S QTY (預設無欠貨)
            .Cells(targetDnRow, 12).Value = ws1.Range("UOM").Offset(r, 0).Value         ' UOM
        End With
        targetDnRow = targetDnRow + 1
    Next r

    ' 5. 完成提示並跳轉
    MsgBox "數據已儲存至 Summary，並已生成送貨單！", vbInformation
    ws4.Activate
End Sub
