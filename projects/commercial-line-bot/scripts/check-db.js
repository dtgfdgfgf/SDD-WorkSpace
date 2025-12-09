// check-db.js - 檢查資料庫結構
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

async function main() {
  try {
    const dbIds = [
      { name: "主問題", id: process.env.MAIN_DB_ID },
      { name: "回合", id: process.env.ROUNDS_DB_ID },
      { name: "題庫", id: process.env.QUESTION_BANK_DB_ID },
      { name: "週報", id: process.env.WEEKLY_DB_ID }
    ];

    for (const db of dbIds) {
      console.log(`\n=== ${db.name} 資料庫 (${db.id}) ===`);
      try {
        const dbInfo = await notion.databases.retrieve({ database_id: db.id });
        console.log("完整資料:", JSON.stringify(dbInfo, null, 2));
      } catch (err) {
        console.error(`取得 ${db.name} 失敗:`, err.message);
        console.error("完整錯誤:", err);
      }
    }
  } catch (err) {
    console.error("❌ 錯誤:", err.body || err);
  }
}

main();

