// check-task-queue.js - 检查任务队列状态
import 'dotenv/config';
import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const TASK_QUEUE_DB_ID = process.env.NOTION_TASK_QUEUE_DB_ID?.trim().replace(/\\n/g, '').replace(/\n/g, '');

async function checkTaskQueue() {
  console.log('🔍 检查任务队列状态...\n');

  try {
    // 查询所有任务
    const response = await notion.databases.query({
      database_id: TASK_QUEUE_DB_ID,
      sorts: [
        {
          timestamp: 'created_time',
          direction: 'descending'
        }
      ],
      page_size: 20
    });

    console.log(`📊 任务队列总数: ${response.results.length}\n`);

    // 按状态分组
    const tasksByStatus = {
      '待處理': [],
      '處理中': [],
      '已完成': [],
      '失敗': []
    };

    response.results.forEach(page => {
      const status = page.properties['狀態']?.select?.name || '未知';
      const title = page.properties['標題']?.title[0]?.plain_text || '无标题';
      const taskType = page.properties['任務類型']?.select?.name || '未知';
      const userId = page.properties['用戶ID']?.rich_text[0]?.plain_text || '未知';
      const createdTime = new Date(page.created_time).toLocaleString('zh-TW');
      const startTime = page.properties['開始時間']?.date?.start;
      const completeTime = page.properties['完成時間']?.date?.start;
      const retryCount = page.properties['重試次數']?.number || 0;

      const task = {
        id: page.id,
        title,
        taskType,
        userId,
        createdTime,
        startTime: startTime ? new Date(startTime).toLocaleString('zh-TW') : null,
        completeTime: completeTime ? new Date(completeTime).toLocaleString('zh-TW') : null,
        retryCount
      };

      if (tasksByStatus[status]) {
        tasksByStatus[status].push(task);
      }
    });

    // 显示统计
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📈 任务状态统计');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    Object.entries(tasksByStatus).forEach(([status, tasks]) => {
      const icon = {
        '待處理': '⏳',
        '處理中': '🔄',
        '已完成': '✅',
        '失敗': '❌'
      }[status] || '❓';

      console.log(`${icon} ${status}: ${tasks.length} 個`);
    });
    console.log('');

    // 显示详细信息
    ['處理中', '待處理', '失敗'].forEach(status => {
      const tasks = tasksByStatus[status];
      if (tasks.length > 0) {
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log(`🔍 ${status}任务详情 (${tasks.length} 個)`);
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        tasks.forEach((task, i) => {
          console.log(`${i + 1}. ${task.title}`);
          console.log(`   📋 类型: ${task.taskType}`);
          console.log(`   👤 用户: ${task.userId}`);
          console.log(`   📅 创建: ${task.createdTime}`);
          if (task.startTime) {
            console.log(`   🏁 开始: ${task.startTime}`);

            // 计算运行时间
            const now = new Date();
            const start = new Date(task.startTime);
            const runningMinutes = Math.floor((now - start) / 1000 / 60);
            console.log(`   ⏱️  运行: ${runningMinutes} 分钟`);

            if (status === '處理中' && runningMinutes > 30) {
              console.log(`   ⚠️  警告: 运行时间过长，可能已卡住`);
            }
          }
          if (task.completeTime) {
            console.log(`   ✅ 完成: ${task.completeTime}`);
          }
          if (task.retryCount > 0) {
            console.log(`   🔁 重试: ${task.retryCount} 次`);
          }
          console.log(`   🔗 ID: ${task.id}`);
          console.log('');
        });
      }
    });

    // 建议
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('💡 操作建议');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    const processingTasks = tasksByStatus['處理中'];
    if (processingTasks.length > 0) {
      const stuckTasks = processingTasks.filter(task => {
        if (!task.startTime) return false;
        const start = new Date(task.startTime);
        const runningMinutes = Math.floor((Date.now() - start) / 1000 / 60);
        return runningMinutes > 30;
      });

      if (stuckTasks.length > 0) {
        console.log('⚠️  检测到卡住的任务！');
        console.log('');
        console.log('执行以下命令重置卡住的任务:');
        console.log('  node scripts/reset-stuck-tasks.js');
        console.log('');
      } else {
        console.log('✅ 有任务正在处理中，请等待完成');
        console.log('');
      }
    }

    const pendingTasks = tasksByStatus['待處理'];
    if (pendingTasks.length > 0) {
      console.log(`⏳ 有 ${pendingTasks.length} 个待处理任务`);
      console.log('');
      console.log('确保 GitHub Actions cron job 正在运行:');
      console.log('  https://github.com/dtgfdgfgf/commercial-line-bot/actions');
      console.log('');
    }

    const failedTasks = tasksByStatus['失敗'];
    if (failedTasks.length > 0) {
      console.log(`❌ 有 ${failedTasks.length} 个失败任务`);
      console.log('');
      console.log('查看失败原因请检查 Notion 中的「錯誤訊息」字段');
      console.log('');
    }

  } catch (error) {
    console.error('❌ 查询失败:', error.message);
    process.exit(1);
  }
}

checkTaskQueue();
