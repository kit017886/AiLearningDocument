const { Client } = require("@notionhq/client");
const fs = require("fs-extra");
const path = require("path");

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

async function sync() {
  console.log("🚀 Starting sync process...");
  
  if (!process.env.NOTION_TOKEN || !DATABASE_ID) {
    console.error("❌ Error: NOTION_TOKEN or NOTION_DATABASE_ID is missing in environment variables.");
    process.exit(1);
  }

  const docsDir = path.join(process.cwd(), "AiLearningDocument");
  
  if (!(await fs.pathExists(docsDir))) {
    console.error(`❌ Error: Directory not found at ${docsDir}`);
    return;
  }

  const files = await getMarkdownFiles(docsDir);
  console.log(`📂 Found ${files.length} markdown files to sync.`);

  for (const file of files) {
    try {
      const content = await fs.readFile(file, "utf-8");
      const title = path.basename(file, ".md");
      const relativePath = path.relative(docsDir, file);

      console.log(`📝 Processing: ${title}...`);

      // 1. 檢查頁面是否已存在
      const response = await notion.databases.query({
        database_id: DATABASE_ID,
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

        await clearPageContent(pageId);
        await appendBlocks(pageId, blocks);
        console.log(`   ✅ Updated: ${title}`);
      } else {
        console.log(`   No existing page found, creating new one...`);
        const newPage = await notion.pages.create({
          parent: { database_id: DATABASE_ID },
          properties: {
            Name: { title: [{ text: { content: title } }] },
          },
          children: blocks.slice(0, 100),
        });

        if (blocks.length > 100) {
          await appendBlocks(newPage.id, blocks.slice(100));
        }
        console.log(`   ✨ Created: ${title}`);
      }
    } catch (err) {
      console.error(`   ❌ Failed to sync ${file}:`, err.message);
      if (err.body) console.error(`      Detail: ${err.body}`);
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

async function clearPageContent(pageId) {
  const { results } = await notion.blocks.children.list({ block_id: pageId });
  for (const block of results) {
    await notion.blocks.delete({ block_id: block.id });
  }
}

async function appendBlocks(blockId, blocks) {
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
