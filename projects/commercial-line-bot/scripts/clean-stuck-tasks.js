/**
 * 清理 Notion 中卡住的任務
 * 用途：將所有「處理中」的任務標記為「失敗」並添加說明
 */

import { Client } from '@notionhq/client';
import dotenv from 'dotenv';

dotenv.config();

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const TASK_QUEUE_DB_ID = (process.env.NOTION_TASK_QUEUE_DB_ID || '').trim().replace(/\n/g, '').replace(/\n/g, '');

async function cleanStuckTasks() {
  console.log('🧹 開始清理卡住的任務...\n');

  if (!TASK_QUEUE_DB_ID) {
    console.log('⚠️  NOTION_TASK_QUEUE_DB_ID 未設置，跳過清理');
    console.log('   （這是正常的，因為新版本不再使用任務隊列）');
    return;
  }

  try {
    // 查詢所有非「已完成」和「失敗」的任務（包含「處理中」和「待處理」）
    const response = await notion.databases.query({
      database_id: TASK_QUEUE_DB_ID,
      filter: {
        or: [
          {
            property: '狀態',
            select: {
              equals: '處理中'
            }
          },
          {
            property: '狀態',
            select: {
              equals: '待處理'
            }
          }
        ]
      }
    });

    console.log(`📊 找到 ${response.results.length} 個需要清理的任務\n`);

    if (response.results.length === 0) {
      console.log('✅ 沒有需要清理的任務');
      return;
    }

    // 更新每個任務為「失敗」
    let cleanedCount = 0;
    for (const task of response.results) {
      const taskTitle = task.properties['任務名稱']?.title?.[0]?.plain_text || '未命名';
      const currentStatus = task.properties['狀態']?.select?.name || '未知';

      console.log(`🔄 清理任務: ${taskTitle} (當前狀態: ${currentStatus})`);

      try {
        await notion.pages.update({
          page_id: task.id,
          properties: {
            '狀態': {
              select: {
                name: '失敗'
              }
            },
            '錯誤訊息': {
              rich_text: [
                {
                  text: {
                    content: '系統已升級：批次總結功能改用直接背景處理，不再使用任務隊列。此任務已過時，已標記為失敗。'
                  }
                }
              ]
            }
          }
        });

        console.log(`  ✅ 已標記為失敗`);
        cleanedCount++;
      } catch (updateError) {
        console.error(`  ❌ 更新失敗:`, updateError.message);
      }
    }

    console.log(`\n✅ 清理完成，成功處理 ${cleanedCount}/${response.results.length} 個任務`);

  } catch (error) {
    console.error('❌ 清理失敗:', error.message);
    if (error.code === 'object_not_found') {
      console.log('\n💡 提示：任務隊列資料庫不存在（這是正常的）');
    }
  }
}

cleanStuckTasks().catch(console.error);
