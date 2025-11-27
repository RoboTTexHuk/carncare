import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform, HttpHeaders, HttpClient;

import 'package:appsflyer_sdk/appsflyer_sdk.dart' as af_core;
import 'package:carncare/pushcare.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, SystemChrome, SystemUiOverlayStyle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as r;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz_zone;



// ============================================================================
// Константы (пиратские флаги)
// ============================================================================
const String k_loaded_event_sent_once = "loaded_event_sent_once";
const String k_ship_stat_endpoint = "https://api.ncarcare.autos/stat";
const String k_cached_fcm_token = "cached_fcm_token";

// ============================================================================
// Сервисы/синглтоны
// ============================================================================
class rum_barrel {
  static final rum_barrel _instance = rum_barrel._internal();
  rum_barrel._internal();
  factory rum_barrel() => _instance;

  final FlutterSecureStorage chest = const FlutterSecureStorage();
  final ship_log log = ship_log();
  final Connectivity crow_nest = Connectivity();
}

class ship_log {
  final Logger _lg = Logger();
  void i(Object msg) => _lg.i(msg);
  void w(Object msg) => _lg.w(msg);
  void e(Object msg) => _lg.e(msg);
}

// ============================================================================
// Сеть/данные
// ============================================================================
class sea_wire {
  final rum_barrel _rum = rum_barrel();

  Future<bool> is_sea_calm() async {
    final c = await _rum.crow_nest.checkConnectivity();
    return c != ConnectivityResult.none;
  }

  Future<void> cast_bottle_json(String url, Map<String, dynamic> cargo) async {
    try {
      await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(cargo),
      );
    } catch (e) {
      _rum.log.e("castBottleJson error: $e");
    }
  }
}

// ============================================================================
// Досье устройства
// ============================================================================
class quartermaster {
  String? ship_id;
  String? voyage_id = "mafia-one-off";
  String? deck;
  String? deck_build;
  String? app_rum;
  String? sailor_tongue;
  String? sea_zone;
  bool cannon_ready = true;

  Future<void> muster() async {
    final spy = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await spy.androidInfo;
      ship_id = a.id;
      deck = "android";
      deck_build = a.version.release;
    } else if (Platform.isIOS) {
      final i = await spy.iosInfo;
      ship_id = i.identifierForVendor;
      deck = "ios";
      deck_build = i.systemVersion;
    }
    final info = await PackageInfo.fromPlatform();
    app_rum = info.version;
    sailor_tongue = Platform.localeName.split('_')[0];
    sea_zone = tz_zone.local.name;
    voyage_id = "voyage-${DateTime.now().millisecondsSinceEpoch}";
  }

  Map<String, dynamic> as_map({String? parrot}) => {
    "fcm_token": parrot ?? 'missing_token',
    "device_id": ship_id ?? 'missing_id',
    "app_name": "carncare",
    "instance_id": voyage_id ?? 'missing_session',
    "platform": deck ?? 'missing_system',
    "os_version": deck_build ?? 'missing_build',
    "app_version": app_rum ?? 'missing_app',
    "language": sailor_tongue ?? 'en',
    "timezone": sea_zone ?? 'UTC',
    "push_enabled": cannon_ready,
  };
}

// ============================================================================
// AppsFlyer
// ============================================================================
class consigliere_captain with ChangeNotifier {
  af_core.AppsFlyerOptions? _chart;
  af_core.AppsflyerSdk? _spyglass;

  String af_ship_id = "";
  String af_treasure = "";

  void hoist(VoidCallback nudge) {
    final cfg = af_core.AppsFlyerOptions(
      afDevKey: "qsBLmy7dAXDQhowM8V3ca4",
      appId: "6755821962",
      showDebug: true,
      timeToWaitForATTUserAuthorization: 0,
    );
    _chart = cfg;
    _spyglass = af_core.AppsflyerSdk(cfg);

    _spyglass?.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
      registerOnDeepLinkingCallback: true,
    );
    _spyglass?.startSDK(
      onSuccess: () => rum_barrel().log.i("Consigliere hoisted"),
      onError: (int c, String m) => rum_barrel().log.e("Consigliere storm $c: $m"),
    );
    _spyglass?.onInstallConversionData((loot) {
      af_treasure = loot.toString();
      nudge();
      notifyListeners();
    });
    _spyglass?.getAppsFlyerUID().then((v) {
      af_ship_id = v.toString();
      nudge();
      notifyListeners();
    });
  }
}

// ============================================================================
// Riverpod/Provider
// ============================================================================
final r_quartermaster = r.FutureProvider<quartermaster>((ref) async {
  final qm = quartermaster();
  await qm.muster();
  return qm;
});

final p_consigliere = p.ChangeNotifierProvider<consigliere_captain>(
  create: (_) => consigliere_captain(),
);

// ============================================================================
// Parrot (FCM) background
// ============================================================================
@pragma('vm:entry-point')
Future<void> parrot_bg_squawk(RemoteMessage msg) async {
  rum_barrel().log.i("bg-parrot: ${msg.messageId}");
  rum_barrel().log.i("bg-cargo: ${msg.data}");
}

