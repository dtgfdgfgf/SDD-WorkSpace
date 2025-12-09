/**
 * 測試 LINE Webhook 簽名驗證功能
 *
 * 用途：驗證簽名驗證邏輯是否正常工作
 * 測試場景：
 *   1. 無簽名的請求（應被拒絕）
 *   2. 錯誤簽名的請求（應被拒絕）
 *   3. 正確簽名的請求（應被接受）
 */

import crypto from 'crypto';

// 測試配置
const TEST_CONFIG = {
  // 本地測試 URL（開發環境）
  localUrl: 'http://localhost:3000/api/webhook',

  // Vercel 測試 URL（根據你的部署修改）
  vercelUrl: 'https://commercial-line-bot.vercel.app/api/webhook',

  // 測試用的 webhook 事件
  testEvent: {
    events: [
      {
        type: 'message',
        message: {
          type: 'text',
          text: '測試訊息'
        },
        source: {
          userId: 'U1234567890abcdef'
        },
        replyToken: 'test-reply-token-1234567890',
        timestamp: Date.now()
      }
    ],
    destination: 'test'
  }
};

/**
 * 計算 LINE webhook 簽名
 */
function calculateSignature(body, secret) {
  return crypto
    .createHmac('SHA256', secret)
    .update(body)
    .digest('base64');
}

/**
 * 測試 1: 無簽名的請求（應返回 401）
 */
async function testMissingSignature(url) {
  console.log('\n🧪 測試 1: 無簽名的請求');
  console.log('─────────────────────────────────');

  const body = JSON.stringify(TEST_CONFIG.testEvent);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: body
    });

    console.log(`📊 狀態碼: ${response.status}`);
    console.log(`📊 預期結果: 401 (Unauthorized)`);

    const responseData = await response.json();
    console.log(`📊 回應內容:`, responseData);

    if (response.status === 401) {
      console.log('✅ PASS - 正確拒絕無簽名的請求');
      return true;
    } else {
      console.log('❌ FAIL - 應該返回 401，但返回了', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ 測試失敗:', error.message);
    return false;
  }
}

/**
 * 測試 2: 錯誤簽名的請求（應返回 401）
 */
async function testInvalidSignature(url) {
  console.log('\n🧪 測試 2: 錯誤簽名的請求');
  console.log('─────────────────────────────────');

  const body = JSON.stringify(TEST_CONFIG.testEvent);
  const fakeSignature = 'fake-signature-1234567890abcdef==';

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-line-signature': fakeSignature
      },
      body: body
    });

    console.log(`📊 狀態碼: ${response.status}`);
    console.log(`📊 預期結果: 401 (Unauthorized)`);

    const responseData = await response.json();
    console.log(`📊 回應內容:`, responseData);

    if (response.status === 401) {
      console.log('✅ PASS - 正確拒絕錯誤簽名的請求');
      return true;
    } else {
      console.log('❌ FAIL - 應該返回 401，但返回了', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ 測試失敗:', error.message);
    return false;
  }
}

/**
 * 測試 3: 正確簽名的請求（應返回 200）
 * 注意：這個測試需要正確的 LINE_CHANNEL_SECRET
 */
async function testValidSignature(url, channelSecret) {
  console.log('\n🧪 測試 3: 正確簽名的請求');
  console.log('─────────────────────────────────');

  if (!channelSecret) {
    console.log('⚠️  跳過：需要提供 LINE_CHANNEL_SECRET 環境變數');
    console.log('   用法: LINE_CHANNEL_SECRET=your_secret node scripts/test-signature-verification.js');
    return null;
  }

  const body = JSON.stringify(TEST_CONFIG.testEvent);
  const validSignature = calculateSignature(body, channelSecret);

  console.log(`🔐 計算的簽名: ${validSignature.substring(0, 20)}...`);

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-line-signature': validSignature
      },
      body: body
    });

    console.log(`📊 狀態碼: ${response.status}`);
    console.log(`📊 預期結果: 200 (OK)`);

    const responseText = await response.text();
    console.log(`📊 回應內容: ${responseText}`);

    if (response.status === 200) {
      console.log('✅ PASS - 正確接受有效簽名的請求');
      console.log('   注意：實際 LINE webhook 可能因為 replyToken 無效而無法完成回覆');
      console.log('   但簽名驗證已經通過，這是測試的重點');
      return true;
    } else {
      console.log('❌ FAIL - 應該返回 200，但返回了', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ 測試失敗:', error.message);
    return false;
  }
}

