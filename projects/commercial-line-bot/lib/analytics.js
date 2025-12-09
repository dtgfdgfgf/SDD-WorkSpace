// lib/analytics.js - 數據分析與週報生成模組
import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });

const MAIN_DB_ID = process.env.NOTION_MAIN_DB_ID;
const ROUNDS_DB_ID = process.env.NOTION_ROUNDS_DB_ID;
const KNOWLEDGE_DB_ID = process.env.NOTION_KNOWLEDGE_DB_ID;

/**
 * 取得指定日期範圍內的主問題
 * @param {string} startDate - 開始日期 (YYYY-MM-DD)
 * @param {string} endDate - 結束日期 (YYYY-MM-DD)
 * @returns {Array} - 主問題陣列
 */
export async function getMainQuestionsByDateRange(startDate, endDate) {
  try {
    const response = await notion.databases.query({
      database_id: MAIN_DB_ID,
      filter: {
        and: [
          {
            property: '日期',
            date: {
              on_or_after: startDate
            }
          },
          {
            property: '日期',
            date: {
              on_or_before: endDate
            }
          }
        ]
      },
      sorts: [
        {
          property: '日期',
          direction: 'descending'
        }
      ]
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['問題']?.title[0]?.plain_text || '',
      date: page.properties['日期']?.date?.start || '',
      status: page.properties['狀態']?.select?.name || '',
      blindSpotTags: page.properties['盲點標籤']?.multi_select?.map(t => t.name) || [],
      summary: page.properties['總結']?.rich_text[0]?.plain_text || ''
    }));
  } catch (error) {
    console.error('取得日期範圍主問題失敗:', error);
    return [];
  }
}

/**
 * 取得指定日期範圍內的知識片段
 * @param {string} startDate - 開始日期 (YYYY-MM-DD)
 * @param {string} endDate - 結束日期 (YYYY-MM-DD)
 * @returns {Array} - 知識片段陣列
 */
export async function getKnowledgeFragmentsByDateRange(startDate, endDate) {
  try {
    const response = await notion.databases.query({
      database_id: KNOWLEDGE_DB_ID,
      filter: {
        and: [
          {
            property: '建立時間',
            date: {
              on_or_after: startDate
            }
          },
          {
            property: '建立時間',
            date: {
              on_or_before: endDate
            }
          }
        ]
      },
      sorts: [
        {
          property: '建立時間',
          direction: 'descending'
        }
      ]
    });

    return response.results.map(page => ({
      id: page.id,
      title: page.properties['標題']?.title[0]?.plain_text || '',
      content: page.properties['內容']?.rich_text[0]?.plain_text || '',
      tags: page.properties['標籤']?.multi_select?.map(t => t.name) || [],
      createdTime: page.created_time
    }));
  } catch (error) {
    console.error('取得日期範圍知識片段失敗:', error);
    return [];
  }
}

/**
 * 生成週報
 * @param {string} startDate - 開始日期 (YYYY-MM-DD，可選，預設為本週一)
 * @param {string} endDate - 結束日期 (YYYY-MM-DD，可選，預設為今天)
 * @returns {string} - 格式化的週報文字
 */