// ============================================================================
// ParrotBridge — токен через нативный канал
// ============================================================================
class parrot_bridge extends ChangeNotifier {
  final rum_barrel _rum = rum_barrel();
  String? _feather;
  final List<void Function(String)> _wait_deck = [];

  String? get token => _feather;

  parrot_bridge() {
    const MethodChannel('com.example.fcm/token').setMethodCallHandler((call) async {
      if (call.method == 'setToken') {
        final String s = call.arguments as String;
        if (s.isNotEmpty) {
          _perch_set(s);
        }
      }
    });
    _restore_feather();
  }

  Future<void> _restore_feather() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final cached = sp.getString(k_cached_fcm_token);
      if (cached != null && cached.isNotEmpty) {
        _perch_set(cached, notify_native: false);
      } else {
        final ss = await _rum.chest.read(key: k_cached_fcm_token);
        if (ss != null && ss.isNotEmpty) {
          _perch_set(ss, notify_native: false);
        }
      }
    } catch (_) {}
  }

  void _perch_set(String t, {bool notify_native = true}) async {
    _feather = t;
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(k_cached_fcm_token, t);
      await _rum.chest.write(key: k_cached_fcm_token, value: t);
    } catch (_) {}
    for (final cb in List.of(_wait_deck)) {
      try {
        cb(t);
      } catch (e) {
        _rum.log.w("parrot-waiter error: $e");
      }
    }
    _wait_deck.clear();
    notifyListeners();
  }

  Future<void> await_feather(Function(String t) on_token) async {
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      if (_feather != null && _feather!.isNotEmpty) {
        on_token(_feather!);
        return;
      }
      _wait_deck.add(on_token);
    } catch (e) {
      _rum.log.e("ParrotBridge awaitFeather: $e");
    }
  }
}

// ============================================================================
// Вестибюль (Splash)
// ============================================================================
class jolly_vestibule extends StatefulWidget {
  const jolly_vestibule({Key? key}) : super(key: key);

  @override
  State<jolly_vestibule> createState() => _jolly_vestibule_state();
}

class _jolly_vestibule_state extends State<jolly_vestibule> {
  final parrot_bridge _parrot = parrot_bridge();
  bool _once = false;
  Timer? _fallback_fuse;
  bool _cover_mute = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));

    _parrot.await_feather((sig) => _sail(sig));
    _fallback_fuse = Timer(const Duration(seconds: 8), () => _sail(''));

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _cover_mute = true);
    });
  }

  void _sail(String sig) {
    if (_once) return;
    _once = true;
    _fallback_fuse?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => captain_harbor(signal: sig)),
    );
  }

  @override
  void dispose() {
    _fallback_fuse?.cancel();
    _parrot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A22),
      body: Stack(
        children: const [
          Center(child: bouncing_loader()),
        ],
      ),
    );
  }
}

// ============================================================================
// MVVM (BosunViewModel + HarborCourier)
// ============================================================================
class bosun_view_model with ChangeNotifier {
  final quartermaster qm;
  final consigliere_captain capo;

  bosun_view_model({required this.qm, required this.capo});

  Map<String, dynamic> cargo_device(String? token) => qm.as_map(parrot: token);

  Map<String, dynamic> cargo_af(String? token) => {
    "content": {
      "af_data": capo.af_treasure,
      "af_id": capo.af_ship_id,
      "fb_app_name": "carncare",
      "app_name": "carncare",
      "deep": null,
      "bundle_identifier": "com.carncare.kolp.carncare",
      "app_version": "1.0.0",
      "apple_id": "6755821962",
      "fcm_token": token ?? "no_token",
      "device_id": qm.ship_id ?? "no_device",
      "instance_id": qm.voyage_id ?? "no_instance",
      "platform": qm.deck ?? "no_type",
      "os_version": qm.deck_build ?? "no_os",
      "app_version": qm.app_rum ?? "no_app",
      "language": qm.sailor_tongue ?? "en",
      "timezone": qm.sea_zone ?? "UTC",
      "push_enabled": qm.cannon_ready,
      "useruid": capo.af_ship_id,
    },
  };
}

class harbor_courier {
  final bosun_view_model model;
  final InAppWebViewController Function() get_web;

  harbor_courier({required this.model, required this.get_web});

  Future<void> stash_device_in_local_storage(String? token) async {
    final m = model.cargo_device(token);
    await get_web().evaluateJavascript(source: '''
localStorage.setItem('app_data', JSON.stringify(${jsonEncode(m)}));
''');
  }

  Future<void> send_raw_to_deck(String? token) async {
    final payload = model.cargo_af(token);
    final json_string = jsonEncode(payload);
    rum_barrel().log.i("SendRawData: $json_string");
    await get_web().evaluateJavascript(source: "sendRawData(${jsonEncode(json_string)});");
  }
}

