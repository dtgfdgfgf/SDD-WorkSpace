// lib/rag.js - RAG (Retrieval Augmented Generation) 知识检索模块
// 为对话提供情境化的知识支持

import Anthropic from '@anthropic-ai/sdk';
import {
  searchKnowledgeByTag,
  searchKnowledgeByMultipleTags,
  searchMainQuestionsByTag,
  searchMainQuestionsByMultipleTags,
  getTopicSummaryByTag
} from './notion.js';
import { TAGS, TAG_CATEGORIES } from './constants.js';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

/**
 * 从用户消息中提取相关标签和关键词
 * @param {string} userMessage - 用户消息
 * @returns {Object} - { tags: [], keywords: [], confidence: 'high'|'medium'|'low' }
 */
export async function extractRelevantTags(userMessage) {
  try {
    const allTags = Object.values(TAG_CATEGORIES).flat();

    const systemPrompt = `你是一位知识分类专家。任务：从用户消息中识别相关的知识标签。

可用标签（28个）：
${allTags.join('、')}

分析原则：
1. **精准匹配**：只选择高度相关的标签（1-3个）
2. **情境理解**：理解用户的真实意图和场景
3. **置信度评估**：
   - high: 明确提到标签主题
   - medium: 隐含相关但不直接
   - low: 可能相关但不确定

输出JSON格式：
{
  "tags": ["标签1", "标签2"],
  "keywords": ["关键词1", "关键词2", "关键词3"],
  "confidence": "high|medium|low",
  "reasoning": "为什么选择这些标签的简短说明"
}

如果消息与知识标签无关（如闲聊），返回空数组。`;

    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 512,
      temperature: 0.3,
      system: systemPrompt,
      messages: [{
        role: 'user',
        content: `用户消息：${userMessage}\n\n请分析并提取相关标签。`
      }]
    });

    const resultText = response.content[0].text;

    // 尝试解析JSON
    let result;
    try {
      result = JSON.parse(resultText);
    } catch (e) {
      // 如果解析失败，尝试提取JSON部分
      const jsonMatch = resultText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        // 解析失败，返回空结果
        return {
          tags: [],
          keywords: [],
          confidence: 'low',
          reasoning: 'Failed to parse response'
        };
      }
    }

    // 验证标签有效性
    const validTags = result.tags.filter(tag => allTags.includes(tag));

    return {
      tags: validTags,
      keywords: result.keywords || [],
      confidence: result.confidence || 'low',
      reasoning: result.reasoning || ''
    };

  } catch (error) {
    console.error('提取标签失败:', error);
    return {
      tags: [],
      keywords: [],
      confidence: 'low',
      reasoning: 'Error occurred'
    };
  }
}

/**
 * 检索相关知识
 * @param {Array} tags - 标签数组
 * @param {string} userMessage - 用户原始消息（用于相似度排序）
 * @returns {Object} - { topicSummary, knowledgeFragments, mainQuestions, totalResults }
 */
export async function retrieveRelevantKnowledge(tags, userMessage = '') {
  if (!tags || tags.length === 0) {
    return {
      topicSummary: null,
      knowledgeFragments: [],
      mainQuestions: [],
      totalResults: 0
    };
  }

  try {
    // Layer 0: 主题总结（只支持单标签）
    let topicSummary = null;
    if (tags.length === 1) {
      topicSummary = await getTopicSummaryByTag(tags[0]);
    }

    // Layer 1: 知识片段（限制3个）
    const knowledgeFragments = tags.length === 1
      ? await searchKnowledgeByTag(tags[0], 3)
      : await searchKnowledgeByMultipleTags(tags, 3);

    // Layer 2: 对话总结（限制2个）
    const mainQuestions = tags.length === 1
      ? await searchMainQuestionsByTag(tags[0], 2)
      : await searchMainQuestionsByMultipleTags(tags, 2);

    const totalResults =
      (topicSummary ? 1 : 0) +
      knowledgeFragments.length +
      mainQuestions.length;

    return {
      topicSummary,
      knowledgeFragments,
      mainQuestions,
      totalResults,
      tags
    };

  } catch (error) {
    console.error('检索知识失败:', error);
    return {
      topicSummary: null,
      knowledgeFragments: [],
      mainQuestions: [],
      totalResults: 0
    };
  }
}

/**
 * 格式化知识为prompt注入格式
 * @param {Object} knowledge - retrieveRelevantKnowledge 返回的对象
 * @returns {string} - 格式化的知识文本
 */
