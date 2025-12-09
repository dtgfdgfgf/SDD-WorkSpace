// init.js
import 'dotenv/config';
import { Client } from "@notionhq/client";
import { tagsToNotionOptions } from './constants.js';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const parentPageId = process.env.PARENT_PAGE_ID;

async function main() {
  try {
    // 1. 建立主問題資料庫
    const mainDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Daily Q&A 主問題" } }],
      properties: {
        "問題": { title: {} },
        "日期": { date: {} },
        "問題類型": { select: { options: [
          { name: "反思" }, { name: "情境" }, { name: "知識探索" }
        ]}},
        "狀態": { select: { options: [
          { name: "進行中" }, { name: "已完成" }
        ]}},
        "總結": { rich_text: {} },
        "盲點標籤": { multi_select: { options: tagsToNotionOptions() }}
        // Relation 與 Rollup 稍後補
      }
    });
    console.log("主問題資料庫建立成功:", mainDb.id);

    // 2. 建立回合資料庫
    const roundsDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Conversation Rounds 回合" } }],
      properties: {
        "標題": { title: {} },  // 必須要有 title 欄位
        "所屬問題": { relation: { database_id: mainDb.id, single_property: {} } },
        "回合編號": { number: {} },
        "使用者回答": { rich_text: {} },
        "AI 回饋": { rich_text: {} },
        "AI 追問": { rich_text: {} },
        "標籤": { multi_select: { options: tagsToNotionOptions() }},
        "時間戳記": { created_time: {} },
        "是否最後一輪": { checkbox: {} }
      }
    });
    console.log("回合資料庫建立成功:", roundsDb.id);

    // 3. 建立題庫資料庫
    const questionBankDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Question Bank 題庫" } }],
      properties: {
        "問題": { title: {} },
        "類型": { select: { options: [
          { name: "反思" }, { name: "情境" }, { name: "知識探索" }
        ]}},
        "建議回答方向": { rich_text: {} },
        "狀態": { select: { options: [
          { name: "未使用" }, { name: "已使用" }, { name: "重複" }
        ]}},
        "使用日期": { date: {} }
        // Relation 稍後補
      }
    });
    console.log("題庫資料庫建立成功:", questionBankDb.id);

    // 4. 建立週報資料庫
    const weeklyDb = await notion.databases.create({
      parent: { type: "page_id", page_id: parentPageId },
      title: [{ type: "text", text: { content: "Weekly Review 週報" } }],
      properties: {
        "標題": { title: {} },  // 必須要有 title 欄位
        "週期": { date: {} },
        "行動計畫": { rich_text: {} },
        "小實驗驗證": { rich_text: {} }
        // Relation 與 Rollup 稍後補
      }
    });
    console.log("週報資料庫建立成功:", weeklyDb.id);

    // 5. 更新主問題資料庫，補 Relation
    await notion.databases.update({
      database_id: mainDb.id,
      properties: {
        "回合紀錄": { relation: { database_id: roundsDb.id, single_property: {} } },
        "週報關聯": { relation: { database_id: weeklyDb.id, single_property: {} } },
        "來源題目": { relation: { database_id: questionBankDb.id, single_property: {} } }
      }
    });

    // 6. 更新題庫資料庫，補 Relation
    await notion.databases.update({
      database_id: questionBankDb.id,
      properties: {
        "關聯主問題": { relation: { database_id: mainDb.id, single_property: {} } }
      }
    });

    // 7. 更新週報資料庫，補 Relation
    await notion.databases.update({
      database_id: weeklyDb.id,
      properties: {
        "關聯主問題": { relation: { database_id: mainDb.id, single_property: {} } }
        // ⚠️ Rollup 需手動在 UI 裡新增
      }
    });

    console.log("所有 Relation 已建立完成 ✅");
    console.log("⚠️ 提醒：Rollup 欄位需在 Notion UI 手動新增（API 尚不支援）");

  } catch (err) {
    console.error("建立失敗:", err.body || err);
  }
}

main();

