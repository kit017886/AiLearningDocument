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

  // 初始化 Notion Client
  const notion = new Client({ auth: token });

  // 修正路徑：直接使用當前目錄下的 AiLearningDocument
  const docsDir = path.resolve(process.cwd(), "AiLearningDocument");
  
  if (!(await fs.pathExists(docsDir))) {
    console.error(`❌ Error: Directory not found at ${docsDir}`);
    return;
  }

  const files = await getMarkdownFiles(docsDir);
  console.log(`📂 Found ${files.length} markdown files to sync.`);

  for (const file of files) {
    const title = path.basename(file, ".md");
    try {
      const content = await fs.readFile(file, "utf-8");
      
      console.log(`📝 Processing: ${title}...`);

      // 1. 檢查頁面是否已存在
      const response = await notion.databases.query({
        database_id: databaseId,
        filter: {
          property: "Name", 
          title: { equals: title },
        },
      });

      const blocks = parseMarkdownToBlocks(content);

      if (response.results.length > 0) {
        const pageId = response.results[0].id;
        console.log(`   Found existing page (ID: ${pageId}), updating...`);
        
        await notion.pages.update({
          page_id: pageId,
          properties: {
            Name: { title: [{ text: { content: title } }] },
          },
        });

        await clearPageContent(notion, pageId);
        await appendBlocks(notion, pageId, blocks);
        console.log(`   ✅ Updated: ${title}`);
      } else {
        console.log(`   No existing page found, creating new one...`);
        const newPage = await notion.pages.create({
          parent: { database_id: databaseId },
          properties: {
            Name: { title: [{ text: { content: title } }] },
          },
          children: blocks.slice(0, 100),
        });

        if (blocks.length > 100) {
          await appendBlocks(notion, newPage.id, blocks.slice(100));
        }
        console.log(`   ✨ Created: ${title}`);
      }
    } catch (err) {
      console.error(`   ❌ Failed to sync ${title}:`, err.message);
      if (err.body) console.log(`      API Response: ${err.body}`);
    }
  }
  console.log("🏁 Sync process finished.");
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

async function clearPageContent(notion, pageId) {
  const { results } = await notion.blocks.children.list({ block_id: pageId });
  for (const block of results) {
    try {
      await notion.blocks.delete({ block_id: block.id });
    } catch (e) {
      // 忽略部分無法刪除的 block 錯誤
    }
  }
}

async function appendBlocks(notion, blockId, blocks) {
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
    const trimmed = line.trim();
    if (!trimmed) continue;

    if (trimmed.startsWith("# ")) {
      blocks.push({
        object: "block",
        type: "heading_1",
        heading_1: { rich_text: [{ type: "text", text: { content: trimmed.substring(2) } }] },
      });
    } else if (trimmed.startsWith("## ")) {
      blocks.push({
        object: "block",
        type: "heading_2",
        heading_2: { rich_text: [{ type: "text", text: { content: trimmed.substring(3) } }] },
      });
    } else if (trimmed.startsWith("### ")) {
      blocks.push({
        object: "block",
        type: "heading_3",
        heading_3: { rich_text: [{ type: "text", text: { content: trimmed.substring(4) } }] },
      });
    } else if (trimmed.startsWith("- ")) {
      blocks.push({
        object: "block",
        type: "bulleted_list_item",
        bulleted_list_item: { rich_text: [{ type: "text", text: { content: trimmed.substring(2) } }] },
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

sync().catch(err => {
  console.error("🔥 Fatal Error:", err);
  process.exit(1);
});
