import { IsString, MaxLength, MinLength } from 'class-validator';

export class UpdateMessageDto {
  @IsString()
  @MinLength(1)
  @MaxLength(20000)
  ciphertext!: string;
}