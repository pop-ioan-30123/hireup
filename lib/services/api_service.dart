import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? retryAfterSeconds;

  const ApiException({
    required this.code,
    required this.message,
    this.retryAfterSeconds,
  });
}

class LoginResult {
  final String accessToken;
  final String refreshToken;

  const LoginResult({required this.accessToken, required this.refreshToken});
}

class ApiService {
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static Future<void> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String gender,
    required String birthDate,
    required String phone,
    required String country,
    required String county,
    required String city,
    required String jobTitle,
    required int yearsExperience,
    required String educationLevel,
    required String educationInstitution,
    required String gdprVersion,
    required String locale,
  }) async {
    await _post('/auth/register-user', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'birthDate': birthDate,
      'phone': phone,
      'country': country,
      'county': county,
      'city': city,
      'jobTitle': jobTitle,
      'yearsExperience': yearsExperience,
      'educationLevel': educationLevel,
      'educationInstitution': educationInstitution,
      'gdprVersion': gdprVersion,
      'locale': locale,
    });
  }

  static Future<void> registerCompany({
    required String email,
    required String password,
    required String companyName,
    required String hrFirstName,
    required String hrLastName,
    required String hrEmail,
    required String gender,
    required String birthDate,
    required String gdprVersion,
    required String locale,
    String countryCode = 'RO',
    String? county,
    String? city,
  }) async {
    await _post('/auth/register-company', {
      'email': email,
      'password': password,
      'companyName': companyName,
      'countryCode': countryCode,
      'county': county,
      'city': city,
      'hrFirstName': hrFirstName,
      'hrLastName': hrLastName,
      'hrEmail': hrEmail,
      'gender': gender,
      'birthDate': birthDate,
      'gdprVersion': gdprVersion,
      'locale': locale,
    });
  }

  static Future<bool> isEmailAvailable({required String email}) async {
    final data = await _post('/auth/check-email', {'email': email});

    return data['available'] == true;
  }

  static Future<LoginResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
  }) async {
    final payload = <String, dynamic>{'email': email, 'password': password};

    final normalizedTwoFactorCode = twoFactorCode?.trim();
    if (normalizedTwoFactorCode != null && normalizedTwoFactorCode.isNotEmpty) {
      payload['twoFactorCode'] = normalizedTwoFactorCode;
    }

    final data = await _post('/auth/login', payload);

    return LoginResult(
      accessToken: data['accessToken']?.toString() ?? '',
      refreshToken: data['refreshToken']?.toString() ?? '',
    );
  }

  static Future<void> uploadAttachment({
    required String accessToken,
    required String attachmentType,
    required String targetType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final uri = Uri.parse('$_baseUrl/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..fields['attachmentType'] = attachmentType
      ..fields['targetType'] = targetType
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(mimeType),
        ),
      );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw _toApiException(response.statusCode, _decodeJsonMap(responseBody));
  }

  static Future<Map<String, dynamic>> getProfile({
    required String accessToken,
  }) async {
    return _get('/profile/me', accessToken);
  }

  static Future<void> updateUserProfile({
    required String accessToken,
    String? phone,
    String? gender,
    String? birthDate,
    String? jobTitle,
    String? country,
    String? county,
    String? city,
    int? yearsExperience,
    String? educationLevel,
    String? educationInstitution,
  }) async {
    await _patch('/profile/user', accessToken, {
      'phone': phone,
      'gender': gender,
      'birthDate': birthDate,
      'jobTitle': jobTitle,
      'country': country,
      'county': county,
      'city': city,
      'yearsExperience': yearsExperience,
      'educationLevel': educationLevel,
      'educationInstitution': educationInstitution,
    });
  }

  static Future<void> updateCompanyProfile({
    required String accessToken,
    String? companyName,
    String? gender,
    String? birthDate,
    String? countryCode,
    String? county,
    String? city,
  }) async {
    await _patch('/profile/company', accessToken, {
      'companyName': companyName,
      'gender': gender,
      'birthDate': birthDate,
      'countryCode': countryCode,
      'county': county,
      'city': city,
    });
  }

  static Future<void> updateProfileVisibility({
    required String accessToken,
    bool? showGender,
    bool? showBirthDate,
    bool? showJobTitle,
    bool? showPhone,
    bool? showCountry,
    bool? showCounty,
    bool? showCity,
    bool? showYearsExperience,
    bool? showEducationLevel,
    bool? showEducationInstitution,
    bool? showCompanyName,
    bool? showCompanyCounty,
    bool? showCompanyCity,
    bool? showHrFirstName,
    bool? showHrLastName,
    bool? showHrEmail,
    bool? showCv,
  }) async {
    await _patch('/profile/visibility', accessToken, {
      'showGender': showGender,
      'showBirthDate': showBirthDate,
      'showJobTitle': showJobTitle,
      'showPhone': showPhone,
      'showCountry': showCountry,
      'showCounty': showCounty,
      'showCity': showCity,
      'showYearsExperience': showYearsExperience,
      'showEducationLevel': showEducationLevel,
      'showEducationInstitution': showEducationInstitution,
      'showCompanyName': showCompanyName,
      'showCompanyCounty': showCompanyCounty,
      'showCompanyCity': showCompanyCity,
      'showHrFirstName': showHrFirstName,
      'showHrLastName': showHrLastName,
      'showHrEmail': showHrEmail,
      'showCv': showCv,
    });
  }

  static Future<void> updateThemePreference({
    required String accessToken,
    required bool isDark,
  }) async {
    await _patch('/profile/theme', accessToken, {
      'defaultTheme': isDark ? 'dark' : 'light',
    });
  }

  static Future<Map<String, dynamic>> resendEmailVerification({
    required String accessToken,
  }) async {
    return _postWithAuth('/auth/verification/resend', accessToken, {});
  }

  static Future<Map<String, dynamic>> setupTwoFactor({
    required String accessToken,
  }) async {
    return _postWithAuth('/auth/2fa/setup', accessToken, {});
  }

  static Future<void> cancelTwoFactorSetup({
    required String accessToken,
  }) async {
    await _postWithAuth('/auth/2fa/setup/cancel', accessToken, {});
  }

  static Future<void> enableTwoFactor({
    required String accessToken,
    required String code,
  }) async {
    await _postWithAuth('/auth/2fa/enable', accessToken, {'code': code});
  }

  static Future<void> disableTwoFactor({
    required String accessToken,
    required String code,
  }) async {
    await _postWithAuth('/auth/2fa/disable', accessToken, {'code': code});
  }

  static Future<List<String>> regenerateTwoFactorBackupCodes({
    required String accessToken,
    required String code,
  }) async {
    final data = await _postWithAuth(
      '/auth/2fa/backup-codes/regenerate',
      accessToken,
      {'code': code},
    );

    final values = data['backupCodes'];
    if (values is! List) return const [];

    return values.map((item) => item.toString()).toList(growable: false);
  }

  static Future<void> uploadAvatar({
    required String accessToken,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    await uploadAttachment(
      accessToken: accessToken,
      attachmentType: 'avatar',
      targetType: 'user',
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
  }

  static Future<Uint8List?> fetchAvatar({required String accessToken}) async {
    final uri = Uri.parse('$_baseUrl/profile/avatar');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().startsWith('image/')) {
        return null;
      }
      return response.bodyBytes;
    }

    throw _toApiException(response.statusCode, _decodeJsonMap(response.body));
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final data = _decodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw _toApiException(response.statusCode, data);
  }

  static Future<Map<String, dynamic>> _postWithAuth(
    String path,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw _toApiException(response.statusCode, data);
  }

  static Map<String, dynamic> _decodeJsonMap(String source) {
    if (source.trim().isEmpty) return <String, dynamic>{};

    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static Future<Map<String, dynamic>> _get(
    String path,
    String accessToken,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    final data = _decodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw _toApiException(response.statusCode, data);
  }

  static Future<Map<String, dynamic>> _patch(
    String path,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
      body: jsonEncode(body),
    );

    final data = _decodeJsonMap(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw _toApiException(response.statusCode, data);
  }

  static ApiException _toApiException(
    int statusCode,
    Map<String, dynamic> data,
  ) {
    dynamic messageNode = data['message'];

    String code = data['code']?.toString() ?? 'HTTP_$statusCode';
    String message = data['error']?.toString() ?? 'Request failed';
    int? retryAfterSeconds;

    if (messageNode is Map<String, dynamic>) {
      code = messageNode['code']?.toString() ?? code;
      message = messageNode['message']?.toString() ?? message;
      retryAfterSeconds = _toInt(messageNode['retryAfterSeconds']);
    } else if (messageNode is String) {
      message = messageNode;
    } else if (messageNode is List && messageNode.isNotEmpty) {
      message = messageNode.first.toString();
    }

    retryAfterSeconds ??= _toInt(data['retryAfterSeconds']);

    return ApiException(
      code: code,
      message: message,
      retryAfterSeconds: retryAfterSeconds,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
