const { Client } = require("@notionhq/client");
const fs = require("fs-extra");
const path = require("path");

async function sync() {
  console.log("🚀 Starting sync process...");
  
  const token = process.env.NOTION_TOKEN;
  const databaseId = process.env.NOTION_DATABASE_ID;

  if (!token || !databaseId) {
    console.error("❌ Error: NOTION_TOKEN or NOTION_DATABASE_ID is missing.");
    process.exit(1);
  }

  console.log("✅ Environment variables loaded successfully.");
  console.log(`   Database ID: ${databaseId.substring(0, 8)}...`);

  // 初始化 Notion Client (官方標準寫法)
  const notion = new Client({ auth: token });
  console.log("✅ Notion Client initialized.");

  // 檢查 SDK 功能
  if (!notion || !notion.databases || typeof notion.databases.query !== 'function') {
    console.error("❌ Notion SDK not properly loaded!");
    console.error("   Debug info:");
    console.error("   - notion exists:", !!notion);
    console.error("   - notion.databases exists:", !!(notion && notion.databases));
    console.error("   - query function type:", notion && notion.databases ? typeof notion.databases.query : 'N/A');
    process.exit(1);
  }
  console.log("✅ Notion SDK verified (databases.query is available).");

  const docsDir = path.resolve(process.cwd(), "AiLearningDocument");
  if (!(await fs.pathExists(docsDir))) {
    console.error(`❌ Error: Directory not found at ${docsDir}`);
    return;
  }

  const files = await getMarkdownFiles(docsDir);
  console.log(`📂 Found ${files.length} markdown files to sync.\n`);

  for (const file of files) {
    const title = path.basename(file, ".md");
    try {
      const content = await fs.readFile(file, "utf-8");
      console.log(`📝 Processing: ${title}...`);

      // 查詢資料庫中是否已有同名頁面
      const queryResponse = await notion.databases.query({
        database_id: databaseId,
        filter: {
          property: "Name",
          title: {
            equals: title,
          },
        },
      });

      const blocks = parseMarkdownToBlocks(content);
      console.log(`   Parsed ${blocks.length} blocks from markdown.`);

      if (queryResponse.results.length > 0) {
        // 更新現有頁面
        const pageId = queryResponse.results[0].id;
        console.log(`   Found existing page, updating (ID: ${pageId.substring(0, 8)}...)...`);
        
        await notion.pages.update({
          page_id: pageId,
          properties: {
            Name: {
              title: [{ text: { content: title } }],
            },
          },
        });

        // 清空舊內容
        await clearPageContent(notion, pageId);
        
        // 新增新內容
        await appendBlocks(notion, pageId, blocks);
        console.log(`   ✅ Updated successfully!\n`);
      } else {
        // 建立新頁面
        console.log(`   Creating new page...`);
        const newPage = await notion.pages.create({
          parent: { database_id: databaseId },
          properties: {
            Name: {
              title: [{ text: { content: title } }],
            },
          },
          children: blocks.slice(0, 100),
        });

        if (blocks.length > 100) {
          await appendBlocks(notion, newPage.id, blocks.slice(100));
        }
        console.log(`   ✨ Created successfully!\n`);
      }
    } catch (err) {
      console.error(`   ❌ Failed to sync ${title}:`);
      console.error(`      Error: ${err.message}`);
      if (err.code) console.error(`      Code: ${err.code}`);
      if (err.body) console.error(`      Body: ${JSON.stringify(err.body, null, 2)}`);
      console.log('');
    }
  }
  console.log("🏁 Sync process finished.");
}

async function getMarkdownFiles(dir) {
  let results = [];
  const items = await fs.readdir(dir);
  
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = await fs.stat(fullPath);
    
    if (stat.isDirectory()) {
      const subFiles = await getMarkdownFiles(fullPath);
      results = results.concat(subFiles);
    } else if (item.endsWith(".md")) {
      results.push(fullPath);
    }
  }
  
  return results;
}

async function clearPageContent(notion, pageId) {
  try {
    const { results } = await notion.blocks.children.list({ 
      block_id: pageId 
    });
    
    for (const block of results) {
      try {
        await notion.blocks.delete({ block_id: block.id });
      } catch (deleteErr) {
        // 某些 block 無法刪除，忽略錯誤
      }
    }
  } catch (err) {
    console.error(`      Warning: Could not clear page content: ${err.message}`);
  }
}

async function appendBlocks(notion, blockId, blocks) {
  // Notion API 限制：一次最多 100 個 blocks
  for (let i = 0; i < blocks.length; i += 100) {
    const chunk = blocks.slice(i, Math.min(i + 100, blocks.length));
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
    const trimmed = line.trim();
    
    // 跳過空行
    if (!trimmed) continue;

    // 標題 1
    if (trimmed.startsWith("# ")) {
      blocks.push({
        object: "block",
        type: "heading_1",
        heading_1: {
          rich_text: [{ 
            type: "text", 
            text: { content: trimmed.substring(2) } 
          }],
        },
      });
    }
    // 標題 2
    else if (trimmed.startsWith("## ")) {
      blocks.push({
        object: "block",
        type: "heading_2",
        heading_2: {
          rich_text: [{ 
            type: "text", 
            text: { content: trimmed.substring(3) } 
          }],
        },
      });
    }
    // 標題 3
    else if (trimmed.startsWith("### ")) {
      blocks.push({
        object: "block",
        type: "heading_3",
        heading_3: {
          rich_text: [{ 
            type: "text", 
            text: { content: trimmed.substring(4) } 
          }],
        },
      });
    }
    // 無序列表
    else if (trimmed.startsWith("- ")) {
      blocks.push({
        object: "block",
        type: "bulleted_list_item",
        bulleted_list_item: {
          rich_text: [{ 
            type: "text", 
            text: { content: trimmed.substring(2) } 
          }],
        },
      });
    }
    // 段落（保留原始縮排）
    else {
      blocks.push({
        object: "block",
        type: "paragraph",
        paragraph: {
          rich_text: [{ 
            type: "text", 
            text: { content: line } 
          }],
        },
      });
    }
  }

  return blocks;
}

// 啟動同步程序
sync().catch(err => {
  console.error("\n🔥 Fatal Error:");
  console.error(err);
  process.exit(1);
});
