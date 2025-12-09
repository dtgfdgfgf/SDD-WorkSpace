// test-task-queue.js - 测试任务队列数据库访问
import 'dotenv/config';
import { Client } from "@notionhq/client";

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const TASK_QUEUE_DB_ID = process.env.NOTION_TASK_QUEUE_DB_ID;

async function testDatabase() {
  console.log('🔍 测试任务队列数据库访问...\n');
  console.log(`📋 数据库 ID: ${TASK_QUEUE_DB_ID}\n`);

  try {
    // 测试 1: 查询数据库
    console.log('📝 测试 1: 查询数据库...');
    const response = await notion.databases.query({
      database_id: TASK_QUEUE_DB_ID,
      page_size: 1
    });
    console.log(`✅ 数据库可访问，当前有 ${response.results.length} 条记录\n`);

    // 测试 2: 获取数据库信息
    console.log('📝 测试 2: 获取数据库 Schema...');
    const dbInfo = await notion.databases.retrieve({
      database_id: TASK_QUEUE_DB_ID
    });

    console.log('✅ 数据库 Schema:');
    console.log(`   标题: ${dbInfo.title[0]?.plain_text || '无标题'}`);
    console.log('   属性:');
    Object.keys(dbInfo.properties).forEach(key => {
      const prop = dbInfo.properties[key];
      console.log(`   - ${key}: ${prop.type}`);
    });
    console.log('');

    // 测试 3: 创建测试任务
    console.log('📝 测试 3: 创建测试任务...');
    const testTask = await notion.pages.create({
      parent: { database_id: TASK_QUEUE_DB_ID },
      properties: {
        '標題': {
          title: [{ text: { content: '测试任务 - 可删除' } }]
        },
        '任務類型': {
          select: { name: '其他' }
        },
        '狀態': {
          select: { name: '待處理' }
        },
        '用戶ID': {
          rich_text: [{ text: { content: 'test_user' } }]
        },
        '任務參數': {
          rich_text: [{ text: { content: JSON.stringify({ test: true }) } }]
        },
        '優先級': {
          select: { name: '低' }
        },
        '重試次數': {
          number: 0
        }
      }
    });
    console.log(`✅ 测试任务创建成功: ${testTask.id}\n`);

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('🎉 所有测试通过！数据库配置正确。\n');
    console.log('💡 提示：请在 Notion 中删除测试任务（标题：测试任务 - 可删除）');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  } catch (error) {
    console.error('\n❌ 测试失败:');
    console.error('错误类型:', error.code || error.name);
    console.error('错误消息:', error.message);

    if (error.code === 'object_not_found') {
      console.error('\n📋 可能原因：');
      console.error('1. 数据库 ID 不正确');
      console.error('2. 数据库已被删除');
      console.error('3. Notion Integration 没有访问权限');
      console.error('\n🔧 解决方法：');
      console.error('1. 执行 node scripts/init-task-queue.js 重新创建数据库');
      console.error('2. 在 Notion 中打开数据库，右上角 ... → Connections → 添加 Integration');
    } else if (error.code === 'validation_error') {
      console.error('\n📋 可能原因：');
      console.error('数据库 Schema 不正确（缺少必需属性或类型不匹配）');
      console.error('\n🔧 解决方法：');
      console.error('执行 node scripts/init-task-queue.js 重新创建数据库');
    }

    process.exit(1);
  }
}

testDatabase();
