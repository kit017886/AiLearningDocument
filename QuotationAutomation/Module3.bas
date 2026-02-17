Attribute VB_Name = "Module3"
Sub DeleteSelectedQuote_And_Renumber()
    Dim wsSummary As Worksheet, wsDetail As Worksheet
    Dim opt As Object ' 使用 Object 以兼容不同類型的按鈕
    Dim selectedBtn As Object
    Dim deleteRow As Long, lastRowSummary As Long
    Dim targetID As String
    Dim i As Long, j As Long
    Dim lastRowDetail As Long
    Dim confirmMsg As VbMsgBoxResult
    
    ' 1. 設定工作表
    Set wsSummary = ThisWorkbook.Sheets("Summary匯總")
    Set wsDetail = ThisWorkbook.Sheets("QuoteDetail報價詳細")
    
    ' 2. 找出被勾選的單選按鈕
    Set selectedBtn = Nothing
    
    ' 遍歷 Summary 上的所有單選按鈕
    For Each opt In wsSummary.OptionButtons
        If opt.Value = 1 Then ' xlOn
            Set selectedBtn = opt
            Exit For
        End If
    Next opt
    
    ' 防錯：如果沒選中
    If selectedBtn Is Nothing Then
        MsgBox "請先勾選要刪除的行！", vbExclamation, "未選擇"
        Exit Sub
    End If
    
    ' 3. 獲取要刪除的資訊
    deleteRow = selectedBtn.TopLeftCell.Row ' 按鈕所在的行
    targetID = wsSummary.Cells(deleteRow, 3).Value ' 假設序號在 C 欄 (第3欄)
    
    ' 4. 刪除確認
    confirmMsg = MsgBox("確定要刪除序號 [" & targetID & "] 嗎？" & vbCrLf & _
                        "這將刪除 Summary 第 " & deleteRow & " 行" & vbCrLf & _
                        "並連動刪除 Detail 中對應的資料。" & vbCrLf & vbCrLf & _
                        "注意：刪除後，後續的序號將會重新排列！", vbYesNo + vbCritical, "刪除確認")
                        
    If confirmMsg = vbNo Then Exit Sub
    
    Application.ScreenUpdating = False ' 關閉螢幕更新加速執行
    
    ' 5. 【刪除階段 - Detail】刪除詳細頁的對應資料
    lastRowDetail = wsDetail.Cells(wsDetail.Rows.Count, 1).End(xlUp).Row
    ' 從下往上刪除
    For i = lastRowDetail To 2 Step -1
        ' 假設 Detail 的關聯序號在 A 欄 (第1欄)
        If CStr(wsDetail.Cells(i, 1).Value) = CStr(targetID) Then
            wsDetail.Rows(i).Delete
        End If
    Next i
    
    ' 6. 【刪除階段 - Summary】刪除匯總頁的按鈕與資料
    selectedBtn.Delete ' 刪除按鈕物件
    wsSummary.Rows(deleteRow).Delete ' 刪除整行
    
    ' =================================================================
    ' 7. 【重整階段】重新排列序號 (Summary & Detail 同步更新)
    ' =================================================================
    
    ' 重新計算 Summary 最後一行
    lastRowSummary = wsSummary.Cells(wsSummary.Rows.Count, 3).End(xlUp).Row
    
    Dim newID As Long
    Dim oldID As String
    
   ' A. 迴圈處理每一行資料 (更新 Summary ID 和 Detail 關聯 ID)
    For i = 3 To lastRowSummary
        ' 計算該行應該要是什麼新的序號 (行號 - 標題行數)
        newID = i - 2
        
        ' 讀取目前格子裡的舊 ID
        oldID = wsSummary.Cells(i, 3).Value
        
        ' 如果 舊ID 不等於 新ID (代表需要更新)
        If CStr(oldID) <> CStr(newID) Then
            
            ' A. 更新 Detail 頁面 (將舊 ID 全部替換成新 ID)
            ' 使用 Replace 方法比迴圈更快
            ' 假設 Detail 的關聯序號在 A 欄 (Columns(1))
            wsDetail.Columns(1).Replace What:=oldID, _
                                        Replacement:=newID, _
                                        LookAt:=xlWhole, _
                                        SearchOrder:=xlByRows, _
                                        MatchCase:=False
            
            ' B. 更新 Summary 頁面 (寫入新 ID)
            wsSummary.Cells(i, 3).Value = newID
            
            ' (選用) 如果你的按鈕名稱也包含 ID，建議這裡也可以順便重命名按鈕
            ' 這裡稍微複雜，如果不影響運作可忽略
        End If
    Next i

    ' B. 遍歷剩餘的所有按鈕並重命名
    Dim btnRow As Long
    For Each opt In wsSummary.OptionButtons
        ' 獲取按鈕目前所在的行數 (因為刪除行後，按鈕會跟著上移，Row 屬性會變)
        btnRow = opt.TopLeftCell.Row
        
        ' 確保只處理資料範圍內的按鈕 (避開可能的標題列按鈕)
        If btnRow > 2 Then
            ' 重命名按鈕 Internal Name (方便程式呼叫) -> "OptBtn_2", "OptBtn_3"...
            opt.Name = "OptBtn_" & btnRow - 2
            
            ' (選用) 如果你想連按鈕上顯示的文字(Caption)都改成序號，請解開下面這行：
            ' opt.Caption = btnRow - 1
        End If
    Next opt


    Application.ScreenUpdating = True
    MsgBox "刪除完成！序號已重新排列。", vbInformation, "成功"

End Sub

