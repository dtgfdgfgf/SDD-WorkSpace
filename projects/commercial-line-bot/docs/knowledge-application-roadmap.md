# 知識應用路線圖（Knowledge Application Roadmap）

> 版本：v1.0
> 更新日期：2025-11-12
> 狀態：Phase 1 已完成 ✅

---

## 📊 系統現況分析

### 當前架構優勢

您的知識庫已建立完整的**四層漸進式架構**：

```
Layer 0: 主題總結（Topic Summary）
         ↓ 系統化知識地圖（500-1000字）
Layer 1: 知識片段（Knowledge Fragments）
         ↓ 精煉方法論（100-200字）
Layer 2: 對話總結（Main Questions）
         ↓ 核心洞察 + 盲點標籤
Layer 3: 對話回合（Rounds）
         ↓ 完整 Q&A 記錄
```

**配合資產：**
- 28 個盲點標籤體系（5大類別）
- Claude Sonnet 4.5 AI 引擎
- Notion 知識庫整合
- LINE 即時互動介面

### 核心價值主張

從「被動資訊倉庫」→「主動知識助手」

---

## 🚀 八大應用方向

---

## 1. 情境化智能助手 ⭐⭐⭐⭐⭐

**狀態：✅ Phase 1 已完成**

### 核心理念

讓知識在「需要時」自動出現，而非「想起時」才查詢

### 使用場景

```
用戶：「我在考慮 SaaS 產品的定價策略」
↓
系統自動：
1. 識別關鍵詞：定價策略、SaaS
2. 檢索相關知識：
   - 主題總結：定價策略完整知識地圖
   - 知識片段：3個最相關的精煉洞察
   - 歷史盲點：您在定價上曾有的2個盲點
3. Claude 回答時引用這些知識：
   「根據你之前的洞察[知識片段#3]，定價不只是成本加成...
    另外，你曾在[2024-10-15對話]中忽略了市場定位的影響...」
```

### 技術實現

**已完成：**
- ✅ `lib/rag.js` - RAG 核心模組
  - `extractRelevantTags()` - 智能標籤提取
  - `retrieveRelevantKnowledge()` - 三層知識檢索
  - `formatKnowledgeForPrompt()` - Prompt 注入
  - `performRAG()` - 完整流程
- ✅ `lib/directChat.js` - 集成 RAG
- ✅ `scripts/test-rag.js` - 測試工具

**實現細節：**

```javascript
// 核心流程
async function chatWithClaudeWithKnowledge(userId, userMessage) {
  // 1. 提取標籤
  const extraction = await extractRelevantTags(userMessage);

  // 2. 檢索知識（三層）
  const knowledge = await retrieveRelevantKnowledge(extraction.tags);

  // 3. 格式化為 Prompt
  const enhancedPrompt = formatKnowledgeForPrompt(knowledge);

  // 4. 注入 Claude（知識已融入）
  const response = await callClaude(enhancedPrompt, userMessage);

  return response;
}
```

### 用戶價值

- ✅ 無需手動查詢，知識自動融入對話
- ✅ Claude 回答更個性化、更精準
- ✅ 持續強化學習循環
- ✅ 自動發現知識連結

### 效果指標

- **啟動率**：相關話題檢測準確度 >90%
- **引用率**：有知識可引用時，引用率 100%
- **滿意度**：對比普通回答，個性化回答更有價值

---

## 2. 主動提醒與複習系統 ⭐⭐⭐⭐

**狀態：🔮 Phase 2 規劃中**

### 核心理念

間隔重複，讓知識內化為習慣

### 使用場景

**每日推送示例：**

```
【今日複習】🧠
你有 3 個盲點連續 2 週未複習：

1. 定價策略（上次：10/15）
   💡 核心洞察：價值錨定 > 成本計算
   🔗 查看：「查詢 定價策略」

2. 客戶開發（上次：10/10）
   💡 你的盲點：假設客戶會主動理性評估
   🎯 建議：本周嘗試一次「問題優先」的客戶對話

【關聯提醒】🔗
你在學習「收入模型」，以下知識可能相關：
• 定價策略（7個知識片段）
• 商業模式（4個知識片段）
```

### 技術實現

#### 文件結構

```
lib/reminder.js          # 提醒引擎
lib/spaced-repetition.js # 間隔重複算法
api/cron/daily-reminder.js # 每日推送任務
```

#### 核心算法

**間隔重複（Spaced Repetition）：**

```javascript
// SM-2 演算法簡化版
function calculateNextReview(lastReview, repetitionCount, difficulty) {
  const intervals = {
    0: 1,      // 1 天
    1: 3,      // 3 天
    2: 7,      // 1 週
    3: 14,     // 2 週
    4: 30,     // 1 月
    5: 60      // 2 月
  };

  let interval = intervals[repetitionCount] || 90;

  // 根據難度調整（1=簡單, 3=困難）
  interval = interval * (2 - difficulty / 3);

  return new Date(lastReview.getTime() + interval * 24 * 60 * 60 * 1000);
}
```

#### 提醒觸發條件

1. **時間衰減**
   - 最近學習：1天後複習
   - 已複習1次：3天後
   - 已複習2次：7天後
   - 已複習3次：14天後

2. **盲點警示**
   - 相同盲點出現 ≥3 次 → 高優先級提醒
   - 連續2週未觸及的標籤 → 中優先級提醒

3. **關聯發現**
   - 當前學習標籤 A → 自動推薦關聯標籤 B
   - 基於共現矩陣計算相關性

#### 實現步驟

**Step 1: 基礎提醒引擎**

