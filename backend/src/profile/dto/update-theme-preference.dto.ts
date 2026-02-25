import { IsIn } from 'class-validator';

export class UpdateThemePreferenceDto {
  @IsIn(['light', 'dark'])
  defaultTheme!: 'light' | 'dark';
}
