// 臨時腳本：在 webhook.js 中插入兩個新的 handler 函數
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const webhookPath = path.join(__dirname, 'api', 'webhook.js');
const content = fs.readFileSync(webhookPath, 'utf-8');

// 新增的兩個函數
const newHandlers = `
/**
 * 處理「總結 [類別]」指令 - 批次生成某類別所有標籤的主題總結
 */
async function handleBatchSummaryByCategory(userId, categoryName) {
  try {
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
      return \`❌ 無效的類別「\${categoryName}」\\n\\n\` +
        \`可用類別：\\n\` +
        \`• 技術類 (5個標籤)\\n\` +
        \`• 商業類 (9個標籤)\\n\` +
        \`• 個人成長類 (7個標籤)\\n\` +
        \`• 團隊協作類 (3個標籤)\\n\` +
        \`• 思維模式類 (4個標籤)\\n\\n\` +
        \`例如：總結 商業類\`;
    }

    const tagsInCategory = TAG_CATEGORIES[normalizedCategory];

    // 先檢查哪些標籤有內容
    let progressText = \`🔄 正在檢查「\${categoryName}」類別的所有標籤...\\n\\n\`;
    progressText += \`📊 共 \${tagsInCategory.length} 個標籤需要檢查\\n\\n\`;
    progressText += \`⏱️ 預計需要 3-5 分鐘，請稍候...\\n\\n\`;
    progressText += \`─────────────────\\n\`;

    const results = {
      generated: [],
      skipped: [],
      failed: []
    };

    // 依序處理每個標籤
    for (const tag of tagsInCategory) {
      try {
        // 取得該標籤的所有相關內容
        const { totalCount } = await getAllContentByTag(tag);

        if (totalCount === 0) {
          results.skipped.push(tag);
          progressText += \`\\n⏭️  跳過：\${tag}（無內容）\`;
          continue;
        }

        // 檢查是否已有主題總結
        const existingSummary = await getTopicSummaryByTag(tag);

        // 取得完整內容用於生成總結
        const { fragments, mainQuestions, rounds } = await getAllContentByTag(tag);

        progressText += \`\\n🔄 處理中：\${tag}（\${existingSummary ? '更新' : '新增'}，\${totalCount} 個來源）\`;

        // 使用 AI 生成主題總結
        const summaryContent = await generateTopicSummary(tag, fragments, mainQuestions, rounds);

        // 儲存或更新到 Notion
        let saveSuccess = false;
        if (existingSummary) {
          saveSuccess = await updateTopicSummary(existingSummary.id, summaryContent, totalCount);
        } else {
          const fragmentIds = fragments.map(f => f.id);
          const questionIds = mainQuestions.map(q => q.id);
          const result = await createTopicSummary(tag, summaryContent, totalCount, fragmentIds, questionIds);
          saveSuccess = result !== null;
        }

        if (saveSuccess) {
          results.generated.push({ tag, action: existingSummary ? '更新' : '新增', count: totalCount });
          progressText += \` ✅\`;
        } else {
          results.failed.push(tag);
          progressText += \` ❌\`;
        }

      } catch (error) {
        console.error(\`處理標籤「\${tag}」失敗:\`, error);
        results.failed.push(tag);
        progressText += \`\\n❌ 失敗：\${tag}\`;
      }
    }

    // 生成最終報告
    let finalReport = \`\\n\\n\${'='.repeat(30)}\\n\\n\`;
    finalReport += \`✅ 批次總結完成：\${categoryName}\\n\\n\`;

    if (results.generated.length > 0) {
      finalReport += \`📝 已處理（\${results.generated.length} 個）：\\n\`;
      results.generated.forEach(({ tag, action, count }) => {
        finalReport += \`• \${tag} - \${action}（\${count} 個來源）\\n\`;
      });
      finalReport += \`\\n\`;
    }

    if (results.skipped.length > 0) {
      finalReport += \`⏭️  已跳過（\${results.skipped.length} 個，無內容）：\\n\`;
      finalReport += \`\${results.skipped.join('、')}\\n\\n\`;
    }

    if (results.failed.length > 0) {
      finalReport += \`❌ 失敗（\${results.failed.length} 個）：\\n\`;
      finalReport += \`\${results.failed.join('、')}\\n\\n\`;
    }

    finalReport += \`📊 統計：\\n\`;
    finalReport += \`• 成功：\${results.generated.length} 個\\n\`;
    finalReport += \`• 跳過：\${results.skipped.length} 個\\n\`;
    finalReport += \`• 失敗：\${results.failed.length} 個\\n\`;
    finalReport += \`• 總計：\${tagsInCategory.length} 個\\n\\n\`;
    finalReport += \`💡 使用「總結狀態」查看所有總結的更新時間\`;

    return progressText + finalReport;

  } catch (error) {
    console.error('批次生成主題總結失敗:', error);
    return '抱歉，批次生成主題總結時發生錯誤。請稍後再試。';
  }
}

/**
 * 處理「總結狀態」指令 - 查看所有標籤的總結狀態
 */
async function handleSummaryStatus(userId) {
  try {
    // 匯入必要的函數
    const { Client: NotionClient } = await import('@notionhq/client');
    const notion = new NotionClient({ auth: process.env.NOTION_TOKEN });
    const TOPIC_SUMMARY_DB_ID = process.env.NOTION_TOPIC_SUMMARY_DB_ID;

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

    let replyText = \`📊 主題總結狀態\\n\\n\`;

    // 按類別顯示
    Object.entries(TAG_CATEGORIES).forEach(([category, tags]) => {
      replyText += \`【\${category}】\\n\`;

      tags.forEach(tag => {
        const summary = summaryMap[tag];
        const fragmentCount = tagFrequency[tag] || 0;

        if (summary) {
          // 已有總結
          const date = new Date(summary.lastUpdated);
          const formattedDate = date.toLocaleDateString('zh-TW', { month: 'M', day: 'd' });
          const daysAgo = Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));

          let statusIcon = '✅';
          let ageNote = '';

          // 檢查是否需要更新（有新內容 + 7天以上）
          if (fragmentCount > summary.sourceCount && daysAgo > 7) {
            statusIcon = '🔄';
            ageNote = \` - 建議更新\`;
          } else if (daysAgo > 30) {
            statusIcon = '⚠️';
            ageNote = \` - \${daysAgo}天前\`;
          } else if (daysAgo > 7) {
            ageNote = \` - \${daysAgo}天前\`;
          }

          replyText += \`\${statusIcon} \${tag}（\${formattedDate}，\${summary.sourceCount}來源\${ageNote}）\\n\`;
        } else if (fragmentCount > 0) {
          // 有內容但未總結
          replyText += \`🆕 \${tag}（未總結，\${fragmentCount}片段）\\n\`;
        } else {
          // 無內容
          replyText += \`⚪ \${tag}（無內容）\\n\`;
        }
      });

      replyText += \`\\n\`;
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

    replyText += \`📈 統計資訊：\\n\`;
    replyText += \`• 已總結：\${summarizedTags}/\${totalTags} 個標籤\\n\`;
    replyText += \`• 有內容：\${tagsWithContent} 個標籤\\n\`;
    replyText += \`• 待總結：\${needSummary} 個標籤\\n\`;
    if (needUpdate.length > 0) {
      replyText += \`• 建議更新：\${needUpdate.length} 個標籤\\n\`;
    }
    replyText += \`\\n\`;

    replyText += \`💡 圖例說明：\\n\`;
    replyText += \`✅ 已總結（最新）\\n\`;
    replyText += \`🔄 建議更新（有新內容 + 7天以上）\\n\`;
    replyText += \`⚠️  需要更新（30天以上）\\n\`;
    replyText += \`🆕 待總結（有內容但未總結）\\n\`;
    replyText += \`⚪ 無內容\\n\\n\`;

    replyText += \`🛠️  快速操作：\\n\`;
    replyText += \`• 總結 [標籤] - 總結單一標籤\\n\`;
    replyText += \`• 總結 [類別] - 批次總結整個類別\\n\`;
    replyText += \`  例如：總結 商業類\`;

    return replyText;

  } catch (error) {
    console.error('取得總結狀態失敗:', error);
    return '抱歉，取得總結狀態時發生錯誤。請稍後再試。';
  }
}

`;

// 找到插入位置 - 在 handleGenerateTopicSummary 結束後，handleHelp 之前
const marker = `}

/**
 * 處理「幫助」指令
 */
function handleHelp() {`;

const newContent = content.replace(marker, `}
${newHandlers}
/**
 * 處理「幫助」指令
 */
function handleHelp() {`);

// 寫回文件
fs.writeFileSync(webhookPath, newContent, 'utf-8');

console.log('✅ 成功添加兩個新的 handler 函數到 webhook.js');
