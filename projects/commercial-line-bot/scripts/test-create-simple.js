// test-create-simple.js - 測試建立簡單資料庫
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({
  auth: process.env.NOTION_TOKEN
  // 使用預設最新版本
});

async function main() {
  try {
    console.log("開始建立測試資料庫...");

    const testDb = await notion.databases.create({
      parent: {
        type: "page_id",
        page_id: process.env.PARENT_PAGE_ID
      },
      title: [{
        type: "text",
        text: { content: "測試資料庫 Test" }
      }],
      properties: {
        "Name": {
          title: {}
        },
        "測試欄位": {
          rich_text: {}
        },
        "日期": {
          date: {}
        }
      }
    });

    console.log("✅ 資料庫建立成功:", testDb.id);
    console.log("\n建立時回傳的 properties:");
    if (testDb.properties) {
      Object.keys(testDb.properties).forEach(prop => {
        console.log(`- ${prop} (${testDb.properties[prop].type})`);
      });
    } else {
      console.log("⚠️ 建立時沒有 properties");
    }

    // 立即讀取確認
    const dbInfo = await notion.databases.retrieve({ database_id: testDb.id });
    console.log("\n讀取時的 properties:");
    if (dbInfo.properties) {
      Object.keys(dbInfo.properties).forEach(prop => {
        console.log(`- ${prop} (${dbInfo.properties[prop].type})`);
      });
    } else {
      console.log("⚠️ 讀取時沒有 properties");
      console.log("\ndbInfo keys:", Object.keys(dbInfo));
    }

  } catch (err) {
    console.error("❌ 失敗:", err.message);
    console.error("詳細:", JSON.stringify(err.body || err, null, 2));
  }
}

main();

