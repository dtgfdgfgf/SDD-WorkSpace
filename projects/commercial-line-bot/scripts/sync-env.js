// sync-env.js - 自動掃描 Notion 資料庫並同步到 .env
import 'dotenv/config';
import { Client } from "@notionhq/client";
import fs from 'fs';
import { execSync } from 'child_process';
import readline from 'readline';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const parentPageId = process.env.PARENT_PAGE_ID;

// 資料庫名稱映射規則
const DB_MAPPING = {
  'Daily Q&A': 'NOTION_MAIN_DB_ID',
  '主問題': 'NOTION_MAIN_DB_ID',
  'Conversation Rounds': 'NOTION_ROUNDS_DB_ID',
  '回合': 'NOTION_ROUNDS_DB_ID',
  'Question Bank': 'NOTION_QUESTION_BANK_DB_ID',
  '題庫': 'NOTION_QUESTION_BANK_DB_ID',
  'Weekly Review': 'WEEKLY_DB_ID',
  '週報': 'WEEKLY_DB_ID',
  'Knowledge Fragments': 'NOTION_KNOWLEDGE_DB_ID',
  '知識片段': 'NOTION_KNOWLEDGE_DB_ID',
  'Topic Summaries': 'NOTION_TOPIC_SUMMARY_DB_ID',
  '主題總結': 'NOTION_TOPIC_SUMMARY_DB_ID'
};

// 命令行參數
const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const syncToVercel = args.includes('--vercel');
const checkOnly = args.includes('--check');

/**
 * 掃描 Notion workspace 中的所有資料庫
 */
async function scanNotionDatabases() {
  console.log('🔍 正在掃描 Notion workspace...\n');

  try {
    // 查詢 parent page 下的所有 blocks
    const response = await notion.blocks.children.list({
      block_id: parentPageId,
      page_size: 100
    });

    const databases = [];

    // 找出所有 child_database 類型的 blocks
    for (const block of response.results) {
      if (block.type === 'child_database') {
        // 查詢資料庫詳細信息
        const dbInfo = await notion.databases.retrieve({
          database_id: block.id
        });

        const title = dbInfo.title[0]?.plain_text || '未命名資料庫';
        databases.push({
          id: block.id,
          title: title,
          envVar: mapDatabaseToEnvVar(title)
        });
      }
    }

    return databases;
  } catch (error) {
    console.error('❌ 掃描失敗:', error.message);
    if (error.code === 'object_not_found') {
      console.error('   請檢查 PARENT_PAGE_ID 是否正確，以及 Integration 是否有存取權限');
    }
    return [];
  }
}

/**
 * 根據資料庫標題映射到環境變數名稱
 */
function mapDatabaseToEnvVar(title) {
  // 完全匹配
  if (DB_MAPPING[title]) {
    return DB_MAPPING[title];
  }

  // 部分匹配（包含關鍵字）
  for (const [keyword, envVar] of Object.entries(DB_MAPPING)) {
    if (title.includes(keyword)) {
      return envVar;
    }
  }

  return null;
}

/**
 * 讀取現有 .env 文件
 */
function readEnvFile() {
  try {
    const envPath = '.env';
    if (!fs.existsSync(envPath)) {
      return {};
    }

    const content = fs.readFileSync(envPath, 'utf-8');
    const env = {};

    content.split('\n').forEach(line => {
      line = line.trim();
      if (line && !line.startsWith('#')) {
        const [key, ...valueParts] = line.split('=');
        if (key) {
          env[key.trim()] = valueParts.join('=').trim();
        }
      }
    });

    return env;
  } catch (error) {
    console.error('❌ 讀取 .env 失敗:', error.message);
    return {};
  }
}

/**
 * 格式化資料庫 ID（移除連字符）
 */
function formatDatabaseId(id) {
  return id.replace(/-/g, '');
}

/**
 * 更新 .env 文件
 */
function updateEnvFile(databases, currentEnv) {
  console.log('\n📝 正在更新 .env...\n');

  // 生成備份
  const envPath = '.env';
  const backupPath = '.env.backup';

  if (fs.existsSync(envPath)) {
    fs.copyFileSync(envPath, backupPath);
    console.log(`✅ 備份已創建：${backupPath}`);
  }

  // 更新環境變數
  const updatedEnv = { ...currentEnv };
  const changes = [];

  databases.forEach(db => {
    if (db.envVar) {
      const formattedId = formatDatabaseId(db.id);
      const oldValue = updatedEnv[db.envVar];

      if (oldValue !== formattedId) {
        updatedEnv[db.envVar] = formattedId;
        changes.push({
          envVar: db.envVar,
          dbTitle: db.title,
          oldValue: oldValue || '（未設置）',
          newValue: formattedId
        });
      }
    }
  });

  if (changes.length === 0) {
    console.log('ℹ️  所有環境變數已是最新，無需更新');
    return { updated: false, changes: [] };
  }

  // 生成新的 .env 內容（保持原有格式和註釋）
  let newContent = '';
  const envLines = fs.existsSync(envPath) ? fs.readFileSync(envPath, 'utf-8').split('\n') : [];
  const updatedKeys = new Set();

  // 保留原有內容，更新變更的值
  envLines.forEach(line => {
    const trimmedLine = line.trim();
    if (!trimmedLine || trimmedLine.startsWith('#')) {
      // 保留空行和註釋
      newContent += line + '\n';
    } else {
      const [key] = trimmedLine.split('=');
      const envKey = key.trim();

      if (updatedEnv[envKey] !== undefined) {
        newContent += `${envKey}=${updatedEnv[envKey]}\n`;
        updatedKeys.add(envKey);
      } else {
        newContent += line + '\n';
      }
    }
  });

  // 添加新的環境變數（如果有）
  Object.entries(updatedEnv).forEach(([key, value]) => {
    if (!updatedKeys.has(key) && key.startsWith('NOTION_') || key === 'WEEKLY_DB_ID') {
      newContent += `${key}=${value}\n`;
    }
  });

  // 寫入文件
  fs.writeFileSync(envPath, newContent.trimEnd() + '\n');
  console.log(`✅ .env 已更新\n`);

  // 顯示變更
  console.log('📊 變更摘要：');
  changes.forEach(change => {
    console.log(`   ${change.envVar}`);
    console.log(`   資料庫：${change.dbTitle}`);
    console.log(`   舊值：${change.oldValue}`);
    console.log(`   新值：${change.newValue}`);
    console.log('');
  });

  return { updated: true, changes };
}

