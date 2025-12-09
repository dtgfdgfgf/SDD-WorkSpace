// test-db-schema.js - 測試不同方式讀取資料庫
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

async function main() {
  try {
    // 使用已經存在的資料庫
    const dbId = "3062c10e-a7a2-47a6-be03-00259a7f9954";

    console.log("方法 1: databases.retrieve");
    const db1 = await notion.databases.retrieve({
      database_id: dbId
    });
    console.log("Keys:", Object.keys(db1));
    console.log("Has properties?", 'properties' in db1);

    console.log("\n方法 2: databases.query (只查1筆)");
    try {
      const query = await notion.databases.query({
        database_id: dbId,
        page_size: 1
      });
      console.log("Query結果:", query);
    } catch (err) {
      console.log("Query錯誤:", err.message);
    }

    // 嘗試直接在 Notion Web 檢視
    console.log("\n資料庫 URL:", `https://notion.so/${dbId.replace(/-/g, '')}`);

  } catch (err) {
    console.error("錯誤:", err.message);
    if (err.body) console.error("詳細:", err.body);
  }
}

main();

