import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DatabaseError } from 'pg';
import { PoolClient } from 'pg';
import { DatabaseService } from '../database/database.service';
import { UpdatePrivacySettingsDto } from './dto/update-privacy-settings.dto';

type Queryable = {
  query: (
    sql: string,
    params?: unknown[],
  ) => Promise<{ rows: any[]; rowCount?: number | null }>;
};

type SocialListRow = {
  id: string;
  first_name: string | null;
  last_name: string | null;
  email: string;
  created_at: string;
};

type SocialNotificationRow = {
  id: string;
  actor_user_id: string;
  first_name: string | null;
  last_name: string | null;
  email: string;
  notification_type:
    | 'follow'
    | 'unfollow'
    | 'contact'
    | 'follow_received'
    | 'follow_sent'
    | 'unfollow_received'
    | 'unfollow_sent'
    | 'contact_created'
    | 'contact_removed';
  image_key: string;
  sent_at: string;
  is_read: boolean;
};

@Injectable()
export class SocialService {
  constructor(private readonly db: DatabaseService) {}

  async followUser(currentUserId: string, targetUserId: string) {
    if (currentUserId === targetUserId) {
      throw new BadRequestException('Cannot follow yourself');
    }

    return this.db.withTransaction(async (client) => {
      await this.assertUserExists(client, targetUserId);

      const inserted = await client.query<{ follower_user_id: string }>(
        `INSERT INTO user_follow (follower_user_id, following_user_id)
         VALUES ($1, $2)
         ON CONFLICT DO NOTHING
         RETURNING follower_user_id`,
        [currentUserId, targetUserId],
      );

      const insertedNow = (inserted.rowCount ?? 0) > 0;
      const becameContact = await this.areMutualFollowers(
        client,
        currentUserId,
        targetUserId,
      );

      if (insertedNow) {
        await this.insertSocialNotification(
          client,
          targetUserId,
          currentUserId,
          'follow_received',
        );
        await this.insertSocialNotification(
          client,
          currentUserId,
          targetUserId,
          'follow_sent',
        );
      }

      if (insertedNow && becameContact) {
        await this.syncAcceptedContactRows(client, currentUserId, targetUserId);
        await this.insertSocialNotification(
          client,
          currentUserId,
          targetUserId,
          'contact_created',
        );
        await this.insertSocialNotification(
          client,
          targetUserId,
          currentUserId,
          'contact_created',
        );
      }

      return { ok: true, becameContact };
    });
  }

  async unfollowUser(currentUserId: string, targetUserId: string) {
    if (currentUserId === targetUserId) {
      throw new BadRequestException('Cannot unfollow yourself');
    }

    return this.db.withTransaction(async (client) => {
      const hadContactBeforeUnfollow = await this.areMutualFollowers(
        client,
        currentUserId,
        targetUserId,
      );

      const deleted = await client.query<{ follower_user_id: string }>(
        `DELETE FROM user_follow
         WHERE follower_user_id = $1 AND following_user_id = $2
         RETURNING follower_user_id`,
        [currentUserId, targetUserId],
      );

      if ((deleted.rowCount ?? 0) > 0) {
        await this.insertSocialNotification(
          client,
          targetUserId,
          currentUserId,
          'unfollow_received',
        );
        await this.insertSocialNotification(
          client,
          currentUserId,
          targetUserId,
          'unfollow_sent',
        );

        if (hadContactBeforeUnfollow) {
          await this.insertSocialNotification(
            client,
            currentUserId,
            targetUserId,
            'contact_removed',
          );
          await this.insertSocialNotification(
            client,
            targetUserId,
            currentUserId,
            'contact_removed',
          );
        }
      }

      await this.removeContactRows(client, currentUserId, targetUserId);
      return { ok: true };
    });
  }

  async listFollowers(userId: string, viewerUserId: string = userId) {
    await this.assertUserExists(this.db, userId);

    const canView =
      viewerUserId === userId ||
      (await this.canViewFollowerList({ targetUserId: userId }));

    if (!canView) {
      return { items: [], total: 0, isVisible: false };
    }

    const result = await this.db.query<SocialListRow>(
      `SELECT au.id, au.first_name, au.last_name, au.email, uf.created_at::text
       FROM user_follow uf
       JOIN app_user au ON au.id = uf.follower_user_id
       WHERE uf.following_user_id = $1
       ORDER BY uf.created_at DESC`,
      [userId],
    );

    return {
      items: result.rows.map((row) => ({
        userId: row.id,
        fullName: this.displayName(row.first_name, row.last_name, row.email),
        email: row.email,
        since: row.created_at,
      })),
      total: result.rowCount ?? 0,
      isVisible: true,
    };
  }