export async function generateWeeklyReport(startDate = null, endDate = null) {
  try {
    // 如果沒有提供日期，計算本週範圍
    if (!startDate || !endDate) {
      const now = new Date();
      const dayOfWeek = now.getDay(); // 0 = Sunday, 1 = Monday, ...
      const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // 計算距離週一的天數

      const monday = new Date(now);
      monday.setDate(now.getDate() - daysToMonday);
      startDate = monday.toISOString().split('T')[0];

      endDate = now.toISOString().split('T')[0];
    }

    // 取得本週的主問題和知識片段
    const mainQuestions = await getMainQuestionsByDateRange(startDate, endDate);
    const knowledgeFragments = await getKnowledgeFragmentsByDateRange(startDate, endDate);

    // 如果沒有任何資料
    if (mainQuestions.length === 0 && knowledgeFragments.length === 0) {
      return `📊 週報 (${startDate} ~ ${endDate})\n\n本週暫無對話記錄。\n\n💡 輸入「問」開始新的思維訓練！`;
    }

    // 統計盲點標籤頻率
    const blindSpotFrequency = {};
    mainQuestions.forEach(q => {
      q.blindSpotTags.forEach(tag => {
        blindSpotFrequency[tag] = (blindSpotFrequency[tag] || 0) + 1;
      });
    });

    // 排序盲點標籤
    const sortedBlindSpots = Object.entries(blindSpotFrequency)
      .sort((a, b) => b[1] - a[1]);

    // 分類盲點
    const highFrequency = sortedBlindSpots.filter(([tag, count]) => count >= 3);
    const mediumFrequency = sortedBlindSpots.filter(([tag, count]) => count >= 2 && count < 3);
    const lowFrequency = sortedBlindSpots.filter(([tag, count]) => count < 2);

    // 組合週報文字
    let report = `📊 週報 (${startDate} ~ ${endDate})\n\n`;

    // 基本統計
    report += `【本週概況】\n`;
    report += `💬 對話次數：${mainQuestions.length} 次\n`;
    report += `💾 知識片段：${knowledgeFragments.length} 個\n`;
    report += `🎯 盲點標籤：${sortedBlindSpots.length} 種\n\n`;

    // 盲點頻率分析
    if (sortedBlindSpots.length > 0) {
      report += `【盲點頻率分析】\n`;

      if (highFrequency.length > 0) {
        report += `🔴 高頻盲點（需警惕，≥3 次）：\n`;
        highFrequency.forEach(([tag, count]) => {
          report += `  • ${tag}：${count} 次\n`;
        });
        report += '\n';
      }

      if (mediumFrequency.length > 0) {
        report += `🟡 中頻盲點（2 次）：\n`;
        mediumFrequency.forEach(([tag, count]) => {
          report += `  • ${tag}：${count} 次\n`;
        });
        report += '\n';
      }

      if (lowFrequency.length > 0) {
        report += `🟢 低頻盲點（1 次）：\n`;
        lowFrequency.slice(0, 5).forEach(([tag, count]) => {
          report += `  • ${tag}\n`;
        });
        if (lowFrequency.length > 5) {
          report += `  （還有 ${lowFrequency.length - 5} 個）\n`;
        }
        report += '\n';
      }
    }

    // 知識片段列表
    if (knowledgeFragments.length > 0) {
      report += `【本週知識片段】\n`;
      knowledgeFragments.forEach((fragment, index) => {
        report += `${index + 1}. ${fragment.title}\n`;
        if (fragment.tags.length > 0) {
          report += `   🏷️ ${fragment.tags.join('、')}\n`;
        }
      });
      report += '\n';
    }

    // 改善建議
    if (highFrequency.length > 0) {
      const topBlindSpot = highFrequency[0][0];
      report += `【本週建議】\n`;
      report += `💡 你的「${topBlindSpot}」盲點出現 ${highFrequency[0][1]} 次，建議：\n`;
      report += `1. 回顧相關知識片段\n`;
      report += `2. 設計小實驗驗證你的假設\n`;
      report += `3. 下週刻意練習這個面向\n\n`;
    }

    report += `💬 輸入「查詢 [標籤]」查看相關知識`;

    return report;

  } catch (error) {
    console.error('生成週報失敗:', error);
    return '抱歉，生成週報時發生錯誤。請稍後再試。';
  }
}

/**
 * 統計所有標籤的使用頻率（全歷史）
 * @returns {Object} - 標籤頻率統計 { tagName: count }
 */
export async function getAllTagsFrequency() {
  try {
    // 查詢回合資料庫（ROUNDS_DB）
    // 這是標籤的主要來源，每次 AI 分析都會自動記錄
    const response = await notion.databases.query({
      database_id: ROUNDS_DB_ID,
      page_size: 100 // 如果回合很多，可能需要分頁處理
    });

    const tagFrequency = {};
    response.results.forEach(page => {
      const tags = page.properties['標籤']?.multi_select?.map(t => t.name) || [];
      tags.forEach(tag => {
        tagFrequency[tag] = (tagFrequency[tag] || 0) + 1;
      });
    });

    return tagFrequency;
  } catch (error) {
    console.error('統計標籤頻率失敗:', error);
    return {};
  }
}
