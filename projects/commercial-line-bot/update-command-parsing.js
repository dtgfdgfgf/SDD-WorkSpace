// 臨時腳本：更新 webhook.js 的命令解析邏輯
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const webhookPath = path.join(__dirname, 'api', 'webhook.js');
const content = fs.readFileSync(webhookPath, 'utf-8');

// 舊的代碼
const oldCode = `  } else if (text === '標籤列表' || text === '标签列表' || text === '標籤' || text === '标签' || text === 'tags') {
    return await handleTagList(userId);
  } else if (text.startsWith('總結 ') || text.startsWith('总结 ')) {
    const tag = text.replace(/^(總結|总结)\\s+/, '').trim();
    return await handleGenerateTopicSummary(userId, tag);
  } else if (text === '清除') {`;

// 新的代碼
const newCode = `  } else if (text === '標籤列表' || text === '标签列表' || text === '標籤' || text === '标签' || text === 'tags') {
    return await handleTagList(userId);
  } else if (text === '總結狀態' || text === '总结状态' || text === '總結状态' || text === '总结狀態') {
    return await handleSummaryStatus(userId);
  } else if (text.startsWith('總結 ') || text.startsWith('总结 ')) {
    const param = text.replace(/^(總結|总结)\\s+/, '').trim();

    // 判斷是類別還是標籤
    const categoryNames = ['技術類', '商業類', '個人成長類', '團隊協作類', '思維模式類',
                          '技术类', '商业类', '个人成长类', '团队协作类', '思维模式类'];

    if (categoryNames.includes(param)) {
      return await handleBatchSummaryByCategory(userId, param);
    } else {
      return await handleGenerateTopicSummary(userId, param);
    }
  } else if (text === '清除') {`;

const newContent = content.replace(oldCode, newCode);

// 寫回文件
fs.writeFileSync(webhookPath, newContent, 'utf-8');

console.log('✅ 成功更新命令解析邏輯');
