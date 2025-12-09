// lib/notion.js - Notion 資料庫操作模組
import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });

// Notion 資料庫 ID（從環境變數讀取，移除可能的換行符）
const MAIN_DB_ID = process.env.NOTION_MAIN_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');
const ROUNDS_DB_ID = process.env.NOTION_ROUNDS_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');
const QUESTION_BANK_DB_ID = process.env.NOTION_QUESTION_BANK_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');
const KNOWLEDGE_DB_ID = process.env.NOTION_KNOWLEDGE_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');
const TOPIC_SUMMARY_DB_ID = process.env.NOTION_TOPIC_SUMMARY_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');

/**
 * 從題庫隨機取得一個未使用的問題
 */
export async function getRandomQuestion() {
  try {
    const response = await notion.databases.query({
      database_id: QUESTION_BANK_DB_ID,
      filter: {
        property: '狀態',
        select: {
          equals: '未使用'
        }
      },
      page_size: 10
    });

    if (response.results.length === 0) {
      // 如果沒有未使用的問題，就從所有問題中隨機選
      const allQuestions = await notion.databases.query({
        database_id: QUESTION_BANK_DB_ID,
        page_size: 10
      });
      if (allQuestions.results.length === 0) {
        return null;
      }
      const randomIndex = Math.floor(Math.random() * allQuestions.results.length);
      return allQuestions.results[randomIndex];
    }

    const randomIndex = Math.floor(Math.random() * response.results.length);
    return response.results[randomIndex];
  } catch (error) {
    console.error('取得問題失敗:', error);
    return null;
  }
}

/**
 * 建立新的主問題記錄
 */
export async function createMainQuestion(questionText, questionType, sourceQuestionId = null) {
  try {
    const properties = {
      '問題': {
        title: [{ text: { content: questionText } }]
      },
      '日期': {
        date: { start: new Date().toISOString().split('T')[0] }
      },
      '問題類型': {
        select: { name: questionType || '反思' }
      },
      '狀態': {
        select: { name: '進行中' }
      }
    };

    // 如果有來源題目，加入關聯
    if (sourceQuestionId) {
      properties['來源題目'] = {
        relation: [{ id: sourceQuestionId }]
      };
    }

    const response = await notion.pages.create({
      parent: { database_id: MAIN_DB_ID },
      properties
    });

    return response;
  } catch (error) {
    console.error('建立主問題失敗:', error);
    return null;
  }
}

/**
 * 建立對話回合記錄
 */
export async function createConversationRound(mainQuestionId, roundNumber, userAnswer, aiFeedback, aiFollowUp, tags = []) {
  try {
    const response = await notion.pages.create({
      parent: { database_id: ROUNDS_DB_ID },
      properties: {
        '標題': {
          title: [{ text: { content: `第 ${roundNumber} 回合` } }]
        },
        '所屬問題': {
          relation: [{ id: mainQuestionId }]
        },
        '回合編號': {
          number: roundNumber
        },
        '使用者回答': {
          rich_text: [{ text: { content: userAnswer } }]
        },
        'AI 回饋': {
          rich_text: [{ text: { content: aiFeedback } }]
        },
        'AI 追問': {
          rich_text: [{ text: { content: aiFollowUp || '' } }]
        },
        '標籤': {
          multi_select: tags.map(tag => ({ name: tag }))
        },
        '是否最後一輪': {
          checkbox: aiFollowUp === '' || aiFollowUp === null
        }
      }
    });

    return response;
  } catch (error) {
    console.error('建立回合記錄失敗:', error);
    return null;
  }
}

/**
 * 更新主問題的總結和標籤（不改變狀態，保持「進行中」）
 * 用於「小結」功能
 */
export async function updateMainQuestionSummary(mainQuestionId, summary, blindSpotTags = []) {
  try {
    await notion.pages.update({
      page_id: mainQuestionId,
      properties: {
        '總結': {
          rich_text: [{ text: { content: summary } }]
        },
        '盲點標籤': {
          multi_select: blindSpotTags.map(tag => ({ name: tag }))
        }
      }
    });
    return true;
  } catch (error) {
    console.error('更新主問題總結失敗:', error);
    return false;
  }
}

/**
 * 更新主問題為已完成
 */
