// test-client-methods.js - 檢查 Client 物件的方法
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });

console.log("Notion Client 物件類型:", typeof notion);
console.log("\n可用的頂層屬性/方法:");
console.log(Object.keys(notion));

if (notion.databases) {
  console.log("\ndatabases 物件的方法:");
  console.log(Object.keys(notion.databases));
  console.log(Object.getOwnPropertyNames(Object.getPrototypeOf(notion.databases)));
}

