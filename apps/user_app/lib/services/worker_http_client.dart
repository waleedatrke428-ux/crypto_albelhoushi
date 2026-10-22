import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _workerHost = 'nameless-brook-137e.waleedaltrke428.workers.dev';
const _dnsTimeout = Duration(seconds: 5);
const _requestTimeout = Duration(seconds: 35);

class WorkerHttpClient extends http.BaseClient {
  WorkerHttpClient() : _inner = _createClient();

  final http.Client _inner;

  static http.Client _createClient() {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 20);
    ioClient.connectionFactory = _connect;
    return IOClient(ioClient);
  }

  static Future<ConnectionTask<Socket>> _connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (proxyHost != null) {
      return Socket.startConnect(proxyHost, proxyPort ?? uri.port);
    }
    if (uri.host != _workerHost) {
      return Socket.startConnect(uri.host, uri.port);
    }

    try {
      final addresses = await InternetAddress.lookup(
        uri.host,
        type: InternetAddressType.IPv4,
      ).timeout(_dnsTimeout);
      if (addresses.isEmpty) {
        throw SocketException('System DNS returned no addresses for ${uri.host}');
      }
      return Socket.startConnect(addresses.first, uri.port);
    } on SocketException {
      return _connectWithDnsOverHttps(uri);
    } on TimeoutException {
      return _connectWithDnsOverHttps(uri);
    }
  }

  static Future<ConnectionTask<Socket>> _connectWithDnsOverHttps(
    Uri uri,
  ) async {
    Object? lastError;
    const resolvers = [
      (host: 'cloudflare-dns.com', ip: '1.1.1.1', path: '/dns-query'),
      (host: 'dns.google', ip: '8.8.8.8', path: '/resolve'),
    ];

    for (final resolver in resolvers) {
      final client = _createDnsClient(resolver.host, resolver.ip);
      try {
        final response = await client
            .get(
              Uri.https(resolver.host, resolver.path, {
                'name': uri.host,
                'type': 'A',
              }),
              headers: const {'accept': 'application/dns-json'},
            )
            .timeout(_dnsTimeout);
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException(
            'DNS-over-HTTPS returned HTTP ${response.statusCode}',
          );
        }

        final payload = jsonDecode(response.body);
        if (payload is! Map<String, dynamic> || payload['Answer'] is! List) {
          throw const FormatException('DNS-over-HTTPS returned an invalid response');
        }
        for (final answer in payload['Answer'] as List) {
          if (answer is Map<String, dynamic> &&
              answer['type'] == 1 &&
              answer['data'] is String) {
            final address = InternetAddress.tryParse(answer['data'] as String);
            if (address != null && address.type == InternetAddressType.IPv4) {
              return Socket.startConnect(address, uri.port);
            }
          }
        }
        throw SocketException(
          'DNS-over-HTTPS returned no IPv4 address for ${uri.host}',
        );
      } on Exception catch (error) {
        lastError = error;
      } finally {
        client.close();
      }
    }

    throw SocketException(
      'System DNS and DNS-over-HTTPS failed for ${uri.host}: $lastError',
    );
  }

  static http.Client _createDnsClient(String resolverHost, String resolverIp) {
    final ioClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    ioClient.connectionFactory = (uri, proxyHost, proxyPort) {
      if (proxyHost != null) {
        return Socket.startConnect(proxyHost, proxyPort ?? uri.port);
      }
      if (uri.host != resolverHost) {
        return Socket.startConnect(uri.host, uri.port);
      }
      return Socket.startConnect(InternetAddress(resolverIp), uri.port);
    };
    return IOClient(ioClient);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request).timeout(_requestTimeout);
    return http.StreamedResponse(
      response.stream.timeout(_requestTimeout),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => _inner.close();
}
