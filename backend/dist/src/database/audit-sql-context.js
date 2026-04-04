"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyAuditSqlContext = applyAuditSqlContext;
async function applyAuditSqlContext(client, context) {
    const pairs = [
        ['app.current_user_id', context.currentUserId],
        ['app.current_user_email', context.currentUserEmail],
        ['app.current_ip', context.ipAddress],
        ['app.current_user_agent', context.userAgent],
        ['app.request_id', context.requestId],
    ];
    for (const [key, value] of pairs) {
        await client.query('SELECT set_config($1, $2, true)', [key, value ?? '']);
    }
}
//# sourceMappingURL=audit-sql-context.js.map