/**
 * 重置卡在「處理中」狀態的任務
 * 使用：node scripts/reset-stuck-tasks.js
 */

import { Client } from '@notionhq/client';
import dotenv from 'dotenv';

dotenv.config();

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const TASK_QUEUE_DB_ID = process.env.NOTION_TASK_QUEUE_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');

async function resetStuckTasks() {
  console.log('🔍 查詢處理中的任務...');

  // 查詢所有「處理中」的任務
  const response = await notion.databases.query({
    database_id: TASK_QUEUE_DB_ID,
    filter: {
      property: '狀態',
      select: {
        equals: '處理中'
      }
    }
  });

  console.log(`📊 找到 ${response.results.length} 個處理中的任務`);

  for (const page of response.results) {
    const title = page.properties['標題']?.title[0]?.plain_text || 'Unknown';
    const startTime = page.properties['開始時間']?.date?.start;

    console.log(`\n🔄 重置任務: ${title}`);
    console.log(`   開始時間: ${startTime}`);

    // 重置狀態為「待處理」
    await notion.pages.update({
      page_id: page.id,
      properties: {
        '狀態': {
          select: {
            name: '待處理'
          }
        },
        '開始時間': {
          date: null
        },
        '錯誤訊息': {
          rich_text: [
            {
              text: {
                content: '任務已重置（之前卡在處理中狀態）'
              }
            }
          ]
        }
      }
    });

    console.log(`   ✅ 已重置為「待處理」`);
  }

  console.log(`\n✅ 完成！重置了 ${response.results.length} 個任務`);
}

resetStuckTasks().catch(error => {
  console.error('❌ 錯誤:', error);
  process.exit(1);
});
