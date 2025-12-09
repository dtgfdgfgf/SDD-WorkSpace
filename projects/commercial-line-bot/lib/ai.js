// lib/ai.js - AI 分析模組 (使用 Claude)
import Anthropic from '@anthropic-ai/sdk';
import { formatTagsForPrompt } from './constants.js';

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY
});

/**
 * 分析使用者的回答並給予回饋
 * @param {string} question - 問題
 * @param {string} userAnswer - 使用者回答
 * @param {number} roundNumber - 當前回合數
 * @param {Array} conversationHistory - 對話歷史
 * @returns {Object} { feedback, followUp, tags, shouldEnd }
 */
export async function analyzeAnswer(question, userAnswer, roundNumber, conversationHistory = []) {
  try {
    const maxRounds = 100;
    const shouldEnd = roundNumber >= maxRounds;

    // 建立對話歷史文字
    let conversationContext = '';
    if (conversationHistory.length > 0) {
      conversationContext = '\n\n以下是之前的對話歷史：\n\n' +
        conversationHistory.map(h =>
          `第 ${h.round} 輪：\n使用者：${h.userAnswer}\nAI 回饋：${h.feedback}\nAI 追問：${h.followUp}`
        ).join('\n\n');
    }

    const systemPrompt = `你是一位專業的商業思維教練，專注於：
1. 發現思維盲點（認知偏誤、未驗證假設、資訊盲區）
2. 提升決策品質（系統性思考、風險評估、假設驗證）
3. 促進行動導向（從洞察到可執行的下一步）

【你的教練風格】
- 蘇格拉底式提問：不直接給答案，而是引導思考
- 挑戰假設：溫和但堅定地質疑未經驗證的假設
- 實戰導向：理論必須連結到具體場景和行動

【當前對話情境】
- 當前回合：第 ${roundNumber} 輪（最多 ${maxRounds} 輪）
- 對話歷史：${conversationHistory.length} 輪

【你的任務】

**1. 深度分析**
分析使用者回答中的：
- ✅ 優點：哪些思考是清晰、深入的
- ⚠️ 盲點：哪些假設未驗證、哪些資訊缺失、哪些邏輯跳躍
- 🎯 機會：可以進一步探索的方向

**2. 結構化回饋（100-300字）**
按照以下框架組織你的回饋：
a) 正面肯定（1-2 句）：指出使用者思考的亮點
b) 盲點提醒（2-3 句）：溫和但明確地指出思維盲點
   - 說明：為什麼這是盲點
   - 影響：忽略它可能導致什麼後果
c) 改進建議（1-2 句）：給出可操作的下一步
   - 避免空泛建議（❌ "要多思考"）
   - 給具體方法（✅ "試著列出 3 個反對這個假設的理由"）

**3. 深度追問（如果不是最後一輪）**
追問策略（選擇其一）：
- 深挖假設：「你說 X，背後的假設是什麼？」
- 探索替代方案：「如果 Y 不可行，還有什麼選擇？」
- 挑戰思維模式：「為什麼選擇 Z 而不是 W？」
- 情境測試：「如果預算減半，這個方案還成立嗎？」

追問必須：
- 針對核心假設或邏輯鏈中的薄弱環節
- 引導更深層次的思考，而非表面資訊
- 一次只問一個問題（避免多重問題）

**4. 標籤識別（選擇 3-6 個）**
從 28 個標籤中選擇最相關的，遵循以下原則：
- 必選：1-2 個主題標籤（如：定價策略、系統架構、時間管理等具體標籤）
- 必選：1-2 個思維方式標籤（批判性思考、系統性思考、創意思維、假設驗證）
- 可選：1-2 個成長/協作標籤（根據對話內容決定）
- 優先選擇細分標籤（如「定價策略」而非籠統的大類）
- 確保標籤能充分反映對話的多維度內容

可用標籤（28 個）：
${formatTagsForPrompt()}

【輸出格式】
請以 JSON 格式回覆：
{
  "feedback": "結構化回饋內容（100-300字，包含：正面肯定、盲點提醒、改進建議）",
  "followUp": "深度追問（如果是最後一輪則為空字串）",
  "tags": ["標籤1", "標籤2", "標籤3", ...],  // 3-6 個標籤
  "summary": "如果是最後一輪，總結關鍵洞察（50字以內）"
}

【重要提醒】
- ❌ 避免：過於理論、說教口吻、模糊建議
- ✅ 追求：具體案例、可操作建議、啟發性問題
- 記住：你的目標不是「評判」，而是「引導成長」`;

    const userPrompt = `${conversationContext}

問題：${question}

使用者回答（第 ${roundNumber} 輪）：${userAnswer}`;

    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 1024,
      messages: [{
        role: 'user',
        content: userPrompt
      }],
      system: systemPrompt
    });

    // 解析 Claude 回應
    const responseText = message.content[0].text;

    // 嘗試從回應中提取 JSON
    let result;
    try {
      // 先嘗試直接解析
      result = JSON.parse(responseText);
    } catch (e) {
      // 如果失敗，嘗試提取 JSON 部分
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        // 如果都失敗，使用預設結構
        result = {
          feedback: responseText.substring(0, 200),
          followUp: '',
          tags: ['思維盲點'],
          summary: ''
        };
      }
    }

    return {
      feedback: result.feedback || '感謝你的分享。',
      followUp: shouldEnd ? '' : (result.followUp || ''),
      tags: result.tags || [],
      summary: result.summary || '',
      shouldEnd
    };

  } catch (error) {
    console.error('AI 分析失敗:', error);
    return {
      feedback: '感謝你的回答。讓我思考一下如何給你更好的回饋。',
      followUp: '',
      tags: [],
      summary: '',
      shouldEnd: true
    };
  }
}

