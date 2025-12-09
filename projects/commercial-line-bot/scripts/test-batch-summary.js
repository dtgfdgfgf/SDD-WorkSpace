// test-batch-summary.js - 测试批次总结功能
import 'dotenv/config';
import { createTask } from '../lib/taskQueue.js';
import { TAG_CATEGORIES } from '../lib/constants.js';

async function testBatchSummary() {
  console.log('🧪 测试批次总结功能...\n');

  const userId = 'test_user_12345';
  const categoryName = '商業類';

  try {
    // Step 1: 验证环境变量
    console.log('📝 Step 1: 检查环境变量...');
    const TOPIC_SUMMARY_DB_ID = process.env.NOTION_TOPIC_SUMMARY_DB_ID?.trim();
    const TASK_QUEUE_DB_ID = process.env.NOTION_TASK_QUEUE_DB_ID?.trim();

    console.log(`   TOPIC_SUMMARY_DB_ID: ${TOPIC_SUMMARY_DB_ID ? '✓' : '✗'}`);
    console.log(`   TASK_QUEUE_DB_ID: ${TASK_QUEUE_DB_ID ? '✓' : '✗'}`);

    if (!TOPIC_SUMMARY_DB_ID) {
      throw new Error('NOTION_TOPIC_SUMMARY_DB_ID 未设置');
    }
    if (!TASK_QUEUE_DB_ID) {
      throw new Error('NOTION_TASK_QUEUE_DB_ID 未设置');
    }
    console.log('✅ 环境变量检查通过\n');

    // Step 2: 验证类别
    console.log('📝 Step 2: 验证类别...');
    const validCategories = Object.keys(TAG_CATEGORIES);
    const categoryMap = {
      '技術類': '技術',
      '商業類': '商業',
      '個人成長類': '個人成長',
      '團隊協作類': '團隊協作',
      '思維模式類': '思維模式'
    };

    const normalizedCategory = categoryMap[categoryName] || categoryName;
    console.log(`   输入类别: ${categoryName}`);
    console.log(`   标准化后: ${normalizedCategory}`);

    if (!validCategories.includes(normalizedCategory)) {
      throw new Error(`无效的类别: ${categoryName}`);
    }
    console.log('✅ 类别验证通过\n');

    // Step 3: 获取标签列表
    console.log('📝 Step 3: 获取标签列表...');
    const tagsInCategory = TAG_CATEGORIES[normalizedCategory];
    console.log(`   类别「${normalizedCategory}」包含 ${tagsInCategory.length} 个标签:`);
    tagsInCategory.forEach((tag, i) => {
      console.log(`   ${i + 1}. ${tag}`);
    });
    console.log('');

    // Step 4: 创建任务
    console.log('📝 Step 4: 创建批次总结任务...');
    const taskId = await createTask('batch_summary', userId, {
      categoryName: normalizedCategory,
      originalCategoryName: categoryName,
      tagsCount: tagsInCategory.length
    }, '高');
    console.log(`✅ 任务创建成功: ${taskId}\n`);

    // Step 5: 生成回复消息
    console.log('📝 Step 5: 生成回复消息...');
    const estimatedMinutes = Math.ceil(tagsInCategory.length * 20 / 60);
    const replyText = `✅ 批次總結任務已加入隊列\n\n` +
      `📊 類別：${categoryName}\n` +
      `🏷️  標籤數量：${tagsInCategory.length} 個\n` +
      `⏱️ 預計時間：${estimatedMinutes} 分鐘\n\n` +
      `🔔 處理完成後會自動通知您\n` +
      `💡 期間您可以繼續使用其他功能\n\n` +
      `📝 查看處理狀態：輸入「總結狀態」`;

    console.log('回复消息:');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(replyText);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    console.log('🎉 测试完成！批次总结功能正常。\n');
    console.log('💡 下一步：');
    console.log('1. 查看 Notion Task Queue 数据库，应该有新任务');
    console.log('2. 检查 Vercel 生产环境是否部署了最新代码');
    console.log('3. 检查 LINE webhook 是否正确配置');

  } catch (error) {
    console.error('\n❌ 测试失败:');
    console.error('错误消息:', error.message);
    console.error('错误堆栈:', error.stack);
    process.exit(1);
  }
}

testBatchSummary();
