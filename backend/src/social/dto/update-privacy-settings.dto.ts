import { IsBoolean, IsIn, IsOptional } from 'class-validator';

export class UpdatePrivacySettingsDto {
  @IsOptional()
  @IsIn(['everyone', 'contacts', 'contacts_and_followers'])
  messagesPrivacy?: 'everyone' | 'contacts' | 'contacts_and_followers';

  @IsOptional()
  @IsBoolean()
  showFollowerList?: boolean;

  @IsOptional()
  @IsBoolean()
  showContactList?: boolean;
}
