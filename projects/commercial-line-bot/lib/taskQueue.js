import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const TASK_QUEUE_DB_ID = process.env.NOTION_TASK_QUEUE_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');

/**
 * 創建新任務
 */
export async function createTask(taskType, userId, params, priority = '中') {
  try {
    const response = await notion.pages.create({
      parent: { database_id: TASK_QUEUE_DB_ID },
      properties: {
        '標題': {
          title: [{ text: { content: `${taskType} - ${params.categoryName || params.tag || 'Unknown'}` } }]
        },
        '任務類型': {
          select: { name: taskType === 'batch_summary' ? '批次總結' : '單一總結' }
        },
        '狀態': {
          select: { name: '待處理' }
        },
        '用戶ID': {
          rich_text: [{ text: { content: userId } }]
        },
        '任務參數': {
          rich_text: [{ text: { content: JSON.stringify(params) } }]
        },
        '優先級': {
          select: { name: priority }
        },
        '重試次數': {
          number: 0
        }
      }
    });

    console.log(`✅ 任務已創建: ${response.id}`);
    return response.id;
  } catch (error) {
    console.error('❌ 創建任務失敗:', error);
    throw error;
  }
}

/**
 * 獲取待處理任務
 */
export async function getPendingTasks(limit = 1) {
  try {
    const response = await notion.databases.query({
      database_id: TASK_QUEUE_DB_ID,
      filter: {
        property: '狀態',
        select: {
          equals: '待處理'
        }
      },
      sorts: [
        {
          property: '優先級',
          direction: 'ascending'
        },
        {
          timestamp: 'created_time',
          direction: 'ascending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      taskType: page.properties['任務類型']?.select?.name || '',
      userId: page.properties['用戶ID']?.rich_text?.[0]?.text?.content || '',
      params: JSON.parse(page.properties['任務參數']?.rich_text?.[0]?.text?.content || '{}'),
      retryCount: page.properties['重試次數']?.number || 0,
      createdTime: page.created_time
    }));
  } catch (error) {
    console.error('❌ 獲取待處理任務失敗:', error);
    return [];
  }
}

/**
 * 標記任務為處理中
 */
export async function markTaskProcessing(taskId) {
  try {
    await notion.pages.update({
      page_id: taskId,
      properties: {
        '狀態': {
          select: { name: '處理中' }
        },
        '開始時間': {
          date: { start: new Date().toISOString() }
        }
      }
    });
    console.log(`🔄 任務標記為處理中: ${taskId}`);
  } catch (error) {
    console.error('❌ 更新任務狀態失敗:', error);
  }
}

/**
 * 標記任務為已完成
 */
export async function markTaskCompleted(taskId, resultMessage) {
  try {
    await notion.pages.update({
      page_id: taskId,
      properties: {
        '狀態': {
          select: { name: '已完成' }
        },
        '完成時間': {
          date: { start: new Date().toISOString() }
        },
        '結果訊息': {
          rich_text: [{ text: { content: resultMessage.substring(0, 2000) } }]
        }
      }
    });
    console.log(`✅ 任務標記為已完成: ${taskId}`);
  } catch (error) {
    console.error('❌ 更新任務狀態失敗:', error);
  }
}

/**
 * 標記任務為失敗
 */
export async function markTaskFailed(taskId, errorMessage) {
  try {
    const page = await notion.pages.retrieve({ page_id: taskId });
    const currentRetryCount = page.properties['重試次數']?.number || 0;

    await notion.pages.update({
      page_id: taskId,
      properties: {
        '狀態': {
          select: { name: '失敗' }
        },
        '完成時間': {
          date: { start: new Date().toISOString() }
        },
        '錯誤訊息': {
          rich_text: [{ text: { content: errorMessage.substring(0, 2000) } }]
        },
        '重試次數': {
          number: currentRetryCount + 1
        }
      }
    });
    console.log(`❌ 任務標記為失敗: ${taskId}`);
  } catch (error) {
    console.error('❌ 更新任務狀態失敗:', error);
  }
}

/**
 * 獲取處理中的任務（避免重複處理）
 */
export async function getProcessingTasks() {
  try {
    const response = await notion.databases.query({
      database_id: TASK_QUEUE_DB_ID,
      filter: {
        property: '狀態',
        select: {
          equals: '處理中'
        }
      }
    });

    return response.results.length;
  } catch (error) {
    console.error('❌ 獲取處理中任務失敗:', error);
    return 0;
  }
}
