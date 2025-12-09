// test-all.js - 為所有資料庫建立測試資料
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

const MAIN_DB_ID = process.env.MAIN_DB_ID;
const ROUNDS_DB_ID = process.env.ROUNDS_DB_ID;
const QUESTION_BANK_DB_ID = process.env.QUESTION_BANK_DB_ID;
const WEEKLY_DB_ID = process.env.WEEKLY_DB_ID;

async function main() {
  try {
    console.log("開始建立測試資料...\n");

    // 1. 建立題庫測試資料
    const questionBankPage = await notion.pages.create({
      parent: { database_id: QUESTION_BANK_DB_ID },
      properties: {
        "問題": { title: [{ text: { content: "你最近遇到最大的技術挑戰是什麼？" } }] },
        "類型": { select: { name: "反思" } },
        "建議回答方向": { rich_text: [{ text: { content: "引導思考具體場景、遇到的困難點、嘗試過的解決方案" } }] },
        "狀態": { select: { name: "已使用" } },
        "使用日期": { date: { start: "2025-10-07" } }
      }
    });
    console.log("✅ 題庫測試資料建立成功:", questionBankPage.id);

    // 2. 建立主問題測試資料
    const mainPage = await notion.pages.create({
      parent: { database_id: MAIN_DB_ID },
      properties: {
        "問題": { title: [{ text: { content: "今天最大的學習盲點是什麼？" } }] },
        "日期": { date: { start: "2025-10-07" } },
        "問題類型": { select: { name: "反思" } },
        "狀態": { select: { name: "進行中" } },
        "總結": { rich_text: [{ text: { content: "發現在資料庫設計時缺乏對未來擴充性的考量，需要加強系統思維" } }] },
        "盲點標籤": { multi_select: [{ name: "思維盲點" }, { name: "技術" }] },
        "來源題目": { relation: [{ id: questionBankPage.id }] }
      }
    });
    console.log("✅ 主問題測試資料建立成功:", mainPage.id);

    // 3. 建立回合測試資料（關聯到主問題）
    const roundPage = await notion.pages.create({
      parent: { database_id: ROUNDS_DB_ID },
      properties: {
        "標題": { title: [{ text: { content: "第一回合" } }] },
        "所屬問題": { relation: [{ id: mainPage.id }] },
        "回合編號": { number: 1 },
        "使用者回答": { rich_text: [{ text: { content: "我常常在設計資料庫結構時卡住，不確定未來擴充性應該如何規劃。" } }] },
        "AI 回饋": { rich_text: [{ text: { content: "很好的觀察！擴充性確實是設計初期容易忽略的。建議先定義核心必要欄位，再逐步增加可選欄位，並善用 Relation 來處理一對多關係。" } }] },
        "AI 追問": { rich_text: [{ text: { content: "如果要支援多輪問答記錄，你會如何設計 Relation 關係？" } }] },
        "標籤": { multi_select: [{ name: "技術" }, { name: "思維盲點" }] },
        "是否最後一輪": { checkbox: false }
      }
    });
    console.log("✅ 回合測試資料建立成功:", roundPage.id);

    // 4. 建立週報測試資料
    const weeklyPage = await notion.pages.create({
      parent: { database_id: WEEKLY_DB_ID },
      properties: {
        "標題": { title: [{ text: { content: "2025 W41 週報" } }] },
        "週期": { date: { start: "2025-10-07", end: "2025-10-13" } },
        "行動計畫": { rich_text: [{ text: { content: "本週重點：\n1. 深入學習資料庫設計模式\n2. 實踐 Notion API 整合\n3. 建立每日反思習慣" } }] },
        "小實驗驗證": { rich_text: [{ text: { content: "實驗1: 用 Notion 建立個人知識管理系統\n驗證指標: 每日至少記錄一個學習盲點" } }] },
        "關聯主問題": { relation: [{ id: mainPage.id }] }
      }
    });
    console.log("✅ 週報測試資料建立成功:", weeklyPage.id);

    // 5. 更新題庫的關聯主問題
    await notion.pages.update({
      page_id: questionBankPage.id,
      properties: {
        "關聯主問題": { relation: [{ id: mainPage.id }] }
      }
    });
    console.log("✅ 題庫關聯已更新");

    console.log("\n🎉 所有測試資料建立完成！");
    console.log("\n資料庫 ID 參考：");
    console.log("- 主問題資料庫:", MAIN_DB_ID);
    console.log("- 回合資料庫:", ROUNDS_DB_ID);
    console.log("- 題庫資料庫:", QUESTION_BANK_DB_ID);
    console.log("- 週報資料庫:", WEEKLY_DB_ID);

  } catch (err) {
    console.error("❌ 建立失敗:", err.body || err);
  }
}

main();

