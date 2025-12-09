// lib/sessionManager.js - 對話狀態管理（使用 Notion 作為持久化存儲）
// 適合 Vercel 無伺服器環境，解決實例重啟導致記憶體清空的問題

import {
  getActiveMainQuestion,
  getRoundsForQuestion,
  getKnowledgeFragments,
  getPageTitle,
  getSelectValue,
  getRelationId
} from './notion.js';

// Session 結構：
// {
//   userId: string,              // LINE 使用者 ID（未使用，因為目前用日期判斷）
//   questionId: string,          // Notion 題庫中的問題 ID
//   mainQuestionId: string,      // Notion 主問題 ID
//   questionText: string,
//   questionType: string,
//   roundNumber: number,
//   lastSavedRound: number,      // 上次儲存知識片段時的回合數
//   conversationHistory: [{
//     round: number,
//     userAnswer: string,
//     feedback: string,
//     followUp: string
//   }]
// }

/**
 * 從 Notion 取得使用者的 session（查詢進行中的問題）
 */
export async function getSession(userId) {
  try {
    // 從 Notion 查詢今天「進行中」的主問題
    const mainQuestion = await getActiveMainQuestion(userId);
    if (!mainQuestion) {
      return null;
    }

    // 取得問題資訊
    const questionText = getPageTitle(mainQuestion);
    const questionType = getSelectValue(mainQuestion, '問題類型') || '反思';
    const questionId = getRelationId(mainQuestion, '來源題目');

    // 取得所有回合記錄
    const rounds = await getRoundsForQuestion(mainQuestion.id);

    // 計算當前回合數（下一輪）
    const roundNumber = rounds.length + 1;

    // 取得該問題的所有知識片段，計算上次儲存的回合數
    const knowledgeFragments = await getKnowledgeFragments(mainQuestion.id);
    let lastSavedRound = 0;

    if (knowledgeFragments.length > 0) {
      // 從最新的知識片段解析回合範圍（例如：「第 1-3 輪」）
      const latestFragment = knowledgeFragments[0];
      const roundRange = latestFragment.roundRange;

      // 解析回合範圍，提取最大回合數
      const match = roundRange.match(/第\s*(\d+)(?:-(\d+))?\s*輪/);
      if (match) {
        lastSavedRound = parseInt(match[2] || match[1], 10);
      }
    }

    return {
      userId,
      questionId,
      mainQuestionId: mainQuestion.id,
      questionText,
      questionType,
      roundNumber,
      lastSavedRound,
      conversationHistory: rounds
    };
  } catch (error) {
    console.error('取得 session 失敗:', error);
    return null;
  }
}

/**
 * 建立新的 session（在 Notion 創建主問題記錄）
 * 注意：實際的 session 創建在 webhook.js 的 handleStartQuestion 中完成
 * 這個函數保留是為了介面一致性
 */
export function createSession(userId, questionId, questionText, questionType, mainQuestionId) {
  // 在新架構中，session 是通過 Notion 的主問題記錄來追蹤的
  // 這個函數不需要做任何事情，因為記錄已經在 Notion 中創建
  return {
    userId,
    questionId,
    mainQuestionId,
    questionText,
    questionType,
    roundNumber: 1,
    conversationHistory: []
  };
}

/**
 * 更新 session（在 Notion 創建新回合記錄）
 * 注意：實際的更新在 webhook.js 中通過 createConversationRound 完成
 * 這個函數保留是為了介面一致性
 */
export function updateSession(userId, userAnswer, feedback, followUp) {
  // 在新架構中，session 更新是通過 Notion 的回合記錄來追蹤的
  // 這個函數不需要做任何事情，因為記錄已經在 Notion 中創建
  return null;
}

/**
 * 清除使用者的 session（在 Notion 更新主問題狀態為「已完成」）
 * 注意：實際的清除在 webhook.js 中通過 completeMainQuestion 完成
 * 這個函數保留是為了介面一致性
 */
export function clearSession(userId) {
  // 在新架構中，session 清除是通過將 Notion 主問題狀態改為「已完成」來實現的
  // 這個函數不需要做任何事情
}

/**
 * 檢查使用者是否在對話中（查詢 Notion 是否有進行中的問題）
 */
export async function isInConversation(userId) {
  try {
    const mainQuestion = await getActiveMainQuestion(userId);
    return mainQuestion !== null;
  } catch (error) {
    console.error('檢查對話狀態失敗:', error);
    return false;
  }
}

