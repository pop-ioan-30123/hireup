import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsNumber,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class UserSkillDto {
  @IsIn(['language', 'soft', 'hard'])
  category!: 'language' | 'soft' | 'hard';

  @IsString()
  name!: string;

  @IsNumber({ allowInfinity: false, allowNaN: false, maxDecimalPlaces: 2 })
  @Min(1)
  @Max(10)
  score!: number;

  @IsBoolean()
  isVisible!: boolean;
}

export class SetUserSkillsDto {
  @IsArray()
  @ArrayMaxSize(60)
  @ValidateNested({ each: true })
  @Type(() => UserSkillDto)
  skills!: UserSkillDto[];
}
