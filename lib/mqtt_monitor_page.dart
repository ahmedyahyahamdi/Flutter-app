import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_page.dart';
import 'login_page.dart';
import 'chatbot_screen.dart';

class MqttMonitorPage extends StatefulWidget {
  const MqttMonitorPage({super.key});

  @override
  State<MqttMonitorPage> createState() => _MqttMonitorPageState();
}

class _MqttMonitorPageState extends State<MqttMonitorPage> {
  final String broker = 'broker.hivemq.com';
  final int port = 1883;
  final String topic = 'sensor';

  MqttServerClient? client;

  // UI State
  String status = 'Déconnecté';
  String rawMessage = 'Aucune donnée';
  bool mqttConnected = false;

  List<String> logHistory = [];
  Map<String, dynamic> parsedData = {};
  Timer? _uiTimer;

  // Sensor cache
  final Map<String, Map<String, dynamic>> _sensorCache = {
    'lum': {'value': 'N/A', 'timestamp': null},
    'rhum': {'value': 'N/A', 'timestamp': null},
    'rtmp': {'value': 'N/A', 'timestamp': null},
    'shum': {'value': 'N/A', 'timestamp': null},
    'stmp': {'value': 'N/A', 'timestamp': null},
  };

  @override
  void initState() {
    super.initState();
    _log('Application lancée');
    _connect();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    client?.disconnect();
    super.dispose();
  }

  void _log(String msg) {
    setState(() {
      logHistory.insert(0, '${DateTime.now().toString().substring(11, 19)}: $msg');
      if (logHistory.length > 15) logHistory.removeLast();
    });
    print('MQTT: $msg');
  }

  String _extractAscii(String text) {
    try {
      final matches = RegExp(r'<(\d+)>').allMatches(text);
      String result = '';

      for (final m in matches) {
        final code = int.tryParse(m.group(1) ?? '');
        if (code != null && code >= 32 && code <= 126) {
          result += String.fromCharCode(code);
        }
      }
      return result.isNotEmpty ? result : text;
    } catch (_) {
      return text;
    }
  }

  String _sanitize(String input) {
    final ascii = _extractAscii(input);
    return ascii.split('').where((c) {
      final code = c.codeUnitAt(0);
      return code >= 32 && code <= 126;
    }).join();
  }

  String _timeAgo(DateTime? ts) {
    if (ts == null) return 'Jamais';
    final diff = DateTime.now().difference(ts);
    return diff.inSeconds < 60
        ? 'Il y a ${diff.inSeconds}s'
        : 'Il y a ${diff.inMinutes} min';
  }

  Future<void> _connect() async {
    try {
      _log('Connexion au broker...');
      setState(() => status = 'Connexion...');

      client = MqttServerClient(
        broker,
        'flutter_${DateTime.now().millisecondsSinceEpoch}',
      )
        ..port = port
        ..logging(on: false)
        ..keepAlivePeriod = 30
        ..onConnected = _onConnect
        ..onDisconnected = _onDisconnect
        ..onSubscribed = _onSubscribed;

      await client!.connect();
    } catch (e) {
      _log('Erreur connexion: $e');
      setState(() => status = 'Erreur: $e');
    }
  }

  void _onConnect() {
    _log('Connecté');
    setState(() {
      mqttConnected = true;
      status = 'Connecté';
    });

    client!.subscribe(topic, MqttQos.atMostOnce);

    client!.updates!.listen((event) {
      if (event.isEmpty) return;

      final rec = event.first.payload as MqttPublishMessage;
      final data = MqttPublishPayload.bytesToString(rec.payload.message);

      _log('Données reçues (${data.length} chars)');
      _handleMessage(data);
    });
  }

  void _onSubscribed(String t) => _log('Abonné à $t');

  void _onDisconnect() {
    _log('Déconnexion du broker');
    setState(() {
      mqttConnected = false;
      status = 'Déconnecté';
    });
  }

  void _handleMessage(String msg) {
    setState(() {
      rawMessage = msg;
      final cleaned = _sanitize(msg);

      try {
        parsedData = jsonDecode(cleaned);
        _log('JSON détecté (${parsedData.length} clés)');

        final now = DateTime.now();
        parsedData.forEach((key, value) {
          if (_sensorCache.containsKey(key)) {
            _sensorCache[key] = {
              'value': value.toString(),
              'timestamp': now,
            };
          }
        });
      } catch (e) {
        _log('JSON invalide: $e');
      }
    });
  }

  Widget _statusCard() {
    final color = status == 'Connecté'
        ? Colors.green
        : status == 'Connexion...'
            ? Colors.orange
            : Colors.red;

    return Card(
      child: ListTile(
        leading: CircleAvatar(radius: 6, backgroundColor: color),
        title: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        subtitle: Text('$broker:$port'),
        trailing: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: mqttConnected ? null : _connect,
        ),
      ),
    );
  }

  Widget _sensorPanel() {
    if (parsedData.isEmpty || parsedData.containsKey('error')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.sensors, size: 50, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('En attente de données...', style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 10),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      );
    }

    Widget item(String name, String key, String unit) {
      final data = _sensorCache[key]!;
      final val = data['value'];
      final ts = data['timestamp'];
      final fresh = ts != null && DateTime.now().difference(ts).inSeconds < 45;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(name)),
                Text(
                  val,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: fresh ? Colors.black : Colors.grey,
                  ),
                ),
                const SizedBox(width: 5),
                Text(unit, style: TextStyle(color: Colors.grey)),
              ],
            ),
            Text(
              _timeAgo(ts),
              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
            )
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                Icon(Icons.sensors, color: Colors.blue),
                SizedBox(width: 8),
                Text('Données Capteurs', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            item('💡 Lumière', 'lum', 'lux'),
            item('💧 Humidité Air', 'rhum', '%'),
            item('🌡️ Température Air', 'rtmp', '°C'),
            item('💦 Humidité Sol', 'shum', '%'),
            item('🌱 Température Sol', 'stmp', '°C'),
          ],
        ),
      ),
    );
  }

  Widget _logPanel() {
    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.list),
          const SizedBox(width: 8),
          Text('Logs (${logHistory.length})'),
        ],
      ),
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView(
            reverse: true,
            children: logHistory
                .map((e) => Text(e, style: const TextStyle(color: Colors.green, fontSize: 11)))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _rawPanel() {
    return ExpansionTile(
      title: const Row(
        children: [
          Icon(Icons.code),
          SizedBox(width: 8),
          Text('Données Brutes'),
        ],
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            rawMessage,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
      ],
    );
  }

  Future<void> _logout() async {
    client?.disconnect();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');

    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring RPi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.dashboard),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardPage())),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Informations'),
                  content: Text(
                    'Broker: $broker:$port\n'
                    'Topic: $topic\n'
                    'Status: $status\n\n'
                    'Capteurs disponibles:\n'
                    '• lum (lux)\n'
                    '• rhum (%)\n'
                    '• rtmp (°C)\n'
                    '• shum (%)\n'
                    '• stmp (°C)',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _statusCard(),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _sensorPanel(),
                    const SizedBox(height: 16),
                    _logPanel(),
                    const SizedBox(height: 8),
                    _rawPanel(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: mqttConnected ? null : _connect,
        tooltip: 'Reconnecter',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
