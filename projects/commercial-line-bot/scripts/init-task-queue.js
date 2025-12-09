// init-task-queue.js - 創建任務隊列資料庫
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const parentPageId = process.env.PARENT_PAGE_ID;

async function main() {
  try {
    console.log('🚀 開始創建任務隊列資料庫...\n');

    // 創建任務隊列資料庫
    const taskQueueDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Task Queue 任務隊列" } }],
      properties: {
        "標題": { title: {} },
        "任務類型": {
          select: {
            options: [
              { name: "批次總結", color: "blue" },
              { name: "單一總結", color: "green" },
              { name: "其他", color: "gray" }
            ]
          }
        },
        "狀態": {
          select: {
            options: [
              { name: "待處理", color: "default" },
              { name: "處理中", color: "yellow" },
              { name: "已完成", color: "green" },
              { name: "失敗", color: "red" }
            ]
          }
        },
        "用戶ID": { rich_text: {} },
        "任務參數": { rich_text: {} },
        "結果訊息": { rich_text: {} },
        "錯誤訊息": { rich_text: {} },
        "開始時間": { date: {} },
        "完成時間": { date: {} },
        "優先級": {
          select: {
            options: [
              { name: "高", color: "red" },
              { name: "中", color: "yellow" },
              { name: "低", color: "gray" }
            ]
          }
        },
        "重試次數": { number: {} }
      }
    });

    console.log("✅ 任務隊列資料庫建立成功!");
    console.log(`📊 資料庫 ID: ${taskQueueDb.id}\n`);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("🎉 設置完成！\n");
    console.log("📝 下一步：");
    console.log("1. 複製以下內容到你的 .env 檔案：");
    console.log(`   NOTION_TASK_QUEUE_DB_ID=${taskQueueDb.id}\n`);
    console.log("2. 設置 Vercel 環境變數：");
    console.log(`   vercel env add NOTION_TASK_QUEUE_DB_ID\n`);
    console.log(`   輸入值：${taskQueueDb.id}\n`);
    console.log("3. 執行部署：");
    console.log(`   vercel --prod\n`);
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

  } catch (error) {
    console.error('❌ 創建失敗:', error);
    process.exit(1);
  }
}

main();