```javascript
// lib/reminder.js
export async function generateDailyReminders(userId) {
  // 1. 獲取用戶的所有知識標籤
  const tagStats = await getUserTagStatistics(userId);

  // 2. 計算需要複習的標籤
  const dueForReview = tagStats.filter(tag => {
    const daysSinceLastReview = calculateDays(tag.lastReviewDate);
    return daysSinceLastReview >= tag.nextReviewInterval;
  });

  // 3. 獲取相關知識片段
  const reminders = await Promise.all(
    dueForReview.map(tag => buildReminder(tag))
  );

  // 4. 發送 LINE 推送
  await pushMessage(userId, formatReminders(reminders));
}
```

**Step 2: Cron Job 配置**

```javascript
// api/cron/daily-reminder.js
export default async function handler(req, res) {
  // 每天早上 9:00 執行
  const activeUsers = await getActiveUsers();

  for (const user of activeUsers) {
    await generateDailyReminders(user.id);
  }

  res.status(200).json({ processed: activeUsers.length });
}
```

**Step 3: GitHub Actions 設定**

```yaml
# .github/workflows/daily-reminder.yml
name: Daily Knowledge Reminder

on:
  schedule:
    - cron: '0 1 * * *'  # 每天 UTC 1:00 (台北 9:00)
  workflow_dispatch:

jobs:
  send-reminders:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Vercel Cron
        run: |
          curl -X GET https://commercial-line-bot.vercel.app/api/cron/daily-reminder
```

### 用戶價值

- ⏰ 避免「學了就忘」
- 🔗 建立知識網絡連接
- 📈 漸進式內化
- 🎯 主動引導學習路徑

### 實施週期

**2-3 週**（中等複雜度）

---

## 3. 決策支援系統 ⭐⭐⭐⭐⭐

**狀態：🔮 Phase 2 規劃中**

### 核心理念

在決策點自動提供相關知識和歷史盲點

### 使用場景

```
新增命令：「決策 [場景描述]」

用戶：「決策 是否接受這個客戶的定制需求」
↓
系統分析：
1. 識別決策類型：客戶管理、需求管理、風險評估
2. 檢索相關知識：
   - 你的歷史盲點：假設驗證、資源分配
   - 相關知識片段：定制需求的3個陷阱
   - 類似決策：你在[10/20]的類似場景中的反思
3. 生成決策檢查清單：
   ✓ 這個需求是否符合你的核心價值主張？
   ✓ 定制成本是否會影響其他客戶？
   ✓ 有沒有替代方案（如配置化）？
   ⚠️  盲點提醒：你傾向於高估定制需求的價值
```

### 技術實現

#### 決策框架模板

```javascript
// lib/decision-framework.js
const DECISION_TYPES = {
  客戶管理: {
    checkpoints: [
      '是否符合目標客戶畫像？',
      '客戶終身價值（LTV）是否 > 獲取成本（CAC）？',
      '是否有風險信號（付款、溝通、期望）？'
    ],
    commonBlindSpots: ['假設驗證', '資源分配', '風險管理']
  },
  需求管理: {
    checkpoints: [
      '需求背後的真實問題是什麼？',
      '是否可以用現有功能解決？',
      '投入產出比如何？',
      '是否會產生技術債務？'
    ],
    commonBlindSpots: ['問題定義', '假設驗證', '成本控制']
  },
  定價決策: {
    checkpoints: [
      '基於價值還是成本？',
      '客戶支付意願驗證了嗎？',
      '競爭對手定價如何？',
      '是否有價格實驗計劃？'
    ],
    commonBlindSpots: ['市場分析', '假設驗證', '定價策略']
  }
  // ... 更多類型
};
```

#### 實現步驟

**Step 1: 決策類型識別**

```javascript
async function identifyDecisionType(description) {
  const prompt = `分析以下決策場景，識別決策類型：
  ${description}

  可選類型：客戶管理、需求管理、定價決策、資源分配、團隊協作

  回傳 JSON: { "type": "決策類型", "confidence": "high|medium|low" }`;

  const result = await callClaude(prompt);
  return result;
}
```

**Step 2: 知識檢索與盲點分析**

```javascript
async function analyzeDecision(description, userId) {
  // 1. 識別決策類型
  const decisionType = await identifyDecisionType(description);

  // 2. 檢索相關標籤的知識
  const relevantTags = DECISION_TYPES[decisionType.type].commonBlindSpots;
  const knowledge = await retrieveRelevantKnowledge(relevantTags);

  // 3. 獲取用戶的歷史盲點
  const userBlindSpots = await getUserBlindSpotHistory(userId, relevantTags);

  // 4. 生成決策框架
  const framework = await generateDecisionFramework(
    decisionType,
    knowledge,
    userBlindSpots
  );

  return framework;
}
```

**Step 3: 決策檢查清單生成**

```javascript
async function generateDecisionFramework(decisionType, knowledge, blindSpots) {
  const prompt = `生成決策檢查清單：

  決策類型：${decisionType.type}
  相關知識：${knowledge}
  歷史盲點：${blindSpots}

  格式：
  ## 關鍵問題（5-7個）
  ✓ 問題1...
  ✓ 問題2...

  ## ⚠️ 盲點提醒（基於歷史）
  - 你曾在...上有盲點
  - 建議重點關注...

  ## 💡 參考知識
  - [知識片段標題]
  - [相關對話]`;

  return await callClaude(prompt);
}
```

**Step 4: Webhook 處理**

```javascript
// api/webhook.js
async function handleDecisionSupport(userId, description) {
  const framework = await analyzeDecision(description, userId);

  let reply = '🎯 決策分析框架\n\n';
  reply += framework.checklist + '\n\n';
  reply += '---\n';
  reply += `💡 此分析基於你的 ${framework.knowledgeCount} 條歷史知識\n`;
  reply += `🏷️ 相關標籤：${framework.tags.join('、')}`;

  return reply;
}
```

### 用戶價值

- 🎯 減少決策盲點
- 📚 提供歷史經驗參考
- ⏸️ 強制停下來思考
- 📊 結構化決策流程

### 實施週期

**3-4 週**（較高複雜度）

---

## 4. 知識圖譜可視化 ⭐⭐⭐

