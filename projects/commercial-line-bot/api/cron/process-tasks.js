/**
 * Vercel Cron Job - 處理任務隊列
 * 每分鐘執行一次，處理待處理的任務
 * 無時間限制，直到任務完成為止
 */

import {
  getPendingTasks,
  markTaskProcessing,
  markTaskCompleted,
  markTaskFailed,
  getProcessingTasks
} from '../../lib/taskQueue.js';
import { pushMessage } from '../../lib/linePush.js';
import { TAG_CATEGORIES } from '../../lib/constants.js';
import {
  getAllContentByTag,
  getTopicSummaryByTag,
  createTopicSummary,
  updateTopicSummary
} from '../../lib/notion.js';
import { generateTopicSummary } from '../../lib/ai.js';

/**
 * 處理批次總結任務
 */
async function processBatchSummaryTask(task) {
  const { categoryName, originalCategoryName, tagsCount } = task.params;
  const userId = task.userId;

  console.log(`📊 開始處理批次總結任務: ${categoryName} (${tagsCount}個標籤)`);

  const tagsInCategory = TAG_CATEGORIES[categoryName];
  if (!tagsInCategory || tagsInCategory.length === 0) {
    throw new Error(`找不到類別「${categoryName}」的標籤`);
  }

  const results = {
    total: tagsInCategory.length,
    success: 0,
    skipped: 0,
    failed: 0,
    details: []
  };

  // 逐個處理每個標籤
  for (let i = 0; i < tagsInCategory.length; i++) {
    const tag = tagsInCategory[i];
    const progress = `[${i + 1}/${tagsInCategory.length}]`;

    console.log(`${progress} 處理標籤: ${tag}`);

    try {
      // 取得該標籤的所有相關內容
      const { fragments, mainQuestions, rounds, totalCount } = await getAllContentByTag(tag);

      if (totalCount === 0) {
        console.log(`${progress} ${tag} - 無內容，跳過`);
        results.skipped++;
        results.details.push({
          tag,
          status: 'skipped',
          reason: '無內容'
        });
        continue;
      }

      // 檢查是否已有主題總結
      const existingSummary = await getTopicSummaryByTag(tag);

      // 使用 AI 生成主題總結
      console.log(`${progress} ${tag} - 生成總結中... (${totalCount}個來源)`);
      const summaryContent = await generateTopicSummary(tag, fragments, mainQuestions, rounds);

      // 儲存或更新到 Notion
      let saveSuccess = false;
      if (existingSummary) {
        // 更新現有總結
        console.log(`${progress} ${tag} - 更新現有總結`);
        saveSuccess = await updateTopicSummary(existingSummary.id, summaryContent, totalCount);
      } else {
        // 創建新總結
        console.log(`${progress} ${tag} - 創建新總結`);
        const fragmentIds = fragments.map(f => f.id);
        const questionIds = mainQuestions.map(q => q.id);
        const result = await createTopicSummary(tag, summaryContent, totalCount, fragmentIds, questionIds);
        saveSuccess = result !== null;
      }

      if (saveSuccess) {
        console.log(`${progress} ${tag} - ✅ 完成`);
        results.success++;
        results.details.push({
          tag,
          status: 'success',
          sourceCount: totalCount,
          action: existingSummary ? '更新' : '新建'
        });
      } else {
        console.log(`${progress} ${tag} - ❌ 儲存失敗`);
        results.failed++;
        results.details.push({
          tag,
          status: 'failed',
          reason: 'Notion儲存失敗'
        });
      }

    } catch (tagError) {
      console.error(`${progress} ${tag} - 處理失敗:`, tagError);
      results.failed++;
      results.details.push({
        tag,
        status: 'failed',
        reason: tagError.message
      });
    }

    // 每處理5個標籤，等待1秒（避免API限流）
    if ((i + 1) % 5 === 0 && i < tagsInCategory.length - 1) {
      console.log(`已處理 ${i + 1}/${tagsInCategory.length} 個標籤，暫停1秒...`);
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }

  // 生成完成通知訊息
  let notificationMessage = `✅ 批次總結完成\n\n`;
  notificationMessage += `📊 類別：${originalCategoryName}\n`;
  notificationMessage += `🏷️  處理結果：\n`;
  notificationMessage += `• 成功：${results.success}/${results.total} 個\n`;
  if (results.skipped > 0) {
    notificationMessage += `• 跳過：${results.skipped} 個（無內容）\n`;
  }
  if (results.failed > 0) {
    notificationMessage += `• 失敗：${results.failed} 個\n`;
  }
  notificationMessage += `\n`;

  // 顯示成功的標籤
  const successTags = results.details.filter(d => d.status === 'success');
  if (successTags.length > 0) {
    notificationMessage += `✨ 已完成標籤：\n`;
    successTags.forEach(d => {
      notificationMessage += `• ${d.tag}（${d.action}，${d.sourceCount}來源）\n`;
    });
    notificationMessage += `\n`;
  }

  // 顯示失敗的標籤
  const failedTags = results.details.filter(d => d.status === 'failed');
  if (failedTags.length > 0) {
    notificationMessage += `❌ 失敗標籤：\n`;
    failedTags.forEach(d => {
      notificationMessage += `• ${d.tag}（${d.reason}）\n`;
    });
    notificationMessage += `\n`;
  }

  notificationMessage += `💡 輸入「總結狀態」查看完整狀態\n`;
  notificationMessage += `💡 輸入「查詢 [標籤]」查看總結內容`;

  // 發送通知
  await pushMessage(userId, notificationMessage);

  return {
    success: true,
    results
  };
}

/**
 * Vercel Cron Job Handler
 */
export default async function handler(req, res) {
  console.log('🔄 Cron job triggered');

  try {
    // 檢查是否有正在處理的任務
    const processingCount = await getProcessingTasks();
    if (processingCount > 0) {
      console.log(`⏸️  已有 ${processingCount} 個任務正在處理中，跳過此次執行`);
      return res.status(200).json({ message: 'Task already in progress', skip: true });
    }

    // 獲取一個待處理的任務
    const tasks = await getPendingTasks(1);
    if (tasks.length === 0) {
      console.log('📭 沒有待處理的任務');
      return res.status(200).json({ message: 'No pending tasks' });
    }

    const task = tasks[0];
    console.log(`📋 獲取任務: ${task.id} (類型: ${task.taskType})`);

    // 標記為處理中
    await markTaskProcessing(task.id);

    // 根據任務類型處理
    let result;
    if (task.taskType === '批次總結') {
      result = await processBatchSummaryTask(task);
    } else {
      throw new Error(`未知的任務類型: ${task.taskType}`);
    }

    // 標記為已完成
    const resultMessage = JSON.stringify(result);
    await markTaskCompleted(task.id, resultMessage);

    console.log(`✅ 任務完成: ${task.id}`);

    return res.status(200).json({
      message: 'Task completed',
      taskId: task.id,
      result
    });

  } catch (error) {
    console.error('❌ Cron job 執行失敗:', error);

    // 如果有任務ID，標記為失敗
    if (error.taskId) {
      await markTaskFailed(error.taskId, error.message);
    }

    return res.status(500).json({
      error: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
}