/**
 * 驗證配置
 */
async function validateConfiguration(databases) {
  console.log('\n🔍 正在驗證配置...\n');

  const results = [];

  for (const db of databases) {
    if (!db.envVar) {
      results.push({
        title: db.title,
        envVar: '未映射',
        status: 'warning',
        message: '資料庫名稱無法自動映射到環境變數'
      });
      continue;
    }

    try {
      // 測試資料庫連接
      await notion.databases.query({
        database_id: db.id,
        page_size: 1
      });

      results.push({
        title: db.title,
        envVar: db.envVar,
        status: 'success',
        message: '連接正常'
      });
    } catch (error) {
      let message = '連接失敗';
      if (error.code === 'unauthorized') {
        message = 'Notion Integration 未授權';
      } else if (error.code === 'object_not_found') {
        message = '資料庫不存在或已刪除';
      }

      results.push({
        title: db.title,
        envVar: db.envVar,
        status: 'error',
        message: message
      });
    }
  }

  // 顯示結果
  results.forEach(result => {
    const icon = result.status === 'success' ? '✅' : result.status === 'error' ? '❌' : '⚠️ ';
    console.log(`${icon} ${result.title}`);
    console.log(`   環境變數：${result.envVar}`);
    console.log(`   狀態：${result.message}\n`);
  });

  const hasErrors = results.some(r => r.status === 'error');
  const hasWarnings = results.some(r => r.status === 'warning');

  if (hasErrors) {
    console.log('⚠️  發現錯誤，請檢查 Notion Integration 授權');
  } else if (hasWarnings) {
    console.log('⚠️  發現警告，某些資料庫無法自動映射');
  } else {
    console.log('✅ 所有資料庫配置正確');
  }

  return results;
}

/**
 * 同步到 Vercel
 */
async function syncToVercel(databases) {
  console.log('\n🚀 正在同步到 Vercel...\n');

  const question = (query) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise(resolve => {
      rl.question(query, answer => {
        rl.close();
        resolve(answer);
      });
    });
  };

  const answer = await question('請選擇環境 (1: Production, 2: All): ');
  const environments = answer === '2' ? ['production', 'preview', 'development'] : ['production'];

  for (const db of databases) {
    if (!db.envVar) continue;

    const formattedId = formatDatabaseId(db.id);

    for (const env of environments) {
      try {
        console.log(`   上傳 ${db.envVar} 到 ${env}...`);
        execSync(`printf "${formattedId}" | vercel env add ${db.envVar} ${env}`, {
          stdio: 'inherit'
        });
      } catch (error) {
        // 如果環境變數已存在，vercel 會返回錯誤，這是正常的
        console.log(`   ℹ️  ${db.envVar} 在 ${env} 環境已存在（跳過）`);
      }
    }
  }

  console.log('\n✅ Vercel 同步完成');
  console.log('⚠️  請記得重新部署：vercel --prod');
}

/**
 * 主函數
 */
async function main() {
  console.log('╔══════════════════════════════════════╗');
  console.log('║   Notion 環境變數自動同步工具       ║');
  console.log('╚══════════════════════════════════════╝\n');

  // 檢查必要的環境變數
  if (!process.env.NOTION_TOKEN) {
    console.error('❌ NOTION_TOKEN 環境變數未設置');
    process.exit(1);
  }

  if (!process.env.PARENT_PAGE_ID) {
    console.error('❌ PARENT_PAGE_ID 環境變數未設置');
    process.exit(1);
  }

  // 掃描資料庫
  const databases = await scanNotionDatabases();

  if (databases.length === 0) {
    console.log('⚠️  未找到任何資料庫');
    return;
  }

  console.log(`找到 ${databases.length} 個資料庫：\n`);
  databases.forEach(db => {
    const icon = db.envVar ? '✅' : '⚠️ ';
    const envVar = db.envVar || '未映射';
    console.log(`${icon} ${db.title} → ${envVar}`);
  });

  // 只檢查模式
  if (checkOnly) {
    await validateConfiguration(databases);
    return;
  }

  // Dry run 模式
  if (isDryRun) {
    console.log('\n🔍 Dry run 模式：只掃描，不寫入');
    return;
  }

  // 更新 .env
  const currentEnv = readEnvFile();
  const { updated, changes } = updateEnvFile(databases, currentEnv);

  // 驗證配置
  await validateConfiguration(databases);

  // 同步到 Vercel
  if (syncToVercel && updated) {
    await syncToVercel(databases);
  }

  console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🎉 環境變數同步完成！\n');

  if (updated) {
    console.log('📝 下一步：');
    if (!syncToVercel) {
      console.log('1. 檢查 .env 文件是否正確');
      console.log('2. 運行 vercel env add 同步到 Vercel（可選）');
      console.log('3. 重新部署：vercel --prod');
    } else {
      console.log('1. 檢查 .env 文件是否正確');
      console.log('2. 重新部署：vercel --prod');
    }
  }
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
}

main().catch(error => {
  console.error('❌ 執行失敗:', error);
  process.exit(1);
});
