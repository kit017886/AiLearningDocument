# 零基礎教學：用 Cursor 把筆記自動同步到 Notion

這篇文章將手把手教你如何打造一個「自動化筆記系統」。你只需要在 Cursor（一個超好用的 AI 程式碼編輯器）裡面寫 Markdown 筆記，存檔後按幾個按鈕，內容就會自動同步到你的 Notion 資料庫中！

即使你從來沒聽過 Git、GitHub 或 API，只要跟著步驟做，一定能完成。

---

## 第一階段：準備工作 (申請帳號與安裝)

### 1. 安裝 Cursor
*   前往 [Cursor 官網](https://cursor.sh/) 下載並安裝。
*   它長得跟 VS Code 很像，但內建了強大的 AI 助手。

### 2. 註冊 GitHub 帳號
*   前往 [GitHub](https://github.com/) 註冊一個免費帳號。
*   這是用來存放你筆記檔案的雲端倉庫。

### 3. 準備 Notion 資料庫
1.  在 Notion 中建立一個新的頁面。
2.  在頁面中輸入 `/database`，選擇 **Table view** (表格檢視) -> **New database** (新資料庫)。
3.  **重要**：請把第一欄（標題欄）保留，你可以把它改名為「標題」或「Title」，這會用來存放筆記的檔名。
4.  複製這個資料庫的 **ID**：
    *   看網址列：`https://www.notion.so/你的帳號/30aa71bd089a...?v=...`
    *   `30aa71bd089a...` 這串 32 個字元的亂碼就是 ID（在問號 `?` 之前）。

### 4. 取得 Notion 權限 (Token)
1.  前往 [Notion Developers](https://www.notion.so/my-integrations)。
2.  點擊 **Create new integration**。
3.  名字隨便取（例如：`Cursor-Sync`），按 Submit。
4.  複製 **Internal Integration Secret**（這是一串 `secret_` 開頭的密碼，請保管好）。
5.  **關鍵步驟**：回到你剛剛建立的 Notion 資料庫頁面，點擊右上角的 **... (三個點)** -> **Connect to** -> 搜尋並選擇你剛剛建立的 `Cursor-Sync`。
    *   *注意：如果沒做這步，程式會抓不到資料庫！*

---

## 第二階段：在 Cursor 中設定專案

### 1. 建立專案資料夾
1.  在電腦上建立一個新資料夾（例如 `MyNotes`）。
2.  打開 Cursor，點擊 `File` -> `Open Folder`，選擇這個資料夾。

### 2. 讓 AI 幫你寫程式
1.  按 `Ctrl + I` (或 `Cmd + I`) 開啟 Composer。
2.  輸入這段指令給 AI：
    > 「幫我建立一個 GitHub Action 自動化流程，當我更新 `Docs` 資料夾裡的 Markdown 檔案時，自動同步到 Notion 資料庫。請幫我寫好 `sync-to-notion.js` 腳本和 `.github/workflows/sync.yml` 設定檔。」
3.  AI 會自動幫你產生所有需要的檔案。你只需要按 `Accept` (接受)。

*(或是直接複製本文附錄的程式碼到對應位置)*

---

## 第三階段：連結 GitHub 並設定密碼

### 1. 初始化 Git (把檔案納入控管)
1.  在 Cursor 上方選單點 `Terminal` -> `New Terminal`。
2.  在下方出現的黑視窗輸入以下指令（每行輸入完按 Enter）：
    ```powershell
    git init
    git add .
    git commit -m "第一次設定"
    ```

### 2. 上傳到 GitHub
1.  去 GitHub 網站右上角點 `+` -> `New repository`。
2.  取個名字（例如 `MyNotes`），按 `Create repository`。
3.  複製畫面上的網址（例如 `https://github.com/你的名字/MyNotes.git`）。
4.  回到 Cursor 的 Terminal 輸入：
    ```powershell
    git remote add origin 貼上你的網址
    git branch -M main
    git push -u origin main
    ```

### 3. 設定 GitHub Secrets (保護你的 Notion 密碼)
1.  在你的 GitHub Repository 頁面，點 **Settings**。
2.  左邊選 **Secrets and variables** -> **Actions**。
3.  點 **New repository secret**，新增兩個秘密：
    *   **Name**: `NOTION_TOKEN`
        *   **Secret**: 貼上剛剛申請的 `secret_xxxx...`
    *   **Name**: `NOTION_DATABASE_ID`
        *   **Secret**: 貼上剛剛複製的資料庫 ID
    *   *(記得名字要全大寫，不能有錯字)*

---

## 第四階段：如何日常使用？

恭喜！設定全部完成了。以後你只需要專注寫筆記：

1.  在 Cursor 的 `AiLearningDocument` (或你設定的筆記資料夾) 中新增或修改 `.md` 檔案。
2.  寫完後，打開 Terminal 輸入這三行咒語：
    ```powershell
    git add .
    git commit -m "更新筆記"
    git push
    ```
3.  等個 1 分鐘，打開你的 Notion 資料庫，筆記就會自動出現了！

---

## 常見問題 (Troubleshooting)

*   **Q: Notion 沒反應？**
    *   檢查 GitHub 的 **Actions** 分頁，看看執行紀錄是綠色（成功）還是紅色（失敗）。
    *   如果是紅色，點進去看 `Run sync script` 的錯誤訊息。
    *   最常見原因是：**忘記在 Notion 資料庫按 `Connect to` 授權**。

*   **Q: 筆記沒更新？**
    *   腳本是根據「標題」來判斷的。如果你在 Notion 修改了標題，程式會以為是新筆記而重新建立一篇。

---

## 附錄：核心程式碼 (如果 AI 沒寫對)

**1. `.github/workflows/notion-sync.yml`**
```yaml
name: Sync to Notion
on:
  push:
    branches: [ main ]
jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm install @notionhq/client@2.2.15 fs-extra
      - run: node .github/scripts/sync-to-notion.js
        env:
          NOTION_TOKEN: ${{ secrets.NOTION_TOKEN }}
          NOTION_DATABASE_ID: ${{ secrets.NOTION_DATABASE_ID }}
```

**2. `.github/scripts/sync-to-notion.js`**
*(請參考專案中完整的腳本，包含自動偵測標題欄位功能)*