// ============================================================================
// Переходы/статистика
// ============================================================================
Future<String> chart_final_url(String start_url, {int max_hops = 10}) async {
  final client = HttpClient();

  try {
    var current = Uri.parse(start_url);
    for (int i = 0; i < max_hops; i++) {
      final req = await client.getUrl(current);
      req.followRedirects = false;
      final res = await req.close();
      if (res.isRedirect) {
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null || loc.isEmpty) break;
        final next = Uri.parse(loc);
        current = next.hasScheme ? next : current.resolveUri(next);
        continue;
      }
      return current.toString();
    }
    return current.toString();
  } catch (e) {
    debugPrint("chartFinalUrl error: $e");
    return start_url;
  } finally {
    client.close(force: true);
  }
}

Future<void> post_harbor_stat({
  required String event,
  required int time_start,
  required String url,
  required int time_finish,
  required String app_sid,
  int? first_page_load_ts,
}) async {
  try {
    final final_url = await chart_final_url(url);
    final payload = {
      "event": event,
      "timestart": time_start,
      "timefinsh": time_finish,
      "url": final_url,
      "appleID": "6755821962",
      "open_count": "$app_sid/$time_start",
    };

    print("loadingstatinsic $payload");
    final res = await http.post(
      Uri.parse("$k_ship_stat_endpoint/$app_sid"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    print(" ur _loaded$k_ship_stat_endpoint/$app_sid");
    debugPrint("_postStat status=${res.statusCode} body=${res.body}");
  } catch (e) {
    debugPrint("_postStat error: $e");
  }
}

// ============================================================================
// Главный WebView
// ============================================================================
class captain_harbor extends StatefulWidget {
  final String? signal;
  const captain_harbor({super.key, required this.signal});

  @override
  State<captain_harbor> createState() => _captain_harbor_state();
}

class _captain_harbor_state extends State<captain_harbor> with WidgetsBindingObserver {
  late InAppWebViewController _pier;
  bool _spin_wheel = false;
  final String _home_port = "https://api.ncarcare.autos/";
  final quartermaster _qm = quartermaster();
  final consigliere_captain _capo = consigliere_captain();

  int _hatch = 0;
  DateTime? _nap_time;
  bool _veil = false;
  double _bar_rel = 0.0;
  late Timer _bar_tick;
  final int _warm_secs = 6;
  bool _cover = true;

  bool _once_loaded_signal_sent = false;
  int? _first_page_stamp;

  harbor_courier? _courier;
  bosun_view_model? _bosun;

  String _current_url = "";
  var _start_load_ts = 0;

  final Set<String> _schemes = {
    'tg',
    'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
    'fb',
    'instagram',
    'twitter',
    'x',
  };

  final Set<String> _external_harbors = {
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'm.me',
    'signal.me',
    'bnl.com',
    'www.bnl.com',
    'x.com',
    'www.x.com',
    'twitter.com',
    'www.twitter.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _first_page_stamp = DateTime.now().millisecondsSinceEpoch;

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _cover = false);
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
    });
    Future.delayed(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() => _veil = true);
    });

    _boot_harbor();
  }

  Future<void> _load_loaded_flag() async {
    final sp = await SharedPreferences.getInstance();
    _once_loaded_signal_sent = sp.getBool(k_loaded_event_sent_once) ?? false;
  }

  Future<void> _save_loaded_flag() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(k_loaded_event_sent_once, true);
    _once_loaded_signal_sent = true;
  }

  Future<void> send_loaded_once({required String url, required int timestart}) async {
    if (_once_loaded_signal_sent) {
      print("Loaded already sent, skipping");
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await post_harbor_stat(
      event: "Loaded",
      time_start: timestart,
      time_finish: now,
      url: url,
      app_sid: _capo.af_ship_id,
      first_page_load_ts: _first_page_stamp,
    );
    await _save_loaded_flag();
  }

  void _boot_harbor() {
    _warm_bar();
    _wire_parrot();
    _capo.hoist(() => setState(() {}));
    _bind_bell();
    _prepare_quartermaster();

    Future.delayed(const Duration(seconds: 6), () async {
      await _push_device();
      await _push_af();
    });
  }

  void _wire_parrot() {
    FirebaseMessaging.onMessage.listen((msg) {
      final link = msg.data['uri'];
      if (link != null) {
        _sail(link.toString());
      } else {
        _reset_to_home();
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final link = msg.data['uri'];
      if (link != null) {
        _sail(link.toString());
      } else {
        _reset_to_home();
      }
    });
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

  Future<void> _prepare_quartermaster() async {
    try {
      await _qm.muster();
      await _ask_quartermaster_perms();
      _bosun = bosun_view_model(qm: _qm, capo: _capo);
      _courier = harbor_courier(model: _bosun!, get_web: () => _pier);
      await _load_loaded_flag();
    } catch (e) {
      rum_barrel().log.e("prepare-quartermaster fail: $e");
    }
  }

  Future<void> _ask_quartermaster_perms() async {
    FirebaseMessaging m = FirebaseMessaging.instance;
    await m.requestPermission(alert: true, badge: true, sound: true);
  }

  void _sail(String link) async {
    if (_pier != null) {
      await _pier.loadUrl(urlRequest: URLRequest(url: WebUri(link)));
    }
  }

  void _reset_to_home() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (_pier != null) {
        _pier.loadUrl(urlRequest: URLRequest(url: WebUri(_home_port)));
      }
    });
  }

  Future<void> _push_device() async {
    rum_barrel().log.i("TOKEN ship ${widget.signal}");
    if (!mounted) return;
    setState(() => _spin_wheel = true);
    try {
      await _courier?.stash_device_in_local_storage(widget.signal);
    } finally {
      if (mounted) setState(() => _spin_wheel = false);
    }
  }

  Future<void> _push_af() async {
    await _courier?.send_raw_to_deck(widget.signal);
  }

  void _warm_bar() {
    int n = 0;
    _bar_rel = 0.0;
    _bar_tick = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() {
        n++;
        _bar_rel = n / (_warm_secs * 10);
        if (_bar_rel >= 1.0) {
          _bar_rel = 1.0;
          _bar_tick.cancel();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState tide) {
    if (tide == AppLifecycleState.paused) {
      _nap_time = DateTime.now();
    }
    if (tide == AppLifecycleState.resumed) {
      if (Platform.isIOS && _nap_time != null) {
        final now = DateTime.now();
        final drift = now.difference(_nap_time!);
        if (drift > const Duration(minutes: 25)) {
          _reboard();
        }
      }
      _nap_time = null;
    }
  }

  void _reboard() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => captain_harbor(signal: widget.signal)),
            (route) => false,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bar_tick.cancel();
    super.dispose();
  }

  // ================== URL helpers ==================
  bool _bare_mail(Uri u) {
    final s = u.scheme;
    if (s.isNotEmpty) return false;
    final raw = u.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  Uri _mailize(Uri u) {
    final full = u.toString();
    final parts = full.split('?');
    final email = parts.first;
    final qp = parts.length > 1 ? Uri.splitQueryString(parts[1]) : <String, String>{};
    return Uri(scheme: 'mailto', path: email, queryParameters: qp.isEmpty ? null : qp);
  }

  bool _platformish(Uri u) {
    final s = u.scheme.toLowerCase();
    if (_schemes.contains(s)) return true;

    if (s == 'http' || s == 'https') {
      final h = u.host.toLowerCase();
      if (_external_harbors.contains(h)) return true;
      if (h.endsWith('t.me')) return true;
      if (h.endsWith('wa.me')) return true;
      if (h.endsWith('m.me')) return true;
      if (h.endsWith('signal.me')) return true;
      if (h.endsWith('x.com')) return true;
      if (h.endsWith('twitter.com')) return true;
      if (h.endsWith('facebook.com')) return true;
      if (h.endsWith('instagram.com')) return true;
    }
    return false;
  }

  Uri _httpize(Uri u) {
    final s = u.scheme.toLowerCase();

    if (s == 'tg' || s == 'telegram') {
      final qp = u.queryParameters;
      final domain = qp['domain'];
      if (domain != null && domain.isNotEmpty) {
        return Uri.https('t.me', '/$domain', {if (qp['start'] != null) 'start': qp['start']!});
      }
      final path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('t.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if ((s == 'http' || s == 'https') && u.host.toLowerCase().endsWith('t.me')) {
      return u;
    }

    if (s == 'viber') return u;

    if (s == 'whatsapp') {
      final qp = u.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${_digits(phone)}', {if (text != null && text.isNotEmpty) 'text': text});
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if ((s == 'http' || s == 'https') &&
        (u.host.toLowerCase().endsWith('wa.me') || u.host.toLowerCase().endsWith('whatsapp.com'))) {
      return u;
    }

    if (s == 'skype') return u;

    if (s == 'fb-messenger') {
      final path = u.pathSegments.isNotEmpty ? u.pathSegments.join('/') : '';
      final qp = u.queryParameters;
      final id = qp['id'] ?? qp['user'] ?? path;
      if (id.isNotEmpty) {
        return Uri.https('m.me', '/$id', u.queryParameters.isEmpty ? null : u.queryParameters);
      }
      return Uri.https('m.me', '/', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if (s == 'sgnl') {
      final qp = u.queryParameters;
      final ph = qp['phone'];
      final un = u.queryParameters['username'];
      if (ph != null && ph.isNotEmpty) return Uri.https('signal.me', '/#p/${_digits(ph)}');
      if (un != null && un.isNotEmpty) return Uri.https('signal.me', '/#u/$un');
      final path = u.pathSegments.join('/');
      if (path.isNotEmpty) return Uri.https('signal.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
      return u;
    }

    if (s == 'tel') {
      return Uri.parse('tel:${_digits(u.path)}');
    }

    if (s == 'mailto') return u;

    if (s == 'bnl') {
      final new_path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('bnl.com', '/$new_path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if ((s == 'http' || s == 'https')) {
      final host = u.host.toLowerCase();
      if (host.endsWith('x.com') ||
          host.endsWith('twitter.com') ||
          host.endsWith('facebook.com') ||
          host.startsWith('m.facebook.com') ||
          host.endsWith('instagram.com')) {
        return u;
      }
    }

    if (s == 'fb' || s == 'instagram' || s == 'twitter' || s == 'x') {
      return u;
    }

    return u;
  }

  Future<bool> _open_mail_web(Uri mailto) async {
    final u = _gmailize(mailto);
    return await _open_web(u);
  }

  Uri _gmailize(Uri m) {
    final qp = m.queryParameters;
    final params = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (m.path.isNotEmpty) 'to': m.path,
      if ((qp['subject'] ?? '').isNotEmpty) 'su': qp['subject']!,
      if ((qp['body'] ?? '').isNotEmpty) 'body': qp['body']!,
      if ((qp['cc'] ?? '').isNotEmpty) 'cc': qp['cc']!,
      if ((qp['bcc'] ?? '').isNotEmpty) 'bcc': qp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', params);
  }

  Future<bool> _open_web(Uri u) async {
    try {
      if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('openInAppBrowser error: $e; url=$u');
      try {
        return await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  @override
  Widget build(BuildContext context) {
    _bind_bell();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A22),
        body: Stack(
          children: [
            if (_cover)
              const bouncing_loader()
            else
              Container(
                color: const Color(0xFF1A1A22),
                child: Stack(
                  children: [
                    InAppWebView(
                      key: ValueKey(_hatch),
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
                        transparentBackground: true,
                      ),
                      initialUrlRequest: URLRequest(url: WebUri(_home_port)),
                      onWebViewCreated: (c) {
                        _pier = c;

                        _bosun ??= bosun_view_model(qm: _qm, capo: _capo);
                        _courier ??= harbor_courier(model: _bosun!, get_web: () => _pier);

                        _pier.addJavaScriptHandler(
                          handlerName: 'onServerResponse',
                          callback: (args) {
                            try {
                              final saved = args.isNotEmpty &&
                                  args[0] is Map &&
                                  args[0]['savedata'].toString() == "false";

                              print("Load True " + args[0].toString());
                              if (saved) {
                      ;
                              }
                            } catch (_) {}
                            if (args.isEmpty) return null;
                            try {
                              return args.reduce((curr, next) => curr + next);
                            } catch (_) {
                              return args.first;
                            }
                          },
                        );
                      },
                      onLoadStart: (c, u) async {
                        setState(() {
                          _start_load_ts = DateTime.now().millisecondsSinceEpoch;
                        });
                        setState(() => _spin_wheel = true);
                        final v = u;
                        if (v != null) {
                          if (_bare_mail(v)) {
                            try {
                              await c.stopLoading();
                            } catch (_) {}
                            final mailto = _mailize(v);
                            await _open_mail_web(mailto);
                            return;
                          }
                          final sch = v.scheme.toLowerCase();
                          if (sch != 'http' && sch != 'https') {
                            try {
                              await c.stopLoading();
                            } catch (_) {}
                          }
                        }
                      },
                      onLoadError: (controller, url, code, message) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "InAppWebViewError(code=$code, message=$message)";
                        await post_harbor_stat(
                          event: ev,
                          time_start: now,
                          time_finish: now,
                          url: url?.toString() ?? '',
                          app_sid: _capo.af_ship_id,
                          first_page_load_ts: _first_page_stamp,
                        );
                        if (mounted) setState(() => _spin_wheel = false);
                      },
                      onReceivedHttpError: (controller, request, errorResponse) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final ev = "HTTPError(status=${errorResponse.statusCode}, reason=${errorResponse.reasonPhrase})";
                        await post_harbor_stat(
                          event: ev,
                          time_start: now,
                          time_finish: now,
                          url: request.url?.toString() ?? '',
                          app_sid: _capo.af_ship_id,
                          first_page_load_ts: _first_page_stamp,
                        );
                      },
                      onReceivedError: (controller, request, error) async {
                        final now = DateTime.now().millisecondsSinceEpoch;
                        final desc = (error.description ?? '').toString();
                        final ev = "WebResourceError(code=${error}, message=$desc)";
                        await post_harbor_stat(
                          event: ev,
                          time_start: now,
                          time_finish: now,
                          url: request.url?.toString() ?? '',
                          app_sid: _capo.af_ship_id,
                          first_page_load_ts: _first_page_stamp,
                        );
                      },
                      onLoadStop: (c, u) async {
                        await c.evaluateJavascript(source: "console.log('Harbor up!');");
                        await _push_device();
                        await _push_af();

                        setState(() => _current_url = u.toString());

                        Future.delayed(const Duration(seconds: 20), () {
                          send_loaded_once(url: _current_url.toString(), timestart: _start_load_ts);
                        });

                        if (mounted) setState(() => _spin_wheel = false);
                      },
                      shouldOverrideUrlLoading: (c, action) async {
                        final uri = action.request.url;
                        if (uri == null) return NavigationActionPolicy.ALLOW;

                        if (_bare_mail(uri)) {
                          final mailto = _mailize(uri);
                          await _open_mail_web(mailto);
                          return NavigationActionPolicy.CANCEL;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _open_mail_web(uri);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (_platformish(uri)) {
                          final web = _httpize(uri);

                          final host = (web.host.isNotEmpty ? web.host : uri.host).toLowerCase();
                          final is_social = host.endsWith('x.com') ||
                              host.endsWith('twitter.com') ||
                              host.endsWith('facebook.com') ||
                              host.startsWith('m.facebook.com') ||
                              host.endsWith('instagram.com') ||
                              host.endsWith('t.me') ||
                              host.endsWith('telegram.me') ||
                              host.endsWith('telegram.dog');

                          if (is_social) {
                            await _open_web(web.scheme == 'http' || web.scheme == 'https' ? web : uri);
                            return NavigationActionPolicy.CANCEL;
                          }

                          if (web.scheme == 'http' || web == uri) {
                            await _open_web(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                                await _open_web(web);
                              }
                            } catch (_) {}
                          }
                          return NavigationActionPolicy.CANCEL;
                        }

                        if (sch != 'http' && sch != 'https') {
                          return NavigationActionPolicy.CANCEL;
                        }

                        return NavigationActionPolicy.ALLOW;
                      },
                      onCreateWindow: (c, req) async {
                        final uri = req.request.url;
                        if (uri == null) return false;

                        if (_bare_mail(uri)) {
                          final mailto = _mailize(uri);
                          await _open_mail_web(mailto);
                          return false;
                        }

                        final sch = uri.scheme.toLowerCase();

                        if (sch == 'mailto') {
                          await _open_mail_web(uri);
                          return false;
                        }

                        if (sch == 'tel') {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                          return false;
                        }

                        if (_platformish(uri)) {
                          final web = _httpize(uri);

                          final host = (web.host.isNotEmpty ? web.host : uri.host).toLowerCase();
                          final is_social = host.endsWith('x.com') ||
                              host.endsWith('twitter.com') ||
                              host.endsWith('facebook.com') ||
                              host.startsWith('m.facebook.com') ||
                              host.endsWith('instagram.com') ||
                              host.endsWith('t.me') ||
                              host.endsWith('telegram.me') ||
                              host.endsWith('telegram.dog');

                          if (is_social) {
                            await _open_web(web.scheme == 'http' || web.scheme == 'https' ? web : uri);
                            return false;
                          }

                          if (web.scheme == 'http' || web.scheme == 'https') {
                            await _open_web(web);
                          } else {
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                                await _open_web(web);
                              }
                            } catch (_) {}
                          }
                          return false;
                        }

                        if (sch == 'http' || sch == 'https') {
                          c.loadUrl(urlRequest: URLRequest(url: uri));
                        }
                        return false;
                      },
                      onDownloadStartRequest: (c, req) async {
                        await _open_web(req.url);
                      },
                    ),
                    Visibility(
                      visible: !_veil,
                      child: const bouncing_loader(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Отдельный WebView на внешнюю ссылку (из нотификаций)
// ============================================================================
class captain_deck extends StatefulWidget with WidgetsBindingObserver {
  final String sea_lane;
  const captain_deck(this.sea_lane, {super.key});

  @override
  State<captain_deck> createState() => _captain_deck_state();
}

class _captain_deck_state extends State<captain_deck> with WidgetsBindingObserver {
  late InAppWebViewController _deck;

  final Set<String> _schemes = {
    'tg',
    'telegram',
    'whatsapp',
    'viber',
    'skype',
    'fb-messenger',
    'sgnl',
    'tel',
    'mailto',
    'bnl',
    'fb',
    'instagram',
    'twitter',
    'x',
  };

  final Set<String> _external_harbors = {
    't.me',
    'telegram.me',
    'telegram.dog',
    'wa.me',
    'api.whatsapp.com',
    'chat.whatsapp.com',
    'm.me',
    'signal.me',
    'bnl.com',
    'www.bnl.com',
    'x.com',
    'www.x.com',
    'twitter.com',
    'www.twitter.com',
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'instagram.com',
    'www.instagram.com',
  };

  bool _bare_mail(Uri u) {
    final s = u.scheme;
    if (s.isNotEmpty) return false;
    final raw = u.toString();
    return raw.contains('@') && !raw.contains(' ');
  }

  Uri _mailize(Uri u) {
    final full = u.toString();
    final parts = full.split('?');
    final email = parts.first;
    final qp = parts.length > 1 ? Uri.splitQueryString(parts[1]) : <String, String>{};
    return Uri(scheme: 'mailto', path: email, queryParameters: qp.isEmpty ? null : qp);
  }

  bool _platformish(Uri u) {
    final s = u.scheme.toLowerCase();
    if (_schemes.contains(s)) return true;

    if (s == 'http' || s == 'https') {
      final h = u.host.toLowerCase();
      if (_external_harbors.contains(h)) return true;
      if (h.endsWith('t.me')) return true;
      if (h.endsWith('wa.me')) return true;
      if (h.endsWith('m.me')) return true;
      if (h.endsWith('signal.me')) return true;
      if (h.endsWith('x.com')) return true;
      if (h.endsWith('twitter.com')) return true;
      if (h.endsWith('facebook.com')) return true;
      if (h.endsWith('instagram.com')) return true;
    }
    return false;
  }

  Uri _httpize(Uri u) {
    final s = u.scheme.toLowerCase();

    if (s == 'tg' || s == 'telegram') {
      final qp = u.queryParameters;
      final domain = qp['domain'];
      if (domain != null && domain.isNotEmpty) {
        return Uri.https('t.me', '/$domain', {if (qp['start'] != null) 'start': qp['start']!});
      }
      final path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('t.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if ((s == 'http' || s == 'https') && u.host.toLowerCase().endsWith('t.me')) {
      return u;
    }

    if (s == 'viber') return u;

    if (s == 'whatsapp') {
      final qp = u.queryParameters;
      final phone = qp['phone'];
      final text = qp['text'];
      if (phone != null && phone.isNotEmpty) {
        return Uri.https('wa.me', '/${_digits(phone)}', {if (text != null && text.isNotEmpty) 'text': text});
      }
      return Uri.https('wa.me', '/', {if (text != null && text.isNotEmpty) 'text': text});
    }

    if ((s == 'http' || s == 'https') &&
        (u.host.toLowerCase().endsWith('wa.me') || u.host.toLowerCase().endsWith('whatsapp.com'))) {
      return u;
    }

    if (s == 'skype') return u;

    if (s == 'fb-messenger') {
      final path = u.pathSegments.isNotEmpty ? u.pathSegments.join('/') : '';
      final qp = u.queryParameters;
      final id = qp['id'] ?? qp['user'] ?? path;
      if (id.isNotEmpty) {
        return Uri.https('m.me', '/$id', u.queryParameters.isEmpty ? null : u.queryParameters);
      }
      return Uri.https('m.me', '/', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if (s == 'sgnl') {
      final qp = u.queryParameters;
      final ph = qp['phone'];
      final un = u.queryParameters['username'];
      if (ph != null && ph.isNotEmpty) return Uri.https('signal.me', '/#p/${_digits(ph)}');
      if (un != null && un.isNotEmpty) return Uri.https('signal.me', '/#u/$un');
      final path = u.pathSegments.join('/');
      if (path.isNotEmpty) return Uri.https('signal.me', '/$path', u.queryParameters.isEmpty ? null : u.queryParameters);
      return u;
    }

    if (s == 'tel') {
      return Uri.parse('tel:${_digits(u.path)}');
    }

    if (s == 'mailto') return u;

    if (s == 'bnl') {
      final new_path = u.path.isNotEmpty ? u.path : '';
      return Uri.https('bnl.com', '/$new_path', u.queryParameters.isEmpty ? null : u.queryParameters);
    }

    if ((s == 'http' || s == 'https')) {
      final host = u.host.toLowerCase();
      if (host.endsWith('x.com') ||
          host.endsWith('twitter.com') ||
          host.endsWith('facebook.com') ||
          host.startsWith('m.facebook.com') ||
          host.endsWith('instagram.com')) {
        return u;
      }
    }

    if (s == 'fb' || s == 'instagram' || s == 'twitter' || s == 'x') {
      return u;
    }

    return u;
  }

  Future<bool> _open_mail_web(Uri mailto) async {
    final u = _gmailize(mailto);
    return await _open_web(u);
  }

  Uri _gmailize(Uri m) {
    final qp = m.queryParameters;
    final params = <String, String>{
      'view': 'cm',
      'fs': '1',
      if (m.path.isNotEmpty) 'to': m.path,
      if ((qp['subject'] ?? '').isNotEmpty) 'su': qp['subject']!,
      if ((qp['body'] ?? '').isNotEmpty) 'body': qp['body']!,
      if ((qp['cc'] ?? '').isNotEmpty) 'cc': qp['cc']!,
      if ((qp['bcc'] ?? '').isNotEmpty) 'bcc': qp['bcc']!,
    };
    return Uri.https('mail.google.com', '/mail/', params);
  }

  Future<bool> _open_web(Uri u) async {
    try {
      if (await launchUrl(u, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('openInAppBrowser error: $e; url=$u');
      try {
        return await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9+]'), '');

  @override
  Widget build(BuildContext context) {
    final night = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: night ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A22),
        body: InAppWebView(
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
          initialUrlRequest: URLRequest(url: WebUri(widget.sea_lane)),
          onWebViewCreated: (c) => _deck = c,
          shouldOverrideUrlLoading: (c, action) async {
            final uri = action.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;

            if (_bare_mail(uri)) {
              final mailto = _mailize(uri);
              await _open_mail_web(mailto);
              return NavigationActionPolicy.CANCEL;
            }

            final sch = uri.scheme.toLowerCase();

            if (sch == 'mailto') {
              await _open_mail_web(uri);
              return NavigationActionPolicy.CANCEL;
            }

            if (sch == 'tel') {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationActionPolicy.CANCEL;
            }

            if (_platformish(uri)) {
              final web = _httpize(uri);

              final host = (web.host.isNotEmpty ? web.host : uri.host).toLowerCase();
              final is_social = host.endsWith('x.com') ||
                  host.endsWith('twitter.com') ||
                  host.endsWith('facebook.com') ||
                  host.startsWith('m.facebook.com') ||
                  host.endsWith('instagram.com') ||
                  host.endsWith('t.me') ||
                  host.endsWith('telegram.me') ||
                  host.endsWith('telegram.dog');

              if (is_social) {
                await _open_web(web.scheme == 'http' || web.scheme == 'https' ? web : uri);
                return NavigationActionPolicy.CANCEL;
              }

              if (web.scheme == 'http' || web == uri) {
                await _open_web(web);
              } else {
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                    await _open_web(web);
                  }
                } catch (_) {}
              }
              return NavigationActionPolicy.CANCEL;
            }

            if (sch != 'http' && sch != 'https') {
              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },
          onCreateWindow: (c, req) async {
            final uri = req.request.url;
            if (uri == null) return false;

            if (_bare_mail(uri)) {
              final mailto = _mailize(uri);
              await _open_mail_web(mailto);
              return false;
            }

            final sch = uri.scheme.toLowerCase();

            if (sch == 'mailto') {
              await _open_mail_web(uri);
              return false;
            }

            if (sch == 'tel') {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return false;
            }

            if (_platformish(uri)) {
              final web = _httpize(uri);

              final host = (web.host.isNotEmpty ? web.host : uri.host).toLowerCase();
              final is_social = host.endsWith('x.com') ||
                  host.endsWith('twitter.com') ||
                  host.endsWith('facebook.com') ||
                  host.startsWith('m.facebook.com') ||
                  host.endsWith('instagram.com') ||
                  host.endsWith('t.me') ||
                  host.endsWith('telegram.me') ||
                  host.endsWith('telegram.dog');

              if (is_social) {
                await _open_web(web.scheme == 'http' || web.scheme == 'https' ? web : uri);
                return false;
              }

              if (web.scheme == 'http' || web.scheme == 'https') {
                await _open_web(web);
              } else {
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else if (web != uri && (web.scheme == 'http' || web.scheme == 'https')) {
                    await _open_web(web);
                  }
                } catch (_) {}
              }
              return false;
            }

            if (sch == 'http' || sch == 'https') {
              c.loadUrl(urlRequest: URLRequest(url: uri));
            }
            return false;
          },
          onDownloadStartRequest: (c, req) async {
            await _open_web(req.url);
          },
        ),
      ),
    );
  }
}

// ============================================================================
// Help экраны
// ============================================================================
class pirate_help extends StatefulWidget {
  const pirate_help({super.key});

  @override
  State<pirate_help> createState() => _pirate_help_state();
}

class _pirate_help_state extends State<pirate_help> with WidgetsBindingObserver {
  InAppWebViewController? _ctrl;
  bool _spin = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A22),
        body: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/index.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
              ),
              onWebViewCreated: (c) => _ctrl = c,
              onLoadStart: (c, u) => setState(() => _spin = true),
              onLoadStop: (c, u) async => setState(() => _spin = false),
              onLoadError: (c, u, code, msg) => setState(() => _spin = false),
            ),
            if (_spin) const bouncing_loader(),
          ],
        ),
      ),
    );
  }
}

class pirate_help_lite extends StatefulWidget {
  const pirate_help_lite({super.key});

  @override
  State<pirate_help_lite> createState() => _pirate_help_lite_state();
}

class _pirate_help_lite_state extends State<pirate_help_lite> {
  InAppWebViewController? _wvc;
  bool _ld = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A22),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialFile: 'assets/dream.html',
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                disableHorizontalScroll: false,
                disableVerticalScroll: false,
                transparentBackground: true,
                mediaPlaybackRequiresUserGesture: false,
                disableDefaultErrorPage: true,
                allowsInlineMediaPlayback: true,
                allowsPictureInPictureMediaPlayback: true,
                useOnDownloadStart: true,
                javaScriptCanOpenWindowsAutomatically: true,
              ),
              onWebViewCreated: (controller) => _wvc = controller,
              onLoadStart: (controller, url) => setState(() => _ld = true),
              onLoadStop: (controller, url) async => setState(() => _ld = false),
              onLoadError: (controller, url, code, message) => setState(() => _ld = false),
            ),
            if (_ld)
              const Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: bouncing_loader(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Анимированный лоадер "car n care"
// ============================================================================
class bouncing_loader extends StatefulWidget {
  const bouncing_loader({Key? key}) : super(key: key);

  @override
  State<bouncing_loader> createState() => _bouncing_loader_state();
}

class _bouncing_loader_state extends State<bouncing_loader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;
  final String _text = "car n care";
  final Duration _total = const Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total)..repeat();
    _animations = [];
    final letters = _text.length;
    for (int i = 0; i < letters; i++) {
      final start = (i / letters) * 0.9;
      final end = start + 0.3;
      final anim = Tween<double>(begin: 0.0, end: -12.0).chain(CurveTween(curve: Curves.easeOut)).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeInOut),
        ),
      );
      _animations.add(anim);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _build_letters(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (ctx, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_text.length, (i) {
            final ch = _text[i];
            final dy = _animations[i].value;
            return Transform.translate(
              offset: Offset(0, dy),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(ch, style: style),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A22),
      child: Center(
        child: _build_letters(context),
      ),
    );
  }
}

// ============================================================================
// main()
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(parrot_bg_squawk);

  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  tz_data.initializeTimeZones();

  runApp(
    p.MultiProvider(
      providers: [
        p_consigliere,
      ],
      child: r.ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const jolly_vestibule(),
        ),
      ),
    ),
  );
}

