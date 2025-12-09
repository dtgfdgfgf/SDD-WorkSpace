import crypto from 'crypto';
import { Client } from '@line/bot-sdk';
import {
  getRandomQuestion,
  createMainQuestion,
  createConversationRound,
  completeMainQuestion,
  updateMainQuestionSummary,
  createKnowledgeFragment,
  markQuestionAsUsed,
  getPageTitle,
  getSelectValue,
  searchKnowledgeByTag,
  searchKnowledgeByMultipleTags,
  searchRoundsByTag,
  searchRoundsByMultipleTags,
  searchMainQuestionsByTag,
  searchMainQuestionsByMultipleTags,
  getAllKnowledgeFragments,
  createTopicSummary,
  updateTopicSummary,
  getTopicSummaryByTag,
  getAllContentByTag
} from '../lib/notion.js';
import { analyzeAnswer, generateSummary, generateKnowledgeFragment, generateTopicSummary } from '../lib/ai.js';
import {
  getSession,
  createSession,
  updateSession,
  clearSession,
  isInConversation
} from '../lib/sessionManager.js';
import { chatWithClaude, clearChatHistory, getChatHistoryLength } from '../lib/directChat.js';
import { generateWeeklyReport, getAllTagsFrequency } from '../lib/analytics.js';
import { TAGS, TAG_CATEGORIES, formatTagsForPrompt } from '../lib/constants.js';
import { pushMessage } from '../lib/linePush.js';


// 清理環境變數，移除可能的換行符和空格
const config = {
  channelAccessToken: (process.env.LINE_CHANNEL_ACCESS_TOKEN || '').trim().replace(/\\n/g, '').replace(/\n/g, ''),
  channelSecret: (process.env.LINE_CHANNEL_SECRET || '').trim().replace(/\\n/g, '').replace(/\n/g, ''),
};

const client = new Client(config);

/**
 * 處理「問」指令 - 開始新問題
 */
async function handleStartQuestion(userId) {
  try {
    // 檢查是否已經在對話中
    if (await isInConversation(userId)) {
      return '你目前還在回答上一個問題中。請先完成當前問題，或輸入「結束」來結束對話。';
    }

    // 從 Notion 題庫隨機取得問題
    const questionPage = await getRandomQuestion();
    if (!questionPage) {
      return '抱歉，目前題庫中沒有問題。請稍後再試。';
    }

    const questionText = getPageTitle(questionPage);
    const questionType = getSelectValue(questionPage, '類型') || '反思';

    // 在 Notion 建立主問題記錄
    const mainQuestion = await createMainQuestion(questionText, questionType, questionPage.id);
    if (!mainQuestion) {
      return '抱歉，建立問題記錄時發生錯誤。請稍後再試。';
    }

    // 標記題庫問題為已使用
    await markQuestionAsUsed(questionPage.id);

    // 建立 session
    createSession(userId, questionPage.id, questionText, questionType, mainQuestion.id);

    return `📝 今天的問題：\n\n${questionText}\n\n請分享你的想法。`;

  } catch (error) {
    console.error('處理開始問題失敗:', error);
    return '抱歉，發生錯誤。請稍後再試。';
  }
}

/**
 * 處理使用者的回答
 */