**狀態：🔮 Phase 3 規劃中（中長期）**

### 核心理念

看見知識之間的連接，發現思維模式

### 使用場景

**新增網頁：`/knowledge-graph`**

```
顯示內容：
- 28個標籤的網絡圖
- 標籤大小 = 使用頻率
- 連線粗細 = 共現次數
- 顏色 = 5大類別（技術/商業/成長/協作/思維）

交互功能：
- 點擊標籤 → 顯示相關知識片段
- 高亮路徑 → 顯示學習軌跡
- 時間軸 → 看知識演變
```

### 技術實現

#### 技術棧

- **前端框架**：Next.js + React
- **圖表庫**：D3.js 或 Cytoscape.js
- **數據源**：Notion API
- **部署**：Vercel 靜態頁面

#### 數據結構

```javascript
// 節點數據
const nodes = [
  {
    id: '定價策略',
    label: '定價策略',
    category: '商業',
    frequency: 15,      // 使用次數
    lastUsed: '2024-11-10',
    knowledgeCount: 8   // 知識片段數
  },
  // ... 其他 27 個標籤
];

// 邊數據（標籤共現）
const edges = [
  {
    source: '定價策略',
    target: '商業模式',
    weight: 12,         // 共現次數
    context: [          // 共現情境
      '對話#15: 定價與商業模式的關係',
      '知識片段#23: 訂閱制定價策略'
    ]
  },
  // ... 其他連接
];
```

#### 共現矩陣計算

```javascript
// lib/knowledge-graph.js
async function calculateCooccurrence() {
  // 1. 獲取所有知識片段和對話
  const fragments = await getAllKnowledgeFragments();
  const rounds = await getAllRounds();

  // 2. 建立共現矩陣
  const matrix = {};

  fragments.forEach(fragment => {
    const tags = fragment.tags;
    for (let i = 0; i < tags.length; i++) {
      for (let j = i + 1; j < tags.length; j++) {
        const key = `${tags[i]}-${tags[j]}`;
        matrix[key] = (matrix[key] || 0) + 1;
      }
    }
  });

  return matrix;
}
```

#### 可視化實現

```javascript
// components/KnowledgeGraph.jsx
import * as d3 from 'd3';

export default function KnowledgeGraph({ nodes, edges }) {
  useEffect(() => {
    // 1. 建立 SVG
    const svg = d3.select('#graph')
      .attr('width', 1200)
      .attr('height', 800);

    // 2. 力導向圖模擬
    const simulation = d3.forceSimulation(nodes)
      .force('link', d3.forceLink(edges).distance(100))
      .force('charge', d3.forceManyBody().strength(-300))
      .force('center', d3.forceCenter(600, 400));

    // 3. 繪製節點
    const node = svg.selectAll('circle')
      .data(nodes)
      .enter().append('circle')
      .attr('r', d => Math.sqrt(d.frequency) * 5)
      .attr('fill', d => categoryColors[d.category]);

    // 4. 繪製連線
    const link = svg.selectAll('line')
      .data(edges)
      .enter().append('line')
      .attr('stroke-width', d => d.weight / 2);

    // 5. 更新位置
    simulation.on('tick', () => {
      link.attr('x1', d => d.source.x)
          .attr('y1', d => d.source.y)
          .attr('x2', d => d.target.x)
          .attr('y2', d => d.target.y);

      node.attr('cx', d => d.x)
          .attr('cy', d => d.y);
    });
  }, [nodes, edges]);

  return <svg id="graph"></svg>;
}
```

### 用戶價值

- 🗺️ 發現知識空白區
- 🔍 識別思維模式
- 📊 規劃學習路徑
- 🎨 視覺化知識網絡

### 實施週期

**4-6 週**（較高複雜度 + 設計需求）

---

## 5. 智能週報升級 ⭐⭐⭐⭐

**狀態：🔮 Phase 2 規劃中**

### 當前週報 vs 升級方向

**當前：** 統計性報告（對話次數、標籤頻率）
**升級：** 洞察性分析 + 行動建議

### 使用場景

```
【本週成長報告】📈

🎯 核心突破：
本週你在「定價策略」上有重要突破：
• 從成本導向 → 價值導向
• 新增 3 個知識片段，質量評分 8.5/10
• 關鍵轉折：[10/18對話] 發現價格錨定的心理學原理

⚠️  思維盲點警示：
「假設驗證」盲點出現 4 次（↑ 上週 2 次）
→ 建議：下週每個決策前問「這個假設如何驗證？」

🔗 知識連接發現：
你正在建立「商業模式 + 定價策略 + 客戶開發」的知識三角
→ 缺口：如何評估定價對客戶獲取成本的影響

📊 本週數據：
• 對話：5 次（↑ 20%）
• 知識片段：3 個
• 覆蓋標籤：8 個（商業類為主）

📋 下週行動計畫（AI 建議）：
1. 複習：定價策略主題總結
2. 實驗：用價值主張測試 1 個客戶對話
3. 反思：記錄假設驗證的過程
4. 填補：學習「客戶獲取成本」相關知識
```

### 技術實現

#### 升級功能模塊

