// 现有单体商城的用户模块，订单服务需要对接它。
// 评审设计方案时，这个文件只能作为只读事实源，不得修改。

const db = require('./db');

async function getUserById(id) {
  const rows = await db.query(
    'SELECT id, username, email, created_at FROM users WHERE id = ?',
    [id],
  );
  return rows[0] || null;
}

// 手机号不在 users 表上，存在 user_contacts 里，且可能未验证。
async function getVerifiedPhone(userId) {
  const rows = await db.query(
    "SELECT value FROM user_contacts WHERE user_id = ? AND channel = 'sms' AND verified = 1",
    [userId],
  );
  return rows.length ? rows[0].value : null;
}

module.exports = { getUserById, getVerifiedPhone };