  async listFollowing(userId: string) {
    const result = await this.db.query<SocialListRow>(
      `SELECT au.id, au.first_name, au.last_name, au.email, uf.created_at::text
       FROM user_follow uf
       JOIN app_user au ON au.id = uf.following_user_id
       WHERE uf.follower_user_id = $1
       ORDER BY uf.created_at DESC`,
      [userId],
    );

    return {
      items: result.rows.map((row) => ({
        userId: row.id,
        fullName: this.displayName(row.first_name, row.last_name, row.email),
        email: row.email,
        since: row.created_at,
      })),
      total: result.rowCount ?? 0,
    };
  }

  async sendContactRequest(currentUserId: string, targetUserId: string) {
    return this.followUser(currentUserId, targetUserId);
  }

  async acceptContactRequest(currentUserId: string, requesterUserId: string) {
    return this.followUser(currentUserId, requesterUserId);
  }

  async rejectContactRequest(currentUserId: string, requesterUserId: string) {
    await this.removeContactRows(this.db, currentUserId, requesterUserId);
    return { ok: true };
  }

  async removeContact(currentUserId: string, targetUserId: string) {
    return this.unfollowUser(currentUserId, targetUserId);
  }

  async listContacts(userId: string, viewerUserId: string = userId) {
    await this.assertUserExists(this.db, userId);

    const canView =
      viewerUserId === userId ||
      (await this.canViewContactList({ targetUserId: userId }));

    if (!canView) {
      return { items: [], total: 0, isVisible: false };
    }

    const result = await this.db.query<SocialListRow>(
      `SELECT other_user.id,
              other_user.first_name,
              other_user.last_name,
              other_user.email,
              GREATEST(outbound.created_at, inbound.created_at)::text AS created_at
       FROM user_follow outbound
       JOIN user_follow inbound
         ON inbound.follower_user_id = outbound.following_user_id
        AND inbound.following_user_id = outbound.follower_user_id
       JOIN app_user other_user ON other_user.id = outbound.following_user_id
       WHERE outbound.follower_user_id = $1
       ORDER BY GREATEST(outbound.created_at, inbound.created_at) DESC`,
      [userId],
    );

    return {
      items: result.rows.map((row) => ({
        userId: row.id,
        fullName: this.displayName(row.first_name, row.last_name, row.email),
        email: row.email,
        since: row.created_at,
      })),
      total: result.rowCount ?? 0,
      isVisible: true,
    };
  }

  async listPendingContactRequests(userId: string) {
    return { items: [], total: 0, isVisible: false };
  }

  async getSocialSummary(currentUserId: string, targetUserId: string) {
    const [privacy, relationshipRow, countsRow] = await Promise.all([
      this.getPrivacyVisibility(targetUserId),
      this.db.query<{
        is_following: boolean;
        is_follower: boolean;
        is_contact: boolean;
      }>(
        `SELECT
           EXISTS(
             SELECT 1 FROM user_follow
             WHERE follower_user_id = $1 AND following_user_id = $2
           ) AS is_following,
           EXISTS(
             SELECT 1 FROM user_follow
             WHERE follower_user_id = $2 AND following_user_id = $1
           ) AS is_follower,
           EXISTS(
             SELECT 1
             FROM user_follow outbound
             JOIN user_follow inbound
               ON inbound.follower_user_id = outbound.following_user_id
              AND inbound.following_user_id = outbound.follower_user_id
             WHERE outbound.follower_user_id = $1
               AND outbound.following_user_id = $2
           ) AS is_contact`,
        [currentUserId, targetUserId],
      ),
      this.db.query<{ follower_count: string; contact_count: string }>(
        `SELECT
           (SELECT COUNT(*)::text FROM user_follow WHERE following_user_id = $1) AS follower_count,
           (
             SELECT COUNT(*)::text
             FROM user_follow outbound
             JOIN user_follow inbound
               ON inbound.follower_user_id = outbound.following_user_id
              AND inbound.following_user_id = outbound.follower_user_id
             WHERE outbound.follower_user_id = $1
           ) AS contact_count`,
        [targetUserId],
      ),
    ]);

    const relationship = relationshipRow.rows[0];
    const counts = countsRow.rows[0];
    const isOwnProfile = currentUserId === targetUserId;

    return {
      isFollowing: relationship?.is_following === true,
      isFollower: relationship?.is_follower === true,
      contactStatus: relationship?.is_contact === true ? 'accepted' : 'none',
      followerCount: parseInt(counts?.follower_count ?? '0', 10),
      contactCount: parseInt(counts?.contact_count ?? '0', 10),
      showFollowerList: isOwnProfile ? true : privacy.showFollowerList,
      showContactList: isOwnProfile ? true : privacy.showContactList,
    };
  }