```javascript
// lib/analytics-advanced.js

// 1. 趨勢分析
async function analyzeTrends(userId, currentWeek, lastWeek) {
  return {
    conversationChange: (currentWeek.count - lastWeek.count) / lastWeek.count,
    topGrowthTag: findFastestGrowingTag(currentWeek, lastWeek),
    blindSpotTrend: analyzeBlindSpotTrend(currentWeek, lastWeek)
  };
}

// 2. 知識連接發現
async function discoverKnowledgeConnections(userId) {
  // 計算標籤共現矩陣
  const cooccurrence = await calculateCooccurrenceMatrix(userId);

  // 識別知識三角/四邊形
  const triangles = findKnowledgeTriangles(cooccurrence);

  // 發現缺口
  const gaps = identifyKnowledgeGaps(triangles);

  return { triangles, gaps };
}

// 3. 質量評分
function scoreKnowledgeQuality(fragment) {
  let score = 0;

  // 長度評分（100-200字為最佳）
  const length = fragment.content.length;
  score += length >= 100 && length <= 200 ? 3 : 1;

  // 標籤數量評分（2-3個為最佳）
  score += fragment.tags.length >= 2 && fragment.tags.length <= 3 ? 3 : 1;

  // 結構評分（是否有明確的方法論）
  if (containsActionableInsights(fragment.content)) score += 4;

  return Math.min(score, 10);
}

// 4. AI 洞察生成
async function generateWeeklyInsights(weekData, userId) {
  const prompt = `分析用戶本週的學習數據，生成洞察和建議：

  【數據】
  - 對話次數：${weekData.conversations}
  - 新增知識：${weekData.fragments.length} 個
  - 標籤分佈：${weekData.tagDistribution}
  - 盲點頻率：${weekData.blindSpots}
  - 知識連接：${weekData.connections}

  【上週對比】
  - 對話變化：${weekData.trends.conversationChange}
  - 成長最快標籤：${weekData.trends.topGrowthTag}
  - 盲點趨勢：${weekData.trends.blindSpotTrend}

  請生成：
  1. 核心突破分析（50字）
  2. 盲點警示（30字）
  3. 知識連接發現（50字）
  4. 下週行動計畫（4條具體建議）

  回傳 JSON 格式。`;

  return await callClaude(prompt);
}
```

#### 實現步驟

**Step 1: 數據聚合**

```javascript
async function aggregateWeeklyData(userId, startDate, endDate) {
  // 並行查詢
  const [
    conversations,
    fragments,
    tagStats,
    blindSpots,
    lastWeekData
  ] = await Promise.all([
    getMainQuestionsByDateRange(startDate, endDate),
    getKnowledgeFragmentsByDateRange(startDate, endDate),
    getTagStatistics(userId),
    getBlindSpotFrequency(userId, startDate, endDate),
    getLastWeekData(userId)
  ]);

  return {
    conversations,
    fragments,
    tagStats,
    blindSpots,
    lastWeekData
  };
}
```

**Step 2: 分析處理**

```javascript
async function processWeeklyAnalysis(weekData, userId) {
  // 1. 趨勢分析
  const trends = await analyzeTrends(userId, weekData, weekData.lastWeekData);

  // 2. 知識連接
  const connections = await discoverKnowledgeConnections(userId);

  // 3. 質量評分
  const qualityScores = weekData.fragments.map(f => ({
    fragment: f,
    score: scoreKnowledgeQuality(f)
  }));

  // 4. AI 洞察
  const insights = await generateWeeklyInsights({
    ...weekData,
    trends,
    connections,
    qualityScores
  }, userId);

  return { trends, connections, qualityScores, insights };
}
```

**Step 3: 報告生成**

```javascript
async function generateUpgradedWeeklyReport(userId) {
  // 1. 聚合數據
  const weekData = await aggregateWeeklyData(userId, ...);

  // 2. 分析處理
  const analysis = await processWeeklyAnalysis(weekData, userId);

  // 3. 格式化報告
  let report = `【本週成長報告】📈\n\n`;

  // 核心突破
  report += `🎯 核心突破：\n${analysis.insights.breakthrough}\n\n`;

  // 盲點警示
  if (analysis.insights.blindSpotAlert) {
    report += `⚠️  思維盲點警示：\n${analysis.insights.blindSpotAlert}\n\n`;
  }

  // 知識連接
  if (analysis.connections.triangles.length > 0) {
    report += `🔗 知識連接發現：\n${formatConnections(analysis.connections)}\n\n`;
  }

  // 數據統計
  report += `📊 本週數據：\n`;
  report += `• 對話：${weekData.conversations.length} 次\n`;
  report += `• 知識片段：${weekData.fragments.length} 個\n\n`;

  // 行動計畫
  report += `📋 下週行動計畫（AI 建議）：\n`;
  analysis.insights.actionPlan.forEach((action, i) => {
    report += `${i + 1}. ${action}\n`;
  });

  return report;
}
```

### 用戶價值

- 📈 從統計 → 洞察
- 🔮 從回顧 → 前瞻
- ✅ 可操作的改進建議
- 🎯 個性化成長路徑

### 實施週期

**2-3 週**（中等複雜度）

---

## 6. 標籤推薦系統 ⭐⭐⭐

**狀態：🔮 Phase 2 規劃中**

### 核心理念

幫助用戶更準確地標記知識

### 使用場景

```
在「儲存」知識片段時：

當前：AI 自動生成 2-3 個標籤
升級：AI 建議 + 用戶確認 + 智能補充

系統：「已生成知識片段《定價錨定的心理學》

      AI建議標籤：
      ✓ 定價策略
      ✓ 客戶心理
      ✓ 價值主張

      💡 相關標籤推薦：
      • 市場分析（你在3個片段中提到市場定位）
      • 假設驗證（內容中包含實驗方法）

      回覆「確認」接受建議，或輸入標籤編號調整」

用戶：「確認」或「1,2,4」（選擇標籤1、2、4）
```

### 技術實現

#### 標籤推薦引擎

