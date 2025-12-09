// lib/directChat.js - 直接與 Claude Sonnet 4.5 對話
// 集成 RAG (Retrieval Augmented Generation) 知识检索
import Anthropic from '@anthropic-ai/sdk';
import { performRAG } from './rag.js';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

// 儲存對話歷史（記憶體，會在重啟時清空）
const conversationHistories = new Map();

/**
 * 取得使用者的對話歷史
 */
function getConversationHistory(userId) {
  if (!conversationHistories.has(userId)) {
    conversationHistories.set(userId, []);
  }
  return conversationHistories.get(userId);
}

/**
 * 新增訊息到對話歷史
 */
function addToHistory(userId, role, content) {
  const history = getConversationHistory(userId);
  history.push({ role, content });

  // 保留最近 10 輪對話（20 條訊息）
  if (history.length > 20) {
    history.splice(0, history.length - 20);
  }

  conversationHistories.set(userId, history);
}

/**
 * 清除對話歷史
 */
export function clearChatHistory(userId) {
  conversationHistories.delete(userId);
}

/**
 * 直接與 Claude 對話（集成 RAG 知识检索）
 */
export async function chatWithClaude(userId, userMessage) {
  try {
    // 取得對話歷史
    const history = getConversationHistory(userId);

    // 新增使用者訊息到歷史
    addToHistory(userId, 'user', userMessage);

    // === RAG 知识检索 ===
    console.log('🔍 启动 RAG 知识检索...');
    const ragResult = await performRAG(userMessage);

    // 基础系統提示詞
    const baseSystemPrompt = `你是一位專業的「商業思維教練 + 創業顧問」。

你的角色：
- 幫助 26 歲的工程師培養商業思維
- 專注於 SaaS、小型商家服務、AI 應用的商業面向
- 協助發現商業新手的盲點與未知未知

你的風格：
- 簡潔直接，避免過度專業術語
- 用具體例子說明抽象概念
- 主動指出對方可能忽略的商業風險
- 提出引導性問題，而非直接給答案
- 保持友善但不過度客套

你的專長領域：
- 商業模式設計
- 定價策略與收費談判
- 客戶對話與需求管理
- 合作流程與風險控制
- 市場定位與競爭分析
- 服務交付與品質管理

重要：
- 當使用者問技術問題時，引導回商業思維面向
- 避免給予過於理想化的建議，要考慮實務限制
- 主動提醒常見的商業新手陷阱`;

    // 根据 RAG 结果增强 system prompt
    let enhancedSystemPrompt = baseSystemPrompt;

    if (ragResult.metadata.totalResults > 0) {
      console.log(`📚 找到 ${ragResult.metadata.totalResults} 条相关知识（标签：${ragResult.metadata.tags.join('、')}）`);
      enhancedSystemPrompt += ragResult.enhancedPrompt;

      // 如果找到知识，在回复开头添加提示（可选）
      enhancedSystemPrompt += `\n\n**回答策略**：\n`;
      enhancedSystemPrompt += `- 这是一次「情境化对话」，用户在询问与其历史知识相关的话题\n`;
      enhancedSystemPrompt += `- 请自然地将知识库内容融入回答，不要生硬罗列\n`;
      enhancedSystemPrompt += `- 例如："根据你之前的洞察《XXX》..." 或 "记得你在XX时的反思吗..."\n`;
      enhancedSystemPrompt += `- 如果发现盲点，温和提醒："这次可以多考虑..."\n`;
    } else {
      console.log('📭 未找到相关知识，使用普通对话模式');
    }

    // 呼叫 Claude API
    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 2048,
      system: enhancedSystemPrompt,
      messages: history.map(h => ({
        role: h.role,
        content: h.content
      }))
    });

    let assistantReply = message.content[0].text;

    // 如果使用了 RAG，在回复末尾添加来源提示
    if (ragResult.metadata.totalResults > 0) {
      assistantReply += `\n\n---\n💡 *此回答引用了你的 ${ragResult.metadata.totalResults} 条历史知识*`;
      if (ragResult.metadata.tags.length > 0) {
        assistantReply += `\n🏷️ 相关标签：${ragResult.metadata.tags.join('、')}`;
      }
    }

    // 新增 Claude 回覆到歷史
    addToHistory(userId, 'assistant', assistantReply);

    return assistantReply;

  } catch (error) {
    console.error('Claude 對話失敗:', error);
    return '抱歉，我遇到了一些問題。請稍後再試。';
  }
}

/**
 * 檢查對話歷史長度
 */
export function getChatHistoryLength(userId) {
  return getConversationHistory(userId).length;
}

