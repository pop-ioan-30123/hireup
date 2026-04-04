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
    required String phone,
    required String country,
    required String county,
    required String city,
    required String jobTitle,
    required int yearsExperience,
    required String educationLevel,
    required String educationInstitution,
    required String specialization,
    required String gdprVersion,
    required String locale,
  }) async {
    await _post('/auth/register-user', {
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'gender': gender,
      'phone': phone,
      'country': country,
      'county': county,
      'city': city,
      'jobTitle': jobTitle,
      'yearsExperience': yearsExperience,
      'educationLevel': educationLevel,
      'educationInstitution': educationInstitution,
      'specialization': specialization,
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
      'gdprVersion': gdprVersion,
      'locale': locale,
    });
  }

  static Future<bool> isEmailAvailable({
    required String email,
    String? locale,
  }) async {
    final payload = <String, dynamic>{'email': email};
    final normalizedLocale = locale?.trim();
    if (normalizedLocale != null && normalizedLocale.isNotEmpty) {
      payload['locale'] = normalizedLocale;
    }

    final data = await _post('/auth/check-email', payload);

    return data['available'] == true;
  }

  static Future<LoginResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
    String? locale,
  }) async {
    final payload = <String, dynamic>{'email': email, 'password': password};

    final normalizedLocale = locale?.trim();
    if (normalizedLocale != null && normalizedLocale.isNotEmpty) {
      payload['locale'] = normalizedLocale;
    }

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

  static Future<Map<String, dynamic>> uploadAttachment({
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
      return _decodeJsonMap(responseBody);
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
    String? specialization,
    String? profileSummary,
    String? linkedInUrl,
    String? githubUrl,
    String? youtubeUrl,
    String? instagramUrl,
    String? tiktokUrl,
    String? professionalStatus,
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
      'specialization': specialization,
      'profileSummary': profileSummary,
      'linkedInUrl': linkedInUrl,
      'githubUrl': githubUrl,
      'youtubeUrl': youtubeUrl,
      'instagramUrl': instagramUrl,
      'tiktokUrl': tiktokUrl,
      'professionalStatus': professionalStatus,
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
    bool? showAccountCreatedDate,
    bool? showAccountCreatedTime,
    bool? showJobTitle,
    bool? showPhone,
    bool? showCountry,
    bool? showCounty,
    bool? showCity,
    bool? showYearsExperience,
    bool? showEducationLevel,
    bool? showEducationInstitution,
    bool? showSpecialization,
    bool? showCompanyName,
    bool? showCompanyCounty,
    bool? showCompanyCity,
    bool? showHrFirstName,
    bool? showHrLastName,
    bool? showHrEmail,
    bool? showCv,
    bool? showProfileSummary,
    bool? showProfessionalStatus,
    bool? showLinkedIn,
    bool? showGithub,
    bool? showYoutube,
    bool? showInstagram,
    bool? showTiktok,
  }) async {
    await _patch('/profile/visibility', accessToken, {
      'showGender': showGender,
      'showBirthDate': showBirthDate,
      'showAccountCreatedDate': showAccountCreatedDate,
      'showAccountCreatedTime': showAccountCreatedTime,
      'showJobTitle': showJobTitle,
      'showPhone': showPhone,
      'showCountry': showCountry,
      'showCounty': showCounty,
      'showCity': showCity,
      'showYearsExperience': showYearsExperience,
      'showEducationLevel': showEducationLevel,
      'showEducationInstitution': showEducationInstitution,
      'showSpecialization': showSpecialization,
      'showCompanyName': showCompanyName,
      'showCompanyCounty': showCompanyCounty,
      'showCompanyCity': showCompanyCity,
      'showHrFirstName': showHrFirstName,
      'showHrLastName': showHrLastName,
      'showHrEmail': showHrEmail,
      'showCv': showCv,
      'showProfileSummary': showProfileSummary,
      'showProfessionalStatus': showProfessionalStatus,
      'showLinkedIn': showLinkedIn,
      'showGithub': showGithub,
      'showYoutube': showYoutube,
      'showInstagram': showInstagram,
      'showTiktok': showTiktok,
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

  static Future<void> setUserExperiences({
    required String accessToken,
    required List<Map<String, dynamic>> experiences,
  }) async {
    await _put('/profile/user/experiences', accessToken, {
      'experiences': experiences,
    });
  }

  static Future<void> setUserEducations({
    required String accessToken,
    required List<Map<String, dynamic>> educations,
  }) async {
    await _put('/profile/user/educations', accessToken, {
      'educations': educations,
    });
  }

  static Future<void> setUserSkills({
    required String accessToken,
    required List<Map<String, dynamic>> skills,
  }) async {
    await _put('/profile/user/skills', accessToken, {'skills': skills});
  }

  static Future<void> setUserProjects({
    required String accessToken,
    required List<Map<String, dynamic>> projects,
  }) async {
    await _put('/profile/user/projects', accessToken, {'projects': projects});
  }

  static Future<Map<String, dynamic>> searchProfiles({
    required String accessToken,
    required String query,
    String field = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/profile/search/users').replace(
      queryParameters: {
        'q': query,
        'field': field,
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );

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

  static Future<Map<String, dynamic>> getProfileByUserId({
    required String accessToken,
    required String userId,
  }) async {
    return _get('/profile/users/$userId', accessToken);
  }

  static Future<Uint8List?> fetchUserAvatar({
    required String accessToken,
    required String userId,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/profile/users/$userId/avatar'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    final body = response.body.trim();
    final map = body.isEmpty ? <String, dynamic>{} : _decodeJsonMap(body);
    throw _toApiException(response.statusCode, map);
  }

  static Future<Map<String, dynamic>> createActivityPost({
    required String accessToken,
    String? content,
    String? sticker,
    List<String>? attachmentIds,
  }) async {
    return _postWithAuth('/profile/activity-posts', accessToken, {
      'content': content,
      'sticker': sticker,
      'attachmentIds': attachmentIds,
    });
  }

  static Future<Map<String, dynamic>> updateActivityPost({
    required String accessToken,
    required String postId,
    String? content,
    String? sticker,
    List<String>? attachmentIds,
  }) async {
    return _patch('/profile/activity-posts/$postId', accessToken, {
      'content': content,
      'sticker': sticker,
      'attachmentIds': attachmentIds,
    });
  }

  static Future<void> deleteActivityPost({
    required String accessToken,
    required String postId,
  }) async {
    await _delete('/profile/activity-posts/$postId', accessToken);
  }

  static Future<Map<String, dynamic>> createActivityComment({
    required String accessToken,
    required String postId,
    required String content,
  }) async {
    return _postWithAuth(
      '/profile/activity-posts/$postId/comments',
      accessToken,
      {'content': content},
    );
  }

  static Future<Map<String, dynamic>> listMarketplaceActivities({
    required String accessToken,
    String filter = 'all',
    String sort = 'postedDesc',
    String section = 'services',
    String? county,
    String? city,
    String? categoryKey,
  }) async {
    final query = <String, String>{
      'filter': filter,
      'sort': sort,
      'section': section,
    };

    final normalizedCounty = county?.trim();
    if (normalizedCounty != null && normalizedCounty.isNotEmpty) {
      query['county'] = normalizedCounty;
    }

    final normalizedCity = city?.trim();
    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      query['city'] = normalizedCity;
    }

    final normalizedCategory = categoryKey?.trim();
    if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
      query['categoryKey'] = normalizedCategory;
    }

    final uri = Uri.parse(
      '$_baseUrl/activities',
    ).replace(queryParameters: query);

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

  static Future<Map<String, dynamic>> listMyActivities({
    required String accessToken,
  }) async {
    return _get('/activities/mine', accessToken);
  }

  static Future<Map<String, dynamic>> listUpcomingActivities({
    required String accessToken,
  }) async {
    return _get('/activities/upcoming', accessToken);
  }

  static Future<Map<String, dynamic>> listActivityNotifications({
    required String accessToken,
  }) async {
    return _get('/activities/notifications', accessToken);
  }

  static Future<Map<String, dynamic>> markAllActivityNotificationsRead({
    required String accessToken,
  }) async {
    return _postWithAuth(
      '/activities/notifications/read',
      accessToken,
      const <String, dynamic>{},
    );
  }

  static Future<Map<String, dynamic>> listMessageConversations({
    required String accessToken,
  }) async {
    return _get('/messages/conversations', accessToken);
  }

  static Future<Map<String, dynamic>> createDirectMessageConversation({
    required String accessToken,
    required String otherUserId,
  }) async {
    return _postWithAuth('/messages/conversations/dm', accessToken, {
      'otherUserId': otherUserId,
    });
  }

  static Future<Map<String, dynamic>> createGroupMessageConversation({
    required String accessToken,
    required String title,
    List<String>? memberIds,
  }) async {
    return _postWithAuth('/messages/conversations/group', accessToken, {
      'title': title,
      'memberIds': memberIds,
    });
  }

  static Future<Map<String, dynamic>> listConversationMessages({
    required String accessToken,
    required String conversationId,
    int limit = 50,
    String? before,
  }) async {
    final query = <String, String>{'limit': limit.toString()};
    final normalizedBefore = before?.trim();
    if (normalizedBefore != null && normalizedBefore.isNotEmpty) {
      query['before'] = normalizedBefore;
    }

    final uri = Uri.parse(
      '$_baseUrl/messages/conversations/$conversationId/messages',
    ).replace(queryParameters: query);

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

  static Future<Map<String, dynamic>> sendConversationMessage({
    required String accessToken,
    required String conversationId,
    required String ciphertext,
    String messageKind = 'text',
    String algorithm = 'xchacha20poly1305',
    String? nonce,
    Map<String, dynamic>? metadata,
  }) async {
    return _postWithAuth(
      '/messages/conversations/$conversationId/messages',
      accessToken,
      {
        'messageKind': messageKind,
        'ciphertext': ciphertext,
        'algorithm': algorithm,
        'nonce': nonce,
        'metadata': metadata == null ? null : jsonEncode(metadata),
      },
    );
  }

  static Future<Map<String, dynamic>> markConversationRead({
    required String accessToken,
    required String conversationId,
  }) async {
    return _postWithAuth(
      '/messages/conversations/$conversationId/read',
      accessToken,
      const <String, dynamic>{},
    );
  }

  static Future<Map<String, dynamic>> updateConversationMessage({
    required String accessToken,
    required String conversationId,
    required String messageId,
    required String ciphertext,
  }) async {
    return _patch(
      '/messages/conversations/$conversationId/messages/$messageId',
      accessToken,
      {'ciphertext': ciphertext},
    );
  }

  static Future<Map<String, dynamic>> reactToConversationMessage({
    required String accessToken,
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    return _postWithAuth(
      '/messages/conversations/$conversationId/messages/$messageId/reaction',
      accessToken,
      {'emoji': emoji},
    );
  }

  static Future<Map<String, dynamic>> deleteConversationMessage({
    required String accessToken,
    required String conversationId,
    required String messageId,
    String scope = 'me',
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/messages/conversations/$conversationId/messages/$messageId',
    ).replace(queryParameters: {'scope': scope});

    final response = await http.delete(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    final data = _decodeJsonMap(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw _toApiException(response.statusCode, data);
  }

  static Future<Map<String, dynamic>> followUser({
    required String accessToken,
    required String userId,
  }) async {
    return _postWithAuth('/social/follow/$userId', accessToken, const <String, dynamic>{});
  }

  static Future<Map<String, dynamic>> unfollowUser({
    required String accessToken,
    required String userId,
  }) async {
    return _delete('/social/follow/$userId', accessToken);
  }

  static Future<Map<String, dynamic>> listFollowers({
    required String accessToken,
    String? userId,
  }) async {
    if (userId != null && userId.trim().isNotEmpty) {
      return _get('/social/users/$userId/followers', accessToken);
    }
    return _get('/social/followers', accessToken);
  }

  static Future<Map<String, dynamic>> listFollowing({
    required String accessToken,
    String? userId,
  }) async {
    if (userId != null && userId.trim().isNotEmpty) {
      return _get('/social/users/$userId/following', accessToken);
    }
    return _get('/social/following', accessToken);
  }

  static Future<Map<String, dynamic>> sendContactRequest({
    required String accessToken,
    required String userId,
  }) async {
    return _postWithAuth('/social/contacts/request/$userId', accessToken, const <String, dynamic>{});
  }

  static Future<Map<String, dynamic>> acceptContactRequest({
    required String accessToken,
    required String userId,
  }) async {
    return _postWithAuth('/social/contacts/accept/$userId', accessToken, const <String, dynamic>{});
  }

  static Future<Map<String, dynamic>> rejectContactRequest({
    required String accessToken,
    required String userId,
  }) async {
    return _postWithAuth('/social/contacts/reject/$userId', accessToken, const <String, dynamic>{});
  }

  static Future<Map<String, dynamic>> removeContact({
    required String accessToken,
    required String userId,
  }) async {
    return _delete('/social/contacts/$userId', accessToken);
  }

  static Future<Map<String, dynamic>> listContacts({
    required String accessToken,
    String? userId,
  }) async {
    if (userId != null && userId.trim().isNotEmpty) {
      return _get('/social/users/$userId/contacts', accessToken);
    }
    return _get('/social/contacts', accessToken);
  }

  static Future<Map<String, dynamic>> listContactRequests({
    required String accessToken,
  }) async {
    return _get('/social/contacts/requests', accessToken);
  }

  static Future<Map<String, dynamic>> getSocialSummary({
    required String accessToken,
    required String userId,
  }) async {
    return _get('/social/users/$userId/summary', accessToken);
  }

  static Future<Map<String, dynamic>> getPrivacySettings({
    required String accessToken,
  }) async {
    return _get('/social/privacy', accessToken);
  }

  static Future<Map<String, dynamic>> updatePrivacySettings({
    required String accessToken,
    String? messagesPrivacy,
    bool? showFollowerList,
    bool? showContactList,
  }) async {
    return _patch('/social/privacy', accessToken, {
      'messagesPrivacy': messagesPrivacy,
      'showFollowerList': showFollowerList,
      'showContactList': showContactList,
    });
  }

  static Future<Map<String, dynamic>> listSocialNotifications({
    required String accessToken,
  }) async {
    return _get('/social/notifications', accessToken);
  }

  static Future<Map<String, dynamic>> markAllSocialNotificationsRead({
    required String accessToken,
  }) async {
    return _postWithAuth(
      '/social/notifications/read',
      accessToken,
      const <String, dynamic>{},
    );
  }

  static Future<Map<String, dynamic>> listAuditLogs({
    required String accessToken,
    String? from,
    String? to,
    String? tableName,
    String? action,
    String? actorUserId,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (from != null && from.trim().isNotEmpty) query['from'] = from;
    if (to != null && to.trim().isNotEmpty) query['to'] = to;
    if (tableName != null && tableName.trim().isNotEmpty) {
      query['tableName'] = tableName;
    }
    if (action != null && action.trim().isNotEmpty) query['action'] = action;
    if (actorUserId != null && actorUserId.trim().isNotEmpty) {
      query['actorUserId'] = actorUserId;
    }

    final uri = Uri.parse(
      '$_baseUrl/audit/logs',
    ).replace(queryParameters: query);
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

  static Future<Map<String, dynamic>> listSecurityEvents({
    required String accessToken,
    String? from,
    String? to,
    String? eventType,
    String? severity,
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (from != null && from.trim().isNotEmpty) query['from'] = from;
    if (to != null && to.trim().isNotEmpty) query['to'] = to;
    if (eventType != null && eventType.trim().isNotEmpty) {
      query['eventType'] = eventType;
    }
    if (severity != null && severity.trim().isNotEmpty) {
      query['severity'] = severity;
    }

    final uri = Uri.parse(
      '$_baseUrl/audit/security-events',
    ).replace(queryParameters: query);
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

  static Future<Map<String, dynamic>> createMarketplaceActivity({
    required String accessToken,
    String section = 'services',
    required String categoryKey,
    String? subcategoryKey,
    required String title,
    required String description,
    required double amountRon,
    required int durationHours,
    required String country,
    required String county,
    required String city,
    required DateTime startAt,
    required bool isRecurring,
    String? recurrencePattern,
    List<int>? recurrenceDays,
    String? recurrenceLabel,
    bool mealIncluded = false,
  }) async {
    return _postWithAuth('/activities', accessToken, {
      'section': section,
      'categoryKey': categoryKey,
      'subcategoryKey': subcategoryKey,
      'title': title,
      'description': description,
      'amountRon': amountRon,
      'durationHours': durationHours,
      'country': country,
      'county': county,
      'city': city,
      'startAt': startAt.toUtc().toIso8601String(),
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceLabel': recurrenceLabel,
      'mealIncluded': mealIncluded,
    });
  }

  static Future<Map<String, dynamic>> updateMarketplaceActivity({
    required String accessToken,
    required String activityId,
    String? section,
    String? categoryKey,
    String? subcategoryKey,
    String? title,
    String? description,
    double? amountRon,
    int? durationHours,
    String? country,
    String? county,
    String? city,
    DateTime? startAt,
    bool? isRecurring,
    String? recurrencePattern,
    List<int>? recurrenceDays,
    String? recurrenceLabel,
    bool? mealIncluded,
  }) async {
    return _patch('/activities/$activityId', accessToken, {
      'section': section,
      'categoryKey': categoryKey,
      'subcategoryKey': subcategoryKey,
      'title': title,
      'description': description,
      'amountRon': amountRon,
      'durationHours': durationHours,
      'country': country,
      'county': county,
      'city': city,
      'startAt': startAt?.toUtc().toIso8601String(),
      'isRecurring': isRecurring,
      'recurrencePattern': recurrencePattern,
      'recurrenceDays': recurrenceDays,
      'recurrenceLabel': recurrenceLabel,
      'mealIncluded': mealIncluded,
    });
  }

  static Future<void> deleteMarketplaceActivity({
    required String accessToken,
    required String activityId,
  }) async {
    await _delete('/activities/$activityId', accessToken);
  }

  static Future<Map<String, dynamic>> acceptMarketplaceActivity({
    required String accessToken,
    required String activityId,
  }) async {
    return _postWithAuth('/activities/$activityId/accept', accessToken, {});
  }

  static Future<Map<String, dynamic>> removeMarketplaceProvider({
    required String accessToken,
    required String activityId,
  }) async {
    return _postWithAuth(
      '/activities/$activityId/remove-provider',
      accessToken,
      {},
    );
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

  static Future<String> uploadPostAttachment({
    required String accessToken,
    required String attachmentType,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final data = await uploadAttachment(
      accessToken: accessToken,
      attachmentType: attachmentType,
      targetType: 'user',
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );

    return data['attachmentId']?.toString() ?? '';
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

  static Future<Map<String, dynamic>> _put(
    String path,
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.put(
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

  static Future<Map<String, dynamic>> _delete(
    String path,
    String accessToken,
  ) async {
    final uri = Uri.parse('$_baseUrl$path');

    final response = await http.delete(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
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
