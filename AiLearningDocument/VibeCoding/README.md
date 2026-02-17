# AI 學習筆記與技巧文件庫

這個資料夾專門用於存放與 AI 使用技巧相關的文章與筆記。

## 如何與 Notion 串接？

由於 Notion 支援 Markdown 匯入與同步，您可以透過以下幾種方式連通：

1. **手動匯入**：在 Notion 中點擊 `Import`，選擇 `Text & Markdown`，然後選取此資料夾中的檔案。
2. **Notion API 自動同步**：目前已配置 GitHub Actions 工作流。當您將變更推送到 GitHub 時，`.github/workflows/notion-sync.yml` 會自動觸發並同步 `AiLearningDocument` 資料夾下的 Markdown 檔案到 Notion。
   - **設定需求**：
     - 在 GitHub Repository 的 `Settings > Secrets and variables > Actions` 中新增：
       - `NOTION_TOKEN`: Notion Integration 的 Secret Token。
       - `NOTION_DATABASE_ID`: 目標 Notion 資料庫的 ID。
     - 確保 Notion 資料庫已分享（Connect）給該 Integration。
3. **直接貼上**：此資料夾中的內容均為 Markdown 格式，您可以直接複製內容並貼上到 Notion，格式會自動保留。

## 資料夾結構建議

- `/Prompts`: 存放各種高效的 Prompt 模板。
- `/Tools`: 紀錄各種 AI 工具的使用心得（如 Cursor, Claude, ChatGPT）。
- `/Workflows`: 紀錄 AI 如何融入工作流的案例。

---
*建立日期：2026-02-17*

