// test-rag.js - 测试 RAG（检索增强生成）功能
import 'dotenv/config';
import { performRAG, extractRelevantTags, retrieveRelevantKnowledge } from '../lib/rag.js';

async function testRAG() {
  console.log('🧪 测试 RAG 功能\n');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

  // 测试用例
  const testCases = [
    {
      name: '测试1：定价相关问题',
      message: '我在思考SaaS产品的定价策略，不知道应该定多少钱合适'
    },
    {
      name: '测试2：商业模式问题',
      message: '如何设计一个可持续的商业模式？'
    },
    {
      name: '测试3：客户开发问题',
      message: '怎么找到第一批客户并验证需求？'
    },
    {
      name: '测试4：闲聊（应该无相关知识）',
      message: '今天天气真不错'
    }
  ];

  for (const testCase of testCases) {
    console.log(`\n📋 ${testCase.name}`);
    console.log(`   用户消息: "${testCase.message}"`);
    console.log('');

    try {
      // Step 1: 测试标签提取
      console.log('   🏷️  Step 1: 提取标签...');
      const extraction = await extractRelevantTags(testCase.message);
      console.log(`   结果: ${extraction.tags.length > 0 ? extraction.tags.join('、') : '无'}`);
      console.log(`   置信度: ${extraction.confidence}`);
      console.log(`   推理: ${extraction.reasoning}`);
      console.log('');

      // Step 2: 测试知识检索
      if (extraction.tags.length > 0) {
        console.log('   📚 Step 2: 检索知识...');
        const knowledge = await retrieveRelevantKnowledge(extraction.tags);
        console.log(`   主题总结: ${knowledge.topicSummary ? '✓ 找到' : '✗ 无'}`);
        console.log(`   知识片段: ${knowledge.knowledgeFragments.length} 个`);
        console.log(`   对话总结: ${knowledge.mainQuestions.length} 个`);
        console.log(`   总计: ${knowledge.totalResults} 条相关知识`);
        console.log('');

        // 显示部分知识内容（如果有）
        if (knowledge.knowledgeFragments.length > 0) {
          console.log('   📖 知识片段示例:');
          const fragment = knowledge.knowledgeFragments[0];
          console.log(`      ${fragment.title}`);
          const contentPreview = fragment.content.substring(0, 100);
          console.log(`      ${contentPreview}${fragment.content.length > 100 ? '...' : ''}`);
          console.log('');
        }
      }

      // Step 3: 测试完整 RAG 流程
      console.log('   🔄 Step 3: 完整 RAG 流程...');
      const ragResult = await performRAG(testCase.message);
      console.log(`   总结: 找到 ${ragResult.metadata.totalResults} 条知识`);

      if (ragResult.metadata.totalResults > 0) {
        console.log(`   增强 Prompt 长度: ${ragResult.enhancedPrompt.length} 字符`);
        console.log('   ✅ RAG 成功');
      } else {
        console.log('   ℹ️  无相关知识（这可能是正常的）');
      }

    } catch (error) {
      console.error(`   ❌ 测试失败: ${error.message}`);
      console.error(`   ${error.stack}`);
    }

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  console.log('\n\n🎉 测试完成！\n');
  console.log('💡 下一步：');
  console.log('1. 在 LINE 中测试实际对话');
  console.log('2. 观察日志确认 RAG 是否被调用');
  console.log('3. 验证 Claude 回答是否引用了知识库');
}

testRAG().catch(error => {
  console.error('❌ 测试脚本执行失败:', error);
  process.exit(1);
});