/**
 * 生成對話總結和盲點分析
 */
export async function generateSummary(question, allRounds) {
  try {
    const roundsText = allRounds.map(r =>
      `第 ${r.roundNumber} 輪：\n使用者：${r.userAnswer}\nAI：${r.feedback}`
    ).join('\n\n');

    const systemPrompt = `你是一位專業的商業思維教練。現在要對整個對話進行深度總結。

【你的任務】
分析 ${allRounds.length} 輪對話，提煉核心價值。

**1. 整合對話脈絡**
- 追蹤思考演進：從第一輪到最後一輪，思維如何深化？
- 識別關鍵轉折：哪些追問帶來了突破性洞察？
- 發現思維模式：重複出現的思考方式或決策習慣

**2. 核心洞察提煉（50-100字）**
總結中必須包含：
a) 主要發現（2-3 句）：使用者在這次對話中最重要的領悟
b) 思維盲點（1-2 句）：發現的認知偏誤、未驗證假設或資訊盲區
c) 成長方向（1 句）：下一步可以改進的方向

【寫作原則】
- ✅ 具體 > 抽象：用使用者的實際案例，而非理論描述
- ✅ 洞察 > 總結：提煉「為什麼」，而非「說了什麼」
- ✅ 行動導向：總結要能指導未來決策

【錯誤示例 vs 正確示例】
❌ 錯誤：「使用者對商業模式有了更深的理解」
✅ 正確：「發現定價不只是成本加成，而是價值感知的戰略工具。盲點：假設客戶會理性比價，忽略品牌溢價空間」

**3. 標籤識別（選擇 2-4 個）**
從整個對話中識別核心主題和思維方式：
- 主題標籤（1-2 個）：對話的核心領域
- 思維標籤（1-2 個）：使用者展現或需要加強的思維方式

可用標籤（28 個）：
${formatTagsForPrompt()}

【輸出格式】
請以 JSON 格式回覆：
{
  "summary": "核心洞察總結（50-100字，包含：主要發現、思維盲點、成長方向）",
  "blindSpotTags": ["標籤1", "標籤2", "標籤3"]
}

【重要】
- 這個總結會儲存到 Notion，未來檢索時要能快速回憶對話價值
- 避免流水帳式總結，要有深度和可操作性`;

    const userPrompt = `問題：${question}

對話記錄：
${roundsText}`;

    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 512,
      messages: [{
        role: 'user',
        content: userPrompt
      }],
      system: systemPrompt
    });

    const responseText = message.content[0].text;

    let result;
    try {
      result = JSON.parse(responseText);
    } catch (e) {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        result = {
          summary: responseText.substring(0, 150),
          blindSpotTags: ['思維盲點']
        };
      }
    }

    return {
      summary: result.summary || '感謝你的參與，這是一次很好的反思。',
      blindSpotTags: result.blindSpotTags || []
    };

  } catch (error) {
    console.error('生成總結失敗:', error);
    return {
      summary: '感謝你的參與，這是一次很好的反思。',
      blindSpotTags: []
    };
  }
}

/**
 * 生成知識片段（段落總結）
 * @param {Array} rounds - 要總結的回合陣列
 * @returns {Object} { title, content, tags }
 */
