const { Client } = require("@notionhq/client");
const fs = require("fs-extra");
const path = require("path");

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

async function sync() {
  const docsDir = path.join(process.cwd(), "AiLearningDocument");
  const files = await getMarkdownFiles(docsDir);

  for (const file of files) {
    const content = await fs.readFile(file, "utf-8");
    const title = path.basename(file, ".md");
    const relativePath = path.relative(docsDir, file);

    console.log(`Syncing: ${title} (${relativePath})...`);

    // 1. 檢查頁面是否已存在於資料庫
    const response = await notion.databases.query({
      database_id: DATABASE_ID,
      filter: {
        property: "Name", // 假設資料庫標題欄位名稱為 "Name"
        title: {
          equals: title,
        },
      },
    });

    const blocks = parseMarkdownToBlocks(content);

    if (response.results.length > 0) {
      // 2. 更新現有頁面
      const pageId = response.results[0].id;
      
      // 更新屬性 (選擇性)
      await notion.pages.update({
        page_id: pageId,
        properties: {
          Name: {
            title: [{ text: { content: title } }],
          },
        },
      });

      // 清除舊內容並寫入新內容
      await clearPageContent(pageId);
      await appendBlocks(pageId, blocks);
      console.log(`✅ Updated: ${title}`);
    } else {
      // 3. 建立新頁面
      const newPage = await notion.pages.create({
        parent: { database_id: DATABASE_ID },
        properties: {
          Name: {
            title: [{ text: { content: title } }],
          },
        },
        children: blocks.slice(0, 100), // Notion API 限制一次最多 100 個 blocks
      });

      if (blocks.length > 100) {
        await appendBlocks(newPage.id, blocks.slice(100));
      }
      console.log(`✨ Created: ${title}`);
    }
  }
}

async function getMarkdownFiles(dir) {
  let results = [];
  const list = await fs.readdir(dir);
  for (const file of list) {
    const fullPath = path.join(dir, file);
    const stat = await fs.stat(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(await getMarkdownFiles(fullPath));
    } else if (file.endsWith(".md")) {
      results.push(fullPath);
    }
  }
  return results;
}

async function clearPageContent(pageId) {
  const { results } = await notion.blocks.children.list({ block_id: pageId });
  for (const block of results) {
    await notion.blocks.delete({ block_id: block.id });
  }
}

async function appendBlocks(blockId, blocks) {
  // Notion API 每次最多只能 append 100 個 blocks
  for (let i = 0; i < blocks.length; i += 100) {
    const chunk = blocks.slice(i, i + 100);
    await notion.blocks.children.append({
      block_id: blockId,
      children: chunk,
    });
  }
}

function parseMarkdownToBlocks(markdown) {
  const lines = markdown.split("\n");
  const blocks = [];

  for (let line of lines) {
    line = line.trim();
    if (!line) continue;

    if (line.startsWith("# ")) {
      blocks.push({
        object: "block",
        type: "heading_1",
        heading_1: { rich_text: [{ type: "text", text: { content: line.substring(2) } }] },
      });
    } else if (line.startsWith("## ")) {
      blocks.push({
        object: "block",
        type: "heading_2",
        heading_2: { rich_text: [{ type: "text", text: { content: line.substring(3) } }] },
      });
    } else if (line.startsWith("### ")) {
      blocks.push({
        object: "block",
        type: "heading_3",
        heading_3: { rich_text: [{ type: "text", text: { content: line.substring(4) } }] },
      });
    } else if (line.startsWith("- ")) {
      blocks.push({
        object: "block",
        type: "bulleted_list_item",
        bulleted_list_item: { rich_text: [{ type: "text", text: { content: line.substring(2) } }] },
      });
    } else {
      blocks.push({
        object: "block",
        type: "paragraph",
        paragraph: { rich_text: [{ type: "text", text: { content: line } }] },
      });
    }
  }

  return blocks;
}

sync().catch(console.error);

