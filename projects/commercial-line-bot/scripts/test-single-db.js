// test-single-db.js - 測試單一資料庫
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

async function main() {
  try {
    // 使用原始格式的 ID（帶連字號）
    const dbId = "3062c10e-a7a2-47a6-be03-00259a7f9954";
    console.log("測試 ID:", dbId);

    const dbInfo = await notion.databases.retrieve({ database_id: dbId });
    console.log("\n完整資料庫資訊:");
    console.log(JSON.stringify(dbInfo, null, 2));
  } catch (err) {
    console.error("❌ 錯誤:", err.message);
    console.error("詳細:", err.body || err);
  }
}

main();

