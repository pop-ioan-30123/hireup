import { IsIn, IsJSON, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class PostMessageDto {
  @IsOptional()
  @IsIn(['text', 'system'])
  messageKind?: 'text' | 'system';

  @IsString()
  @MinLength(1)
  @MaxLength(20000)
  ciphertext!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  algorithm?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  nonce?: string;

  @IsOptional()
  @IsJSON()
  metadata?: string;

  @IsOptional()
  @IsUUID()
  clientMessageId?: string;
}
