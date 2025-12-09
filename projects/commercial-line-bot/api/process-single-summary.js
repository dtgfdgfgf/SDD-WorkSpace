/**
 * 背景處理 Function - 單一標籤總結
 *
 * 用途：處理單一標籤的主題總結生成，避免阻塞 webhook
 * 流程：
 *   1. 驗證請求來源（內部 API 簽名）
 *   2. 取得標籤相關內容
 *   3. 生成 AI 總結
 *   4. 儲存到 Notion
 *   5. Push Message 通知用戶完成
 *
 * 這是一個獨立的 Vercel Serverless Function，有自己的 300 秒 timeout
 */

import { generateTopicSummary } from '../lib/ai.js';
import {
  getAllContentByTag,
  getTopicSummaryByTag,
  updateTopicSummary,
  createTopicSummary
} from '../lib/notion.js';
import { pushMessage } from '../lib/linePush.js';

/**
 * Vercel Serverless Function Handler
 */
export default async function handler(req, res) {
  // 只接受 POST 請求
  if (req.method !== 'POST') {
    console.log('❌ 拒絕非 POST 請求:', req.method);
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  console.log('📥 收到背景處理請求');

  // ===== 驗證內部 API 簽名 =====
  // 防止外部濫用這個 API endpoint
  const signature = req.headers['x-internal-signature'];
  // 清理環境變數，移除可能的換行符和空格
  const expectedSignature = (process.env.INTERNAL_API_SECRET || 'dev-secret-123').trim().replace(/\\n/g, '').replace(/\n/g, '');

  if (signature !== expectedSignature) {
    console.error('🚨 安全警告: 內部 API 簽名驗證失敗');
    console.error('   收到的簽名:', signature);
    console.error('   來源 IP:', req.headers['x-forwarded-for'] || req.connection?.remoteAddress);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid internal API signature'
    });
  }

  console.log('✅ 內部 API 簽名驗證通過');

  // ===== 解析請求參數 =====
  const { userId, tag } = req.body;

  if (!userId || !tag) {
    console.error('❌ 缺少必要參數:', { userId, tag });
    return res.status(400).json({
      error: 'Bad Request',
      message: 'Missing userId or tag'
    });
  }

  console.log(`🔄 開始處理單一標籤總結: "${tag}" for user ${userId}`);

  try {
    // ===== Step 1: 取得所有相關內容 =====
    console.log(`📊 Step 1: 取得標籤「${tag}」的相關內容`);

    const { fragments, mainQuestions, rounds, sourceTypes, totalCount } =
      await getAllContentByTag(tag);

    if (totalCount === 0) {
      console.log(`⚠️  標籤「${tag}」沒有相關內容`);
      await pushMessage(userId,
        `❌ 找不到任何與「${tag}」相關的內容\n\n` +
        `請先完成對話或儲存知識片段後再生成總結`
      );
      return res.status(200).json({
        success: false,
        reason: 'no_content',
        tag
      });
    }

    console.log(`✅ 找到 ${totalCount} 個來源：`);
    console.log(`   - 知識片段：${fragments.length} 個`);
    console.log(`   - 對話總結：${mainQuestions.length} 個`);
    console.log(`   - 對話回合：${rounds.length} 個`);

    // ===== Step 2: 生成 AI 總結 =====
    console.log(`🤖 Step 2: 使用 Claude 生成主題總結`);
    const startTime = Date.now();

    const summaryContent = await generateTopicSummary(
      tag,
      fragments,
      mainQuestions,
      rounds
    );

    const generationTime = Math.round((Date.now() - startTime) / 1000);
    console.log(`✅ 總結生成完成，耗時 ${generationTime} 秒`);
    console.log(`   總結長度：${summaryContent.length} 字符`);

    // ===== Step 3: 儲存到 Notion =====
    console.log(`💾 Step 3: 儲存總結到 Notion`);

    const existingSummary = await getTopicSummaryByTag(tag);
    let saveSuccess = false;
    let action = 'created';

    if (existingSummary) {
      console.log(`🔄 更新現有總結: ${existingSummary.id}`);
      action = 'updated';
      saveSuccess = await updateTopicSummary(
        existingSummary.id,
        summaryContent,
        totalCount
      );
    } else {
      console.log(`✨ 創建新總結`);
      action = 'created';
      const fragmentIds = fragments.map(f => f.id);
      const questionIds = mainQuestions.map(q => q.id);
      const result = await createTopicSummary(
        tag,
        summaryContent,
        totalCount,
        fragmentIds,
        questionIds
      );
      saveSuccess = result !== null;
    }

    if (!saveSuccess) {
      console.error(`❌ 儲存到 Notion 失敗`);
      await pushMessage(userId,
        `❌ 生成「${tag}」總結成功，但儲存到 Notion 失敗\n\n` +
        `📋 可能原因：\n` +
        `• Notion Integration 未授權資料庫\n` +
        `• 資料庫欄位名稱不匹配\n` +
        `• 網路連接問題\n\n` +
        `請檢查設定後重試`
      );
      return res.status(200).json({
        success: false,
        reason: 'save_failed',
        tag
      });
    }

    console.log(`✅ 儲存成功 (${action})`);

    // ===== Step 4: 發送完成通知 =====
    console.log(`📤 Step 4: 發送完成通知給用戶`);

    let resultMessage = `✅ 已${action === 'updated' ? '更新' : '生成'}「${tag}」知識地圖\n\n`;

    // 顯示來源統計
    resultMessage += `📊 內容來源：\n`;
    resultMessage += `• ✨ 知識片段：${fragments.length} 個\n`;
    resultMessage += `• 💡 對話總結：${mainQuestions.length} 個\n`;
    if (rounds.length > 0) {
      resultMessage += `• 📝 對話回合：${rounds.length} 個\n`;
    }
    resultMessage += `📅 ${new Date().toLocaleDateString('zh-TW')}\n`;
    resultMessage += `⏱️ 處理時間：${generationTime} 秒\n\n`;

    // 質量提示
    if (rounds.length > 0 && sourceTypes.refinedCount < 5) {
      resultMessage += `💡 提示：當前主要來自原始對話\n`;
      resultMessage += `建議使用「儲存」指令精煉關鍵知識\n\n`;
    }

    resultMessage += `─────────────────\n\n`;

    // 顯示總結內容（如果太長則截斷）
    const maxLength = 1500; // LINE 訊息建議長度
    if (summaryContent.length <= maxLength) {
      resultMessage += summaryContent;
    } else {
      resultMessage += summaryContent.substring(0, maxLength) + '...\n\n';
      resultMessage += `📝 完整內容已儲存到 Notion`;
    }

    resultMessage += `\n\n💡 輸入「查詢 ${tag}」可隨時查看此總結`;

    const pushSuccess = await pushMessage(userId, resultMessage);

    if (!pushSuccess) {
      console.error(`❌ Push Message 發送失敗`);
      // 即使 push 失敗，任務本身是成功的
    } else {
      console.log(`✅ Push Message 發送成功`);
    }

    // ===== 返回成功結果 =====
    const totalTime = Math.round((Date.now() - startTime) / 1000);
    console.log(`🎉 單一標籤總結完成: ${tag}，總耗時 ${totalTime} 秒`);

    return res.status(200).json({
      success: true,
      tag,
      action,
      totalCount,
      sources: {
        fragments: fragments.length,
        mainQuestions: mainQuestions.length,
        rounds: rounds.length
      },
      processingTime: totalTime,
      summaryLength: summaryContent.length
    });

  } catch (error) {
    // ===== 錯誤處理 =====
    console.error(`❌ 處理單一標籤總結失敗: ${tag}`);
    console.error('   錯誤類型:', error.name);
    console.error('   錯誤訊息:', error.message);
    console.error('   錯誤堆疊:', error.stack);

    // 通知用戶失敗
    try {
      await pushMessage(userId,
        `❌ 生成「${tag}」總結時發生錯誤\n\n` +
        `錯誤訊息：${error.message}\n\n` +
        `請稍後再試，或聯繫系統管理員`
      );
    } catch (pushError) {
      console.error('❌ 發送錯誤通知失敗:', pushError);
    }

    return res.status(500).json({
      success: false,
      reason: 'processing_error',
      tag,
      error: error.message,
      // 在 development 環境提供堆疊追蹤
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
}