  async getPrivacySettings(userId: string) {
    try {
      const result = await this.db.query<{
        messages_privacy: string;
        show_follower_list: boolean;
        show_contact_list: boolean;
      }>(
        `SELECT messages_privacy, show_follower_list, show_contact_list
         FROM user_privacy_settings
         WHERE user_id = $1`,
        [userId],
      );

      if ((result.rowCount ?? 0) === 0) {
        return {
          messagesPrivacy: 'everyone',
          showFollowerList: true,
          showContactList: true,
        };
      }

      const row = result.rows[0];
      return {
        messagesPrivacy: row.messages_privacy,
        showFollowerList: row.show_follower_list,
        showContactList: row.show_contact_list,
      };
    } catch (error) {
      if (error instanceof DatabaseError && (this.isMissingColumn(error, 'show_follower_list') || this.isMissingColumn(error, 'show_contact_list'))) {
        const legacy = await this.db.query<{ messages_privacy: string }>(
          `SELECT messages_privacy
           FROM user_privacy_settings
           WHERE user_id = $1`,
          [userId],
        );
        return {
          messagesPrivacy: legacy.rows[0]?.messages_privacy ?? 'everyone',
          showFollowerList: true,
          showContactList: true,
        };
      }
      throw error;
    }
  }

  async updatePrivacySettings(userId: string, dto: UpdatePrivacySettingsDto) {
    try {
      await this.db.query(
        `INSERT INTO user_privacy_settings (user_id, messages_privacy, show_follower_list, show_contact_list)
         VALUES ($1, COALESCE($2, 'everyone'), COALESCE($3, TRUE), COALESCE($4, TRUE))
         ON CONFLICT (user_id) DO UPDATE SET
           messages_privacy = COALESCE($2, user_privacy_settings.messages_privacy),
           show_follower_list = COALESCE($3, user_privacy_settings.show_follower_list),
           show_contact_list = COALESCE($4, user_privacy_settings.show_contact_list),
           updated_at = NOW()`,
        [
          userId,
          dto.messagesPrivacy ?? null,
          dto.showFollowerList ?? null,
          dto.showContactList ?? null,
        ],
      );
    } catch (error) {
      if (error instanceof DatabaseError && (this.isMissingColumn(error, 'show_follower_list') || this.isMissingColumn(error, 'show_contact_list'))) {
        await this.db.query(
          `INSERT INTO user_privacy_settings (user_id, messages_privacy)
           VALUES ($1, COALESCE($2, 'everyone'))
           ON CONFLICT (user_id) DO UPDATE SET
             messages_privacy = COALESCE($2, user_privacy_settings.messages_privacy),
             updated_at = NOW()`,
          [userId, dto.messagesPrivacy ?? null],
        );
      } else {
        throw error;
      }
    }

    return this.getPrivacySettings(userId);
  }

  async listSocialNotifications(userId: string) {
    let result;
    try {
      result = await this.db.query<SocialNotificationRow>(
        `SELECT sn.id,
                sn.actor_user_id,
                sn.notification_type,
                sn.image_key,
                sn.sent_at::text,
                sn.is_read,
                actor.first_name,
                actor.last_name,
                actor.email
         FROM social_notification sn
         JOIN app_user actor ON actor.id = sn.actor_user_id
         WHERE sn.recipient_user_id = $1
         ORDER BY sn.sent_at DESC
         LIMIT 100`,
        [userId],
      );
    } catch (error) {
      if (error instanceof DatabaseError && this.isMissingRelation(error, 'social_notification')) {
        return { items: [] };
      }
      throw error;
    }

    return {
      items: result.rows.map((row) => ({
        id: row.id,
        type: row.notification_type,
        imageKey: row.image_key,
        sentAt: row.sent_at,
        isRead: row.is_read,
        actorUserId: row.actor_user_id,
        actorFullName: this.displayName(row.first_name, row.last_name, row.email),
      })),
    };
  }

  async markNotificationsRead(userId: string) {
    try {
      await this.db.query(
        `
        UPDATE social_notification
        SET is_read = TRUE,
            read_at = COALESCE(read_at, NOW())
        WHERE recipient_user_id = $1
          AND is_read = FALSE
        `,
        [userId],
      );
    } catch (error) {
      if (error instanceof DatabaseError && this.isMissingRelation(error, 'social_notification')) {
        return { ok: true };
      }
      throw error;
    }

    return { ok: true };
  }

  async canSendDirectMessage(
    senderUserId: string,
    targetUserId: string,
  ): Promise<'active' | 'request'> {
    // Message threads are active only for mutual contacts.
    // Everyone else is routed through message requests.
    const isContact = await this.areMutualFollowers(
      this.db,
      senderUserId,
      targetUserId,
    );
    if (isContact) {
      return 'active';
    }
    return 'request';
  }