export async function completeMainQuestion(mainQuestionId, summary, blindSpotTags = []) {
  try {
    await notion.pages.update({
      page_id: mainQuestionId,
      properties: {
        '狀態': {
          select: { name: '已完成' }
        },
        '總結': {
          rich_text: [{ text: { content: summary } }]
        },
        '盲點標籤': {
          multi_select: blindSpotTags.map(tag => ({ name: tag }))
        }
      }
    });
    return true;
  } catch (error) {
    console.error('更新主問題失敗:', error);
    return false;
  }
}

/**
 * 更新題庫問題為已使用
 */
export async function markQuestionAsUsed(questionId) {
  try {
    await notion.pages.update({
      page_id: questionId,
      properties: {
        '狀態': {
          select: { name: '已使用' }
        },
        '使用日期': {
          date: { start: new Date().toISOString().split('T')[0] }
        }
      }
    });
    return true;
  } catch (error) {
    console.error('更新題庫失敗:', error);
    return false;
  }
}

/**
 * 取得 Notion 頁面的標題文字
 */
export function getPageTitle(page) {
  const titleProp = page.properties['問題'] || page.properties['標題'];
  if (!titleProp) return '';

  if (titleProp.title && titleProp.title.length > 0) {
    return titleProp.title[0].plain_text;
  }
  return '';
}

/**
 * 取得 Notion 頁面的 select 屬性值
 */
export function getSelectValue(page, propertyName) {
  const prop = page.properties[propertyName];
  if (!prop || !prop.select) return null;
  return prop.select.name;
}

/**
 * 查詢使用者進行中的主問題（基於日期和狀態）
 */
export async function getActiveMainQuestion(userId) {
  try {
    const today = new Date().toISOString().split('T')[0];

    const response = await notion.databases.query({
      database_id: MAIN_DB_ID,
      filter: {
        and: [
          {
            property: '狀態',
            select: {
              equals: '進行中'
            }
          },
          {
            property: '日期',
            date: {
              equals: today
            }
          }
        ]
      },
      sorts: [
        {
          property: '日期',
          direction: 'descending'
        }
      ],
      page_size: 1
    });

    if (response.results.length > 0) {
      return response.results[0];
    }
    return null;
  } catch (error) {
    console.error('查詢進行中問題失敗:', error);
    return null;
  }
}

/**
 * 取得主問題的所有回合記錄
 */
export async function getRoundsForQuestion(mainQuestionId) {
  try {
    const response = await notion.databases.query({
      database_id: ROUNDS_DB_ID,
      filter: {
        property: '所屬問題',
        relation: {
          contains: mainQuestionId
        }
      },
      sorts: [
        {
          property: '回合編號',
          direction: 'ascending'
        }
      ]
    });

    return response.results.map(page => ({
      roundNumber: page.properties['回合編號']?.number || 0,
      userAnswer: page.properties['使用者回答']?.rich_text[0]?.plain_text || '',
      feedback: page.properties['AI 回饋']?.rich_text[0]?.plain_text || '',
      followUp: page.properties['AI 追問']?.rich_text[0]?.plain_text || ''
    }));
  } catch (error) {
    console.error('取得回合記錄失敗:', error);
    return [];
  }
}

/**
 * 取得 Notion 頁面的 rich_text 屬性值
 */
export function getRichTextValue(page, propertyName) {
  const prop = page.properties[propertyName];
  if (!prop || !prop.rich_text || prop.rich_text.length === 0) return '';
  return prop.rich_text[0].plain_text;
}

/**
 * 取得 Notion 頁面的 relation 屬性值（返回第一個 ID）
 */
export function getRelationId(page, propertyName) {
  const prop = page.properties[propertyName];
  if (!prop || !prop.relation || prop.relation.length === 0) return null;
  return prop.relation[0].id;
}

/**
 * 創建知識片段
 * @param {string} title - 片段標題
 * @param {string} content - 知識內容
 * @param {Array} tags - 標籤陣列
 * @param {string} mainQuestionId - 來源問題 ID
 * @param {string} roundRange - 回合範圍（例如：「第 1-3 輪」）
 * @returns {Object|null} - 創建的知識片段頁面
 */