export async function generateKnowledgeFragment(rounds) {
  try {
    const roundsText = rounds.map(r =>
      `第 ${r.roundNumber} 輪：\n使用者：${r.userAnswer}\nAI：${r.feedback}`
    ).join('\n\n');

    const systemPrompt = `你是一位專業的知識管理助手。你的任務是從對話中提取可重用的知識片段，為未來的檢索和再利用做準備。

【知識片段的價值】
這些片段將被儲存到 Notion 知識庫，未來可能用於：
- 快速查找類似情境的思考框架
- 建立個人化的決策模式庫
- 支援 RAG (檢索增強生成) 系統，提供情境化建議

【你的任務】

**1. 提煉核心洞察（100-200字）**
從對話中提取「可遷移的智慧」，而非「對話摘要」：
- ✅ 正確：「定價策略的核心是價值錨定，而非成本計算。高價位可以透過限量、專業背書、儀式感來建立心理正當性。實驗方法：先推高價位測試市場反應，再決定是否調整。」
- ❌ 錯誤：「使用者討論了定價問題，我提問了幾個問題，最後得出一些結論。」

寫作原則：
- 抽離具體情境：將「我的產品」轉換為「此類產品」
- 提煉方法論：不只是「做什麼」，更要「為什麼」和「如何驗證」
- 保留可操作性：包含具體的實驗方法或檢查清單

**2. 創建可檢索的標題（10字以內）**
標題必須平衡兩個目標：
- 📍 主題明確：一眼看出知識領域（如「定價策略」而非「商業思考」）
- 🎯 情境清晰：能區分細微差異（如「SaaS 定價錨定法」vs「實體商品定價策略」）

【錯誤示例 vs 正確示例】
❌ 錯誤：「商業模式思考」（太籠統）
✅ 正確：「訂閱制的留存率陷阱」
❌ 錯誤：「今天的討論總結」（無檢索價值）
✅ 正確：「技術債務的量化評估法」

**3. 標籤選擇（2-3 個）**
從 28 個標籤中選擇最相關的：
- 必選（1-2 個）：主題標籤，優先選擇細分標籤
  - 如「定價策略」而非籠統的「商業模式」
  - 如「系統架構」而非籠統的「技術」
- 可選（0-1 個）：思維方式標籤（僅當對話明顯展現該思維模式時才選）
  - 批判性思考、系統性思考、創意思維、假設驗證

可用標籤（28 個）：
${formatTagsForPrompt()}

【輸出格式】
請以 JSON 格式回覆：
{
  "title": "片段標題（10字以內）",
  "content": "核心洞察內容（100-200字，抽離情境的方法論）",
  "tags": ["標籤1", "標籤2"]
}

【重要提醒】
- ❌ 避免：流水帳總結、過度具體的個人案例、理論堆砌
- ✅ 追求：可遷移的框架、具體的驗證方法、未來可直接應用的洞察
- 記住：這不是「會議記錄」，而是「提煉出來的可重用智慧」`;

    const userPrompt = `對話片段：
${roundsText}`;

    const message = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 512,
      messages: [{
        role: 'user',
        content: userPrompt
      }],
      system: systemPrompt
    });

    const responseText = message.content[0].text;

    let result;
    try {
      result = JSON.parse(responseText);
    } catch (e) {
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        result = JSON.parse(jsonMatch[0]);
      } else {
        // 如果解析失敗，使用預設結構
        result = {
          title: '知識片段',
          content: responseText.substring(0, 200),
          tags: ['思維盲點']
        };
      }
    }

    return {
      title: result.title || '知識片段',
      content: result.content || '這是一段有價值的思考。',
      tags: result.tags || []
    };

  } catch (error) {
    console.error('生成知識片段失敗:', error);
    return {
      title: '知識片段',
      content: '這是一段有價值的思考。',
      tags: []
    };
  }
}

/**
 * 生成主題總結（整合所有相關知識片段和對話總結）
 * @param {string} tag - 主題標籤
 * @param {Array} fragments - 知識片段陣列 [{ title, content, tags }]
 * @param {Array} mainQuestions - 主問題總結陣列 [{ questionText, summary, blindSpotTags }]
 * @param {Array} rounds - 對話回合陣列 [{ roundNumber, userAnswer, aiFeedback, aiFollowUp }]
 * @returns {string} - 主題總結（500-1000字，無長度限制）
 */
