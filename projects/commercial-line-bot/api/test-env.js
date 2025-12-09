// 測試環境變數的端點
export default function handler(req, res) {
  const taskQueueId = process.env.NOTION_TASK_QUEUE_DB_ID;

  res.status(200).json({
    raw: taskQueueId,
    length: taskQueueId?.length,
    bytes: taskQueueId ? Array.from(taskQueueId).map(c => c.charCodeAt(0)) : null,
    trimmed: taskQueueId?.trim(),
    trimmedLength: taskQueueId?.trim().length,
    hasNewline: taskQueueId?.includes('\n'),
    lastChar: taskQueueId ? taskQueueId.charCodeAt(taskQueueId.length - 1) : null
  });
}
