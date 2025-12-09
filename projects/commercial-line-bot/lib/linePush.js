import { Client } from '@line/bot-sdk';

// 清理環境變數，移除可能的換行符和空格
const config = {
  channelAccessToken: (process.env.LINE_CHANNEL_ACCESS_TOKEN || '').trim().replace(/\\n/g, '').replace(/\n/g, ''),
  channelSecret: (process.env.LINE_CHANNEL_SECRET || '').trim().replace(/\\n/g, '').replace(/\n/g, ''),
};

const client = new Client(config);

/**
 * 發送 Push 訊息到用戶
 */
export async function pushMessage(userId, message) {
  try {
    await client.pushMessage(userId, {
      type: 'text',
      text: message
    });
    console.log(`📤 Push 訊息已發送到用戶: ${userId}`);
    return true;
  } catch (error) {
    console.error('❌ 發送 Push 訊息失敗:', error);
    return false;
  }
}

/**
 * 發送多條 Push 訊息
 */
export async function pushMessages(userId, messages) {
  try {
    const messageObjects = messages.map(msg => ({
      type: 'text',
      text: msg
    }));

    await client.pushMessage(userId, messageObjects);
    console.log(`📤 已發送 ${messages.length} 條 Push 訊息到用戶: ${userId}`);
    return true;
  } catch (error) {
    console.error('❌ 發送 Push 訊息失敗:', error);
    return false;
  }
}