```javascript
// lib/tag-recommender.js

async function recommendTags(fragment) {
  // 1. AI 基礎標籤（已有）
  const aiTags = fragment.tags;

  // 2. 內容分析推薦
  const contentTags = await analyzeContentForTags(fragment.content);

  // 3. 用戶習慣推薦
  const userPatternTags = await analyzeUserTaggingPattern(fragment.userId);

  // 4. 共現推薦
  const cooccurrenceTags = await findCooccurringTags(aiTags);

  // 5. 合併去重
  const allRecommendations = [
    ...aiTags.map(t => ({ tag: t, source: 'AI', confidence: 1.0 })),
    ...contentTags.map(t => ({ tag: t, source: 'content', confidence: 0.8 })),
    ...userPatternTags.map(t => ({ tag: t, source: 'pattern', confidence: 0.7 })),
    ...cooccurrenceTags.map(t => ({ tag: t, source: 'cooccurrence', confidence: 0.6 }))
  ];

  // 6. 排序和過濾
  return deduplicateAndRank(allRecommendations);
}

// 內容分析（關鍵詞提取）
async function analyzeContentForTags(content) {
  const keywords = extractKeywords(content);
  const matchedTags = [];

  // 關鍵詞與標籤的映射
  const keywordToTagMap = {
    '定價': ['定價策略'],
    '客戶': ['客戶開發', '市場分析'],
    '實驗': ['假設驗證'],
    '成本': ['成本控制', '定價策略'],
    // ... 更多映射
  };

  keywords.forEach(keyword => {
    if (keywordToTagMap[keyword]) {
      matchedTags.push(...keywordToTagMap[keyword]);
    }
  });

  return [...new Set(matchedTags)];
}

// 用戶標籤習慣分析
async function analyzeUserTaggingPattern(userId) {
  // 獲取用戶的歷史標籤使用
  const history = await getUserTagHistory(userId);

  // 找出高頻但本次未使用的標籤
  const frequentTags = history
    .sort((a, b) => b.count - a.count)
    .slice(0, 5)
    .map(t => t.tag);

  return frequentTags;
}

// 共現標籤推薦
async function findCooccurringTags(selectedTags) {
  // 查詢與選定標籤經常一起出現的標籤
  const cooccurrence = await getCooccurrenceMatrix();

  const recommendations = [];
  selectedTags.forEach(tag => {
    const related = cooccurrence[tag] || [];
    recommendations.push(...related.slice(0, 3));
  });

  return [...new Set(recommendations)];
}
```

#### 互動流程

```javascript
// api/webhook.js
async function handleSaveKnowledge(userId) {
  const session = await getSession(userId);

  // 1. 生成知識片段
  const fragment = await generateKnowledgeFragment(unsavedRounds);

  // 2. 獲取標籤推薦
  const recommendations = await recommendTags(fragment);

  // 3. 儲存到臨時狀態
  await saveTempFragment(userId, fragment, recommendations);

  // 4. 詢問用戶確認
  let reply = `✅ 已生成知識片段\n\n`;
  reply += `📝 ${fragment.title}\n\n`;
  reply += `AI建議標籤：\n`;
  recommendations.ai.forEach((tag, i) => {
    reply += `${i + 1}. ✓ ${tag}\n`;
  });
  reply += `\n`;

  if (recommendations.suggested.length > 0) {
    reply += `💡 相關標籤推薦：\n`;
    recommendations.suggested.forEach((rec, i) => {
      reply += `${recommendations.ai.length + i + 1}. ${rec.tag}（${rec.reason}）\n`;
    });
    reply += `\n`;
  }

  reply += `回覆「確認」接受建議，或輸入標籤編號（如「1,2,4」）調整`;

  return reply;
}

async function handleTagConfirmation(userId, input) {
  const tempFragment = await getTempFragment(userId);

  let finalTags;
  if (input === '確認' || input === '确认') {
    finalTags = tempFragment.allTags;
  } else {
    // 解析用戶選擇的標籤編號
    const indices = input.split(',').map(s => parseInt(s.trim()) - 1);
    finalTags = indices.map(i => tempFragment.allTags[i]).filter(Boolean);
  }

  // 儲存到 Notion
  await createKnowledgeFragment(
    tempFragment.title,
    tempFragment.content,
    finalTags,
    tempFragment.mainQuestionId,
    tempFragment.roundRange
  );

  // 清除臨時狀態
  await clearTempFragment(userId);

  return `✅ 知識片段已儲存\n🏷️ 標籤：${finalTags.join('、')}`;
}
```

### 用戶價值

- 🎯 提升標籤準確性
- 🔗 建立更好的知識連接
- 💡 發現隱含主題
- 📊 改善知識檢索效果

### 實施週期

**2-3 週**（中等複雜度）

---

## 7. 知識導出與分享 ⭐⭐⭐⭐

**狀態：🔮 Phase 3 規劃中**

### 核心理念

讓知識可以在其他場景使用

### 使用場景

```
新增命令：「導出 [標籤/類別]」

用戶：「導出 商業類」
↓
系統生成：
1. Markdown 文件（結構化）
2. PDF（帶目錄、可打印）✨
3. Notion 頁面鏈接

內容結構：
# 商業類知識地圖

## 一、核心框架
[主題總結內容]

## 二、精煉洞察（9個知識片段）
### 1. 定價策略
[知識片段內容]

## 三、歷史反思（12次對話）
[對話總結]

## 四、關鍵盲點
[盲點分析]

## 五、學習軌跡
[時間軸圖表]
```

### 技術實現

#### 導出引擎

