// test.js
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

// 請在 .env 裡設定這些 ID
// MAIN_DB_ID = Daily Q&A 主問題資料庫 ID
// ROUNDS_DB_ID = Conversation Rounds 回合資料庫 ID
const MAIN_DB_ID = process.env.MAIN_DB_ID;
const ROUNDS_DB_ID = process.env.ROUNDS_DB_ID;

async function main() {
  try {
    // 1. 新增一筆主問題
    const mainPage = await notion.pages.create({
      parent: { database_id: MAIN_DB_ID },
      properties: {
        "問題": { title: [{ text: { content: "今天最大的學習盲點是什麼？" } }] },
        "日期": { date: { start: new Date().toISOString().slice(0, 10) } },
        "問題類型": { select: { name: "反思" } },
        "狀態": { select: { name: "進行中" } },
        "盲點標籤": { multi_select: [{ name: "思維盲點" }] }
      }
    });

    console.log("✅ 主問題建立成功:", mainPage.id);

    // 2. 新增一筆回合，並關聯到主問題
    const roundPage = await notion.pages.create({
      parent: { database_id: ROUNDS_DB_ID },
      properties: {
        "所屬問題": { relation: [{ id: mainPage.id }] },
        "回合編號": { number: 1 },
        "使用者回答": { rich_text: [{ text: { content: "我常常在設計資料庫結構時卡住，不確定未來擴充性。" } }] },
        "AI 回饋": { rich_text: [{ text: { content: "很好，你已經意識到擴充性問題。建議先定義核心欄位，再逐步加上可選欄位。" } }] },
        "AI 追問": { rich_text: [{ text: { content: "如果要支援多輪問答，你會怎麼設計 Relation？" } }] },
        "標籤": { multi_select: [{ name: "技術" }] },
        "是否最後一輪": { checkbox: false }
      }
    });

    console.log("✅ 回合建立成功:", roundPage.id);

  } catch (err) {
    console.error("❌ 建立失敗:", err.body || err);
  }
}

main();

