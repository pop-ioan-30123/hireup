import { IsString, MaxLength } from 'class-validator';

export class SetMessageReactionDto {
  @IsString()
  @MaxLength(16)
  emoji!: string;
}