```javascript
// lib/export.js

async function exportKnowledge(userId, target) {
  // 1. 確定導出範圍
  const scope = parseExportTarget(target); // '商業類' or '定價策略'

  // 2. 收集所有相關內容
  const data = await collectExportData(userId, scope);

  // 3. 生成 Markdown
  const markdown = await generateMarkdown(data);

  // 4. 可選：生成 PDF
  const pdf = await generatePDF(markdown);

  // 5. 可選：創建 Notion 頁面
  const notionPage = await createNotionExportPage(data);

  return { markdown, pdf, notionPage };
}

// 數據收集
async function collectExportData(userId, scope) {
  let tags;
  if (scope.type === 'category') {
    tags = TAG_CATEGORIES[scope.name];
  } else {
    tags = [scope.name];
  }

  // 並行查詢所有相關數據
  const [
    topicSummaries,
    fragments,
    mainQuestions,
    rounds,
    timeline
  ] = await Promise.all([
    Promise.all(tags.map(tag => getTopicSummaryByTag(tag))),
    getAllKnowledgeFragmentsByTags(tags),
    getAllMainQuestionsByTags(tags),
    getAllRoundsByTags(tags),
    getTimelineByTags(userId, tags)
  ]);

  return {
    scope,
    tags,
    topicSummaries: topicSummaries.filter(Boolean),
    fragments,
    mainQuestions,
    rounds,
    timeline
  };
}

// Markdown 生成
function generateMarkdown(data) {
  let md = '';

  // 標題
  md += `# ${data.scope.displayName} 知識地圖\n\n`;
  md += `> 導出時間：${new Date().toLocaleString('zh-TW')}\n`;
  md += `> 涵蓋標籤：${data.tags.join('、')}\n\n`;
  md += `---\n\n`;

  // 目錄
  md += `## 目錄\n\n`;
  md += `1. [核心框架](#核心框架)\n`;
  md += `2. [精煉洞察](#精煉洞察)\n`;
  md += `3. [歷史反思](#歷史反思)\n`;
  md += `4. [關鍵盲點](#關鍵盲點)\n`;
  md += `5. [學習軌跡](#學習軌跡)\n\n`;
  md += `---\n\n`;

  // 1. 核心框架（主題總結）
  md += `## 一、核心框架\n\n`;
  if (data.topicSummaries.length > 0) {
    data.topicSummaries.forEach(summary => {
      md += `### ${summary.tag}\n\n`;
      md += `${summary.summary}\n\n`;
      md += `> 📊 整合來源：${summary.sourceCount} 個\n`;
      md += `> 📅 最後更新：${summary.lastUpdated}\n\n`;
    });
  } else {
    md += `*此部分暫無內容*\n\n`;
  }

  // 2. 精煉洞察（知識片段）
  md += `## 二、精煉洞察（${data.fragments.length}個）\n\n`;
  data.fragments.forEach((fragment, i) => {
    md += `### ${i + 1}. ${fragment.title}\n\n`;
    md += `${fragment.content}\n\n`;
    md += `**標籤：** ${fragment.tags.join('、')}\n`;
    if (fragment.roundRange) {
      md += `**來源：** ${fragment.roundRange}\n`;
    }
    md += `**建立時間：** ${new Date(fragment.createdTime).toLocaleDateString('zh-TW')}\n\n`;
  });

  // 3. 歷史反思（對話總結）
  md += `## 三、歷史反思（${data.mainQuestions.length}個）\n\n`;
  data.mainQuestions.forEach((q, i) => {
    md += `### ${i + 1}. ${q.questionText}\n\n`;
    md += `${q.summary}\n\n`;
    md += `**盲點標籤：** ${q.blindSpotTags.join('、')}\n`;
    md += `**日期：** ${q.date}\n\n`;
  });

  // 4. 關鍵盲點
  md += `## 四、關鍵盲點\n\n`;
  const blindSpots = extractBlindSpots(data);
  Object.entries(blindSpots).forEach(([tag, count]) => {
    md += `- **${tag}**：出現 ${count} 次\n`;
  });
  md += `\n`;

  // 5. 學習軌跡
  md += `## 五、學習軌跡\n\n`;
  md += `\`\`\`mermaid\n`;
  md += generateTimelineDiagram(data.timeline);
  md += `\`\`\`\n\n`;

  return md;
}

// PDF 生成（可選）
async function generatePDF(markdown) {
  // 使用 Pandoc 或其他工具將 Markdown 轉為 PDF
  // 也可以直接在瀏覽器中使用 jsPDF
  // 這裡提供簡化版本

  const html = markdownToHTML(markdown);
  const pdf = await htmlToPDF(html);

  return pdf;
}

// Notion 頁面創建
async function createNotionExportPage(data) {
  const page = await notion.pages.create({
    parent: { database_id: EXPORT_DB_ID },
    properties: {
      '標題': {
        title: [{ text: { content: `${data.scope.displayName} 知識地圖` } }]
      },
      '導出日期': {
        date: { start: new Date().toISOString().split('T')[0] }
      }
    },
    children: [
      // 添加頁面內容塊
      ...formatDataAsNotionBlocks(data)
    ]
  });

  return page.url;
}
```

#### Webhook 處理

```javascript
// api/webhook.js
async function handleExport(userId, target) {
  try {
    // 發送「處理中」提示
    await sendMessage(userId, `🔄 正在導出「${target}」的知識地圖，請稍候...`);

    // 執行導出
    const result = await exportKnowledge(userId, target);

    // 上傳文件到臨時存儲
    const fileUrl = await uploadToStorage(result.markdown);

    // 發送結果
    let reply = `✅ 導出完成！\n\n`;
    reply += `📊 統計：\n`;
    reply += `• 主題總結：${result.data.topicSummaries.length} 個\n`;
    reply += `• 知識片段：${result.data.fragments.length} 個\n`;
    reply += `• 對話記錄：${result.data.mainQuestions.length} 個\n\n`;
    reply += `📥 下載連結（24小時內有效）：\n`;
    reply += `${fileUrl}\n\n`;

    if (result.notionPage) {
      reply += `🔗 Notion 頁面：\n${result.notionPage}`;
    }

    return reply;
  } catch (error) {
    console.error('導出失敗:', error);
    return '❌ 導出失敗，請稍後再試。';
  }
}
```

### 用戶價值

- 📄 知識複用（寫文章、做分享）
- 💾 備份與歸檔
- 🤝 團隊知識共享
- 📊 視覺化呈現

### 實施週期

**3-4 週**（中等複雜度 + 文件處理）

---

## 8. AI Agent 集成 ⭐⭐⭐⭐⭐

**狀態：🔮 Phase 4 規劃中（未來方向）**

### 核心理念

知識不只是查詢，而是主動執行

### 使用場景

```
用戶：「幫我分析這個商業計劃」
[上傳文檔或粘貼內容]
↓
AI Agent 執行：