export async function createKnowledgeFragment(title, content, tags = [], mainQuestionId, roundRange = '') {
  try {
    const response = await notion.pages.create({
      parent: { database_id: KNOWLEDGE_DB_ID },
      properties: {
        '標題': {
          title: [{ text: { content: title } }]
        },
        '內容': {
          rich_text: [{ text: { content: content } }]
        },
        '標籤': {
          multi_select: tags.map(tag => ({ name: tag }))
        },
        '回合範圍': {
          rich_text: [{ text: { content: roundRange } }]
        },
        '來源問題': {
          relation: [{ id: mainQuestionId }]
        }
      }
    });

    return response;
  } catch (error) {
    console.error('創建知識片段失敗:', error);
    return null;
  }
}

/**
 * 取得主問題的所有知識片段
 * @param {string} mainQuestionId - 主問題 ID
 * @returns {Array} - 知識片段陣列
 */
export async function getKnowledgeFragments(mainQuestionId) {
  try {
    const response = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      filter: {
        property: '來源問題',
        relation: {
          contains: mainQuestionId
        }
      },
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ]
    });

    return response.results.map(page => ({
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['回合範圍']?.rich_text[0]?.plain_text || ''
    }));
  } catch (error) {
    console.error('取得知識片段失敗:', error);
    return [];
  }
}

/**
 * 按標籤搜尋知識片段（單一標籤）
 * @param {string} tag - 標籤名稱
 * @param {number} limit - 返回結果數量限制（預設 10）
 * @returns {Array} - 知識片段陣列
 */
export async function searchKnowledgeByTag(tag, limit = 10) {
  try {
    const response = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      filter: {
        property: '標籤',
        multi_select: {
          contains: tag
        }
      },
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['回合範圍']?.rich_text[0]?.plain_text || '',
      createdTime: page.created_time
    }));
  } catch (error) {
    console.error('搜尋知識片段失敗:', error);
    return [];
  }
}

/**
 * 按多個標籤搜尋知識片段（AND 邏輯，必須包含所有標籤）
 * @param {Array} tags - 標籤名稱陣列
 * @param {number} limit - 返回結果數量限制（預設 10）
 * @returns {Array} - 知識片段陣列
 */
export async function searchKnowledgeByMultipleTags(tags, limit = 10) {
  try {
    // 建立 AND 過濾條件
    const filters = tags.map(tag => ({
      property: '標籤',
      multi_select: {
        contains: tag
      }
    }));

    const response = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      filter: {
        and: filters
      },
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['回合範圍']?.rich_text[0]?.plain_text || '',
      createdTime: page.created_time
    }));
  } catch (error) {
    console.error('搜尋多標籤知識片段失敗:', error);
    return [];
  }
}

/**
 * 取得所有知識片段（用於統計）
 * @param {number} limit - 返回結果數量限制（預設 100）
 * @returns {Array} - 知識片段陣列
 */
export async function getAllKnowledgeFragments(limit = 100) {
  try {
    const response = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['回合範圍']?.rich_text[0]?.plain_text || '',
      createdTime: page.created_time
    }));
  } catch (error) {
    console.error('取得所有知識片段失敗:', error);
    return [];
  }
}

/**
 * 按標籤搜尋回合記錄（單一標籤）- 當知識片段查無結果時的降級選項
 * @param {string} tag - 標籤名稱
 * @param {number} limit - 返回結果數量限制（預設 10）
 * @returns {Array} - 回合記錄陣列（格式化為類似知識片段）
 */
