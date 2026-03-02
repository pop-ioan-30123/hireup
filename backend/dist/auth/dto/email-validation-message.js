"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.invalidEmailFormatMessage = invalidEmailFormatMessage;
function invalidEmailFormatMessage(args) {
    const locale = args.object?.locale
        ?.toString()
        .trim()
        .toUpperCase() ?? 'RO';
    if (locale == 'EN') {
        return 'The provided email does not follow the standard email format.';
    }
    return 'Email-ul introdus nu are formatul de e-mail standard.';
}
//# sourceMappingURL=email-validation-message.js.map