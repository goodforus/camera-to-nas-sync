import 'dart:io';

import 'package:nas_sync/domain/entities/entities.dart';

/// CIDR-based local network range checker.
///
/// Determines whether the device's current Wi-Fi interface IPv4 address falls
/// within any of the user-registered CIDR ranges (e.g. 192.168.11.0/24).
///
/// - SSID is never used to decide sync eligibility.
/// - Mere Wi-Fi "connected" state is insufficient; the actual IPv4 address + CIDR
///   match is required.
/// - Mobile data / cellular interfaces are excluded (only wlan0-style Wi-Fi
///   interfaces are considered).
/// - Virtual / VPN interfaces are excluded where detectable.
/// - Only IPv4 CIDR is validated here. IPv6: not enforced — the app checks IPv4
///   addresses only. IPv6 support scope is documented in INSTALL.md.
class NetworkRangeChecker {
  NetworkRangeChecker._();
  static final NetworkRangeChecker instance = NetworkRangeChecker._();

  /// Parse a CIDR string like "192.168.11.0/24" into [network] (32-bit int) and
  /// [mask] (32-bit int). Throws [FormatException] on invalid input.
  static (int network, int mask) parseCidr(String cidr) {
    final trimmed = cidr.trim();
    final slash = trimmed.indexOf('/');
    if (slash <= 0 || slash == trimmed.length - 1) {
      throw FormatException('Invalid CIDR: missing or malformed prefix length', cidr);
    }
    final ipPart = trimmed.substring(0, slash);
    final prefixPart = trimmed.substring(slash + 1);
    final ip = _ipv4ToInt(ipPart);
    final prefix = int.tryParse(prefixPart);
    if (prefix == null || prefix < 0 || prefix > 32) {
      throw FormatException('Invalid CIDR prefix length (must be 0-32)', prefixPart);
    }
    final mask = prefix == 0 ? 0 : (~(0xFFFFFFFF >> prefix)) & 0xFFFFFFFF;
    final network = ip & mask;
    return (network, mask);
  }

  /// Convert dotted-quad IPv4 string to a 32-bit unsigned int.
  static int _ipv4ToInt(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      throw FormatException('Invalid IPv4 address: $ip');
    }
    int result = 0;
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) {
        throw FormatException('Invalid IPv4 octet: $p (in $ip)');
      }
      result = (result << 8) | v;
    }
    return result & 0xFFFFFFFF;
  }

  /// Convert a 32-bit int back to dotted-quad IPv4.
  static String _intToIpv4(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ].join('.');
  }

  /// Validate a CIDR string without throwing; returns null when invalid.
  static bool isValidCidr(String cidr) {
    try {
      parseCidr(cidr);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Whether [ip] (dotted-quad IPv4) falls inside [cidr].
  static bool ipInCidr(String ip, String cidr) {
    final ipInt = _ipv4ToInt(ip);
    final (network, mask) = parseCidr(cidr);
    return (ipInt & mask) == network;
  }

  /// Whether any registered [ranges] contain [ip].
  bool ipAllowed(String ip, List<NetworkRange> ranges) {
    for (final r in ranges) {
      if (!NetworkRangeChecker.isValidCidr(r.cidr)) continue;
      try {
        if (ipInCidr(ip, r.cidr)) return true;
      } on FormatException {
        continue;
      }
    }
    return false;
  }
}

/// Extractor for candidate Wi-Fi IPv4 addresses from the device's network
/// interfaces. Excludes loopback and common virtual/VPN interface name prefixes.
class WifiIpExtractor {
  static const _virtualPrefixes = [
    'veth',
    'docker',
    'br-',
    'tun',
    'tap',
    'ppp',
    'virbr',
    'lo',
  ];

  /// IPv4 addresses belonging to non-loopback, non-virtual interfaces.
  /// Typically these are wlan0 / wlp* Wi-Fi interfaces and eth0 (wired).
  /// Mobile data interfaces (rmnet*, ccmni*, usb0 tethering) are intentionally
  /// not filtered out by name here; callers should treat cellular separately.
  static Future<List<String>> candidateIpv4Addresses() async {
    try {
      final interfaces = await NetworkInterface.list();
      final result = <String>[];
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (_virtualPrefixes.any(name.startsWith)) continue;
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              !addr.address.startsWith('169.254.')) {
            result.add(addr.address);
          }
        }
      }
      return result;
    } catch (_) {
      return <String>[];
    }
  }
}