1. 文檔分析
   - 識別：商業模式、定價、市場、團隊...

2. 知識檢索（自動）
   - 檢索你的「商業模式」知識
   - 檢索你的「定價策略」知識
   - 檢索你的歷史盲點

3. 對比分析
   - 計劃 vs 你的知識框架
   - 發現差距和風險

4. 生成報告
   ✓ 優勢：與你的「客戶開發」知識一致
   ⚠️  風險：你曾在「市場分析」上有盲點
   💡 建議：參考知識片段《市場驗證三步法》

   【詳細分析】
   - 商業模式：...
   - 定價策略：...
   - 市場分析：...

   【盲點檢查】
   - ⚠️ 假設驗證不足...
   - ⚠️ 競爭分析缺失...
```

### 技術實現

#### Agent 架構

```javascript
// lib/agent.js
import { AnthropicBedrock } from '@anthropic-ai/bedrock-sdk';

class KnowledgeAgent {
  constructor(userId) {
    this.userId = userId;
    this.tools = [
      {
        name: 'search_knowledge',
        description: '搜索用戶的知識庫',
        input_schema: {
          type: 'object',
          properties: {
            tags: {
              type: 'array',
              items: { type: 'string' },
              description: '要搜索的標籤'
            }
          },
          required: ['tags']
        }
      },
      {
        name: 'get_blind_spots',
        description: '獲取用戶的歷史盲點',
        input_schema: {
          type: 'object',
          properties: {
            topic: {
              type: 'string',
              description: '主題名稱'
            }
          },
          required: ['topic']
        }
      }
    ];
  }

  async run(task) {
    let conversation = [];
    let toolResults = [];

    // 初始任務
    conversation.push({
      role: 'user',
      content: task
    });

    while (true) {
      // 調用 Claude
      const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-5-20250929',
        max_tokens: 4096,
        tools: this.tools,
        messages: conversation
      });

      // 檢查是否需要使用工具
      if (response.stop_reason === 'tool_use') {
        const toolUse = response.content.find(block => block.type === 'tool_use');

        // 執行工具
        const result = await this.executeTool(toolUse);
        toolResults.push(result);

        // 添加工具結果到對話
        conversation.push({
          role: 'assistant',
          content: response.content
        });
        conversation.push({
          role: 'user',
          content: [{
            type: 'tool_result',
            tool_use_id: toolUse.id,
            content: JSON.stringify(result)
          }]
        });
      } else {
        // 完成
        return {
          response: response.content[0].text,
          toolsUsed: toolResults
        };
      }
    }
  }

  async executeTool(toolUse) {
    switch (toolUse.name) {
      case 'search_knowledge':
        return await retrieveRelevantKnowledge(toolUse.input.tags);

      case 'get_blind_spots':
        return await getUserBlindSpots(this.userId, toolUse.input.topic);

      default:
        throw new Error(`Unknown tool: ${toolUse.name}`);
    }
  }
}
```

#### 使用示例

```javascript
// api/webhook.js
async function handleAgentTask(userId, task, attachment) {
  // 創建 Agent
  const agent = new KnowledgeAgent(userId);

  // 構建完整任務
  let fullTask = task;
  if (attachment) {
    fullTask += `\n\n【附件內容】\n${attachment}`;
  }

  // 執行
  const result = await agent.run(fullTask);

  // 格式化回覆
  let reply = result.response;

  if (result.toolsUsed.length > 0) {
    reply += `\n\n---\n`;
    reply += `🔧 使用了 ${result.toolsUsed.length} 個工具：\n`;
    result.toolsUsed.forEach(tool => {
      reply += `• ${tool.name}\n`;
    });
  }

  return reply;
}
```

### 用戶價值

- 🤖 知識主動應用
- 🎯 深度個性化分析
- 💪 持續強化專業能力
- 🚀 從助手 → 自主代理

### 實施週期

**6-8 週**（高複雜度 + AI Agent 技術）

---

## 📅 實施路線圖

### Phase 1: 快速增強（1-2週）✅ 已完成

- [x] **情境化智能助手**（#1）- 最高價值 ✅
- [ ] **智能週報升級**（#5）- 快速見效

**當前進度：**
- ✅ RAG 模組完成
- ✅ 已部署到生產環境
- 🔄 等待知識庫累積測試效果

---

### Phase 2: 深化應用（2-4週）

**優先順序：**

1. **主動提醒系統**（#2）- 2週
   - 目標：提升用戶留存和知識內化
   - 關鍵：間隔重複演算法 + 每日推送

2. **決策支援系統**（#3）- 3週
   - 目標：高實用性，解決實際問題
   - 關鍵：決策框架 + 盲點提醒

3. **智能週報升級**（#5）- 2週
   - 目標：從數據 → 洞察
   - 關鍵：AI 生成建議 + 趨勢分析

**預計完成：Phase 1 + 1 個月**

---

### Phase 3: 生態擴展（1-2月）

1. **知識導出功能**（#7）- 3週
   - 目標：知識複用和分享
   - 關鍵：Markdown + PDF 生成

2. **標籤推薦系統**（#6）- 2週
   - 目標：提升知識質量
   - 關鍵：智能推薦 + 用戶確認

3. **知識圖譜可視化**（#4）- 4週
   - 目標：視覺化知識連接
   - 關鍵：D3.js + 互動設計

**預計完成：Phase 2 + 2 個月**

---

### Phase 4: 戰略升級（長期）

1. **AI Agent 集成**（#8）- 6週
   - 目標：自主知識應用
   - 關鍵：Function Calling + Multi-turn

**預計完成：Phase 3 + 3 個月**

---

## 📊 優先級矩陣

```
高價值 ↑
      │
  #1  │  #3    #2
  ✅  │  🎯    ⏰
──────┼──────────────→ 高複雜度
  #5  │  #8    #4
  📊  │  🤖    🗺️
      │
  #6  │  #7
  🏷️ │  📄