export function formatKnowledgeForPrompt(knowledge) {
  if (knowledge.totalResults === 0) {
    return '';
  }

  let formatted = '\n\n【相关知识库内容】\n';
  formatted += `（从用户的历史对话和知识积累中检索到 ${knowledge.totalResults} 条相关内容）\n\n`;

  // 主题总结
  if (knowledge.topicSummary) {
    formatted += `## 主题总结：${knowledge.topicSummary.tag}\n`;
    // 只取前500字，避免prompt过长
    const summaryCut = knowledge.topicSummary.summary.length > 500
      ? knowledge.topicSummary.summary.substring(0, 500) + '...'
      : knowledge.topicSummary.summary;
    formatted += `${summaryCut}\n\n`;
  }

  // 知识片段
  if (knowledge.knowledgeFragments.length > 0) {
    formatted += `## 精炼洞察（${knowledge.knowledgeFragments.length}个）：\n`;
    knowledge.knowledgeFragments.forEach((fragment, i) => {
      formatted += `${i + 1}. ${fragment.title}\n`;
      formatted += `   ${fragment.content}\n`;
      if (fragment.tags && fragment.tags.length > 0) {
        formatted += `   标签：${fragment.tags.join('、')}\n`;
      }
      formatted += '\n';
    });
  }

  // 历史盲点（从对话总结中提取）
  if (knowledge.mainQuestions.length > 0) {
    const allBlindSpots = knowledge.mainQuestions
      .flatMap(q => q.blindSpotTags || [])
      .filter((tag, index, self) => self.indexOf(tag) === index); // 去重

    if (allBlindSpots.length > 0) {
      formatted += `## ⚠️ 用户的历史思维盲点：\n`;
      formatted += `${allBlindSpots.join('、')}\n`;
      formatted += `（这些是用户在相关主题上曾经忽略或误判的方面，请在回答时温和提醒）\n\n`;
    }

    // 历史反思
    formatted += `## 历史对话洞察（${knowledge.mainQuestions.length}个）：\n`;
    knowledge.mainQuestions.forEach((q, i) => {
      formatted += `${i + 1}. ${q.questionText}\n`;
      // 只取前100字
      const summaryCut = q.summary.length > 100
        ? q.summary.substring(0, 100) + '...'
        : q.summary;
      formatted += `   ${summaryCut}\n\n`;
    });
  }

  formatted += `---\n`;
  formatted += `💡 回答建议：\n`;
  formatted += `1. 优先引用上述知识库内容，使其个性化和连贯\n`;
  formatted += `2. 指出用户的历史盲点（如有），但要温和建设性\n`;
  formatted += `3. 建立新知识与旧知识的连接\n`;
  formatted += `4. 如果知识库内容不足，正常回答即可，不要生硬拼凑\n`;

  return formatted;
}

/**
 * 完整的RAG流程（一次调用）
 * @param {string} userMessage - 用户消息
 * @returns {Object} - { knowledge, enhancedPrompt, metadata }
 */
export async function performRAG(userMessage) {
  try {
    console.log('🔍 RAG: 开始处理用户消息');

    // Step 1: 提取标签
    const extraction = await extractRelevantTags(userMessage);
    console.log(`🏷️  RAG: 提取到 ${extraction.tags.length} 个标签 (置信度: ${extraction.confidence})`);

    // 如果置信度太低或没有标签，直接返回
    if (extraction.confidence === 'low' || extraction.tags.length === 0) {
      console.log('📭 RAG: 未找到相关知识，使用普通对话');
      return {
        knowledge: null,
        enhancedPrompt: '',
        metadata: {
          tags: [],
          confidence: extraction.confidence,
          totalResults: 0
        }
      };
    }

    // Step 2: 检索知识
    const knowledge = await retrieveRelevantKnowledge(extraction.tags, userMessage);
    console.log(`📚 RAG: 检索到 ${knowledge.totalResults} 条相关知识`);

    // Step 3: 格式化为prompt
    const enhancedPrompt = formatKnowledgeForPrompt(knowledge);

    return {
      knowledge,
      enhancedPrompt,
      metadata: {
        tags: extraction.tags,
        keywords: extraction.keywords,
        confidence: extraction.confidence,
        reasoning: extraction.reasoning,
        totalResults: knowledge.totalResults
      }
    };

  } catch (error) {
    console.error('❌ RAG流程失败:', error);
    return {
      knowledge: null,
      enhancedPrompt: '',
      metadata: {
        tags: [],
        confidence: 'error',
        totalResults: 0,
        error: error.message
      }
    };
  }
}