  private async assertUserExists(client: Queryable, userId: string) {
    const result = await client.query('SELECT id FROM app_user WHERE id = $1', [
      userId,
    ]);
    if ((result.rowCount ?? 0) === 0) {
      throw new NotFoundException('User not found');
    }
  }

  private async canViewFollowerList({ targetUserId }: { targetUserId: string }) {
    try {
      const result = await this.db.query<{ show_follower_list: boolean }>(
        `SELECT show_follower_list FROM user_privacy_settings WHERE user_id = $1`,
        [targetUserId],
      );
      return result.rows[0]?.show_follower_list ?? true;
    } catch (error) {
      if (error instanceof DatabaseError && this.isMissingColumn(error, 'show_follower_list')) {
        return true;
      }
      throw error;
    }
  }

  private async canViewContactList({ targetUserId }: { targetUserId: string }) {
    try {
      const result = await this.db.query<{ show_contact_list: boolean }>(
        `SELECT show_contact_list FROM user_privacy_settings WHERE user_id = $1`,
        [targetUserId],
      );
      return result.rows[0]?.show_contact_list ?? true;
    } catch (error) {
      if (error instanceof DatabaseError && this.isMissingColumn(error, 'show_contact_list')) {
        return true;
      }
      throw error;
    }
  }

  private async areMutualFollowers(
    client: Queryable,
    firstUserId: string,
    secondUserId: string,
  ) {
    const result = await client.query(
      `SELECT 1
       FROM user_follow outbound
       JOIN user_follow inbound
         ON inbound.follower_user_id = outbound.following_user_id
        AND inbound.following_user_id = outbound.follower_user_id
       WHERE outbound.follower_user_id = $1
         AND outbound.following_user_id = $2
       LIMIT 1`,
      [firstUserId, secondUserId],
    );
    return (result.rowCount ?? 0) > 0;
  }

  private async syncAcceptedContactRows(
    client: PoolClient,
    firstUserId: string,
    secondUserId: string,
  ) {
    await client.query(
      `INSERT INTO user_contact (requester_user_id, target_user_id, status)
       VALUES ($1, $2, 'accepted'), ($2, $1, 'accepted')
       ON CONFLICT (requester_user_id, target_user_id)
       DO UPDATE SET status = 'accepted', updated_at = NOW()`,
      [firstUserId, secondUserId],
    );
  }

  private async removeContactRows(
    client: Queryable,
    firstUserId: string,
    secondUserId: string,
  ) {
    await client.query(
      `DELETE FROM user_contact
       WHERE (requester_user_id = $1 AND target_user_id = $2)
          OR (requester_user_id = $2 AND target_user_id = $1)`,
      [firstUserId, secondUserId],
    );
  }

  private async insertSocialNotification(
    client: PoolClient,
    recipientUserId: string,
    actorUserId: string,
    type:
      | 'follow'
      | 'unfollow'
      | 'contact'
      | 'follow_received'
      | 'follow_sent'
      | 'unfollow_received'
      | 'unfollow_sent'
      | 'contact_created'
      | 'contact_removed',
  ) {
    if (recipientUserId === actorUserId) {
      return;
    }

    try {
      await client.query(
        `INSERT INTO social_notification (recipient_user_id, actor_user_id, notification_type, image_key)
         VALUES ($1, $2, $3, $4)`,
        [recipientUserId, actorUserId, type, type],
      );
    } catch (error) {
      if (error instanceof DatabaseError && this.isMissingRelation(error, 'social_notification')) {
        return;
      }
      throw error;
    }
  }

  private async getPrivacyVisibility(userId: string) {
    try {
      const result = await this.db.query<{
        show_follower_list: boolean;
        show_contact_list: boolean;
      }>(
        `SELECT show_follower_list, show_contact_list
         FROM user_privacy_settings
         WHERE user_id = $1`,
        [userId],
      );
      return {
        showFollowerList: result.rows[0]?.show_follower_list ?? true,
        showContactList: result.rows[0]?.show_contact_list ?? true,
      };
    } catch (error) {
      if (error instanceof DatabaseError && (this.isMissingColumn(error, 'show_follower_list') || this.isMissingColumn(error, 'show_contact_list'))) {
        return {
          showFollowerList: true,
          showContactList: true,
        };
      }
      throw error;
    }
  }

  private isMissingRelation(error: DatabaseError, relationName: string) {
    return error.code === '42P01' && error.message.includes(relationName);
  }

  private isMissingColumn(error: DatabaseError, columnName: string) {
    return error.code === '42703' && error.message.includes(columnName);
  }

  private displayName(
    firstName: string | null,
    lastName: string | null,
    email: string,
  ) {
    const merged = [firstName?.trim() ?? '', lastName?.trim() ?? '']
      .filter((value) => value.length > 0)
      .join(' ')
      .trim();
    return merged.length > 0 ? merged : email;
  }
}