export async function generateTopicSummary(tag, fragments, mainQuestions, rounds = []) {
  try {
    // 格式化知識片段（最高質量）
    const fragmentsText = fragments.length > 0
      ? fragments.map((f, i) => `${i + 1}. 標題：${f.title}\n   內容：${f.content}\n   標籤：${f.tags.join('、')}`).join('\n\n')
      : '（無）';

    // 格式化對話總結（中等質量）
    const questionsText = mainQuestions.length > 0
      ? mainQuestions.map((q, i) => `${i + 1}. 問題：${q.questionText}\n   總結：${q.summary}\n   盲點：${q.blindSpotTags.join('、')}`).join('\n\n')
      : '（無）';

    // 格式化對話回合（待精煉）
    const roundsText = rounds.length > 0
      ? rounds.map((r, i) => `${i + 1}. 回合 ${r.roundNumber}\n   使用者回答：${r.userAnswer}\n   AI 回饋：${r.aiFeedback}${r.aiFollowUp ? `\n   AI 追問：${r.aiFollowUp}` : ''}`).join('\n\n')
      : '（無）';

    const totalCount = fragments.length + mainQuestions.length + rounds.length;
    const refinedCount = fragments.length + mainQuestions.length;

    // 判斷內容質量
    let qualityNote = '';
    if (refinedCount >= 5) {
      qualityNote = '內容質量：✨ 高品質精煉內容充足';
    } else if (refinedCount >= 2) {
      qualityNote = '內容質量：💡 部分精煉內容 + 原始對話';
    } else {
      qualityNote = '內容質量：📝 主要來自原始對話（建議使用「儲存」指令精煉知識）';
    }

    const systemPrompt = `你是一位知識整合專家。現在要為「${tag}」生成完整的知識地圖。

【任務目標】
整合以下所有內容，生成一個**系統化、可操作**的主題總結。

【來源內容】（共 ${totalCount} 個）
${qualityNote}

【知識片段】（${fragments.length} 個 - ✨ 最高質量，已精煉）
${fragmentsText}

【對話總結】（${mainQuestions.length} 個 - 💡 中等質量，含盲點洞察）
${questionsText}

【對話回合】（${rounds.length} 個 - 📝 原始對話，待提煉）
${roundsText}

【處理策略】
1. **優先整合知識片段和對話總結**（已精煉內容）
2. **從對話回合中提取方法論**：
   - 識別可複用的具體方法、步驟、框架
   - 忽略個人化的情境細節
   - 提煉出通用的思維模型
3. **去重整合**：相似的洞察要整合，避免重複
4. **標註來源質量**：在總結末尾說明內容來源

【輸出結構】（500-1000字，無長度限制，追求完整性）

## 核心理念（50-100字）
- 這個主題的本質是什麼？
- 最重要的底層邏輯
- 與其他概念的區別

## 方法論體系（300-500字）
整合所有具體方法，建立清晰框架：
### 子主題 1：[名稱]
- 具體方法/步驟
- 適用場景
- 注意事項

### 子主題 2：[名稱]
...

（如果方法很多，可以分更多子主題）

## 常見盲點（100-200字）
整合所有盲點分析：
- 哪些假設容易出錯
- 哪些陷阱容易踩
- 為什麼會有這些盲點
- 如何避免這些盲點

## 實戰建議（100-200字）
- 可操作的下一步
- 驗證方法
- 小實驗設計
- 參考資源或案例

---

## 📊 內容來源
- ✨ 精煉知識片段：${fragments.length} 個
- 💡 對話總結洞察：${mainQuestions.length} 個
- 📝 原始對話記錄：${rounds.length} 個

${rounds.length > 0 ? '\n💡 **建議**：使用「儲存」指令精煉關鍵對話，可獲得更精準的知識地圖。' : ''}

【寫作原則】
✅ 系統化 > 碎片化：建立知識體系，不是列表堆砌
✅ 框架化 > 理論化：提供可複用的思維模型
✅ 可演進：為未來新增內容預留空間
✅ 追求完整性：長度無限制，但要有清晰結構
✅ 去重整合：相似的洞察要整合，不要重複
✅ 實戰導向：每個方法都要說明「何時用」「如何用」
✅ 從對話回合中提取通用方法論（非個人化細節）
❌ 避免：流水帳、重複內容、過度抽象、理論堆砌

【重要】
- 如果來源內容很少（<3個），也要盡力整合並指出知識缺口
- 如果某個部分（如盲點）沒有足夠資料，可以簡短說明「暫無足夠盲點分析」
- 輸出完整的 Markdown 格式文字，不需要 JSON 包裝
- 直接輸出內容，不要加「以下是總結」之類的前綴
- 必須包含「📊 內容來源」部分`;

    const userPrompt = `請為「${tag}」生成完整的知識地圖總結。`;

    const response = await anthropic.messages.create({
      model: 'claude-sonnet-4-5-20250929',
      max_tokens: 4096,
      temperature: 0.7,
      system: systemPrompt,
      messages: [
        { role: 'user', content: userPrompt }
      ]
    });

    const summary = response.content[0].text.trim();
    return summary;

  } catch (error) {
    console.error('生成主題總結失敗:', error);
    return `# ${tag} 知識地圖\n\n暫時無法生成主題總結，請稍後再試。`;
  }
}