/**
 * 測試 4: GET 請求（應返回 405）
 */
async function testInvalidMethod(url) {
  console.log('\n🧪 測試 4: GET 請求（應拒絕非 POST 請求）');
  console.log('─────────────────────────────────');

  try {
    const response = await fetch(url, {
      method: 'GET'
    });

    console.log(`📊 狀態碼: ${response.status}`);
    console.log(`📊 預期結果: 405 (Method Not Allowed)`);

    if (response.status === 405) {
      console.log('✅ PASS - 正確拒絕非 POST 請求');
      return true;
    } else {
      console.log('❌ FAIL - 應該返回 405，但返回了', response.status);
      return false;
    }
  } catch (error) {
    console.error('❌ 測試失敗:', error.message);
    return false;
  }
}

/**
 * 主測試函數
 */
async function runTests() {
  console.log('╔════════════════════════════════════════════╗');
  console.log('║  LINE Webhook 簽名驗證測試套件            ║');
  console.log('╚════════════════════════════════════════════╝');

  // 檢查測試模式
  const isLocal = process.argv.includes('--local');
  const testUrl = isLocal ? TEST_CONFIG.localUrl : TEST_CONFIG.vercelUrl;
  const channelSecret = process.env.LINE_CHANNEL_SECRET;

  console.log(`\n📍 測試目標: ${testUrl}`);
  console.log(`🔐 Channel Secret: ${channelSecret ? '✅ 已設置' : '⚠️  未設置（測試 3 將跳過）'}`);

  // 運行所有測試
  const results = {
    test1: await testMissingSignature(testUrl),
    test2: await testInvalidSignature(testUrl),
    test3: await testValidSignature(testUrl, channelSecret),
    test4: await testInvalidMethod(testUrl)
  };

  // 統計結果
  console.log('\n╔════════════════════════════════════════════╗');
  console.log('║  測試結果總結                              ║');
  console.log('╚════════════════════════════════════════════╝');

  const passed = Object.values(results).filter(r => r === true).length;
  const failed = Object.values(results).filter(r => r === false).length;
  const skipped = Object.values(results).filter(r => r === null).length;
  const total = Object.values(results).length;

  console.log(`\n✅ 通過: ${passed}/${total}`);
  console.log(`❌ 失敗: ${failed}/${total}`);
  console.log(`⚠️  跳過: ${skipped}/${total}`);

  if (failed === 0 && passed > 0) {
    console.log('\n🎉 所有測試通過！簽名驗證功能正常運作。');
    process.exit(0);
  } else if (failed > 0) {
    console.log('\n⚠️  部分測試失敗，請檢查錯誤訊息。');
    process.exit(1);
  } else {
    console.log('\n⚠️  沒有執行任何測試。');
    process.exit(1);
  }
}

// 顯示使用說明
function showUsage() {
  console.log(`
用法:
  # 測試本地開發環境
  npm run dev  # 先啟動 Vercel dev server
  node scripts/test-signature-verification.js --local

  # 測試 Vercel production 環境
  node scripts/test-signature-verification.js

  # 包含正確簽名測試（需要 channel secret）
  LINE_CHANNEL_SECRET=your_secret node scripts/test-signature-verification.js

環境變數:
  LINE_CHANNEL_SECRET - 用於計算正確的簽名（測試 3）

選項:
  --local  - 測試本地開發環境 (http://localhost:3000)
  --help   - 顯示此幫助訊息
`);
}

// 主程序
if (process.argv.includes('--help')) {
  showUsage();
  process.exit(0);
}

// 檢查 fetch 是否可用（Node.js 18+）
if (typeof fetch === 'undefined') {
  console.error('❌ 錯誤: 此腳本需要 Node.js 18 或更高版本（內建 fetch）');
  console.error('   或者安裝 node-fetch: npm install node-fetch');
  process.exit(1);
}

// 運行測試
runTests().catch(error => {
  console.error('\n❌ 測試執行失敗:', error);
  process.exit(1);
});