export async function searchRoundsByTag(tag, limit = 10) {
  try {
    const response = await notion.databases.query({
      database_id: ROUNDS_DB_ID,
      filter: {
        property: '標籤',
        multi_select: {
          contains: tag
        }
      },
      sorts: [
        {
          property: '回合編號',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '對話回合',
      content: formatRoundContent(page),
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['標題']?.title[0]?.plain_text || '',
      createdTime: page.created_time,
      isRound: true // 標記這是回合記錄而非知識片段
    }));
  } catch (error) {
    console.error('搜尋回合記錄失敗:', error);
    return [];
  }
}

/**
 * 按多個標籤搜尋回合記錄（AND 邏輯）
 * @param {Array} tags - 標籤名稱陣列
 * @param {number} limit - 返回結果數量限制（預設 10）
 * @returns {Array} - 回合記錄陣列
 */
export async function searchRoundsByMultipleTags(tags, limit = 10) {
  try {
    const filters = tags.map(tag => ({
      property: '標籤',
      multi_select: {
        contains: tag
      }
    }));

    const response = await notion.databases.query({
      database_id: ROUNDS_DB_ID,
      filter: {
        and: filters
      },
      sorts: [
        {
          property: '回合編號',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '對話回合',
      content: formatRoundContent(page),
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      roundRange: page.properties['標題']?.title[0]?.plain_text || '',
      createdTime: page.created_time,
      isRound: true
    }));
  } catch (error) {
    console.error('搜尋多標籤回合記錄失敗:', error);
    return [];
  }
}

/**
 * 格式化回合記錄內容為可讀格式
 * @param {Object} page - Notion 回合記錄頁面
 * @returns {string} - 格式化的內容
 */
function formatRoundContent(page) {
  const userAnswer = page.properties['使用者回答']?.rich_text[0]?.plain_text || '';
  const feedback = page.properties['AI 回饋']?.rich_text[0]?.plain_text || '';
  const followUp = page.properties['AI 追問']?.rich_text[0]?.plain_text || '';

  let content = '';
  if (userAnswer) {
    content += `💬 回答：${userAnswer}\n\n`;
  }
  if (feedback) {
    content += `💡 回饋：${feedback}`;
  }
  if (followUp) {
    content += `\n\n❓ 追問：${followUp}`;
  }

  return content.trim();
}

/**
 * 按標籤搜尋主問題總結（單一標籤）
 * @param {string} tag - 標籤名稱
 * @param {number} limit - 返回結果數量限制（預設 5）
 * @returns {Array} - 主問題總結陣列
 */
export async function searchMainQuestionsByTag(tag, limit = 5) {
  try {
    const response = await notion.databases.query({
      database_id: MAIN_DB_ID,
      filter: {
        and: [
          {
            property: '盲點標籤',
            multi_select: {
              contains: tag
            }
          },
          {
            property: '狀態',
            select: {
              equals: '已完成'
            }
          }
        ]
      },
      sorts: [
        {
          property: '日期',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      questionText: page.properties['問題']?.title[0]?.plain_text || '',
      summary: page.properties['總結']?.rich_text[0]?.plain_text || '',
      blindSpotTags: page.properties['盲點標籤']?.multi_select?.map(t => t.name) || [],
      date: page.properties['日期']?.date?.start || '',
      createdTime: page.created_time,
      isMainQuestion: true // 標記這是主問題總結而非知識片段
    }));
  } catch (error) {
    console.error('搜尋主問題總結失敗:', error);
    return [];
  }
}

/**
 * 按多個標籤搜尋主問題總結（AND 邏輯）
 * @param {Array} tags - 標籤名稱陣列
 * @param {number} limit - 返回結果數量限制（預設 5）
 * @returns {Array} - 主問題總結陣列
 */
export async function searchMainQuestionsByMultipleTags(tags, limit = 5) {
  try {
    const tagFilters = tags.map(tag => ({
      property: '盲點標籤',
      multi_select: {
        contains: tag
      }
    }));

    const response = await notion.databases.query({
      database_id: MAIN_DB_ID,
      filter: {
        and: [
          ...tagFilters,
          {
            property: '狀態',
            select: {
              equals: '已完成'
            }
          }
        ]
      },
      sorts: [
        {
          property: '日期',
          direction: 'descending'
        }
      ],
      page_size: limit
    });

    return response.results.map(page => ({
      id: page.id,
      questionText: page.properties['問題']?.title[0]?.plain_text || '',
      summary: page.properties['總結']?.rich_text[0]?.plain_text || '',
      blindSpotTags: page.properties['盲點標籤']?.multi_select?.map(t => t.name) || [],
      date: page.properties['日期']?.date?.start || '',
      createdTime: page.created_time,
      isMainQuestion: true
    }));
  } catch (error) {
    console.error('搜尋多標籤主問題總結失敗:', error);
    return [];
  }
}


/**
 * 將長文本分割為 Notion rich_text 數組（每段最多 2000 字符）
 * Notion API 限制：rich_text 屬性中每個文本對象最多 2000 字符
 * @param {string} text - 要分割的文本
 * @returns {Array} - Notion rich_text 數組
 */
function splitTextForNotion(text) {
  const MAX_LENGTH = 2000;
  const richTextArray = [];

  for (let i = 0; i < text.length; i += MAX_LENGTH) {
    richTextArray.push({
      text: { content: text.substring(i, i + MAX_LENGTH) }
    });
  }

  return richTextArray;
}

/**
 * 創建主題總結
 * @param {string} tag - 主題標籤
 * @param {string} summary - 總結內容（500-1000字，無長度限制）
 * @param {number} sourceCount - 來源統計（整合了幾個來源）
 * @param {Array} relatedFragmentIds - 關聯的知識片段 ID
 * @param {Array} relatedQuestionIds - 關聯的主問題 ID
 * @returns {Object|null} - 創建的主題總結頁面
 */
export async function createTopicSummary(tag, summary, sourceCount = 0, relatedFragmentIds = [], relatedQuestionIds = []) {
  try {
    // 檢查環境變數
    if (!TOPIC_SUMMARY_DB_ID) {
      console.error('❌ 創建主題總結失敗：NOTION_TOPIC_SUMMARY_DB_ID 環境變數未設置');
      console.error('請在 Vercel 設置環境變數或檢查 .env 檔案');
      return null;
    }

    const properties = {
      '標題': {
        title: [{ text: { content: `${tag} 完整知識地圖` } }]
      },
      '主題標籤': {
        select: { name: tag }
      },
      '總結內容': {
        rich_text: splitTextForNotion(summary)
      },
      '來源統計': {
        number: sourceCount
      },
      '最後更新日期': {
        date: { start: new Date().toISOString().split('T')[0] }
      },
      '狀態': {
        select: { name: '已完成' }
      }
    };

    // 如果有關聯的知識片段
    if (relatedFragmentIds.length > 0) {
      properties['關聯知識片段'] = {
        relation: relatedFragmentIds.map(id => ({ id }))
      };
    }

    // 如果有關聯的主問題
    if (relatedQuestionIds.length > 0) {
      properties['關聯對話總結'] = {
        relation: relatedQuestionIds.map(id => ({ id }))
      };
    }

    console.log(`📝 正在創建主題總結：${tag}（資料庫 ID: ${TOPIC_SUMMARY_DB_ID}）`);

    const response = await notion.pages.create({
      parent: { database_id: TOPIC_SUMMARY_DB_ID },
      properties
    });

    console.log(`✅ 主題總結創建成功：${tag}（頁面 ID: ${response.id}）`);
    return response;
  } catch (error) {
    console.error('❌ 創建主題總結失敗:', error);
    console.error('標籤:', tag);
    console.error('資料庫 ID:', TOPIC_SUMMARY_DB_ID);
    if (error.code) console.error('錯誤代碼:', error.code);
    if (error.message) console.error('錯誤訊息:', error.message);
    return null;
  }
}

/**
 * 更新主題總結
 * @param {string} topicSummaryId - 主題總結 ID
 * @param {string} summary - 更新的總結內容
 * @param {number} sourceCount - 更新的來源統計
 * @returns {boolean}
 */
export async function updateTopicSummary(topicSummaryId, summary, sourceCount) {
  try {
    console.log(`📝 正在更新主題總結（頁面 ID: ${topicSummaryId}）`);

    await notion.pages.update({
      page_id: topicSummaryId,
      properties: {
        '總結內容': {
        rich_text: splitTextForNotion(summary)
      },
        '來源統計': {
          number: sourceCount
        },
        '最後更新日期': {
          date: { start: new Date().toISOString().split('T')[0] }
        }
      }
    });

    console.log(`✅ 主題總結更新成功（頁面 ID: ${topicSummaryId}）`);
    return true;
  } catch (error) {
    console.error('❌ 更新主題總結失敗:', error);
    console.error('頁面 ID:', topicSummaryId);
    if (error.code) console.error('錯誤代碼:', error.code);
    if (error.message) console.error('錯誤訊息:', error.message);
    return false;
  }
}

/**
 * 按主題標籤查詢主題總結
 * @param {string} tag - 主題標籤
 * @returns {Object|null} - 主題總結
 */
export async function getTopicSummaryByTag(tag) {
  try {
    const response = await notion.databases.query({
      database_id: TOPIC_SUMMARY_DB_ID,
      filter: {
        property: '主題標籤',
        select: {
          equals: tag
        }
      },
      sorts: [
        {
          property: '最後更新日期',
          direction: 'descending'
        }
      ],
      page_size: 1
    });

    if (response.results.length === 0) {
      return null;
    }

    const page = response.results[0];
    return {
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      tag: page.properties['主題標籤']?.select?.name || '',
      summary: page.properties['總結內容']?.rich_text[0]?.plain_text || '',
      sourceCount: page.properties['來源統計']?.number || 0,
      lastUpdated: page.properties['最後更新日期']?.date?.start || '',
      createdTime: page.created_time,
      isTopicSummary: true
    };
  } catch (error) {
    console.error('查詢主題總結失敗:', error);
    return null;
  }
}

/**
 * 取得某個標籤的所有相關內容（用於生成主題總結）
 * @param {string} tag - 標籤名稱
 * @returns {Object} - { fragments, mainQuestions, rounds, sourceTypes, totalCount }
 */
export async function getAllContentByTag(tag) {
  try {
    // 查詢知識片段
    const fragmentsResponse = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      filter: {
        property: '標籤',
        multi_select: {
          contains: tag
        }
      },
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ],
      page_size: 100
    });

    const fragments = fragmentsResponse.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || []
    }));

    // 查詢主問題總結
    const questionsResponse = await notion.databases.query({
      database_id: MAIN_DB_ID,
      filter: {
        and: [
          {
            property: '盲點標籤',
            multi_select: {
              contains: tag
            }
          },
          {
            property: '狀態',
            select: {
              equals: '已完成'
            }
          }
        ]
      },
      sorts: [
        {
          property: '日期',
          direction: 'descending'
        }
      ],
      page_size: 100
    });

    const mainQuestions = questionsResponse.results.map(page => ({
      id: page.id,
      questionText: page.properties['問題']?.title[0]?.plain_text || '',
      summary: page.properties['總結']?.rich_text[0]?.plain_text || '',
      blindSpotTags: page.properties['盲點標籤']?.multi_select?.map(t => t.name) || []
    }));

    // 計算精煉內容總數
    const refinedCount = fragments.length + mainQuestions.length;
    let rounds = [];

    // 智能降級：如果精煉內容 < 5，補充查詢對話回合
    if (refinedCount < 5) {
      const roundsResponse = await notion.databases.query({
        database_id: ROUNDS_DB_ID,
        filter: {
          property: '標籤',
          multi_select: {
            contains: tag
          }
        },
        sorts: [
          {
            property: '回合編號',
            direction: 'descending'
          }
        ],
        page_size: 20 // 最多 20 個對話回合
      });

      rounds = roundsResponse.results.map(page => ({
        id: page.id,
        title: page.properties['標題']?.title[0]?.plain_text || '對話回合',
        roundNumber: page.properties['回合編號']?.number || 0,
        userAnswer: page.properties['使用者回答']?.rich_text[0]?.plain_text || '',
        aiFeedback: page.properties['AI 回饋']?.rich_text[0]?.plain_text || '',
        aiFollowUp: page.properties['AI 追問']?.rich_text[0]?.plain_text || '',
        tags: page.properties['標籤']?.multi_select?.map(t => t.name) || []
      }));
    }

    // 來源類型統計
    const sourceTypes = {
      hasFragments: fragments.length > 0,
      hasMainQuestions: mainQuestions.length > 0,
      hasRounds: rounds.length > 0,
      refinedCount: refinedCount,
      roundsCount: rounds.length,
      totalCount: refinedCount + rounds.length
    };

    return {
      fragments,
      mainQuestions,
      rounds,
      sourceTypes,
      // 保持向下兼容
      totalCount: refinedCount + rounds.length
    };
  } catch (error) {
    console.error('取得標籤相關內容失敗:', error);
    return {
      fragments: [],
      mainQuestions: [],
      rounds: [],
      sourceTypes: {
        hasFragments: false,
        hasMainQuestions: false,
        hasRounds: false,
        refinedCount: 0,
        roundsCount: 0,
        totalCount: 0
      },
      totalCount: 0
    };
  }
}

