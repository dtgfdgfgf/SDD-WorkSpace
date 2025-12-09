// init-topic-summary.js - 自動創建主題總結資料庫
import 'dotenv/config';
import { Client } from "@notionhq/client";
import { tagsToNotionOptions } from './constants.js';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const parentPageId = process.env.PARENT_PAGE_ID;

// 已存在的資料庫 IDs（用於建立 Relation）
const KNOWLEDGE_DB_ID = process.env.NOTION_KNOWLEDGE_DB_ID;
const MAIN_DB_ID = process.env.NOTION_MAIN_DB_ID;

async function main() {
  try {
    console.log('🚀 開始創建主題總結資料庫...\n');

    // 創建主題總結資料庫
    const topicSummaryDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Topic Summaries 主題總結" } }],
      properties: {
        "標題": { title: {} },
        "主題標籤": {
          select: {
            options: tagsToNotionOptions()
          }
        },
        "總結內容": { rich_text: {} },
        "來源統計": { number: {} },
        "最後更新日期": { date: {} },
        "狀態": {
          select: {
            options: [
              { name: "已完成" },
              { name: "草稿" },
              { name: "需更新" }
            ]
          }
        }
      }
    });

    console.log("✅ 主題總結資料庫建立成功!");
    console.log(`📊 資料庫 ID: ${topicSummaryDb.id}\n`);

    // 如果有知識片段和主問題資料庫，建立 Relation
    if (KNOWLEDGE_DB_ID && MAIN_DB_ID) {
      console.log('🔗 正在建立資料庫關聯（Relation）...\n');

      await notion.databases.update({
        database_id: topicSummaryDb.id,
        properties: {
          "關聯知識片段": {
            relation: {
              database_id: KNOWLEDGE_DB_ID,
              single_property: {}
            }
          },
          "關聯對話總結": {
            relation: {
              database_id: MAIN_DB_ID,
              single_property: {}
            }
          }
        }
      });

      console.log("✅ 資料庫關聯建立成功!\n");
    } else {
      console.log("⚠️  未找到知識片段或主問題資料庫 ID");
      console.log("   Relation 欄位已跳過（可稍後在 Notion UI 手動新增）\n");
    }

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🎉 設置完成！\n");
    console.log("📝 下一步：");
    console.log("1. 複製以下內容到你的 .env 檔案：");
    console.log(`   NOTION_TOPIC_SUMMARY_DB_ID=${topicSummaryDb.id}\n`);
    console.log("2. 設置 Vercel 環境變數：");
    console.log(`   vercel env add NOTION_TOPIC_SUMMARY_DB_ID\n`);
    console.log("3. 重新部署：");
    console.log("   vercel --prod\n");
    console.log("4. 測試功能：");
    console.log("   - LINE: 總結 客戶開發");
    console.log("   - LINE: 查詢 客戶開發");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

  } catch (err) {
    console.error("❌ 建立失敗:", err.body || err);
    process.exit(1);
  }
}

main();
