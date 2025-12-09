/**
 * Root endpoint - System information page
 * Handles requests to the root path (/)
 */
export default async function handler(req, res) {
  const html = `
<!DOCTYPE html>
<html lang="zh-TW">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LINE Bot - Business Thinking Coach</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang TC', 'Microsoft JhengHei', sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 20px;
    }
    .container {
      background: white;
      border-radius: 20px;
      padding: 40px;
      max-width: 600px;
      box-shadow: 0 20px 60px rgba(0,0,0,0.3);
    }
    h1 {
      color: #333;
      font-size: 32px;
      margin-bottom: 20px;
      text-align: center;
    }
    .status {
      background: #10b981;
      color: white;
      padding: 10px 20px;
      border-radius: 50px;
      display: inline-block;
      font-weight: 600;
      margin-bottom: 30px;
    }
    .info {
      background: #f3f4f6;
      padding: 20px;
      border-radius: 10px;
      margin-bottom: 20px;
    }
    .info-item {
      display: flex;
      justify-content: space-between;
      padding: 10px 0;
      border-bottom: 1px solid #e5e7eb;
    }
    .info-item:last-child { border-bottom: none; }
    .label { font-weight: 600; color: #6b7280; }
    .value { color: #111827; font-family: monospace; }
    .features {
      margin-top: 30px;
    }
    .features h2 {
      color: #333;
      font-size: 20px;
      margin-bottom: 15px;
    }
    .feature-list {
      list-style: none;
      padding-left: 0;
    }
    .feature-list li {
      padding: 8px 0;
      color: #4b5563;
      display: flex;
      align-items: center;
    }
    .feature-list li:before {
      content: "✓";
      color: #10b981;
      font-weight: bold;
      margin-right: 10px;
      font-size: 18px;
    }
    .endpoint {
      background: #1f2937;
      color: #f3f4f6;
      padding: 15px;
      border-radius: 8px;
      margin-top: 20px;
      font-family: monospace;
      font-size: 14px;
    }
    .center { text-align: center; }
  </style>
</head>
<body>
  <div class="container">
    <div class="center">
      <span class="status">● System Online</span>
    </div>

    <h1>LINE Bot<br/>Business Thinking Coach</h1>

    <div class="info">
      <div class="info-item">
        <span class="label">Project</span>
        <span class="value">commercial-line-bot</span>
      </div>
      <div class="info-item">
        <span class="label">Status</span>
        <span class="value">Ready</span>
      </div>
      <div class="info-item">
        <span class="label">Environment</span>
        <span class="value">Production</span>
      </div>
      <div class="info-item">
        <span class="label">Deployed</span>
        <span class="value">${new Date().toLocaleString('zh-TW', { timeZone: 'Asia/Taipei' })}</span>
      </div>
    </div>

    <div class="features">
      <h2>Features</h2>
      <ul class="feature-list">
        <li>Structured Training (問, 儲存, 小結, 結束, 狀態)</li>
        <li>Knowledge Retrieval (查詢, 主題總結, 週報, 標籤)</li>
        <li>Free Conversation with Claude AI</li>
        <li>28 Blind Spot Tags Analysis</li>
        <li>Notion Database Integration</li>
      </ul>
    </div>

    <div class="endpoint">
      <strong>Webhook Endpoint:</strong><br/>
      POST /api/webhook
    </div>
  </div>
</body>
</html>
  `;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.status(200).send(html);
}