```

**圖例：**
- ✅ #1 情境化智能助手（已完成）
- 🎯 #3 決策支援（高價值 + 中複雜度）
- ⏰ #2 主動提醒（高價值 + 中複雜度）
- 📊 #5 智能週報（中價值 + 低複雜度）
- 🤖 #8 AI Agent（高價值 + 高複雜度）
- 🗺️ #4 知識圖譜（中價值 + 高複雜度）
- 🏷️ #6 標籤推薦（中價值 + 低複雜度）
- 📄 #7 知識導出（中價值 + 中複雜度）

---

## 🎯 成功指標

### Phase 1 指標（情境化助手）

- **技術指標**
  - ✅ RAG 啟動率 >50%（相關話題檢測）
  - ✅ 知識檢索成功率 >90%
  - ✅ 回應時間 <5秒

- **用戶指標**
  - 📊 自由對話使用率提升 30%
  - 📊 對話滿意度提升 20%
  - 📊 知識複用率（被引用次數）

### Phase 2 指標

- **主動提醒**
  - 推送開啟率 >60%
  - 提醒後複習率 >40%

- **決策支援**
  - 使用頻率 ≥2次/週
  - 決策質量主觀評分 ≥8/10

- **智能週報**
  - 閱讀完成率 >80%
  - 行動計畫執行率 >50%

### Phase 3-4 指標

- **知識導出**
  - 導出使用率 ≥1次/月
  - 知識分享次數

- **AI Agent**
  - 任務完成率 >85%
  - 自主工具調用準確率 >90%

---

## 💡 關鍵成功因素

### 1. 知識質量

- **現狀：** 知識庫剛建立，內容有限
- **關鍵：** 持續積累高質量知識片段
- **建議：**
  - 每週至少 2-3 次結構化對話
  - 使用「儲存」提取精煉洞察
  - 定期「總結」生成主題地圖

### 2. 用戶習慣

- **現狀：** 需要適應新功能
- **關鍵：** 降低使用門檻，自然融入
- **建議：**
  - RAG 自動啟動（無需命令）✅
  - 提醒系統溫和不打擾
  - 週報自動生成並推送

### 3. 技術穩定性

- **現狀：** Vercel 免費方案限制
- **關鍵：** 優化性能，控制成本
- **建議：**
  - 實施請求限流
  - 監控 Claude API 使用量
  - 考慮升級 Vercel 方案

### 4. 迭代反饋

- **現狀：** 單用戶系統
- **關鍵：** 快速驗證，靈活調整
- **建議：**
  - 每個 Phase 後評估效果
  - 基於實際使用調整優先級
  - 保持敏捷開發節奏

---

## 🔧 技術準備

### 當前技術棧

- **前端/介面：** LINE Messaging API
- **後端：** Vercel Serverless Functions
- **AI：** Claude Sonnet 4.5 (Anthropic)
- **資料庫：** Notion (作為 CMS)
- **部署：** Vercel + GitHub Actions

### 新增需求（按 Phase）

**Phase 2:**
- Cron Job 調度（每日提醒）✅ 已有
- 演算法：間隔重複 (Spaced Repetition)

**Phase 3:**
- 文件生成：Pandoc 或 jsPDF
- 前端框架：Next.js (知識圖譜)
- 圖表庫：D3.js 或 Cytoscape.js

**Phase 4:**
- AI Agent：Claude Function Calling
- 文件上傳：LINE Rich Menu + File API

---

## 📝 後續行動

### 立即可做（本週）

1. **測試 RAG 功能**
   - 在 LINE 中進行自由對話
   - 觀察知識是否被引用
   - 檢查 Vercel 日誌

2. **累積知識庫**
   - 完成 2-3 次結構化對話
   - 使用「儲存」提取知識片段
   - 為重要標籤生成主題總結

### 下週準備（Phase 2 啟動）

1. **評估 RAG 效果**
   - 收集使用數據
   - 用戶主觀反饋

2. **選擇 Phase 2 功能**
   - 根據評估結果
   - 決定優先實施 #2 或 #3 或 #5

3. **技術準備**
   - 研究間隔重複演算法
   - 設計決策框架模板

---

## 📚 參考資源

### 相關技術文檔

- **RAG (Retrieval Augmented Generation)**
  - [Anthropic RAG Guide](https://docs.anthropic.com/claude/docs/retrieval-augmented-generation)
  - [LangChain RAG Tutorial](https://python.langchain.com/docs/use_cases/question_answering/)

- **間隔重複演算法**
  - [SM-2 Algorithm](https://en.wikipedia.org/wiki/SuperMemo#SM-2_algorithm)
  - [Anki Source Code](https://github.com/ankitects/anki)

- **Knowledge Graph**
  - [D3.js Force Layout](https://d3js.org/d3-force)
  - [Cytoscape.js](https://js.cytoscape.org/)

- **AI Agents**
  - [Claude Function Calling](https://docs.anthropic.com/claude/docs/tool-use)
  - [LangChain Agents](https://python.langchain.com/docs/modules/agents/)

### 靈感來源

- **Obsidian** - 知識圖譜可視化
- **Anki** - 間隔重複系統
- **Notion AI** - 知識整合
- **Perplexity** - RAG 對話體驗

---

## 🎉 總結

這個路線圖將您的知識庫從：

**階段 0（當前）：** 資訊倉庫
↓
**Phase 1（✅ 已完成）：** 情境化助手
↓
**Phase 2：** 主動學習系統
↓
**Phase 3：** 完整知識生態
↓
**Phase 4：** 自主 AI 代理

**最終願景：**
一個能夠**主動學習、智能提醒、輔助決策、視覺化呈現、自由分享**的個人知識系統，讓您的每一次思考都能轉化為可複用的智慧資產。

---

**版本歷史：**
- v1.0 (2025-11-12): 初始版本，Phase 1 已完成
