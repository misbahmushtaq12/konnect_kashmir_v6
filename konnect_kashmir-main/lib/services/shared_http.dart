import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// One HTTP client for the whole app. `http.get(...)` on its own opens a new
/// connection (new TCP + TLS handshake) for every request; sharing a client keeps
/// connections open, so repeat requests to Supabase start faster.
///
/// It also copes with networks whose DNS cannot find our server: some Indian
/// mobile networks (for example Jio) fail to resolve `*.supabase.co`, while the
/// same address works on Wi-Fi. When the phone's own DNS fails, the server's
/// address is looked up over HTTPS (Cloudflare / Google DNS-over-HTTPS) and the
/// connection is made to that address. The TLS check still uses the real host
/// name, so the connection is exactly as secure as before.
final http.Client sharedHttp = _build();

http.Client _build() {
  final inner = HttpClient()..connectionFactory = connectWithDnsFallback;
  return IOClient(inner);
}

/// Addresses found over HTTPS, kept for a few minutes. While an entry is fresh the
/// phone's own DNS is not asked again (it is known to be failing), so only the
/// first request on such a network waits.
final Map<String, ({List<InternetAddress> addrs, DateTime at})> _dohCache = {};
const Duration _dohFresh = Duration(minutes: 5);

List<InternetAddress>? _freshDoh(String host) {
  final hit = _dohCache[host];
  if (hit == null) return null;
  return DateTime.now().difference(hit.at) < _dohFresh ? hit.addrs : null;
}

/// Used as the HttpClient's connection factory (public so it can be tested).
/// With a factory, the client no longer starts TLS by itself, so this does it:
/// the secure handshake is made against the real host name, whatever address
/// the connection went to.
Future<ConnectionTask<Socket>> connectWithDnsFallback(
    Uri uri, String? proxyHost, int? proxyPort,
    {bool forceFallback = false}) async {
  // Through a proxy the client tunnels and secures the connection itself.
  if (proxyHost != null) {
    return Socket.startConnect(proxyHost, proxyPort ?? 8080);
  }
  final host = uri.host;
  final port = uri.port;
  final secure = uri.scheme == 'https';

  if (!forceFallback && _freshDoh(host) == null) {
    // Normal case: the phone's own DNS works.
    List<InternetAddress> found = const [];
    try {
      found = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    if (found.isNotEmpty) {
      return secure
          ? SecureSocket.startConnect(host, port)
          : Socket.startConnect(host, port);
    }
  }

  // The phone's DNS could not find the host: ask a public DNS over HTTPS.
  final addrs = await resolveOverHttps(host);
  if (addrs.isEmpty) {
    // Nothing worked: connect the normal way and fail with its own error.
    return secure
        ? SecureSocket.startConnect(host, port)
        : Socket.startConnect(host, port);
  }
  final task = await Socket.startConnect(addrs.first, port);
  if (!secure) return task;
  final Future<Socket> upgraded =
      task.socket.then<Socket>((s) => SecureSocket.secure(s, host: host));
  return ConnectionTask.fromSocket(upgraded, task.cancel);
}

/// The IPv4 addresses of [host] from public DNS-over-HTTPS servers.
Future<List<InternetAddress>> resolveOverHttps(String host) async {
  final cached = _freshDoh(host);
  if (cached != null) return cached;
  // The servers are reached by IP address, so no DNS is needed to ask them.
  for (final base in const [
    'https://1.1.1.1/dns-query',
    'https://8.8.8.8/resolve',
    'https://1.0.0.1/dns-query',
  ]) {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final req = await client
          .getUrl(Uri.parse('$base?name=$host&type=A'))
          .timeout(const Duration(seconds: 5));
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) continue;
      final body = await res.transform(utf8.decoder).join();
      final answers = (jsonDecode(body)['Answer'] as List?) ?? const [];
      final out = <InternetAddress>[
        for (final a in answers)
          if (a is Map && a['type'] == 1)
            if (InternetAddress.tryParse('${a['data']}') != null)
              InternetAddress.tryParse('${a['data']}')!,
      ];
      if (out.isNotEmpty) {
        _dohCache[host] = (addrs: out, at: DateTime.now());
        return out;
      }
    } catch (_) {
      // try the next server
    } finally {
      client.close(force: true);
    }
  }
  return const [];
}
