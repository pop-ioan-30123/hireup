import { ValidationArguments } from 'class-validator';

export function invalidEmailFormatMessage(args: ValidationArguments): string {
  const locale =
    (args.object as { locale?: string } | null)?.locale
      ?.toString()
      .trim()
      .toUpperCase() ?? 'RO';

  if (locale == 'EN') {
    return 'The provided email does not follow the standard email format.';
  }

  return 'Email-ul introdus nu are formatul de e-mail standard.';
}