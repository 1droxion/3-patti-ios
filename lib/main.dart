import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://3-patti-ios.vercel.app',
);

void main() => runApp(const ThreePattiApp());

class ThreePattiApp extends StatelessWidget {
  const ThreePattiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3 Patti Social',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE2B347),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF07110D),
        useMaterial3: true,
      ),
      home: const LobbyScreen(),
    );
  }
}

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final nameController = TextEditingController(text: 'Guest');
  late final String playerId = 'p-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final country = PlatformDispatcher.instance.locale.countryCode ?? 'US';
    final storePrice = country == 'IN' ? '₹99' : r'$1.99';

    return Scaffold(
      appBar: AppBar(
        title: const Text('3 PATTI SOCIAL', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: Center(child: Text('10,000 chips')),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF102019),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose exactly how many players', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('10-chip boot • 5,000-chip cap • social play • no cash-out'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameController,
                      maxLength: 24,
                      decoration: const InputDecoration(
                        labelText: 'Your display name',
                        counterText: '',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Optional store example: VIP $storePrice • betting chips are never sold for cash.', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  itemCount: 9,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.45,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final players = index + 2;
                    final featured = players <= 5;
                    return FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        side: BorderSide(color: featured ? const Color(0xFFE2B347) : Colors.white12),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim().isEmpty ? 'Guest' : nameController.text.trim();
                        if (!context.mounted) return;
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MatchmakingScreen(
                            playerId: playerId,
                            name: name,
                            playerCount: players,
                          ),
                        ));
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(players == 2 ? Icons.bolt_rounded : Icons.groups_2_rounded, size: 30),
                          const SizedBox(height: 6),
                          Text('$players PLAYERS', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text(featured ? 'FAST MATCH' : 'JOIN TABLE', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchmakingScreen extends StatefulWidget {
  final String playerId;
  final String name;
  final int playerCount;

  const MatchmakingScreen({
    super.key,
    required this.playerId,
    required this.name,
    required this.playerCount,
  });

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  String? roomId;
  int joined = 1;
  String message = 'Joining queue...';
  String? error;
  Timer? poller;

  @override
  void initState() {
    super.initState();
    _join();
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> _join() async {
    try {
      final state = await Api.post('/join', {
        'playerId': widget.playerId,
        'name': widget.name,
        'playerCount': widget.playerCount,
      });
      roomId = state['roomId'] as String;
      _consume(state);
      poller = Timer.periodic(const Duration(milliseconds: 900), (_) => _poll());
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _poll() async {
    if (roomId == null) return;
    try {
      final state = await Api.get('/state?roomId=${Uri.encodeComponent(roomId!)}&playerId=${Uri.encodeComponent(widget.playerId)}');
      _consume(state);
      if (state['status'] == 'playing' && mounted) {
        poller?.cancel();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TableScreen(
            roomId: roomId!,
            playerId: widget.playerId,
          ),
        ));
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _consume(Map<String, dynamic> state) {
    if (!mounted) return;
    setState(() {
      joined = state['joinedPlayers'] as int? ?? joined;
      message = state['message'] as String? ?? message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (error == null) const CircularProgressIndicator(),
              if (error != null) const Icon(Icons.cloud_off_rounded, size: 52),
              const SizedBox(height: 24),
              Text('Finding ${widget.playerCount}-player table', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Text(error ?? '$joined / ${widget.playerCount} players ready'),
              const SizedBox(height: 8),
              Text(error ?? message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              if (error != null) ...[
                const SizedBox(height: 18),
                FilledButton(onPressed: () { setState(() => error = null); _join(); }, child: const Text('TRY AGAIN')),
                const SizedBox(height: 10),
                Text('Server: $apiBaseUrl', style: const TextStyle(fontSize: 11, color: Colors.white38)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TableScreen extends StatefulWidget {
  final String roomId;
  final String playerId;

  const TableScreen({super.key, required this.roomId, required this.playerId});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  Timer? poller;
  Map<String, dynamic>? state;
  String? error;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _poll();
    poller = Timer.periodic(const Duration(milliseconds: 900), (_) => _poll());
  }

  @override
  void dispose() {
    poller?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final s = await Api.get('/state?roomId=${Uri.encodeComponent(widget.roomId)}&playerId=${Uri.encodeComponent(widget.playerId)}');
      if (mounted) setState(() { state = s; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _action(String action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final s = await Api.post('/action', {
        'roomId': widget.roomId,
        'playerId': widget.playerId,
        'action': action,
      });
      if (mounted) setState(() { state = s; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return Scaffold(body: Center(child: error == null ? const CircularProgressIndicator() : Text(error!)));
    }
    final players = (s['players'] as List).cast<Map<String, dynamic>>();
    final me = players.firstWhere((p) => p['id'] == widget.playerId);
    final cards = (s['myCards'] as List).cast<Map<String, dynamic>>();
    final seen = s['mySeen'] == true || s['status'] == 'showdown';
    final showdown = s['status'] == 'showdown';
    final winnerId = s['winnerId'];

    return Scaffold(
      appBar: AppBar(
        title: Text('${s['requestedPlayers']}-Player Table'),
        actions: [Padding(padding: const EdgeInsets.only(right: 14), child: Center(child: Text('${me['chips']} chips')))],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: players.where((p) => p['id'] != widget.playerId).map((p) {
                  final isWinner = p['id'] == winnerId;
                  return Chip(
                    avatar: CircleAvatar(child: Icon(isWinner ? Icons.emoji_events : Icons.person, size: 16)),
                    label: Text('${p['name']} • ${p['chips']}${p['folded'] == true ? ' • PACK' : ''}'),
                  );
                }).toList(),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF123829),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text('POT', style: TextStyle(color: Colors.white60)),
                    Text('${s['pot']} chips', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    Text('Cap: ${s['cap']} • Next chaal: ${s['currentBet']}', style: const TextStyle(color: Colors.white60)),
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: cards.map((c) => PlayingCardView(card: c, faceUp: seen)).toList(),
                    ),
                    const SizedBox(height: 14),
                    Text('${s['message']}', textAlign: TextAlign.center, style: TextStyle(fontWeight: winnerId == widget.playerId ? FontWeight.w900 : FontWeight.normal)),
                    if (showdown) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const Text('SHOWDOWN', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      ...((s['revealedHands'] as List).cast<Map<String, dynamic>>().map((hand) {
                        final handCards = (hand['cards'] as List).cast<Map<String, dynamic>>();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(width: 78, child: Text('${hand['name']}', overflow: TextOverflow.ellipsis)),
                              ...handCards.map((c) => Transform.scale(scale: .72, child: PlayingCardView(card: c, faceUp: true))),
                            ],
                          ),
                        );
                      })),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              if (!showdown) ...[
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: busy ? null : () => _action('pack'), child: const Text('PACK'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.tonal(onPressed: busy || seen ? null : () => _action('see'), child: const Text('SEE'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(onPressed: busy ? null : () => _action('chaal'), child: Text('CHAAL ${s['currentBet']}'))),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: busy ? null : () => _action('show'), child: const Text('SHOW'))),
              ] else
                SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () => _action('new'), child: const Text('PLAY AGAIN'))),
              const SizedBox(height: 6),
              const Text('Virtual chips only • no deposits • no cash-out', style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }
}

class PlayingCardView extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool faceUp;

  const PlayingCardView({super.key, required this.card, required this.faceUp});

  @override
  Widget build(BuildContext context) {
    final rank = card['rank'] as int? ?? 2;
    final suit = card['suit'] as int? ?? 0;
    final rankLabel = rank <= 10 ? '$rank' : const {11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[rank]!;
    final suitLabel = const ['♠', '♥', '♦', '♣'][suit];
    final red = suit == 1 || suit == 2;
    return Container(
      width: 72,
      height: 102,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faceUp ? Colors.white : const Color(0xFF7A1E2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: faceUp
          ? Text('$rankLabel$suitLabel', style: TextStyle(color: red ? Colors.red : Colors.black, fontWeight: FontWeight.w900, fontSize: 22))
          : const Icon(Icons.style_rounded, size: 30),
    );
  }
}

class Api {
  static Future<Map<String, dynamic>> get(String path) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse('$apiBaseUrl$path'));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> payload) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$apiBaseUrl$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(payload));
      final res = await req.close();
      final body = await utf8.decoder.bind(res).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
      }
      return data;
    } finally {
      client.close(force: true);
    }
  }
}
