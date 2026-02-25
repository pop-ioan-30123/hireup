import { PoolClient } from 'pg';

export interface AuditSqlContext {
  currentUserId?: string | null;
  currentUserEmail?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  requestId?: string | null;
}

export async function applyAuditSqlContext(
  client: PoolClient,
  context: AuditSqlContext,
): Promise<void> {
  const pairs: Array<[string, string | null | undefined]> = [
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