import { IsUUID } from 'class-validator';

export class CreateDmConversationDto {
  @IsUUID()
  otherUserId!: string;
}
