// -----------------------------------------------------------------------------
// Spirit-flavored refactor (snake_case): все классы и переменные в машинном стиле
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';

import 'package:appsflyer_sdk/appsflyer_sdk.dart' show AppsFlyerOptions, AppsflyerSdk;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodCall, MethodChannel, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Предполагаемые новые имена экранов в main.dart
import 'main.dart' show SpiritMafiaHarbor, SpiritCaptainHarbor, CaptainHarbor, CaptainDeck, captain_harbor;

// ============================================================================
// Паттерны/инфраструктура (spirit edition, snake_case)
// ============================================================================

class spirit_black_box {
  const spirit_black_box();
  void spirit_log(Object msg) => debugPrint('[SpiritBlackBox] $msg');
  void spirit_warn(Object msg) => debugPrint('[SpiritBlackBox/WARN] $msg');
  void spirit_err(Object msg) => debugPrint('[SpiritBlackBox/ERR] $msg');
}

class spirit_rum_chest {
  static final spirit_rum_chest _spirit_single = spirit_rum_chest._spirit();
  spirit_rum_chest._spirit();
  factory spirit_rum_chest() => _spirit_single;

  final spirit_black_box spirit_box = const spirit_black_box();
}

/// Утилиты маршрутов/почты (Spirit Sextant)
class spirit_sextant_kit {
  // Похоже ли на голый e-mail (без схемы)
  static bool looks_like_bare_mail(Uri spirit_uri) {
    final s = spirit_uri.scheme;
    if (s.isNotEmpty) return false;
    final raw = spirit_uri.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  // Превращает "bare" или обычный URL в mailto:
  static Uri to_mailto(Uri spirit_uri) {
    final full = spirit_uri.toString();
    final bits = full.split('?');
    final who = bits.first;
    final qp = bits.length > 1 ? Uri.splitQueryString(bits[1]) : <String, String>{};
    return Uri(
      scheme: 'mailto',
      path: who,
      queryParameters: qp.isEmpty ? null : qp,
    );
  }

  // Делает Gmail compose-ссылку
  static Uri gmailize(Uri spirit_mailto) {
    final qp = spirit_mailto.queryParameters;
    final params = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (spirit_mailto.path.isNotEmpty) 'to': spirit_mailto.path,
      if ((qp['subject'] ?? '').isNotEmpty) 'su': qp['subject']!,
      if ((qp['body'] ?? '').isNotEmpty) 'body': qp['body']!,
      if ((qp['cc'] ?? '').isNotEmpty) 'cc': qp['cc']!,
      if ((qp['bcc'] ?? '').isNotEmpty) 'bcc': qp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', params);
  }

  static String just_digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');
}

/// Сервис открытия внешних ссылок/протоколов (Spirit Messenger)
class spirit_parrot_signal {
  static Future<bool> open(Uri spirit_uri) async {
    try {
      if (await launchUrl(spirit_uri, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(spirit_uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('SpiritParrotSignal error: $e; url=$spirit_uri');
      try {
        return await launchUrl(spirit_uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }
}

// ============================================================================
// FCM Background Handler — дух-попугай
// ============================================================================
@pragma('vm:entry-point')
Future<void> spirit_bg_parrot(RemoteMessage spirit_bottle) async {
  debugPrint("Spirit Bottle ID: ${spirit_bottle.messageId}");
  debugPrint("Spirit Bottle Data: ${spirit_bottle.data}");
}

// ============================================================================
// Виджет-каюта с webview — spirit_captain_deck
// ============================================================================
class spirit_captain_deckload extends StatefulWidget with WidgetsBindingObserver {
  String spirit_sea_route;
  spirit_captain_deckload(this.spirit_sea_route, {super.key});

  @override
  State<spirit_captain_deckload> createState() => _spirit_captain_deckload_state(spirit_sea_route);
}

class _spirit_captain_deckload_state extends State<spirit_captain_deckload> with WidgetsBindingObserver {
  _spirit_captain_deckload_state(this._spirit_current_route);

  final spirit_rum_chest _spirit_rum = spirit_rum_chest();

  late InAppWebViewController _spirit_helm; // штурвал
  String? _spirit_parrot_token; // FCM token
  String? _spirit_ship_id; // device id
  String? _spirit_ship_build; // os build
  String? _spirit_ship_kind; // android/ios
  String? _spirit_ship_os; // locale/lang
  String? _spirit_app_sextant; // timezone
  bool _spirit_cannon_armed = true; // push enabled
  bool _spirit_crew_busy = false;
  var _spirit_gate_open = true;
  String _spirit_current_route;
  DateTime? _spirit_last_dock_time;

  // Внешние гавани (tg/wa/bnl)
  final Set<String> _spirit_harbor_hosts = {
    't.me', 'telegram.me', 'telegram.dog',
    'wa.me', 'api.whatsapp.com', 'chat.whatsapp.com',
    'bnl.com', 'www.bnl.com',
  };
  final Set<String> _spirit_harbor_schemes = {'tg', 'telegram', 'whatsapp', 'bnl'};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    FirebaseMessaging.onBackgroundMessage(spirit_bg_parrot);

    _spirit_rig_parrot_fcm();
    _spirit_scan_ship_gizmo();
    _spirit_wire_foredeck_fcm();
    _bind_bell();

    Future.delayed(const Duration(seconds: 2), () {});
    Future.delayed(const Duration(seconds: 6), () {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState spirit_tide) {
    if (spirit_tide == AppLifecycleState.paused) {
      _spirit_last_dock_time = DateTime.now();
    }
    if (spirit_tide == AppLifecycleState.resumed) {
      if (Platform.isIOS && _spirit_last_dock_time != null) {
        final now = DateTime.now();
        final drift = now.difference(_spirit_last_dock_time!);
        if (drift > const Duration(minutes: 25)) {
          _spirit_hard_reload_to_harbor();
        }
      }
      _spirit_last_dock_time = null;
    }
  }

  void _spirit_hard_reload_to_harbor() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) =>captain_harbor(signal: "")),
            (route) => false,
      );
    });
  }

  // --------------------------------------------------------------------------
  // Каналы связи
  // --------------------------------------------------------------------------
  void _spirit_wire_foredeck_fcm() {
    FirebaseMessaging.onMessage.listen((RemoteMessage spirit_bottle) {
      if (spirit_bottle.data['uri'] != null) {
        _spirit_sail_to(spirit_bottle.data['uri'].toString());
      } else {
        _spirit_return_to_course();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage spirit_bottle) {
      if (spirit_bottle.data['uri'] != null) {
        _spirit_sail_to(spirit_bottle.data['uri'].toString());
      } else {
        _spirit_return_to_course();
      }
    });
  }

  void _spirit_sail_to(String spirit_new_lane) async {
    await _spirit_helm.loadUrl(urlRequest: URLRequest(url: WebUri(spirit_new_lane)));
  }

  void _spirit_return_to_course() async {
    Future.delayed(const Duration(seconds: 3), () {
      _spirit_helm.loadUrl(urlRequest: URLRequest(url: WebUri(_spirit_current_route)));
    });
  }

  Future<void> _spirit_rig_parrot_fcm() async {
    FirebaseMessaging spirit_deck = FirebaseMessaging.instance;
    await spirit_deck.requestPermission(alert: true, badge: true, sound: true);
    _spirit_parrot_token = await spirit_deck.getToken();
  }

  // --------------------------------------------------------------------------
  // Досье корабля
  // --------------------------------------------------------------------------
  Future<void> _spirit_scan_ship_gizmo() async {
    try {
      final spirit_spy = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await spirit_spy.androidInfo;
        _spirit_ship_id = a.id;
        _spirit_ship_kind = "android";
        _spirit_ship_build = a.version.release;
      } else if (Platform.isIOS) {
        final i = await spirit_spy.iosInfo;
        _spirit_ship_id = i.identifierForVendor;
        _spirit_ship_kind = "ios";
        _spirit_ship_build = i.systemVersion;
      }
      final spirit_pkg = await PackageInfo.fromPlatform();
      _spirit_ship_os = Platform.localeName.split('_')[0];
      _spirit_app_sextant = timezone.local.name;
    } catch (e) {
      debugPrint("Spirit Ship Gizmo Error: $e");
    }
  }

  void _bind_bell() {
    MethodChannel('com.example.fcm/notification').setMethodCallHandler((call) async {
      if (call.method == "onNotificationTap") {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(call.arguments);
        if (payload["uri"] != null && !payload["uri"].contains("Нет URI")) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => spirit_captain_deckload(payload["uri"].toString())),
                (route) => false,
          );
        }
      }
    });
  }

  // --------------------------------------------------------------------------
  // Построение UI
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    _bind_bell(); // повторная привязка

    final spirit_is_night = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: spirit_is_night ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                disableDefaultErrorPage: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: true,
              ),
              initialUrlRequest: URLRequest(url: WebUri(_spirit_current_route)),
              onWebViewCreated: (spirit_controller) {
                _spirit_helm = spirit_controller;

                _spirit_helm.addJavaScriptHandler(
                  handlerName: 'onServerResponse',
                  callback: (spirit_args) {
                    _spirit_rum.spirit_box.spirit_log("JS Args: $spirit_args");
                    try {
                      return spirit_args.reduce((v, e) => v + e);
                    } catch (_) {
                      return spirit_args.toString();
                    }
                  },
                );
              },
              onLoadStart: (spirit_controller, spirit_uri) async {
                if (spirit_uri != null) {
                  if (spirit_sextant_kit.looks_like_bare_mail(spirit_uri)) {
                    try {
                      await spirit_controller.stopLoading();
                    } catch (_) {}
                    final mailto = spirit_sextant_kit.to_mailto(spirit_uri);
                    await spirit_parrot_signal.open(spirit_sextant_kit.gmailize(mailto));
                    return;
                  }
                  final s = spirit_uri.scheme.toLowerCase();
                  if (s != 'http' && s != 'https') {
                    try {
                      await spirit_controller.stopLoading();
                    } catch (_) {}
                  }
                }
              },
              onLoadStop: (spirit_controller, spirit_uri) async {
                await spirit_controller.evaluateJavascript(source: "console.log('Ahoy from JS!');");
              },
              shouldOverrideUrlLoading: (spirit_controller, spirit_nav) async {
                final spirit_uri = spirit_nav.request.url;
                if (spirit_uri == null) return NavigationActionPolicy.ALLOW;

                if (spirit_sextant_kit.looks_like_bare_mail(spirit_uri)) {
                  final mailto = spirit_sextant_kit.to_mailto(spirit_uri);
                  await spirit_parrot_signal.open(spirit_sextant_kit.gmailize(mailto));
                  return NavigationActionPolicy.CANCEL;
                }

                final sch = spirit_uri.scheme.toLowerCase();
                if (sch == 'mailto') {
                  await spirit_parrot_signal.open(spirit_sextant_kit.gmailize(spirit_uri));
                  return NavigationActionPolicy.CANCEL;
                }

                if (_spirit_is_outer_harbor(spirit_uri)) {
                  await spirit_parrot_signal.open(_spirit_map_outer_to_http(spirit_uri));
                  return NavigationActionPolicy.CANCEL;
                }

                if (sch != 'http' && sch != 'https') {
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onCreateWindow: (spirit_controller, spirit_req) async {
                final u = spirit_req.request.url;
                if (u == null) return false;

                if (spirit_sextant_kit.looks_like_bare_mail(u)) {
                  final m = spirit_sextant_kit.to_mailto(u);
                  await spirit_parrot_signal.open(spirit_sextant_kit.gmailize(m));
                  return false;
                }

                final sch = u.scheme.toLowerCase();
                if (sch == 'mailto') {
                  await spirit_parrot_signal.open(spirit_sextant_kit.gmailize(u));
                  return false;
                }

                if (_spirit_is_outer_harbor(u)) {
                  await spirit_parrot_signal.open(_spirit_map_outer_to_http(u));
                  return false;
                }

                if (sch == 'http' || sch == 'https') {
                  spirit_controller.loadUrl(urlRequest: URLRequest(url: u));
                }
                return false;
              },
            ),

            if (_spirit_crew_busy)
              Positioned.fill(
                child: Container(
                  color: Colors.black87,
                  child: Center(
                    child: CircularProgressIndicator(
                      backgroundColor: Colors.grey.shade800,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                      strokeWidth: 6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // Пиратские утилиты маршрутов (протоколы/внешние гавани)
  // ========================================================================
  bool _spirit_is_outer_harbor(Uri spirit_uri) {
    final sch = spirit_uri.scheme.toLowerCase();
    if (_spirit_harbor_schemes.contains(sch)) return true;

    if (sch == 'http' || sch == 'https') {
      final h = spirit_uri.host.toLowerCase();
      if (_spirit_harbor_hosts.contains(h)) return true;
    }
    return false;
  }

  Uri _spirit_map_outer_to_http(Uri spirit_uri) {
    final sch = spirit_uri.scheme.toLowerCase();

    if (sch == 'tg' || sch == 'telegram') {
      final qp = spirit_uri.queryParameters;
      final domain = qp['domain'];
      if (domain != null && domain.isNotEmpty) {
        return Uri.https('t.me', '/$domain', {
          if (qp['start'] != null) 'start': qp['start']!,
        });
      }
      final path = spirit_uri.path.isNotEmpty ? spirit_uri.path : '';
      return Uri.https('t.me', '/$path', qp.isEmpty ? null : qp);
    }

    if (sch == 'whatsapp') {
      final qp = spirit_uri.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${spirit_sextant_kit.just_digits(phone)}', {
          if (text != null && text.isNotEmpty) 'text': text,
        });
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if (sch == 'bnl') {
      final new_path = spirit_uri.path.isNotEmpty ? spirit_uri.path : '';
      return Uri.https('bnl.com', '/$new_path', spirit_uri.queryParameters.isEmpty ? null : spirit_uri.queryParameters);
    }

    return spirit_uri;
  }
}