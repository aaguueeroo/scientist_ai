import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/user_api_keys_constants.dart';
import '../dto/api_error_dto.dart';
import 'scientist_backend_client.dart';

/// Real-network implementation against the FastAPI backend.
class HttpScientistBackendClient implements ScientistBackendClient {
  HttpScientistBackendClient({
    required this.baseUrl,
    this.openAiApiKeyProvider,
    this.tavilyApiKeyProvider,
  });

  final Uri baseUrl;

  /// Returns the active OpenAI API key for this request, or null to omit the header.
  final String? Function()? openAiApiKeyProvider;

  /// Returns the active Tavily API key for this request, or null to omit the header.
  final String? Function()? tavilyApiKeyProvider;

  Uri _resolve(String path) {
    final String base = baseUrl.toString().replaceAll(RegExp(r'/+$'), '');
    final String p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p');
  }

  void _maybeAttachOpenAiKeyHeader(HttpClientRequest request) {
    final String? Function()? provider = openAiApiKeyProvider;
    if (provider == null) {
      return;
    }
    final String? key = provider();
    if (key == null || key.isEmpty) {
      return;
    }
    request.headers.set(kOpenAiApiKeyHttpHeader, key);
  }

  void _maybeAttachTavilyKeyHeader(HttpClientRequest request) {
    final String? Function()? provider = tavilyApiKeyProvider;
    if (provider == null) {
      return;
    }
    final String? key = provider();
    if (key == null || key.isEmpty) {
      return;
    }
    request.headers.set(kTavilyApiKeyHttpHeader, key);
  }

  void _maybeAttachAgentApiKeyHeaders(HttpClientRequest request) {
    _maybeAttachOpenAiKeyHeader(request);
    _maybeAttachTavilyKeyHeader(request);
  }

  @override
  Stream<Map<String, dynamic>> streamLiteratureReview(
    Map<String, dynamic> requestBody,
  ) async* {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.postUrl(_resolve('literature-review'));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
      _maybeAttachAgentApiKeyHeaders(request);
      request.write(jsonEncode(requestBody));
      final HttpClientResponse response = await request.close();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode != HttpStatus.ok) {
        final String body =
            await response.transform(utf8.decoder).join();
        throw _transportFromHttp(
          response.statusCode,
          body,
          headerRequestId: headerRequestId,
        );
      }
      final Stream<String> lines = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final String line in lines) {
        if (line.isEmpty) {
          continue;
        }
        if (line.startsWith('data:')) {
          final String payload = line.substring(5).trim();
          if (payload.isEmpty) {
            continue;
          }
          try {
            final Object? decoded = jsonDecode(payload);
            if (decoded is Map<String, dynamic>) {
              yield decoded;
            }
          } on FormatException {
            throw ScientistTransportException(
              code: 'parse_error',
              message: 'Malformed SSE payload from literature review.',
              statusCode: response.statusCode,
              requestId: headerRequestId,
            );
          }
        }
      }
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> postExperimentPlan(
    Map<String, dynamic> requestBody,
  ) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.postUrl(_resolve('experiment-plan'));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      _maybeAttachAgentApiKeyHeaders(request);
      request.write(jsonEncode(requestBody));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final Object? decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } on FormatException {
          throw ScientistTransportException(
            code: 'parse_error',
            message: 'Experiment plan response was not valid JSON.',
            statusCode: response.statusCode,
            requestId: headerRequestId,
          );
        }
        throw ScientistTransportException(
          code: 'parse_error',
          message: 'Experiment plan response was not a JSON object.',
          statusCode: response.statusCode,
          requestId: headerRequestId,
        );
      }
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> postFeedback(
    Map<String, dynamic> requestBody,
  ) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.postUrl(_resolve('feedback'));
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      _maybeAttachAgentApiKeyHeaders(request);
      request.write(jsonEncode(requestBody));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchConversations() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.getUrl(_resolve('conversations'));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<void> deletePlan(String planId) async {
    final HttpClient client = HttpClient();
    try {
      final String encoded = Uri.encodeComponent(planId);
      final HttpClientRequest request =
          await client.deleteUrl(_resolve('plans/$encoded'));
      final HttpClientResponse response = await request.close();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode == 204 ||
          response.statusCode == 200 ||
          response.statusCode == 404) {
        await response.drain<void>();
        return;
      }
      final String body = await response.transform(utf8.decoder).join();
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> getPlanById(String planId) async {
    final HttpClient client = HttpClient();
    try {
      final String encoded = Uri.encodeComponent(planId);
      final HttpClientRequest request =
          await client.getUrl(_resolve('plans/$encoded'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> fetchReviews() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.getUrl(_resolve('feedback'));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();
      final String? headerRequestId =
          response.headers.value('x-request-id') ??
              response.headers.value('X-Request-ID');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
      throw _transportFromHttp(
        response.statusCode,
        body,
        headerRequestId: headerRequestId,
      );
    } on ScientistTransportException {
      rethrow;
    } on SocketException catch (e) {
      throw ScientistTransportException(
        code: 'network_error',
        message: e.message,
      );
    } finally {
      client.close(force: true);
    }
  }

  ScientistTransportException _transportFromHttp(
    int statusCode,
    String body, {
    String? headerRequestId,
  }) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final ApiErrorDto err = ApiErrorDto.fromJson(decoded);
        return ScientistTransportException(
          code: err.code,
          message: err.message,
          statusCode: statusCode,
          requestId: err.requestId ?? headerRequestId,
        );
      }
    } catch (_) {
      // fall through
    }
    return ScientistTransportException(
      code: 'http_$statusCode',
      message: body.isNotEmpty ? body : 'Request failed ($statusCode).',
      statusCode: statusCode,
      requestId: headerRequestId,
    );
  }
}