async function handleAnswer(userId, userAnswer) {
  try {
    const session = await getSession(userId);
    if (!session) {
      return '請先輸入「問」來開始新的問題。';
    }

    // 使用 AI 分析回答
    const analysis = await analyzeAnswer(
      session.questionText,
      userAnswer,
      session.roundNumber,
      session.conversationHistory
    );

    // 儲存到 Notion
    await createConversationRound(
      session.mainQuestionId,
      session.roundNumber,
      userAnswer,
      analysis.feedback,
      analysis.followUp,
      analysis.tags
    );

    // 建立回覆訊息
    let replyText = `💡 AI 回饋：\n\n${analysis.feedback}`;

    if (analysis.followUp && analysis.followUp.trim() !== '') {
      replyText += `\n\n❓ 進一步思考：\n\n${analysis.followUp}`;
    } else {
      // 對話結束，生成總結
      const summary = await generateSummary(session.questionText, session.conversationHistory);

      // 更新 Notion 主問題為已完成
      await completeMainQuestion(
        session.mainQuestionId,
        summary.summary,
        summary.blindSpotTags
      );

      replyText += `\n\n✅ 對話完成！\n\n📊 總結：\n${summary.summary}`;

      if (summary.blindSpotTags.length > 0) {
        replyText += `\n\n🎯 發現的盲點：${summary.blindSpotTags.join('、')}`;
      }

      replyText += `\n\n所有記錄已儲存到 Notion。\n輸入「問」開始下一個問題。`;
    }

    return replyText;

  } catch (error) {
    console.error('處理回答失敗:', error);
    return '抱歉，處理你的回答時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「小結」指令 - 生成階段性總結但不結束對話
 */
async function handleSummary(userId) {
  const session = await getSession(userId);
  if (!session) {
    return '目前沒有進行中的對話。';
  }

  if (session.conversationHistory.length === 0) {
    return '還沒有任何對話記錄。請先回答問題。';
  }

  // 生成總結
  const summary = await generateSummary(session.questionText, session.conversationHistory);

  // 更新主問題的總結和標籤（但不改變狀態，保持「進行中」）
  await updateMainQuestionSummary(
    session.mainQuestionId,
    summary.summary,
    summary.blindSpotTags
  );

  let replyText = '📊 階段性總結：\n\n' + summary.summary;

  if (summary.blindSpotTags.length > 0) {
    replyText += `\n\n🎯 發現的盲點：${summary.blindSpotTags.join('、')}`;
  }

  replyText += `\n\n✅ 總結已儲存到 Notion。\n💬 對話將繼續進行，請繼續回答或輸入「結束」完成對話。`;

  return replyText;
}

/**
 * 處理「儲存」指令 - 儲存當前對話片段為知識片段
 */
async function handleSaveKnowledge(userId) {
  const session = await getSession(userId);
  if (!session) {
    return '目前沒有進行中的對話。';
  }

  // 計算未儲存的回合
  const unsavedRounds = session.conversationHistory.filter(
    r => r.roundNumber > session.lastSavedRound
  );

  if (unsavedRounds.length === 0) {
    return '目前沒有新的對話需要儲存。請繼續回答問題後再儲存。';
  }

  // 生成知識片段
  const fragment = await generateKnowledgeFragment(unsavedRounds);

  // 建立回合範圍文字
  const startRound = unsavedRounds[0].roundNumber;
  const endRound = unsavedRounds[unsavedRounds.length - 1].roundNumber;
  const roundRange = startRound === endRound
    ? `第 ${startRound} 輪`
    : `第 ${startRound}-${endRound} 輪`;

  // 儲存到 Notion
  await createKnowledgeFragment(
    fragment.title,
    fragment.content,
    fragment.tags,
    session.mainQuestionId,
    roundRange
  );

  let replyText = '✅ 已儲存知識片段\n\n';
  replyText += `📝 ${fragment.title}\n\n`;
  replyText += `${fragment.content}\n\n`;

  if (fragment.tags.length > 0) {
    replyText += `🏷️ 標籤：${fragment.tags.join('、')}\n`;
  }

  replyText += `📊 記錄：${roundRange}\n\n`;
  replyText += `💬 對話將繼續，請繼續回答或輸入「結束」完成對話。`;

  return replyText;
}

/**
 * 處理「結束」指令
 */
async function handleEndConversation(userId) {
  const session = await getSession(userId);
  if (!session) {
    return '目前沒有進行中的對話。';
  }

  // 生成總結（即使對話未完成）
  if (session.conversationHistory.length > 0) {
    const summary = await generateSummary(session.questionText, session.conversationHistory);
    await completeMainQuestion(
      session.mainQuestionId,
      `對話提前結束。${summary.summary}`,
      summary.blindSpotTags
    );

    let replyText = '✅ 對話已結束。\n\n📊 總結：\n' + summary.summary;

    if (summary.blindSpotTags.length > 0) {
      replyText += `\n\n🎯 發現的盲點：${summary.blindSpotTags.join('、')}`;
    }

    replyText += '\n\n記錄已儲存到 Notion。\n輸入「問」開始新問題。';
    return replyText;
  } else {
    // 如果沒有任何回合記錄，直接完成
    await completeMainQuestion(
      session.mainQuestionId,
      '對話未進行就結束。',
      []
    );
    return '✅ 對話已結束。記錄已儲存到 Notion。\n輸入「問」開始新問題。';
  }
}

/**
 * 處理「狀態」指令
 */
async function handleStatus(userId) {
  const session = await getSession(userId);
  if (!session) {
    return '目前沒有進行中的對話。輸入「問」開始新問題。';
  }

  // 計算未儲存的回合數
  const unsavedCount = session.conversationHistory.length - session.lastSavedRound;

  let statusText = `📊 當前狀態：\n\n`;
  statusText += `問題：${session.questionText}\n`;
  statusText += `當前回合：第 ${session.roundNumber} 輪\n`;
  statusText += `已回答：${session.conversationHistory.length} 次\n`;

  if (session.lastSavedRound > 0) {
    statusText += `上次儲存：第 ${session.lastSavedRound} 輪\n`;
  }

  if (unsavedCount > 0) {
    statusText += `💾 未儲存：${unsavedCount} 輪\n\n`;
    statusText += `💡 輸入「儲存」保存當前進度\n`;
  } else {
    statusText += `✅ 所有回合已儲存\n\n`;
  }

  statusText += `💡 輸入「小結」查看整體總結`;

  return statusText;
}

/**
 * 處理「查詢」指令 - 三層知識架構（主題總結 > 知識片段 > 對話總結）
 */
async function handleSearchKnowledge(userId, queryText) {
  try {
    // 解析查詢文字，支援 "標籤" 或 "標籤1+標籤2"
    const tags = queryText.split('+').map(t => t.trim()).filter(t => t);

    if (tags.length === 0) {
      return '請提供要查詢的標籤，例如：\n• 查詢 定價策略\n• 查詢 定價策略+假設驗證\n\n💡 輸入「標籤列表」查看所有可用標籤';
    }

    // Layer 0：查詢主題總結（只支援單一標籤）
    let topicSummary = null;
    if (tags.length === 1) {
      topicSummary = await getTopicSummaryByTag(tags[0]);
    }

    // Layer 1：查詢知識片段（精煉洞察）
    const knowledgeFragments = tags.length === 1
      ? await searchKnowledgeByTag(tags[0], 3)
      : await searchKnowledgeByMultipleTags(tags, 3);

    // Layer 2：查詢主問題總結（對話洞察 + 盲點）
    const mainQuestions = tags.length === 1
      ? await searchMainQuestionsByTag(tags[0], 3)
      : await searchMainQuestionsByMultipleTags(tags, 3);

    // 如果三個來源都沒結果
    if (!topicSummary && knowledgeFragments.length === 0 && mainQuestions.length === 0) {
      let emptyMessage = `沒有找到包含「${tags.join(' + ')}」的相關內容。\n\n💡 提示：\n`;
      emptyMessage += `• 輸入「標籤列表」查看所有可用標籤\n`;
      emptyMessage += `• 完成對話後輸入「儲存」可精煉知識片段\n`;
      if (tags.length === 1) {
        emptyMessage += `• 輸入「總結 ${tags[0]}」可生成主題總結`;
      }
      return emptyMessage;
    }

    // 構建回覆文字
    let replyText = '';

    // === Layer 0：主題總結（完整知識地圖）===
    if (topicSummary) {
      replyText += `【主題總結】✨ ${topicSummary.title}\n`;
      replyText += `📊 整合了 ${topicSummary.sourceCount} 個來源 | 📅 ${topicSummary.lastUpdated}\n\n`;

      // 顯示總結內容（前 800 字）
      const summaryPreview = topicSummary.summary.length > 800
        ? topicSummary.summary.substring(0, 800) + '...'
        : topicSummary.summary;
      replyText += summaryPreview + '\n\n';

      if (topicSummary.summary.length > 800) {
        replyText += `📝 完整內容請查看 Notion\n\n`;
      }

      replyText += `─────────────────\n\n`;
    }

    // === Layer 1：精煉洞察（知識片段）===
    if (knowledgeFragments.length > 0) {
      replyText += `【精煉洞察】📚 ${knowledgeFragments.length} 個知識片段\n`;
      if (tags.length > 1) {
        replyText += `（包含：${tags.join(' + ')}）\n`;
      }
      replyText += '\n';

      knowledgeFragments.forEach((item, index) => {
        const createdDate = new Date(item.createdTime).toLocaleDateString('zh-TW');
        replyText += `${index + 1}. ${item.title}\n`;
        replyText += `   📅 ${createdDate}`;
        if (item.roundRange) {
          replyText += ` | ${item.roundRange}`;
        }
        replyText += '\n';
        if (item.tags && item.tags.length > 0) {
          replyText += `   🏷️ ${item.tags.join('、')}\n`;
        }
        // 顯示內容預覽（前 150 字）
        const preview = item.content.length > 150
          ? item.content.substring(0, 150) + '...'
          : item.content;
        replyText += `   ${preview}\n\n`;
      });
    }

    // === 第二部分：對話總結（主問題洞察 + 盲點）===
    if (mainQuestions.length > 0) {
      if (knowledgeFragments.length > 0) {
        replyText += `─────────────────\n\n`;
      }
      replyText += `【對話總結】💡 ${mainQuestions.length} 個歷史洞察\n`;
      if (tags.length > 1) {
        replyText += `（包含：${tags.join(' + ')}）\n`;
      }
      replyText += '\n';

      mainQuestions.forEach((item, index) => {
        const createdDate = new Date(item.createdTime).toLocaleDateString('zh-TW');
        replyText += `${index + 1}. ${item.questionText}\n`;
        replyText += `   📅 ${createdDate}\n`;
        if (item.blindSpotTags && item.blindSpotTags.length > 0) {
          replyText += `   🎯 ${item.blindSpotTags.join('、')}\n`;
        }
        // 顯示總結內容（前 150 字）
        const summaryPreview = item.summary.length > 150
          ? item.summary.substring(0, 150) + '...'
          : item.summary;
        replyText += `   ${summaryPreview}\n\n`;
      });
    }

    // === 底部提示 ===
    replyText += `💡 完整內容請查看 Notion 資料庫`;

    return replyText;
  } catch (error) {
    console.error('處理查詢失敗:', error);
    return '抱歉，查詢時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「週報」指令 - 生成本週思維報告
 */
async function handleWeeklyReport(userId) {
  try {
    const report = await generateWeeklyReport();
    return report;
  } catch (error) {
    console.error('處理週報失敗:', error);
    return '抱歉，生成週報時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「標籤列表」指令 - 顯示所有可用標籤及使用統計
 */
async function handleTagList(userId) {
  try {
    // 取得標籤使用頻率
    const tagFrequency = await getAllTagsFrequency();

    let replyText = '🏷️ 標籤列表（28 個）\n\n';

    // 按類別顯示標籤
    Object.entries(TAG_CATEGORIES).forEach(([category, tags]) => {
      replyText += `【${category}】\n`;
      tags.forEach(tag => {
        const count = tagFrequency[tag] || 0;
        const countDisplay = count > 0 ? ` (${count})` : '';
        replyText += `• ${tag}${countDisplay}\n`;
      });
      replyText += '\n';
    });

    // 顯示使用統計
    const totalFragments = Object.values(tagFrequency).reduce((sum, count) => sum + count, 0);
    const usedTags = Object.keys(tagFrequency).length;

    replyText += `📊 使用統計：\n`;
    replyText += `• 已使用標籤：${usedTags}/28 個\n`;
    replyText += `• 知識片段總數：${totalFragments} 個\n\n`;
    replyText += `💡 使用方式：\n`;
    replyText += `• 查詢 [標籤] - 搜尋單一標籤\n`;
    replyText += `• 查詢 [標籤1]+[標籤2] - 組合查詢`;

    return replyText;
  } catch (error) {
    console.error('處理標籤列表失敗:', error);
    return '抱歉，取得標籤列表時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「總結」指令 - 生成或更新主題總結（使用背景處理）
 */
async function handleGenerateTopicSummary(userId, tag) {
  try {
    // 驗證標籤是否有效
    const allTags = Object.values(TAG_CATEGORIES).flat();
    if (!allTags.includes(tag)) {
      return `❌ 無效的標籤「${tag}」\n\n請輸入「標籤列表」查看所有可用標籤`;
    }

    // 快速檢查是否有內容（不需要取得完整資料）
    const { totalCount } = await getAllContentByTag(tag);

    if (totalCount === 0) {
      return `❌ 找不到任何與「${tag}」相關的內容\n\n請先完成對話或儲存知識片段後再生成總結`;
    }

    // 立即返回進度訊息
    const progressText = `🔄 開始生成「${tag}」知識地圖...\n\n` +
      `📊 發現 ${totalCount} 個相關來源\n` +
      `⏱️  預計需要 20-30 秒\n\n` +
      `🔔 完成後會自動通知您\n` +
      `💡 期間您可以繼續使用其他功能`;

    // 觸發背景處理（非阻塞）
    const backgroundUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}/api/process-single-summary`
      : 'http://localhost:3000/api/process-single-summary';

    console.log(`🚀 觸發背景處理: ${backgroundUrl}`);
    console.log(`   標籤: ${tag}, 使用者: ${userId}`);

    // 非阻塞 fetch - 不等待結果
    // 清理環境變數，移除可能的換行符和空格
    const internalSecret = (process.env.INTERNAL_API_SECRET || 'dev-secret-123').trim().replace(/\\n/g, '').replace(/\n/g, '');
    fetch(backgroundUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-internal-signature': internalSecret
      },
      body: JSON.stringify({ userId, tag })
    }).catch(err => {
      console.error('❌ 背景任務觸發失敗:', err.message);
      // 不中斷主流程，背景任務失敗會在 process-single-summary.js 中通知用戶
    });

    return progressText;

  } catch (error) {
    console.error('生成主題總結失敗:', error);
    return '抱歉，生成主題總結時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「總結 [類別]」指令 - 批次生成某類別所有標籤的主題總結
 * 直接觸發多個背景處理，每個標籤獨立處理並推送通知
 */
async function handleBatchSummaryByCategory(userId, categoryName) {
  try {
    // 檢查環境變數（移除可能的換行符）
    const TOPIC_SUMMARY_DB_ID = process.env.NOTION_TOPIC_SUMMARY_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');

    if (!TOPIC_SUMMARY_DB_ID) {
      return `❌ 主題總結功能尚未設定\n\n` +
        `系統管理員需要：\n` +
        `1. 執行 scripts/init-topic-summary.js 建立資料庫\n` +
        `2. 在 Vercel 設定 NOTION_TOPIC_SUMMARY_DB_ID 環境變數\n` +
        `3. 重新部署應用\n\n` +
        `請聯繫系統管理員完成設定。`;
    }

    // 驗證類別是否有效
    const validCategories = Object.keys(TAG_CATEGORIES);
    const categoryMap = {
      '技術類': '技術',
      '商業類': '商業',
      '個人成長類': '個人成長',
      '團隊協作類': '團隊協作',
      '思維模式類': '思維模式'
    };

    const normalizedCategory = categoryMap[categoryName] || categoryName;

    if (!validCategories.includes(normalizedCategory)) {
      return `❌ 無效的類別「${categoryName}」\n\n` +
        `可用類別：\n` +
        `• 技術類 (5個標籤)\n` +
        `• 商業類 (9個標籤)\n` +
        `• 個人成長類 (7個標籤)\n` +
        `• 團隊協作類 (3個標籤)\n` +
        `• 思維模式類 (4個標籤)\n\n` +
        `例如：總結 商業類`;
    }

    const tagsInCategory = TAG_CATEGORIES[normalizedCategory];

    // 計算預估時間
    const estimatedMinutes = Math.ceil(tagsInCategory.length * 0.5); // 每個標籤約 30 秒

    console.log(`🔄 開始批次處理類別「${categoryName}」的 ${tagsInCategory.length} 個標籤`);

    // 觸發所有標籤的背景處理（並行）
    const backgroundUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}/api/process-single-summary`
      : 'http://localhost:3000/api/process-single-summary';

    const internalSecret = (process.env.INTERNAL_API_SECRET || 'dev-secret-123').trim().replace(/\\n/g, '').replace(/\n/g, '');

    // 為每個標籤觸發背景處理
    let triggeredCount = 0;
    for (const tag of tagsInCategory) {
      // 非阻塞 fetch - 不等待結果
      fetch(backgroundUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-internal-signature': internalSecret
        },
        body: JSON.stringify({ userId, tag })
      }).catch(err => {
        console.error(`❌ 觸發標籤「${tag}」失敗:`, err.message);
      });
      triggeredCount++;
    }

    console.log(`✅ 已觸發 ${triggeredCount} 個背景處理任務`);

    // 立即回覆用戶
    return `✅ 批次總結已開始處理\n\n` +
      `📊 類別：${categoryName}\n` +
      `🏷️  標籤數量：${tagsInCategory.length} 個\n` +
      `⏱️ 預計時間：${estimatedMinutes} 分鐘\n\n` +
      `🔔 每個標籤完成後會立即通知您\n` +
      `💡 期間您可以繼續使用其他功能\n\n` +
      `💡 標籤列表：\n${tagsInCategory.map(t => `  • ${t}`).join('\n')}`;

  } catch (error) {
    console.error('批次總結處理失敗:', error);
    return '抱歉，批次總結處理時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「總結狀態」指令 - 查看所有標籤的總結狀態
 */
async function handleSummaryStatus(userId) {
  try {
    // 檢查環境變數（移除可能的換行符）
    const TOPIC_SUMMARY_DB_ID = process.env.NOTION_TOPIC_SUMMARY_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');
    if (!TOPIC_SUMMARY_DB_ID) {
      return `❌ 主題總結功能尚未設定\n\n` +
        `系統管理員需要：\n` +
        `1. 執行 scripts/init-topic-summary.js 建立資料庫\n` +
        `2. 在 Vercel 設定 NOTION_TOPIC_SUMMARY_DB_ID 環境變數\n` +
        `3. 重新部署應用\n\n` +
        `請聯繫系統管理員完成設定。`;
    }

    // 匯入必要的函數
    const { Client: NotionClient } = await import('@notionhq/client');
    const notion = new NotionClient({ auth: process.env.NOTION_TOKEN });

    // 取得所有主題總結
    const response = await notion.databases.query({
      database_id: TOPIC_SUMMARY_DB_ID,
      sorts: [
        {
          property: '最後更新日期',
          direction: 'descending'
        }
      ],
      page_size: 100
    });

    // 建立標籤到總結的對應表
    const summaryMap = {};
    response.results.forEach(page => {
      const tag = page.properties['主題標籤']?.select?.name || '';
      const lastUpdated = page.properties['最後更新日期']?.date?.start || '';
      const sourceCount = page.properties['來源統計']?.number || 0;

      if (tag) {
        summaryMap[tag] = {
          lastUpdated,
          sourceCount,
          id: page.id
        };
      }
    });

    // 取得標籤使用頻率（知識片段數量）
    const tagFrequency = await getAllTagsFrequency();

    let replyText = `📊 主題總結狀態\n\n`;

    // 按類別顯示
    Object.entries(TAG_CATEGORIES).forEach(([category, tags]) => {
      replyText += `【${category}】\n`;

      tags.forEach(tag => {
        const summary = summaryMap[tag];
        const fragmentCount = tagFrequency[tag] || 0;

        if (summary) {
          // 已有總結
          const date = new Date(summary.lastUpdated);
          const formattedDate = date.toLocaleDateString('zh-TW', { month: 'numeric', day: 'numeric' });
          const daysAgo = Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));

          let statusIcon = '✅';
          let ageNote = '';

          // 檢查是否需要更新（有新內容 + 7天以上）
          if (fragmentCount > summary.sourceCount && daysAgo > 7) {
            statusIcon = '🔄';
            ageNote = ` - 建議更新`;
          } else if (daysAgo > 30) {
            statusIcon = '⚠️';
            ageNote = ` - ${daysAgo}天前`;
          } else if (daysAgo > 7) {
            ageNote = ` - ${daysAgo}天前`;
          }

          replyText += `${statusIcon} ${tag}（${formattedDate}，${summary.sourceCount}來源${ageNote}）\n`;
        } else if (fragmentCount > 0) {
          // 有內容但未總結
          replyText += `🆕 ${tag}（未總結，${fragmentCount}片段）\n`;
        } else {
          // 無內容
          replyText += `⚪ ${tag}（無內容）\n`;
        }
      });

      replyText += `\n`;
    });

    // 統計
    const totalTags = Object.values(TAG_CATEGORIES).flat().length;
    const summarizedTags = Object.keys(summaryMap).length;
    const tagsWithContent = Object.keys(tagFrequency).length;
    const needSummary = tagsWithContent - summarizedTags;

    // 檢查需要更新的標籤
    const needUpdate = Object.values(TAG_CATEGORIES).flat().filter(tag => {
      const summary = summaryMap[tag];
      const fragmentCount = tagFrequency[tag] || 0;
      if (!summary) return false;
      const daysAgo = Math.floor((Date.now() - new Date(summary.lastUpdated).getTime()) / (1000 * 60 * 60 * 24));
      return fragmentCount > summary.sourceCount && daysAgo > 7;
    });

    replyText += `📈 統計資訊：\n`;
    replyText += `• 已總結：${summarizedTags}/${totalTags} 個標籤\n`;
    replyText += `• 有內容：${tagsWithContent} 個標籤\n`;
    replyText += `• 待總結：${needSummary} 個標籤\n`;
    if (needUpdate.length > 0) {
      replyText += `• 建議更新：${needUpdate.length} 個標籤\n`;
    }
    replyText += `\n`;

    replyText += `💡 圖例說明：\n`;
    replyText += `✅ 已總結（最新）\n`;
    replyText += `🔄 建議更新（有新內容 + 7天以上）\n`;
    replyText += `⚠️  需要更新（30天以上）\n`;
    replyText += `🆕 待總結（有內容但未總結）\n`;
    replyText += `⚪ 無內容\n\n`;

    replyText += `🛠️  快速操作：\n`;
    replyText += `• 總結 [標籤] - 總結單一標籤\n`;
    replyText += `• 總結 [類別] - 批次總結整個類別\n`;
    replyText += `  例如：總結 商業類`;

    return replyText;

  } catch (error) {
    console.error('取得總結狀態失敗:', error);
    return '抱歉，取得總結狀態時發生錯誤。請稍後再試。';
  }
}


/**
 * 處理「幫助」指令
 */
function handleHelp() {
  return `🤖 Business Thinking Coach\n\n` +
    `【結構化訓練】\n` +
    `• 問 - 開始新問題\n` +
    `• 儲存 - 儲存當前對話為知識片段\n` +
    `• 小結 - 查看階段性總結\n` +
    `• 結束 - 結束對話並儲存\n` +
    `• 狀態 - 查看當前狀態\n\n` +
    `【知識檢索】新功能\n` +
    `• 查詢 [標籤] - 搜尋知識片段\n` +
    `  例如：查詢 定價策略\n` +
    `• 查詢 [標籤1]+[標籤2] - 組合查詢\n` +
    `  例如：查詢 定價策略+假設驗證\n` +
    `• 總結 [標籤] - 生成單一標籤總結\n` +
    `  例如：總結 客戶開發\n` +
    `• 總結 [類別] - 批次總結整個類別\n` +
    `  例如：總結 商業類\n` +
    `• 總結狀態 - 查看所有標籤總結狀態\n` +
    `• 週報 - 查看本週思維報告\n` +
    `• 標籤列表 - 查看所有可用標籤\n\n` +
    `【系統】\n` +
    `• 清除 - 清除對話記憶\n` +
    `• 系統 - 查看系統資訊\n` +
    `• 幫助 - 顯示此說明\n\n` +
    `【使用模式】\n` +
    `1. 結構化訓練：輸入「問」開始\n` +
    `2. 自由對話：直接輸入問題\n\n` +
    `所有結構化訓練會記錄到 Notion\n` +
    `知識片段可隨時查詢重用`;
}

/**
 * 處理「清除」指令 - 清除對話記憶
 */
function handleClearChat(userId) {
  clearChatHistory(userId);
  return '✅ 對話記憶已清除。';
}

/**
 * 處理「系統」指令 - 顯示系統資訊
 */
function handleSystemInfo() {
  const deployTime = process.env.VERCEL_GIT_COMMIT_SHA
    ? new Date(parseInt(process.env.VERCEL_GIT_COMMIT_REF) * 1000 || Date.now()).toLocaleString('zh-TW')
    : '本地開發環境';

  const projectUrl = process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : 'https://commercial-line-bot.vercel.app';

  let infoText = `🤖 系統資訊\n\n`;
  infoText += `📦 專案：commercial-line-bot\n`;
  infoText += `📌 版本：v1.0.0\n`;
  infoText += `🌐 環境：${process.env.VERCEL_ENV || 'development'}\n`;
  infoText += `🔗 URL：${projectUrl}\n`;
  infoText += `⏰ 部署：${deployTime}\n\n`;
  infoText += `✨ LINE Bot x Notion x Claude AI - Business Thinking Coach\n\n`;
  infoText += `💡 輸入「幫助」查看所有指令`;

  return infoText;
}

/**
 * 主要的訊息處理邏輯
 */
async function handleMessage(userId, messageText) {
  const text = messageText.trim();

  // 指令處理
  if (text === '問') {
    return await handleStartQuestion(userId);
  } else if (text === '儲存' || text === '储存' || text === '保存') {
    return await handleSaveKnowledge(userId);
  } else if (text === '小結' || text === '小结' || text === '總結' || text === '总结') {
    return await handleSummary(userId);
  } else if (text === '結束' || text === '结束') {
    return await handleEndConversation(userId);
  } else if (text === '狀態' || text === '状态') {
    return await handleStatus(userId);
  } else if (text.startsWith('查詢 ') || text.startsWith('查询 ') || text.startsWith('搜尋 ') || text.startsWith('搜索 ')) {
    const queryText = text.replace(/^(查詢|查询|搜尋|搜索)\s+/, '').trim();
    return await handleSearchKnowledge(userId, queryText);
  } else if (text === '週報' || text === '周报' || text === '週報告' || text === '周报告') {
    return await handleWeeklyReport(userId);
  } else if (text === '標籤列表' || text === '标签列表' || text === '標籤' || text === '标签' || text === 'tags') {
    return await handleTagList(userId);
  } else if (text === '總結狀態' || text === '总结状态' || text === '總結状态' || text === '总结狀態') {
    return await handleSummaryStatus(userId);
  } else if (text.startsWith('總結 ') || text.startsWith('总结 ')) {
    const param = text.replace(/^(總結|总结)\s+/, '').trim();

    // 判斷是類別還是標籤
    const categoryNames = ['技術類', '商業類', '個人成長類', '團隊協作類', '思維模式類',
                          '技术类', '商业类', '个人成长类', '团队协作类', '思维模式类'];

    if (categoryNames.includes(param)) {
      return await handleBatchSummaryByCategory(userId, param);
    } else {
      return await handleGenerateTopicSummary(userId, param);
    }
  } else if (text === '清除') {
    return handleClearChat(userId);
  } else if (text === '系統' || text === '系统' || text === '版本' || text === 'version' || text === 'info') {
    return handleSystemInfo();
  } else if (text === '幫助' || text === '帮助') {
    return handleHelp();
  }

  // 如果在結構化訓練對話中，視為回答
  if (await isInConversation(userId)) {
    return await handleAnswer(userId, text);
  }

  // 否則直接與 Claude 對話（自由模式）
  return await chatWithClaude(userId, text);
}

/**
 * Vercel Serverless Function Handler
 */
export default async function handler(req, res) {
  // 只接受 POST 請求
  if (req.method !== 'POST') {
    console.log('❌ 拒絕非 POST 請求:', req.method);
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  console.log('📥 收到 webhook 請求');

  // ===== LINE Webhook 簽名驗證 =====
  // 驗證請求確實來自 LINE 平台，防止偽造請求
  // 參考: https://developers.line.biz/en/docs/messaging-api/receiving-messages/#verifying-signatures

  const signature = req.headers['x-line-signature'];

  // 檢查簽名是否存在
  if (!signature) {
    console.error('🚨 安全警告: 缺少 x-line-signature header');
    console.error('   來源 IP:', req.headers['x-forwarded-for'] || req.connection?.remoteAddress);
    console.error('   User-Agent:', req.headers['user-agent']);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Missing signature'
    });
  }

  // 計算請求體的 HMAC-SHA256 簽名
  const body = JSON.stringify(req.body);
  // 清理環境變數，移除可能的換行符和空格
  const channelSecret = (process.env.LINE_CHANNEL_SECRET || '').trim().replace(/\\n/g, '').replace(/\n/g, '');
  const expectedSignature = crypto
    .createHmac('SHA256', channelSecret)
    .update(body)
    .digest('base64');

  // 比對簽名
  if (signature !== expectedSignature) {
    console.error('🚨 安全警告: 簽名驗證失敗');
    console.error('   收到的簽名:', signature);
    console.error('   預期的簽名:', expectedSignature);
    console.error('   來源 IP:', req.headers['x-forwarded-for'] || req.connection?.remoteAddress);
    console.error('   請求體長度:', body.length);
    return res.status(401).json({
      error: 'Unauthorized',
      message: 'Invalid signature'
    });
  }

  // ✅ 簽名驗證通過
  console.log('✅ LINE 簽名驗證通過');

  // 處理 webhook 事件
  const events = req.body.events;
  console.log('📊 事件數量:', events?.length || 0);

  // 處理每個事件（獨立 try-catch，避免單一錯誤影響其他事件）
  for (let event of events) {
    try {
      console.log('📝 事件類型:', event.type);
      if (event.type === 'message' && event.message.type === 'text') {
        const userId = event.source.userId;
        const messageText = event.message.text;
        console.log('👤 使用者ID:', userId);
        console.log('💬 訊息內容:', messageText);

        // 處理訊息
        console.log('=== 開始處理訊息 ===');
        const replyText = await handleMessage(userId, messageText);
        console.log('✅ 處理完成，回覆內容長度:', replyText?.length || 0);

        // 回覆使用者
        console.log('📤 準備回覆 LINE...');
        try {
          await client.replyMessage(event.replyToken, {
            type: 'text',
            text: replyText,
          });
          console.log('✅ 回覆 LINE 成功');
        } catch (replyError) {
          console.error('❌ LINE API 回覆失敗:', replyError);
          console.error('   錯誤詳情:', replyError.message);
          console.error('   錯誤回應:', JSON.stringify(replyError.response?.data || replyError.originalError || {}));
        }
      }
    } catch (eventError) {
      console.error('❌ 處理事件失敗:', eventError);
      console.error('   事件內容:', JSON.stringify(event));
      console.error('   錯誤堆疊:', eventError.stack);
    }
  }

  // 無論處理成功與否，都返回 200（表示已接收 webhook）
  console.log('✅ Webhook 處理完成，返回 200 OK');
  res.status(200).send('OK');
}
