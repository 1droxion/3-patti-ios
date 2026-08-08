import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://3-patti-ios.vercel.app',
);

const gold = Color(0xFFF4C34D);
const goldDeep = Color(0xFF8A5A00);
const ink = Color(0xFF020A08);
const panel = Color(0xFF071A14);
const panel2 = Color(0xFF0B251B);
const greenAccent = Color(0xFF48E05F);
const blueAccent = Color(0xFF3D9CFF);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var playerId = prefs.getString('three_patti_player_id');
  if (playerId == null || playerId.isEmpty) {
    playerId = 'p-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
    await prefs.setString('three_patti_player_id', playerId);
  }
  final displayName = prefs.getString('three_patti_display_name') ?? 'Player';
  final avatarIndex = (prefs.getInt('three_patti_avatar') ?? 1).clamp(1, 8).toInt();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(ThreePattiApp(playerId: playerId, displayName: displayName, avatarIndex: avatarIndex));
}

class ThreePattiApp extends StatefulWidget {
  final String playerId;
  final String displayName;
  final int avatarIndex;

  const ThreePattiApp({super.key, required this.playerId, required this.displayName, required this.avatarIndex});

  @override
  State<ThreePattiApp> createState() => _ThreePattiAppState();
}

class _ThreePattiAppState extends State<ThreePattiApp> {
  late final AppSession session;

  @override
  void initState() {
    super.initState();
    session = AppSession(playerId: widget.playerId, displayName: widget.displayName, avatarIndex: widget.avatarIndex);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '3 Patti Social',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: panel,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontWeight: FontWeight.w900),
          headlineMedium: TextStyle(fontWeight: FontWeight.w900),
          titleLarge: TextStyle(fontWeight: FontWeight.w800),
          titleMedium: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      home: AppShell(session: session),
    );
  }
}

class AppSession extends ChangeNotifier {
  String displayName;
  int walletChips = 10000;
  int navPage = 0; // 0 home, 1 store, 2 history, 3 profile, 4 chips, 6 settings, 7 support, 8 rules
  bool soundEnabled = true;
  bool musicEnabled = true;
  bool vipActive = false;
  int avatarIndex;
  final String playerId;
  final List<GameHistoryItem> history = [];

  AppSession({required this.playerId, this.displayName = 'Player', this.avatarIndex = 1});

  void setPage(int value) {
    if (navPage == value) return;
    navPage = value;
    notifyListeners();
  }

  void updateName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    displayName = cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
    unawaited(SharedPreferences.getInstance().then((prefs) => prefs.setString('three_patti_display_name', displayName)));
    notifyListeners();
  }

  void setSoundEnabled(bool value) {
    if (soundEnabled == value) return;
    soundEnabled = value;
    notifyListeners();
  }

  void setMusicEnabled(bool value) {
    if (musicEnabled == value) return;
    musicEnabled = value;
    notifyListeners();
  }

  void setVipActive(bool value) {
    if (vipActive == value) return;
    vipActive = value;
    notifyListeners();
  }

  void updateAvatar(int value) {
    final next = value.clamp(1, 8).toInt();
    if (avatarIndex == next) return;
    avatarIndex = next;
    unawaited(SharedPreferences.getInstance().then((prefs) => prefs.setInt('three_patti_avatar', avatarIndex)));
    notifyListeners();
  }

  void updateWallet(int value) {
    final next = max(0, value);
    if (walletChips == next) return;
    walletChips = next;
    notifyListeners();
  }

  void addHistory(GameHistoryItem item) {
    history.insert(0, item);
    if (history.length > 50) history.removeLast();
    notifyListeners();
  }

  void resetAccount() {
    displayName = 'Player';
    walletChips = 10000;
    history.clear();
    soundEnabled = true;
    musicEnabled = true;
    vipActive = false;
    avatarIndex = 1;
    navPage = 0;
    unawaited(SharedPreferences.getInstance().then((prefs) async {
      await prefs.setString('three_patti_display_name', 'Player');
      await prefs.setInt('three_patti_avatar', 1);
    }));
    notifyListeners();
  }
}

class GameHistoryItem {
  final DateTime at;
  final int players;
  final int pot;
  final int payout;
  final int fee;
  final bool won;

  const GameHistoryItem({
    required this.at,
    required this.players,
    required this.pot,
    required this.payout,
    required this.fee,
    required this.won,
  });
}

class AppShell extends StatefulWidget {
  final AppSession session;

  const AppShell({super.key, required this.session});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    Api.configureSession(widget.session);
    unawaited(Api.ensureSession());
  }

  void goHome() => widget.session.setPage(0);

  Widget _pageFor(int page) => switch (page) {
        1 => StoreView(session: widget.session),
        2 => HistoryView(session: widget.session),
        3 => ProfileView(session: widget.session),
        4 => WalletView(session: widget.session),
        5 => WalletView(session: widget.session),
        6 => SettingsView(session: widget.session),
        7 => SupportView(session: widget.session),
        8 => RulesView(session: widget.session),
        _ => LobbyView(session: widget.session),
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final page = widget.session.navPage;
        return Scaffold(
          key: scaffoldKey,
          backgroundColor: ink,
          endDrawerEnableOpenDragGesture: true,
          endDrawer: AppMenu(session: widget.session, activePage: page),
          body: CasinoBackdrop(
            child: SafeArea(
              child: Column(
                children: [
                  AppHeader(
                    session: widget.session,
                    page: page,
                    onHome: goHome,
                    onWallet: () => widget.session.setPage(4),
                    onMenu: () => scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final slide = Tween<Offset>(begin: const Offset(.025, 0), end: Offset.zero).animate(animation);
                        return FadeTransition(opacity: animation, child: SlideTransition(position: slide, child: child));
                      },
                      child: KeyedSubtree(key: ValueKey(page), child: _pageFor(page)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CasinoBackdrop extends StatelessWidget {
  final Widget child;

  const CasinoBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07110D), Color(0xFF00100B), Color(0xFF040706)],
        ),
      ),
      child: CustomPaint(
        painter: _FeltTexturePainter(),
        child: SizedBox.expand(child: child),
      ),
    );
  }
}

class _FeltTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFB89238).withValues(alpha: .035)
      ..strokeWidth = .7;
    const step = 34.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), line);
    }
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x1638FF94), Color(0x00000000)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * .47, size.height * .48), radius: size.width * .42));
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppHeader extends StatelessWidget {
  final AppSession session;
  final int page;
  final VoidCallback onHome;
  final VoidCallback onWallet;
  final VoidCallback onMenu;

  const AppHeader({
    super.key,
    required this.session,
    required this.page,
    required this.onHome,
    required this.onWallet,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Container(
          height: compact ? 52 : 58,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
          decoration: const BoxDecoration(
            color: Color(0xE9030A07),
            border: Border(bottom: BorderSide(color: Color(0x887A5A10))),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 5))],
          ),
          child: Row(
            children: [
              if (page != 0) ...[
                _HeaderIconButton(icon: Icons.home_rounded, tooltip: 'Home', onTap: onHome),
                SizedBox(width: compact ? 6 : 10),
              ],
              InkWell(
                onTap: onHome,
                borderRadius: BorderRadius.circular(14),
                child: Row(
                  children: [
                    SizedBox(width: compact ? 44 : 54, height: 42, child: const _CardLogo()),
                    SizedBox(width: compact ? 4 : 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '3 PATTI SOCIAL',
                        style: TextStyle(
                          fontSize: compact ? 17 : 22,
                          color: gold,
                          fontWeight: FontWeight.w900,
                          letterSpacing: compact ? .4 : 1.1,
                          shadows: const [Shadow(color: Color(0x888A5A00), blurRadius: 10)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onWallet,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: compact ? 38 : 42,
                  padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07150F),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF9A6813)),
                    boxShadow: const [BoxShadow(color: Color(0x334E3300), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: compact ? 24 : 28,
                        height: compact ? 24 : 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFFFFD95C), Color(0xFFB97505)]),
                          border: Border.all(color: const Color(0xFFFFE69A)),
                        ),
                        child: const Icon(Icons.stars_rounded, size: 16, color: Color(0xFF4C2E00)),
                      ),
                      const SizedBox(width: 7),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              '${_money(session.walletChips)} CHIPS',
                              key: ValueKey(session.walletChips),
                              style: TextStyle(fontSize: compact ? 14 : 16, height: 1, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (!compact)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('SOCIAL CHIP BALANCE', style: TextStyle(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: .6)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: compact ? 7 : 11),
              _HeaderIconButton(icon: Icons.menu_rounded, tooltip: 'Menu', onTap: onMenu),
            ],
          ),
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: gold, size: 25),
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          maximumSize: const Size(44, 44),
          backgroundColor: const Color(0xFF0D130F),
          side: const BorderSide(color: Color(0xFF75500B)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
    );
  }
}

class _CardLogo extends StatelessWidget {
  const _CardLogo();

  @override
  Widget build(BuildContext context) {
    Widget card(String text, double angle, double dx) => Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: 24,
              height: 34,
              alignment: Alignment.topLeft,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: const Color(0xFFBA963C)),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
              ),
              child: Text(text, style: TextStyle(color: text.contains('♥') ? const Color(0xFFAD1E28) : Colors.black, fontWeight: FontWeight.w900, fontSize: 9)),
            ),
          ),
        );
    return Stack(
      alignment: Alignment.center,
      children: [card('A♠', -.18, -9), card('A♥', 0, 0), card('A♣', .18, 9)],
    );
  }
}



class LobbyView extends StatefulWidget {
  final AppSession session;

  const LobbyView({super.key, required this.session});

  @override
  State<LobbyView> createState() => _LobbyViewState();
}

class _LobbyViewState extends State<LobbyView> {
  Timer? livePoller;
  final Map<int, Map<String, dynamic>> liveStats = {};
  bool liveConnected = false;

  @override
  void initState() {
    super.initState();
    _pollLiveTables();
    livePoller = Timer.periodic(const Duration(milliseconds: 1500), (_) => _pollLiveTables());
  }

  @override
  void dispose() {
    livePoller?.cancel();
    super.dispose();
  }

  Future<void> _pollLiveTables() async {
    try {
      final data = await Api.get('/lobby');
      final rows = data['tables'];
      if (!mounted || rows is! List) return;
      final next = <int, Map<String, dynamic>>{};
      for (final raw in rows) {
        if (raw is Map) {
          final row = Map<String, dynamic>.from(raw);
          final players = row['players'];
          if (players is int) next[players] = row;
        }
      }
      setState(() {
        liveStats
          ..clear()
          ..addAll(next);
        liveConnected = true;
      });
    } catch (_) {
      if (mounted && liveConnected) setState(() => liveConnected = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 340;
        final pad = compact ? 7.0 : 11.0;
        final roomWidth = compact ? 184.0 : 224.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(pad, compact ? 5 : 8, pad, pad),
          child: Column(
            children: [
              Row(
                children: [
                  _LivePulseDot(connected: liveConnected),
                  const SizedBox(width: 8),
                  const Text(
                    'LIVE TABLES',
                    style: TextStyle(color: Color(0xFFFFE4A0), fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 1.15),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    liveConnected ? 'ONLINE • SWIPE LEFT / RIGHT' : 'CONNECTING TO LIVE ROOMS...',
                    style: TextStyle(
                      color: liveConnected ? Colors.white54 : Colors.orangeAccent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .45,
                    ),
                  ),
                  const Spacer(),
                  const _TierLegend(color: Color(0xFF76F06A), text: '5K'),
                  const SizedBox(width: 7),
                  const _TierLegend(color: Color(0xFF62B9FF), text: '20K'),
                  const SizedBox(width: 7),
                  const _TierLegend(color: Color(0xFFFFD45A), text: '50K'),
                ],
              ),
              SizedBox(height: compact ? 5 : 8),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFF6D521C).withValues(alpha: .75)),
                    gradient: const RadialGradient(
                      center: Alignment(0, -.15),
                      radius: 1.25,
                      colors: [Color(0xFF0D3E29), Color(0xFF061D14), Color(0xFF020706)],
                    ),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8))],
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _LobbyFeltGlow()),
                      Positioned.fill(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 28, vertical: compact ? 7 : 12),
                          itemCount: 9,
                          separatorBuilder: (_, __) => SizedBox(width: compact ? 15 : 22),
                          itemBuilder: (context, index) {
                            final players = index + 2;
                            final stat = liveStats[players] ?? const <String, dynamic>{};
                            return SizedBox(
                              width: roomWidth,
                              child: RoundRoomCard(
                                players: players,
                                compact: compact,
                                waitingPlayers: stat['waitingPlayers'] as int? ?? 0,
                                activeRooms: stat['activeRooms'] as int? ?? 0,
                                onTap: () {
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => MatchmakingScreen(session: widget.session, playerCount: players),
                                  ));
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const Positioned(left: 0, top: 0, bottom: 0, child: _EdgeFade(left: true)),
                      const Positioned(right: 0, top: 0, bottom: 0, child: _EdgeFade(left: false)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: compact ? 3 : 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.swipe_rounded, size: 14, color: gold),
                  SizedBox(width: 5),
                  Text('SWIPE ROOMS • TAP A ROUND TABLE TO JOIN', style: TextStyle(color: Colors.white38, fontSize: 9.2, fontWeight: FontWeight.w800, letterSpacing: .35)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LivePulseDot extends StatefulWidget {
  final bool connected;
  const _LivePulseDot({required this.connected});

  @override
  State<_LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<_LivePulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.connected ? const Color(0xFF53EE72) : Colors.orangeAccent;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Container(
        width: 11 + controller.value * 2,
        height: 11 + controller.value * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color.withValues(alpha: .18 + controller.value * .35), blurRadius: 7 + controller.value * 8, spreadRadius: controller.value * 2)],
        ),
      ),
    );
  }
}

class _LobbyFeltGlow extends StatelessWidget {
  const _LobbyFeltGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _LobbyFeltPainter()),
    );
  }
}

class _LobbyFeltPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFFFDB72).withValues(alpha: .022)
      ..strokeWidth = .7;
    const step = 32.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), grid);
    }
    final glow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x1F55FF96), Color(0x00000000)]).createShader(
        Rect.fromCircle(center: Offset(size.width * .5, size.height * .5), radius: size.width * .48),
      );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TierLegend extends StatelessWidget {
  final Color color;
  final String text;

  const _TierLegend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 5),
          Text('$text LIMIT', style: TextStyle(fontSize: 8.5, color: color, fontWeight: FontWeight.w900, letterSpacing: .5)),
        ],
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  final bool left;
  const _EdgeFade({required this.left});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: const [Color(0xEE020A08), Color(0x00020A08)],
          ),
        ),
      ),
    );
  }
}

class PremiumHeroBanner extends StatelessWidget {
  const PremiumHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFAD7B16), width: 1.1),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D4D32), Color(0xFF072719), Color(0xFF030806)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroTexturePainter())),
          Positioned(
            right: -20,
            top: -24,
            child: Opacity(
              opacity: .11,
              child: Transform.rotate(
                angle: -.16,
                child: const Icon(Icons.casino_rounded, size: 185, color: Color(0xFFFFD96A)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'CHOOSE YOUR TABLE',
                          style: TextStyle(
                            fontSize: 27,
                            color: Color(0xFFFFE7A4),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: [Shadow(color: Color(0xAA8C6300), blurRadius: 10)],
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 14,
                        runSpacing: 2,
                        children: const [
                          _HeroInfo(icon: Icons.local_fire_department_rounded, text: 'BOOT 10'),
                          _HeroInfo(icon: Icons.people_alt_rounded, text: 'REAL PLAYERS'),
                          _HeroInfo(icon: Icons.swipe_rounded, text: 'HORIZONTAL ROOMS'),
                        ],
                      ),
                    ],
                  ),
                ),
                const _HeroChipAndCards(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFFFFD75A).withValues(alpha: .045)
      ..strokeWidth = .7;
    for (double x = -size.height; x < size.width + size.height; x += 25) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
    final glow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x2238F095), Color(0x00000000)]).createShader(
        Rect.fromCircle(center: Offset(size.width * .28, size.height * .48), radius: size.width * .36),
      );
    canvas.drawRect(Offset.zero & size, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeroInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: gold),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 9.5, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: .45)),
      ],
    );
  }
}

class _HeroChipAndCards extends StatelessWidget {
  const _HeroChipAndCards();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 154,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(right: 10, top: 1, child: _BigCard(mark: 'A♠', angle: .16, height: 58)),
          const Positioned(right: 40, top: 3, child: _BigCard(mark: 'A♥', angle: -.03, height: 58)),
          const Positioned(right: 70, top: 5, child: _BigCard(mark: 'A♣', angle: -.18, height: 58)),
          Positioned(
            right: 8,
            bottom: -3,
            child: Container(
              width: 57,
              height: 57,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFFFFE483), Color(0xFFD89208), Color(0xFF704000)]),
                border: Border.all(color: const Color(0xFFFFE6A4), width: 2),
                boxShadow: const [BoxShadow(color: Color(0x88764B00), blurRadius: 16)],
              ),
              child: const Icon(Icons.stars_rounded, color: Color(0xFF5E3400), size: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final String mark;
  final double angle;
  final double height;
  const _BigCard({required this.mark, required this.angle, required this.height});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: height * .64,
        height: height,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6DE),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFD8B45A)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 7, offset: Offset(0, 4))],
        ),
        child: Text(
          mark,
          style: TextStyle(
            color: mark.contains('♥') ? const Color(0xFFB32028) : Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: max(10.0, height * .18),
          ),
        ),
      ),
    );
  }
}

class RoundRoomCard extends StatefulWidget {
  final int players;
  final bool compact;
  final int waitingPlayers;
  final int activeRooms;
  final VoidCallback onTap;

  const RoundRoomCard({
    super.key,
    required this.players,
    required this.compact,
    required this.waitingPlayers,
    required this.activeRooms,
    required this.onTap,
  });

  @override
  State<RoundRoomCard> createState() => _RoundRoomCardState();
}

class _RoundRoomCardState extends State<RoundRoomCard> with SingleTickerProviderStateMixin {
  bool pressed = false;
  late final AnimationController wheelController;

  @override
  void initState() {
    super.initState();
    wheelController = AnimationController(vsync: this, duration: Duration(milliseconds: 6800 + widget.players * 170))..repeat();
  }

  @override
  void dispose() {
    wheelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final palette = _paletteFor(players);
    final limit = _limitFor(players);
    final title = players == 2 ? '1 VS 1' : '$players';
    final subtitle = players == 2 ? 'DUEL' : 'PLAYERS';
    final diameter = widget.compact ? 170.0 : 204.0;
    final hasActivity = widget.waitingPlayers > 0 || widget.activeRooms > 0;
    final liveText = widget.waitingPlayers > 0
        ? '${widget.waitingPlayers} WAITING'
        : (widget.activeRooms > 0 ? '${widget.activeRooms} LIVE' : 'OPEN');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .9, end: 1),
      duration: Duration(milliseconds: 260 + players * 18),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(opacity: min(1.0, value), child: Transform.scale(scale: value, child: child)),
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressed = true),
        onTapCancel: () => setState(() => pressed = false),
        onTapUp: (_) {
          setState(() => pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: pressed ? .95 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Center(
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-.28, -.38),
                        radius: 1.0,
                        colors: [palette.top, palette.bottom],
                      ),
                      border: Border.all(color: palette.accent.withValues(alpha: .9), width: 2.2),
                      boxShadow: [
                        BoxShadow(color: palette.accent.withValues(alpha: .25), blurRadius: 20, spreadRadius: 1),
                        const BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 8)),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: RotationTransition(
                      turns: wheelController,
                      child: CustomPaint(painter: _CasinoRingPainter(palette.accent)),
                    ),
                  ),
                  Positioned(
                    right: widget.compact ? 2 : 3,
                    top: widget.compact ? 10 : 13,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasActivity ? const Color(0xE6123A22) : const Color(0xD31B211E),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: hasActivity ? const Color(0xFF59F27D) : Colors.white24),
                        boxShadow: hasActivity ? const [BoxShadow(color: Color(0x5559F27D), blurRadius: 9)] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: hasActivity ? const Color(0xFF59F27D) : Colors.white38)),
                          const SizedBox(width: 4),
                          Text(liveText, style: TextStyle(fontSize: 7.5, color: hasActivity ? const Color(0xFFBFFFCB) : Colors.white54, fontWeight: FontWeight.w900, letterSpacing: .45)),
                        ],
                      ),
                    ),
                  ),
                  Positioned(top: -10, child: _RoomCards(accent: palette.accent, compact: widget.compact)),
                  Positioned(
                    top: widget.compact ? 44 : 57,
                    child: Icon(players == 2 ? Icons.person_rounded : Icons.groups_rounded, color: palette.accent, size: widget.compact ? 26 : 30),
                  ),
                  Positioned(
                    top: widget.compact ? 71 : 90,
                    child: Column(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: players == 2 ? (widget.compact ? 24 : 28) : (widget.compact ? 31 : 38),
                            height: .9,
                            color: const Color(0xFFFFF3D0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: .2,
                            shadows: const [Shadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 2))],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w900, letterSpacing: .8)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: widget.compact ? 16 : 20,
                    bottom: widget.compact ? 32 : 38,
                    child: _ChipStack(accent: palette.accent, mirror: false, compact: widget.compact),
                  ),
                  Positioned(
                    right: widget.compact ? 16 : 20,
                    bottom: widget.compact ? 32 : 38,
                    child: _ChipStack(accent: palette.accent, mirror: true, compact: widget.compact),
                  ),
                  Positioned(
                    bottom: widget.compact ? 10 : 13,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 18 : 22, vertical: widget.compact ? 5 : 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(colors: [palette.button1, palette.button2]),
                        border: Border.all(color: palette.accent.withValues(alpha: .6)),
                        boxShadow: [BoxShadow(color: palette.accent.withValues(alpha: .18), blurRadius: 8)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, color: Colors.white70, size: 12),
                          const SizedBox(width: 4),
                          const Text('10', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 8),
                          Text('•  $limit LIMIT', style: TextStyle(fontSize: 10, color: palette.accent, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCards extends StatelessWidget {
  final Color accent;
  final bool compact;
  const _RoomCards({required this.accent, required this.compact});

  @override
  Widget build(BuildContext context) {
    final h = compact ? 42.0 : 50.0;
    Widget mini(String mark, double angle, double dx) => Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: angle,
            child: Container(
              width: h * .63,
              height: h,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DE),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withValues(alpha: .75)),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5, offset: Offset(0, 3))],
              ),
              child: Text(
                mark,
                style: TextStyle(color: mark.contains('♥') ? const Color(0xFFB51F28) : Colors.black, fontWeight: FontWeight.w900, fontSize: compact ? 8 : 10),
              ),
            ),
          ),
        );
    return SizedBox(
      width: h * 1.9,
      height: h + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [mini('A♣', -.2, -20), mini('A♥', 0, 0), mini('A♠', .2, 20)],
      ),
    );
  }
}

class _ChipStack extends StatelessWidget {
  final Color accent;
  final bool mirror;
  final bool compact;
  const _ChipStack({required this.accent, required this.mirror, required this.compact});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 14.0 : 17.0;
    return Transform.rotate(
      angle: mirror ? .12 : -.12,
      child: Row(
        children: List.generate(3, (i) {
          return Transform.translate(
            offset: Offset(i * -3.0, -i * 3.0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i.isEven ? accent : const Color(0xFF111111),
                border: Border.all(color: const Color(0xFFFFE6A4), width: 1),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
              ),
              child: Center(child: Container(width: size * .36, height: size * .36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x55FFFFFF)))),
            ),
          );
        }),
      ),
    );
  }
}

class _CasinoRingPainter extends CustomPainter {
  final Color accent;
  const _CasinoRingPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 7;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFD86A).withValues(alpha: .46);
    canvas.drawCircle(center, radius, ring);
    final inner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = accent.withValues(alpha: .28);
    canvas.drawCircle(center, radius - 7, inner);
    final dot = Paint()..color = const Color(0xFFFFE5A0).withValues(alpha: .75);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      canvas.drawCircle(Offset(center.dx + cos(a) * radius, center.dy + sin(a) * radius), 1.3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _CasinoRingPainter oldDelegate) => oldDelegate.accent != accent;
}

String _limitFor(int players) {
  if (players <= 5) return '5K';
  if (players <= 8) return '20K';
  return '50K';
}

_TablePalette _paletteFor(int players) {
  if (players <= 5) {
    return const _TablePalette(
      top: Color(0xFF126238),
      bottom: Color(0xFF03180F),
      accent: Color(0xFF76F06A),
      button1: Color(0xFF13943A),
      button2: Color(0xFF07511E),
    );
  }
  if (players <= 8) {
    return const _TablePalette(
      top: Color(0xFF115998),
      bottom: Color(0xFF03182D),
      accent: Color(0xFF62B9FF),
      button1: Color(0xFF1473C8),
      button2: Color(0xFF073F78),
    );
  }
  return const _TablePalette(
    top: Color(0xFF765108),
    bottom: Color(0xFF241600),
    accent: Color(0xFFFFD45A),
    button1: Color(0xFFC88B12),
    button2: Color(0xFF7C5005),
  );
}

class _TablePalette {
  final Color top;
  final Color bottom;
  final Color accent;
  final Color button1;
  final Color button2;
  const _TablePalette({required this.top, required this.bottom, required this.accent, required this.button1, required this.button2});
}

class AppMenu extends StatelessWidget {
  final AppSession session;
  final int activePage;

  const AppMenu({super.key, required this.session, required this.activePage});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: min(width * .38, 330.0),
      backgroundColor: const Color(0xFF050A08),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(22), bottomLeft: Radius.circular(22)),
        side: BorderSide(color: Color(0xFF8B6417)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: 42, height: 35, child: _CardLogo()),
                  const SizedBox(width: 6),
                  const Expanded(child: Text('3 PATTI', style: TextStyle(fontSize: 18, color: gold, fontWeight: FontWeight.w900, letterSpacing: 1))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: gold)),
                ],
              ),
              const Divider(height: 10, color: Color(0xFF5E4617)),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _MenuTile(icon: Icons.home_rounded, label: 'Home', selected: activePage == 0, onTap: () => _select(context, 0)),
                    _MenuTile(icon: Icons.shopping_cart_outlined, label: 'Store', selected: activePage == 1, onTap: () => _select(context, 1)),
                    _MenuTile(icon: Icons.history_rounded, label: 'History', selected: activePage == 2, onTap: () => _select(context, 2)),
                    _MenuTile(icon: Icons.person_rounded, label: 'Profile', selected: activePage == 3, onTap: () => _select(context, 3)),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 3), child: Divider(color: Colors.white10)),
                    _MenuTile(icon: Icons.paid_rounded, label: 'Social Chips', selected: activePage == 4, onTap: () => _select(context, 4)),
                    _MenuTile(icon: Icons.settings_rounded, label: 'Settings', selected: activePage == 6, onTap: () => _select(context, 6)),
                    _MenuTile(icon: Icons.support_agent_rounded, label: 'Support', selected: activePage == 7, onTap: () => _select(context, 7)),
                    _MenuTile(icon: Icons.gavel_rounded, label: 'Rules & fees', selected: activePage == 8, onTap: () => _select(context, 8)),
                  ],
                ),
              ),
              const Text('3 Patti Social • v1.6', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white30)),
            ],
          ),
        ),
      ),
    );
  }

  void _select(BuildContext context, int page) {
    session.setPage(page);
    Navigator.pop(context);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        onTap: onTap,
        leading: Icon(icon, color: selected ? gold : const Color(0xFFC9B782), size: 21),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: selected ? const Color(0xFFFFE6A4) : Colors.white70)),
        trailing: Icon(Icons.chevron_right_rounded, size: 20, color: selected ? gold : Colors.white30),
        tileColor: selected ? const Color(0xFF123A23) : const Color(0xFF0A110E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? const Color(0xFF8F6C21) : const Color(0xFF3A3018)),
        ),
      ),
    );
  }
}

const _socialProductIds = <String>{
  'com.droxion.threepatti.chips25k',
  'com.droxion.threepatti.chips150k',
  'com.droxion.threepatti.chips400k',
  'com.droxion.threepatti.chips1m',
  'com.droxion.threepatti.vip.monthly',
};

class _SocialOffer {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool vip;
  const _SocialOffer(this.id, this.title, this.subtitle, this.icon, {this.vip = false});
}

const _socialOffers = <_SocialOffer>[
  _SocialOffer('com.droxion.threepatti.chips25k', '25K CHIPS', 'Starter chip pack', Icons.paid_rounded),
  _SocialOffer('com.droxion.threepatti.chips150k', '150K CHIPS', 'Best for regular play', Icons.stars_rounded),
  _SocialOffer('com.droxion.threepatti.chips400k', '400K CHIPS', 'Big social chip pack', Icons.local_fire_department_rounded),
  _SocialOffer('com.droxion.threepatti.chips1m', '1M CHIPS', 'Mega social chip pack', Icons.diamond_rounded),
  _SocialOffer('com.droxion.threepatti.vip.monthly', 'VIP MONTHLY', 'VIP badge + premium status', Icons.workspace_premium_rounded, vip: true),
];

class StoreView extends StatefulWidget {
  final AppSession session;
  const StoreView({super.key, required this.session});

  @override
  State<StoreView> createState() => _StoreViewState();
}

class _StoreViewState extends State<StoreView> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  Map<String, ProductDetails> products = {};
  final Set<String> claiming = {};
  bool storeAvailable = false;
  bool loading = true;
  String message = 'Loading App Store products…';

  @override
  void initState() {
    super.initState();
    _purchaseSub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
      if (mounted) setState(() => message = 'Purchase update error: $e');
    });
    _load();
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      storeAvailable = await _iap.isAvailable();
      if (storeAvailable) {
        final response = await _iap.queryProductDetails(_socialProductIds);
        products = {for (final p in response.productDetails) p.id: p};
        if (response.error != null) {
          message = 'App Store: ${response.error!.message}';
        } else if (products.isEmpty) {
          message = 'Create the 5 products in App Store Connect to activate purchases.';
        } else {
          message = 'SOCIAL CHIPS • NO CASH VALUE • NO WITHDRAWAL';
        }
      } else {
        message = 'App Store purchases are unavailable on this device.';
      }
      try {
        final cfg = await Api.get('/social/store-config?playerId=${Uri.encodeQueryComponent(widget.session.playerId)}');
        final wallet = cfg['wallet'];
        if (wallet is Map && wallet['chips'] is int) widget.session.updateWallet(wallet['chips'] as int);
        widget.session.setVipActive(cfg['vipActive'] == true);
      } catch (_) {}
    } catch (e) {
      message = 'Could not load store: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _buy(_SocialOffer offer) async {
    final product = products[offer.id];
    if (!storeAvailable || product == null) {
      setState(() => message = 'This product is not active in App Store Connect yet.');
      return;
    }
    HapticFeedback.selectionClick();
    final param = PurchaseParam(productDetails: product);
    if (offer.vip) {
      await _iap.buyNonConsumable(purchaseParam: param);
    } else {
      await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => message = 'Waiting for App Store confirmation…');
        continue;
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) setState(() => message = purchase.error?.message ?? 'Purchase failed.');
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) setState(() => message = 'Purchase canceled.');
      } else if (purchase.status == PurchaseStatus.purchased || purchase.status == PurchaseStatus.restored) {
        await _claimPurchase(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _claimPurchase(PurchaseDetails purchase) async {
    final purchaseId = purchase.purchaseID ?? '${purchase.productID}:${purchase.transactionDate ?? DateTime.now().millisecondsSinceEpoch}';
    if (!claiming.add(purchaseId)) return;
    try {
      final result = await Api.post('/social/iap/claim', {
        'playerId': widget.session.playerId,
        'productId': purchase.productID,
        'transactionId': purchaseId,
        'transactionDate': purchase.transactionDate,
        'verificationSource': purchase.verificationData.source,
        'verificationData': purchase.verificationData.serverVerificationData,
      });
      final chips = result['walletChips'];
      if (chips is int) widget.session.updateWallet(chips);
      widget.session.setVipActive(result['vipActive'] == true);
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          message = result['idempotent'] == true
              ? 'Purchase already delivered.'
              : '${result['message'] ?? 'Purchase delivered.'}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => message = 'Purchase verification pending: $e');
    } finally {
      claiming.remove(purchaseId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'SOCIAL STORE',
      subtitle: 'Virtual chips and VIP — never redeemable for cash',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C2117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF7A5A16)),
            ),
            child: Row(
              children: [
                const CasinoChip(color: Color(0xFFE4B530), size: 30),
                const SizedBox(width: 9),
                Text('${_money(widget.session.walletChips)} CHIPS', style: const TextStyle(fontSize: 18, color: gold, fontWeight: FontWeight.w900)),
                if (widget.session.vipActive) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF5B3A04), borderRadius: BorderRadius.circular(99), border: Border.all(color: gold)),
                    child: const Text('VIP', style: TextStyle(color: Color(0xFFFFE39A), fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: storeAvailable ? () => _iap.restorePurchases() : null,
                  icon: const Icon(Icons.restore_rounded, size: 17),
                  label: const Text('RESTORE'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 5 : 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
              ),
              itemCount: _socialOffers.length,
              itemBuilder: (context, index) {
                final offer = _socialOffers[index];
                final product = products[offer.id];
                return InkWell(
                  onTap: loading ? null : () => _buy(offer),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: offer.vip
                          ? const LinearGradient(colors: [Color(0xFF6A4305), Color(0xFF1B1203)])
                          : const LinearGradient(colors: [Color(0xFF0D482A), Color(0xFF06170F)]),
                      border: Border.all(color: offer.vip ? gold : const Color(0xFF39915A)),
                      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(offer.icon, color: offer.vip ? gold : const Color(0xFF74F095), size: 30),
                        const Spacer(),
                        Text(offer.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(offer.subtitle, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                        const SizedBox(height: 8),
                        Text(product?.price ?? 'SET UP IN APP STORE', style: TextStyle(fontSize: 11, color: product == null ? Colors.white38 : gold, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Colors.white54, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          const Text('Purchased chips are virtual entertainment credits only. They cannot be sold, transferred, redeemed, or withdrawn for money.', textAlign: TextAlign.center, style: TextStyle(fontSize: 8.5, color: Colors.white38)),
        ],
      ),
    );
  }
}

class HistoryView extends StatelessWidget {
  final AppSession session;

  const HistoryView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    if (session.history.isEmpty) {
      return const PageFrame(
        title: 'HISTORY',
        subtitle: 'Your recent tables and results',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history_rounded, size: 58, color: Colors.white24),
              SizedBox(height: 12),
              Text('No games yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('Completed rounds from this app session will appear here.', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }
    return PageFrame(
      title: 'HISTORY',
      subtitle: 'Your recent tables and results',
      child: ListView.separated(
        itemCount: session.history.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final item = session.history[index];
          return ListTile(
            tileColor: const Color(0xFF0A1712),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF38483E))),
            leading: CircleAvatar(
              backgroundColor: item.won ? const Color(0xFF0F5722) : const Color(0xFF4A2323),
              child: Icon(item.won ? Icons.emoji_events_rounded : Icons.style_rounded, color: item.won ? gold : Colors.white70),
            ),
            title: Text('${item.players}-player table • Pot ${item.pot} chips', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(item.won ? 'Won ${item.payout} chips' : 'Round completed', style: const TextStyle(color: Colors.white60)),
            trailing: Text('${_two(item.at.hour)}:${_two(item.at.minute)}', style: const TextStyle(color: Colors.white38)),
          );
        },
      ),
    );
  }
}


class ProfileView extends StatelessWidget {
  final AppSession session;

  const ProfileView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'PROFILE',
      subtitle: 'Your player identity',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _panelDecoration(),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 106,
                        height: 106,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [Color(0xFFFFDB73), Color(0xFF7B5108)]),
                          boxShadow: const [BoxShadow(color: Color(0x668C5E00), blurRadius: 18)],
                        ),
                        child: ClipOval(child: Image.asset(_avatarAsset(session.avatarIndex), fit: BoxFit.cover)),
                      ),
                      const SizedBox(height: 11),
                      Text(session.displayName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                      Text('Player ID: ${session.playerId}', style: const TextStyle(fontSize: 9.5, color: Colors.white38)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CasinoChip(color: Color(0xFFE4B530), size: 22),
                          const SizedBox(width: 7),
                          Text('${_money(session.walletChips)} CHIPS', style: const TextStyle(fontSize: 16, color: gold, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: () => _editName(context),
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text('EDIT DISPLAY NAME'),
                      ),
                      const SizedBox(height: 8),
                      const Text('SOCIAL MODE • NO CASH VALUE', style: TextStyle(fontSize: 9.5, color: Colors.white54, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('CHOOSE PROFILE IMAGE', style: TextStyle(fontSize: 13, color: gold, fontWeight: FontWeight.w900, letterSpacing: .8)),
                      const SizedBox(height: 4),
                      const Text('This round avatar and your name are shown to players at the live table.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1,
                        ),
                        itemCount: 8,
                        itemBuilder: (context, index) {
                          final avatar = index + 1;
                          final selected = session.avatarIndex == avatar;
                          return InkWell(
                            onTap: () => session.updateAvatar(avatar),
                            customBorder: const CircleBorder(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: EdgeInsets.all(selected ? 4 : 7),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? const Color(0xFF5C410A) : const Color(0xFF0B1712),
                                border: Border.all(color: selected ? gold : Colors.white12, width: selected ? 3 : 1),
                                boxShadow: selected ? const [BoxShadow(color: Color(0x557C5700), blurRadius: 12)] : null,
                              ),
                              child: ClipOval(child: Image.asset(_avatarAsset(avatar), fit: BoxFit.cover)),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: session.displayName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(controller: controller, maxLength: 24, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('SAVE')),
        ],
      ),
    );
    controller.dispose();
    if (result != null) session.updateName(result);
  }
}

class KycScreen extends StatefulWidget {
  final AppSession session;
  const KycScreen({super.key, required this.session});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final legalName = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final dob = TextEditingController();
  final address = TextEditingController();
  final taxId = TextEditingController();
  final govId = TextEditingController();
  String taxType = 'ssn';
  String govType = 'license';
  bool age21 = false;
  bool loading = true;
  bool saving = false;
  String status = 'UNVERIFIED';
  String message = 'Complete identity details to prepare Cash Mode verification.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    legalName.dispose(); email.dispose(); phone.dispose(); dob.dispose(); address.dispose(); taxId.dispose(); govId.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Api.get('/kyc/status?playerId=${Uri.encodeQueryComponent(widget.session.playerId)}');
      final p = data['profile'];
      final v = data['verification'];
      if (p is Map) {
        legalName.text = '${p['legalName'] ?? ''}';
        email.text = '${p['email'] ?? ''}';
        phone.text = '${p['phone'] ?? ''}';
        dob.text = '${p['dob'] ?? ''}';
        address.text = '${p['homeAddress'] ?? ''}';
        taxType = '${p['taxIdType'] ?? ''}' == 'tin' ? 'tin' : 'ssn';
        govType = '${p['governmentIdType'] ?? ''}' == 'passport' ? 'passport' : 'license';
        age21 = p['ageDeclared21'] == true;
      }
      if (v is Map) status = '${v['kycStatus'] ?? 'unverified'}'.toUpperCase();
    } catch (e) {
      message = 'Could not load verification status: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() { saving = true; message = 'Submitting identity details…'; });
    try {
      final data = await Api.post('/kyc/profile', {
        'playerId': widget.session.playerId,
        'legalName': legalName.text,
        'email': email.text,
        'phone': phone.text,
        'dob': dob.text,
        'homeAddress': address.text,
        'taxIdType': taxType,
        'taxId': taxId.text,
        'governmentIdType': govType,
        'governmentId': govId.text,
        'ageDeclared21': age21,
      });
      status = '${data['status'] ?? 'submitted'}'.toUpperCase();
      message = '${data['message'] ?? 'Submitted.'}';
      taxId.clear();
      govId.clear();
    } catch (e) {
      message = 'Verification submission failed: $e';
    }
    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        backgroundColor: const Color(0xFF050B08),
        title: const Text('VERIFY IDENTITY / 21+', style: TextStyle(color: gold, fontWeight: FontWeight.w900)),
      ),
      body: CasinoBackdrop(
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: _panelDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Icon(Icons.verified_user_rounded, color: gold, size: 30),
                              const SizedBox(width: 10),
                              Expanded(child: Text('STATUS: $status', style: const TextStyle(fontSize: 18, color: Color(0xFFFFE0A0), fontWeight: FontWeight.w900))),
                            ]),
                            const SizedBox(height: 6),
                            const Text('No selfie or video in this flow. SSN/TIN is optional at initial submission. An approved cash-gaming operator/KYC provider may still require additional information before real-money play.', style: TextStyle(fontSize: 10.5, color: Colors.white60)),
                            const SizedBox(height: 14),
                            Row(children: [
                              Expanded(child: TextField(controller: legalName, decoration: const InputDecoration(labelText: 'Full legal name', border: OutlineInputBorder()))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', border: OutlineInputBorder()))),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: dob, decoration: const InputDecoration(labelText: 'Date of birth', hintText: 'YYYY-MM-DD', border: OutlineInputBorder()))),
                            ]),
                            const SizedBox(height: 10),
                            TextField(controller: address, decoration: const InputDecoration(labelText: 'Home address', border: OutlineInputBorder())),
                            const SizedBox(height: 10),
                            Row(children: [
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<String>(
                                  value: taxType,
                                  decoration: const InputDecoration(labelText: 'Optional tax ID', border: OutlineInputBorder()),
                                  items: const [DropdownMenuItem(value: 'ssn', child: Text('SSN')), DropdownMenuItem(value: 'tin', child: Text('TIN'))],
                                  onChanged: (v) => setState(() => taxType = v ?? 'ssn'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: taxId, obscureText: true, decoration: const InputDecoration(labelText: 'SSN/TIN — optional now', hintText: 'Not stored in raw form', border: OutlineInputBorder()))),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<String>(
                                  value: govType,
                                  decoration: const InputDecoration(labelText: 'Government ID', border: OutlineInputBorder()),
                                  items: const [DropdownMenuItem(value: 'license', child: Text("Driver's license")), DropdownMenuItem(value: 'passport', child: Text('Passport'))],
                                  onChanged: (v) => setState(() => govType = v ?? 'license'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: TextField(controller: govId, obscureText: true, decoration: const InputDecoration(labelText: 'License / passport number', hintText: 'Not stored in raw form', border: OutlineInputBorder()))),
                            ]),
                            const SizedBox(height: 8),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: age21,
                              onChanged: (v) => setState(() => age21 = v == true),
                              activeColor: gold,
                              title: const Text('I confirm I am 21 or older', style: TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: const Text('Date of birth must also show age 21+.', style: TextStyle(fontSize: 10, color: Colors.white54)),
                            ),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              onPressed: saving ? null : _save,
                              icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.lock_rounded),
                              label: const Text('SUBMIT FOR VERIFICATION'),
                            ),
                            const SizedBox(height: 10),
                            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class PageFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const PageFrame({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 4, height: 28, decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 20, color: Color(0xFFFFE2A1), fontWeight: FontWeight.w900, letterSpacing: .8)),
                  Text(subtitle, style: const TextStyle(fontSize: 9.5, color: Color(0x75FFFFFF))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}


class WalletView extends StatelessWidget {
  final AppSession session;
  const WalletView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'SOCIAL CHIPS',
      subtitle: 'Entertainment credits only — no cash value',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Color(0xFFFFE58A), Color(0xFFD6930B), Color(0xFF5F3700)]),
                  border: Border.all(color: const Color(0xFFFFEDB0), width: 4),
                  boxShadow: const [BoxShadow(color: Color(0x887A5000), blurRadius: 28)],
                ),
                child: const Icon(Icons.stars_rounded, size: 72, color: Color(0xFF4D2C00)),
              ),
              const SizedBox(height: 14),
              Text('${_money(session.walletChips)} CHIPS', style: const TextStyle(fontSize: 31, color: gold, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              const Text('SOCIAL CHIP BALANCE', style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1)),
              if (session.vipActive) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF563804), borderRadius: BorderRadius.circular(99), border: Border.all(color: gold)),
                  child: const Text('★ VIP ACTIVE', style: TextStyle(color: Color(0xFFFFE0A0), fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => session.setPage(1),
                icon: const Icon(Icons.shopping_bag_rounded),
                label: const Text('GET MORE CHIPS'),
              ),
              const SizedBox(height: 11),
              const Text(
                'Social chips can only be used inside 3 Patti Social. They cannot be withdrawn, redeemed for USD, transferred to PayPal/bank, or exchanged for anything of value.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.white54, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawView extends StatefulWidget {
  final AppSession session;
  const WithdrawView({super.key, required this.session});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final destinationController = TextEditingController();
  final chipsController = TextEditingController();
  bool sending = false;
  bool cashModeEnabled = false;
  String provider = 'paypal';
  String? requestId;
  String? message;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final result = await Api.get('/payments-config');
      if (mounted) setState(() => cashModeEnabled = result['cashModeEnabled'] == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    destinationController.dispose();
    chipsController.dispose();
    super.dispose();
  }

  Future<void> _submitSandbox() async {
    final destination = destinationController.text.trim();
    final chips = int.tryParse(chipsController.text.replaceAll(',', '').trim()) ?? 0;
    final destinationOk = provider == 'paypal' ? destination.contains('@') : destination.length >= 4;
    if (!destinationOk || chips <= 0 || chips > widget.session.walletChips) {
      setState(() => message = provider == 'paypal'
          ? 'Enter a valid PayPal email and chip amount within your balance.'
          : 'Enter bank account last 4 digits/reference and a chip amount within your balance.');
      return;
    }
    setState(() {
      sending = true;
      message = null;
      requestId = null;
    });
    try {
      final result = await Api.post('/withdraw-sandbox', {
        'playerId': widget.session.playerId,
        'provider': provider,
        'destination': destination,
        'chips': chips,
      });
      if (!mounted) return;
      final walletChips = result['walletChips'];
      if (walletChips is int) widget.session.updateWallet(walletChips);
      setState(() {
        requestId = '${result['requestId']}';
        message = '${_providerLabel(provider)} sandbox withdrawal created. No real payout was sent.';
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usdPreview = widget.session.walletChips / 100.0;
    return PageFrame(
      title: 'WITHDRAW',
      subtitle: cashModeEnabled ? 'Approved payout mode' : 'PayPal + bank payout rails — sandbox',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: _panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _PayoutSelector(selected: provider == 'paypal', icon: Icons.account_balance_wallet_rounded, title: 'PAYPAL', onTap: () => setState(() { provider = 'paypal'; destinationController.clear(); message = null; }))),
                      const SizedBox(width: 10),
                      Expanded(child: _PayoutSelector(selected: provider == 'bank', icon: Icons.account_balance_rounded, title: 'BANK / ACH', onTap: () => setState(() { provider = 'bank'; destinationController.clear(); message = null; }))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('${_money(widget.session.walletChips)} CHIPS AVAILABLE', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  Text('Sandbox preview • 100 chips = \$1.00 • \$${usdPreview.toStringAsFixed(2)} shown balance', style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destinationController,
                    keyboardType: provider == 'paypal' ? TextInputType.emailAddress : TextInputType.text,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: provider == 'paypal' ? 'PayPal email' : 'Bank payout reference / last 4',
                      hintText: provider == 'paypal' ? 'name@example.com' : '1234',
                      prefixIcon: Icon(provider == 'paypal' ? Icons.alternate_email_rounded : Icons.account_balance_rounded),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: chipsController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Chips to withdraw', hintText: '1000', prefixIcon: Icon(Icons.stars_rounded), border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: sending ? null : _submitSandbox,
                    icon: sending ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.payments_rounded),
                    label: Text(sending ? 'CREATING REQUEST...' : 'REQUEST ${_providerLabel(provider)} WITHDRAWAL — SANDBOX'),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: requestId == null ? const Color(0xFF351C15) : const Color(0xFF0F3020), borderRadius: BorderRadius.circular(12), border: Border.all(color: requestId == null ? Colors.orangeAccent : const Color(0xFF59E781))),
                      child: Text(requestId == null ? message! : '$message\nRequest: $requestId', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const _PrototypeNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PayoutSelector extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _PayoutSelector({required this.selected, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123A23) : const Color(0xFF0A110E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? gold : const Color(0xFF3A3018)),
        ),
        child: Row(children: [Icon(icon, color: selected ? gold : Colors.white60), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: selected ? const Color(0xFFFFE6A4) : Colors.white70))]),
      ),
    );
  }
}

String _providerLabel(String provider) => switch (provider) {
      'apple_pay' => 'APPLE PAY',
      'cash_app' => 'CASH APP PAY',
      'card' => 'CARD',
      'bank' => 'BANK / ACH',
      _ => 'PAYPAL',
    };

class SettingsView extends StatelessWidget {
  final AppSession session;
  const SettingsView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => PageFrame(
        title: 'SETTINGS',
        subtitle: 'Game preferences and account controls',
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _panelDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    value: session.soundEnabled,
                    onChanged: session.setSoundEnabled,
                    title: const Text('Card & chip sounds'),
                    subtitle: const Text('Deal, card and chip effects', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    secondary: const Icon(Icons.volume_up_rounded, color: gold),
                  ),
                  SwitchListTile(
                    value: session.musicEnabled,
                    onChanged: session.setMusicEnabled,
                    title: const Text('Win music'),
                    subtitle: const Text('Winner celebration jingle', style: TextStyle(fontSize: 10, color: Colors.white54)),
                    secondary: const Icon(Icons.music_note_rounded, color: gold),
                  ),
                  const Divider(height: 22),
                  const Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 10)),
                  const SizedBox(height: 7),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                    onPressed: () => _confirmDelete(context),
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('DELETE ACCOUNT'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('Are you sure? This prototype will clear your local profile name and game history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: () => Navigator.pop(context, true), child: const Text('DELETE')),
        ],
      ),
    );
    if (ok == true) session.resetAccount();
  }
}

class RulesView extends StatelessWidget {
  final AppSession session;
  const RulesView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'RULES & FEES',
      subtitle: 'Clear rules before you play',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RuleLine('3 Patti Social uses virtual entertainment chips only. Chips have no cash value.'),
                _RuleLine('Purchased chips cannot be withdrawn, sold, transferred, or redeemed for money or prizes.'),
                _RuleLine('Boot starts at 10 chips.'),
                _RuleLine('Table limits: 2-5 players = 5K, 6-8 players = 20K, 9-10 players = 50K.'),
                _RuleLine('Players compete against other players; the server deals the cards.'),
                _RuleLine('A 5% virtual-chip table fee is deducted from a settled pot to help balance the social-chip economy.'),
                _RuleLine('VIP is a digital membership benefit and does not increase the odds of winning cards.'),
                SizedBox(height: 12),
                Text(
                  'This release is social entertainment only. There are no real-money deposits, cash winnings, PayPal withdrawals, bank withdrawals, or cash conversion.',
                  style: TextStyle(color: Colors.amberAccent, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  final String text;
  const _RuleLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_rounded, color: greenAccent, size: 19),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

class SupportView extends StatelessWidget {
  final AppSession session;
  const SupportView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'SUPPORT',
      subtitle: 'Help and player support',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _panelDecoration(),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(Icons.support_agent_rounded, color: gold, size: 34), SizedBox(width: 10), Text('Support center', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900))]),
                SizedBox(height: 10),
                Text('Add your real support email, FAQ, and ticket system before public launch.', style: TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String helper;

  const _MetricCard({required this.label, required this.value, required this.helper});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        Text(helper, style: const TextStyle(color: Colors.white54)),
      ]),
    );
  }
}

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF302511), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF805F1B))),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: gold),
        SizedBox(width: 10),
        Expanded(child: Text('Payment, KYC, bank, and withdrawal processing are intentionally not connected in this prototype build.')),
      ]),
    );
  }
}

class MatchmakingScreen extends StatefulWidget {
  final AppSession session;
  final int playerCount;
  final String? excludeRoomId;

  const MatchmakingScreen({super.key, required this.session, required this.playerCount, this.excludeRoomId});

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
        'playerId': widget.session.playerId,
        'name': widget.session.displayName,
        'avatar': widget.session.avatarIndex,
        'playerCount': widget.playerCount,
        if (widget.excludeRoomId != null) 'excludeRoomId': widget.excludeRoomId,
      });
      roomId = state['roomId'] as String;
      _consume(state);
      poller?.cancel();
      poller = Timer.periodic(const Duration(milliseconds: 850), (_) => _poll());
      if (state['status'] == 'playing') _openTable();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _poll() async {
    if (roomId == null) return;
    try {
      final state = await Api.get('/state?roomId=${Uri.encodeComponent(roomId!)}&playerId=${Uri.encodeComponent(widget.session.playerId)}');
      _consume(state);
      if (state['status'] == 'playing') _openTable();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _openTable() {
    if (!mounted || roomId == null) return;
    poller?.cancel();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => TableScreen(roomId: roomId!, session: widget.session),
    ));
  }

  void _consume(Map<String, dynamic> state) {
    if (!mounted) return;
    setState(() {
      joined = state['joinedPlayers'] as int? ?? joined;
      message = state['message'] as String? ?? message;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(widget.playerCount);
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: const Color(0xFF04100B),
        foregroundColor: gold,
        title: Text(widget.playerCount == 2 ? '1 VS 1 MATCHMAKING' : '${widget.playerCount}-PLAYER MATCHMAKING', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        actions: [
          TextButton.icon(
            onPressed: () {
              widget.session.setPage(0);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_rounded, color: gold, size: 19),
            label: const Text('HOME', style: TextStyle(color: gold, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CasinoBackdrop(
        child: SafeArea(
          child: Center(
            child: Container(
              width: min(MediaQuery.sizeOf(context).width * .72, 700.0),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(colors: [palette.top, palette.bottom]),
                border: Border.all(color: palette.accent),
                boxShadow: [BoxShadow(color: palette.accent.withValues(alpha: .15), blurRadius: 22)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(error == null ? Icons.casino_rounded : Icons.cloud_off_rounded, size: 52, color: palette.accent),
                  const SizedBox(height: 12),
                  Text(widget.playerCount == 2 ? 'Finding your 1 VS 1 rival' : 'Finding ${widget.playerCount}-player table', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(error ?? '$joined / ${widget.playerCount} players ready', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(error ?? message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                  if (error == null) ...[
                    const SizedBox(height: 18),
                    LinearProgressIndicator(value: joined / widget.playerCount, color: palette.accent, backgroundColor: Colors.white12),
                  ] else ...[
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () { setState(() => error = null); _join(); }, child: const Text('TRY AGAIN')),
                  ],
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class TableScreen extends StatefulWidget {
  final String roomId;
  final AppSession session;

  const TableScreen({super.key, required this.roomId, required this.session});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with WidgetsBindingObserver {
  Timer? poller;
  Timer? ticker;
  Map<String, dynamic>? state;
  String? error;
  bool busy = false;
  bool appActive = true;
  bool reconnecting = false;
  int serverClockOffsetMs = 0;
  int networkEpoch = 0;
  int? recordedRound;
  int? lastRound;
  int lastPot = 0;
  String? lastWinnerId;
  String? lastTurnPlayerId;
  final AudioPlayer sfxPlayer = AudioPlayer();
  final AudioPlayer musicPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _poll();
    poller = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (appActive) _poll();
    });
    ticker = Timer.periodic(const Duration(milliseconds: 160), (_) {
      if (mounted && appActive && state?['status'] == 'playing') setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    // iOS can briefly become inactive while a notification/control overlay is shown.
    // Keep the live table polling in that case; only stop when genuinely backgrounded.
    appActive = lifecycleState == AppLifecycleState.resumed || lifecycleState == AppLifecycleState.inactive;
    if (lifecycleState == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      if (mounted) setState(() => reconnecting = true);
      _poll().whenComplete(() {
        if (mounted) setState(() => reconnecting = false);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poller?.cancel();
    ticker?.cancel();
    sfxPlayer.dispose();
    musicPlayer.dispose();
    super.dispose();
  }

  Future<void> _playSfx(String asset) async {
    if (!widget.session.soundEnabled) return;
    try {
      await sfxPlayer.stop();
      await sfxPlayer.play(AssetSource('sfx/$asset'));
    } catch (_) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  Future<void> _playWin() async {
    if (!widget.session.musicEnabled) return;
    try {
      await musicPlayer.stop();
      await musicPlayer.play(AssetSource('sfx/win.wav'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _poll() async {
    if (busy) return;
    final epoch = networkEpoch;
    try {
      final s = await Api.get('/state?roomId=${Uri.encodeComponent(widget.roomId)}&playerId=${Uri.encodeComponent(widget.session.playerId)}');
      if (!mounted || busy || epoch != networkEpoch) return;
      final localNow = DateTime.now().millisecondsSinceEpoch;
      final serverNow = s['serverNow'];
      if (serverNow is int) serverClockOffsetMs = serverNow - localNow;
      _handleGameTransitions(s);
      setState(() {
        state = s;
        error = null;
      });
      _syncWallet(s);
      _recordIfComplete(s);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _handleGameTransitions(Map<String, dynamic> s) {
    final round = s['round'] as int? ?? 0;
    final pot = s['pot'] as int? ?? 0;
    final winnerId = s['winnerId'] as String?;
    final turnPlayer = s['currentPlayerId'] as String?;

    if (lastRound != null && round != lastRound) _playSfx('card.wav');
    if (lastRound == null && s['status'] == 'playing') _playSfx('card.wav');
    if (pot > lastPot) _playSfx('chips.wav');
    if (winnerId != null && winnerId != lastWinnerId) {
      HapticFeedback.heavyImpact();
      _playWin();
    }
    if (turnPlayer == widget.session.playerId && turnPlayer != lastTurnPlayerId) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
    }

    lastRound = round;
    lastPot = pot;
    lastWinnerId = winnerId;
    lastTurnPlayerId = turnPlayer;
  }

  void _applyOptimisticBet(String action) {
    final current = state;
    if (current == null || (action != 'blind' && action != 'chaal')) return;
    final playersRaw = current['players'];
    if (playersRaw is! List) return;

    final players = playersRaw.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
    final meIndex = players.indexWhere((p) => p['id'] == widget.session.playerId);
    if (meIndex < 0) return;

    final me = players[meIndex];
    final pot = current['pot'] as int? ?? 0;
    final cap = current['cap'] as int? ?? 0;
    final blind = current['blindAmount'] as int? ?? 10;
    final chaal = current['chaalAmount'] as int? ?? blind * 2;
    final chips = me['chips'] as int? ?? 0;
    final wanted = action == 'chaal' ? chaal : blind;
    final amount = max(0, min(wanted, min(chips, max(0, cap - pot)))).toInt();
    if (amount <= 0) return;

    me['chips'] = chips - amount;
    final newPot = pot + amount;
    final currentId = current['currentPlayerId'];
    final currentIndex = players.indexWhere((p) => p['id'] == currentId);
    String? nextId;
    if (currentIndex >= 0) {
      for (var step = 1; step <= players.length; step++) {
        final candidate = players[(currentIndex + step) % players.length];
        if (candidate['folded'] != true) {
          nextId = candidate['id'] as String?;
          break;
        }
      }
    }

    final duration = current['turnDurationMs'] as int? ?? 60000;
    final serverNow = DateTime.now().millisecondsSinceEpoch + serverClockOffsetMs;
    final next = Map<String, dynamic>.from(current)
      ..['players'] = players
      ..['pot'] = newPot
      ..['lastAction'] = action
      ..['lastActorId'] = widget.session.playerId
      ..['lastBetAmount'] = amount
      ..['actionSeq'] = (current['actionSeq'] as int? ?? 0) + 1
      ..['message'] = action == 'chaal' ? 'You play CHAAL for $amount chips.' : 'You play BLIND for $amount chips.'
      ..['currentPlayerId'] = nextId
      ..['turnExpiresAt'] = nextId == null ? 0 : serverNow + duration
      ..['serverNow'] = serverNow;

    lastPot = newPot;
    widget.session.updateWallet(chips - amount);
    setState(() => state = next);
  }

  Future<void> _action(String action) async {
    if (busy) return;
    final rollback = state == null ? null : jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
    final isBet = action == 'blind' || action == 'chaal';
    networkEpoch += 1;
    HapticFeedback.mediumImpact();
    setState(() => busy = true);

    if (isBet) {
      _playSfx('chips.wav');
      _applyOptimisticBet(action);
    } else if (action == 'see' || action == 'show' || action == 'sideshow') {
      _playSfx('card.wav');
    }

    try {
      final result = await Api.post('/action', {
        'roomId': widget.roomId,
        'playerId': widget.session.playerId,
        'action': action,
      });
      if (!mounted) return;
      final localNow = DateTime.now().millisecondsSinceEpoch;
      final serverNow = result['serverNow'];
      if (serverNow is int) serverClockOffsetMs = serverNow - localNow;
      _handleGameTransitions(result);
      setState(() {
        state = result;
        error = null;
      });
      _syncWallet(result);
      _recordIfComplete(result);
    } catch (e) {
      if (!mounted) return;
      if (rollback != null) {
        setState(() {
          state = rollback;
          error = '$e';
        });
        _syncWallet(rollback);
      } else {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        Future<void>.delayed(const Duration(milliseconds: 80), _poll);
      }
    }
  }

  void _syncWallet(Map<String, dynamic> s) {
    final rawPlayers = s['players'];
    if (rawPlayers is! List) return;
    for (final raw in rawPlayers) {
      if (raw is Map && raw['id'] == widget.session.playerId) {
        final chips = raw['chips'];
        if (chips is int) widget.session.updateWallet(chips);
        break;
      }
    }
  }

  void _recordIfComplete(Map<String, dynamic> s) {
    if (s['status'] != 'showdown') return;
    final round = s['round'] as int? ?? 0;
    if (recordedRound == round) return;
    recordedRound = round;
    final won = s['winnerId'] == widget.session.playerId;
    widget.session.addHistory(GameHistoryItem(
      at: DateTime.now(),
      players: s['requestedPlayers'] as int? ?? 0,
      pot: s['pot'] as int? ?? 0,
      payout: s['lastPayout'] as int? ?? 0,
      fee: s['lastFee'] as int? ?? 0,
      won: won,
    ));
  }

  int _remainingMs(Map<String, dynamic> s) {
    final raw = s['turnExpiresAt'];
    if (raw is! int || raw <= 0) return 0;
    final adjustedNow = DateTime.now().millisecondsSinceEpoch + serverClockOffsetMs;
    return max(0, raw - adjustedNow);
  }


  Future<void> _leaveTable() async {
    try {
      final result = await Api.post('/leave', {
        'roomId': widget.roomId,
        'playerId': widget.session.playerId,
      });
      final walletChips = result['walletChips'];
      if (walletChips is int) widget.session.updateWallet(walletChips);
    } catch (_) {
      // Navigation should still succeed if the table already disappeared.
    }
  }

  Future<void> _exitTable() async {
    if (busy) return;
    setState(() => busy = true);
    await _leaveTable();
    if (!mounted) return;
    widget.session.setPage(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _switchTable(int playerCount) async {
    if (busy) return;
    setState(() => busy = true);
    await _leaveTable();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MatchmakingScreen(session: widget.session, playerCount: playerCount, excludeRoomId: widget.roomId),
    ));
  }


  void _applyOptimisticTip(int amount) {
    final current = state;
    if (current == null) return;
    final rawPlayers = current['players'];
    if (rawPlayers is! List) return;
    final players = rawPlayers.map((raw) => Map<String, dynamic>.from(raw as Map)).toList();
    final meIndex = players.indexWhere((p) => p['id'] == widget.session.playerId);
    if (meIndex < 0) return;
    final me = players[meIndex];
    final chips = me['chips'] as int? ?? 0;
    if (chips < amount) return;
    me['chips'] = chips - amount;
    final next = Map<String, dynamic>.from(current)
      ..['players'] = players
      ..['dealerTipTotal'] = (current['dealerTipTotal'] as int? ?? 0) + amount
      ..['lastTipAmount'] = amount
      ..['lastTipPlayerId'] = widget.session.playerId
      ..['lastAction'] = 'tip'
      ..['lastActorId'] = widget.session.playerId
      ..['lastBetAmount'] = 0
      ..['actionSeq'] = (current['actionSeq'] as int? ?? 0) + 1
      ..['message'] = 'You tipped the dealer $amount chips. Thank you!';
    widget.session.updateWallet(chips - amount);
    setState(() => state = next);
  }

  Future<void> _tipDealer() async {
    if (busy || state == null) return;
    final amount = await showDialog<int>(
      context: context,
      useRootNavigator: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF07110D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFF8E6B1D))),
        title: const Text('TIP THE DEALER', style: TextStyle(color: gold, fontWeight: FontWeight.w900, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose a sandbox chip tip. It is recorded separately from the game pot.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white54)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [10, 25, 50, 100].map((chips) => SizedBox(
                width: 92,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(chips),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: gold), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const CasinoChip(color: Color(0xFFE4B530), size: 20), const SizedBox(width: 5), Text('$chips', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))]),
                ),
              )).toList(),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('CANCEL'))],
      ),
    );
    if (amount == null || !mounted) return;

    final rollback = state == null ? null : jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
    setState(() => busy = true);
    HapticFeedback.mediumImpact();
    _playSfx('chips.wav');
    _applyOptimisticTip(amount);

    try {
      final result = await Api.post('/tip-dealer', {
        'roomId': widget.roomId,
        'playerId': widget.session.playerId,
        'chips': amount,
      });
      if (!mounted) return;
      _handleGameTransitions(result);
      setState(() {
        state = result;
        error = null;
      });
      _syncWallet(result);
    } catch (e) {
      if (!mounted) return;
      if (rollback != null) {
        setState(() {
          state = rollback;
          error = '$e';
        });
        _syncWallet(rollback);
      } else {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  void _goHome() {
    _exitTable();
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF020604),
        body: CasinoBackdrop(
          child: Center(
            child: error == null
                ? const CircularProgressIndicator(color: gold)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.orangeAccent, size: 44),
                      const SizedBox(height: 10),
                      Text(error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _poll, child: const Text('RECONNECT')),
                    ],
                  ),
          ),
        ),
      );
    }

    final players = (s['players'] as List).cast<Map<String, dynamic>>();
    final me = players.firstWhere((p) => p['id'] == widget.session.playerId);
    final cards = (s['myCards'] as List).cast<Map<String, dynamic>>();
    final seen = s['mySeen'] == true || s['status'] == 'showdown';
    final showdown = s['status'] == 'showdown';
    final winnerId = s['winnerId'] as String?;
    final currentPlayerId = s['currentPlayerId'] as String?;
    final isMyTurn = !showdown && currentPlayerId == widget.session.playerId && me['folded'] != true;
    final requestedPlayers = s['requestedPlayers'] as int? ?? 2;
    final palette = _paletteFor(requestedPlayers);
    final remainingMs = _remainingMs(s);
    final seconds = (remainingMs / 1000).ceil().clamp(0, 60).toInt();
    final turnDurationMs = s['turnDurationMs'] as int? ?? 60000;
    final fraction = (remainingMs / max(1, turnDurationMs)).clamp(0.0, 1.0).toDouble();
    final activeCount = players.where((p) => p['folded'] != true).length;
    final canSideShow = s['canSideShow'] == true;
    final blindAmount = s['blindAmount'] as int? ?? 10;
    final chaalAmount = s['chaalAmount'] as int? ?? blindAmount * 2;

    return Scaffold(
      backgroundColor: const Color(0xFF010403),
      body: CasinoBackdrop(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GameRoomBackdrop(accent: palette.accent),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 6,
                height: 44,
                child: GameTopHud(
                  requestedPlayers: requestedPlayers,
                  cap: s['cap'] as int? ?? 0,
                  chips: widget.session.walletChips,
                  soundEnabled: widget.session.soundEnabled,
                  reconnecting: reconnecting,
                  accent: palette.accent,
                  onHome: _goHome,
                ),
              ),
              Positioned(
                left: 5,
                right: 5,
                top: 47,
                bottom: 83,
                child: GameTableArena(
                  state: s,
                  session: widget.session,
                  palette: palette,
                  currentPlayerId: currentPlayerId,
                  winnerId: winnerId,
                  timerFraction: fraction,
                  timerSeconds: seconds,
                  myCards: cards,
                  mySeen: seen,
                  onTipDealer: _tipDealer,
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 7,
                height: 72,
                child: GameActionDock(
                  enabled: isMyTurn && !busy,
                  seen: seen,
                  activeCount: activeCount,
                  canSideShow: canSideShow,
                  busy: busy,
                  betAmount: seen ? chaalAmount : blindAmount,
                  onBet: () => _action(seen ? 'chaal' : 'blind'),
                  onSee: () => _action('see'),
                  onPack: () => _action('pack'),
                  onShow: () => _action('show'),
                  onSideShow: () => _action('sideshow'),
                ),
              ),
              if (isMyTurn && !showdown)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 78,
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: .92, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeInOut,
                        builder: (context, v, child) => Transform.scale(scale: v, child: child),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xE6102D20),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: palette.accent.withValues(alpha: .75)),
                            boxShadow: [BoxShadow(color: palette.accent.withValues(alpha: .25), blurRadius: 12)],
                          ),
                          child: const Text('YOUR TURN', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ),
                      ),
                    ),
                  ),
                ),
              if (showdown)
                Positioned.fill(
                  child: WinnerOverlay(
                    won: winnerId == widget.session.playerId,
                    message: '${s['message']}',
                    payout: s['lastPayout'] as int? ?? 0,
                    readyCount: s['nextRoundReadyCount'] as int? ?? 0,
                    playerCount: players.length,
                    alreadyReady: me['readyNext'] == true,
                    onAgain: busy || me['readyNext'] == true
                        ? null
                        : () {
                            recordedRound = null;
                            _action('new');
                          },
                    onSwitch: busy ? null : () => _switchTable(requestedPlayers),
                    onExit: busy ? null : _exitTable,
                  ),
                ),
              if (s['status'] == 'waiting')
                const Positioned.fill(child: WaitingForPlayerOverlay()),
              if (error != null)
                Positioned(
                  right: 12,
                  top: 55,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xF06B2919),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.orangeAccent),
                      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                    ),
                    child: Text(error!, style: const TextStyle(fontSize: 10, color: Colors.white)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameRoomBackdrop extends StatelessWidget {
  final Color accent;
  const GameRoomBackdrop({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -.15),
          radius: 1.1,
          colors: [Color(0xFF173227), Color(0xFF07110D), Color(0xFF010302)],
        ),
        boxShadow: [BoxShadow(color: accent.withValues(alpha: .06), blurRadius: 60, spreadRadius: 15)],
      ),
      child: CustomPaint(painter: _GameRoomPainter(accent)),
    );
  }
}

class _GameRoomPainter extends CustomPainter {
  final Color accent;
  const _GameRoomPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final floor = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, accent.withValues(alpha: .04)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, floor);

    final rail = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFFFD776).withValues(alpha: .05);
    for (double y = size.height * .15; y < size.height; y += 36) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), rail);
    }
  }

  @override
  bool shouldRepaint(covariant _GameRoomPainter oldDelegate) => oldDelegate.accent != accent;
}

class GameTopHud extends StatelessWidget {
  final int requestedPlayers;
  final int cap;
  final int chips;
  final bool soundEnabled;
  final bool reconnecting;
  final Color accent;
  final VoidCallback onHome;

  const GameTopHud({
    super.key,
    required this.requestedPlayers,
    required this.cap,
    required this.chips,
    required this.soundEnabled,
    required this.reconnecting,
    required this.accent,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HudIconButton(icon: Icons.home_rounded, onTap: onHome),
        const SizedBox(width: 8),
        Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xD909120D),
            border: Border.all(color: accent.withValues(alpha: .55)),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
          ),
          child: Row(
            children: [
              Icon(Icons.casino_rounded, color: accent, size: 18),
              const SizedBox(width: 6),
              Text(
                requestedPlayers == 2 ? '1 VS 1' : '$requestedPlayers PLAYER',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .5),
              ),
              const SizedBox(width: 7),
              Container(width: 1, height: 16, color: Colors.white12),
              const SizedBox(width: 7),
              Text('LIMIT ${_shortLimit(cap)}', style: const TextStyle(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: reconnecting ? const Color(0xD95B3A0B) : const Color(0xD90C2819),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: reconnecting ? Colors.amberAccent.withValues(alpha: .45) : Colors.greenAccent.withValues(alpha: .28)),
          ),
          child: Row(
            children: [
              Icon(reconnecting ? Icons.sync_rounded : Icons.wifi_rounded, size: 15, color: reconnecting ? Colors.amberAccent : Colors.greenAccent),
              const SizedBox(width: 5),
              Text(reconnecting ? 'SYNCING' : 'LIVE', style: const TextStyle(fontSize: 8.5, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .7)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xDF0B120E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF8F6B21)),
          ),
          child: Row(
            children: [
              const CasinoChip(color: Color(0xFFE5B62C), size: 22),
              const SizedBox(width: 6),
              Text('${_money(chips)} CHIPS', style: const TextStyle(fontSize: 10, color: Color(0xFFFFE2A0), fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(color: const Color(0xD90A120E), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white12)),
          child: Icon(soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 17, color: Colors.white60),
        ),
      ],
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HudIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Ink(
        width: 39,
        height: 39,
        decoration: BoxDecoration(
          color: const Color(0xDD0A120E),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: const Color(0xFF876820)),
        ),
        child: Icon(icon, color: gold, size: 19),
      ),
    );
  }
}

class GameTableArena extends StatelessWidget {
  final Map<String, dynamic> state;
  final AppSession session;
  final _TablePalette palette;
  final String? currentPlayerId;
  final String? winnerId;
  final double timerFraction;
  final int timerSeconds;
  final List<Map<String, dynamic>> myCards;
  final bool mySeen;
  final VoidCallback onTipDealer;

  const GameTableArena({
    super.key,
    required this.state,
    required this.session,
    required this.palette,
    required this.currentPlayerId,
    required this.winnerId,
    required this.timerFraction,
    required this.timerSeconds,
    required this.myCards,
    required this.mySeen,
    required this.onTipDealer,
  });

  @override
  Widget build(BuildContext context) {
    final players = (state['players'] as List).cast<Map<String, dynamic>>();
    final meIndex = players.indexWhere((p) => p['id'] == session.playerId);
    final revealed = <String, List<Map<String, dynamic>>>{};
    final revealedRaw = state['revealedHands'];
    if (revealedRaw is List) {
      for (final raw in revealedRaw) {
        if (raw is Map) {
          final hand = Map<String, dynamic>.from(raw);
          final id = '${hand['id'] ?? ''}';
          final cardsRaw = hand['cards'];
          if (id.isNotEmpty && cardsRaw is List) {
            revealed[id] = cardsRaw.map((c) => Map<String, dynamic>.from(c as Map)).toList();
          }
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dense = players.length >= 7 || h < 240;
        final seatW = dense ? 108.0 : 128.0;
        final seatH = dense ? 60.0 : 72.0;
        final tableW = min(w * .88, 900.0);
        final tableH = min(h * .72, 300.0);
        final center = Offset(w / 2, h * .50);
        final rx = tableW * .49;
        final ry = tableH * .52;
        final dealerW = dense ? 105.0 : 124.0;
        final dealerH = dense ? 75.0 : 90.0;
        final dealerTop = max(0.0, center.dy - tableH / 2 - dealerH * .43);
        final dealerCenter = Offset(center.dx, dealerTop + dealerH * .57);
        final seatCenters = <String, Offset>{};
        final children = <Widget>[
          Positioned(
            left: center.dx - tableW / 2,
            top: center.dy - tableH / 2,
            width: tableW,
            height: tableH,
            child: PremiumTeenPattiTable(accent: palette.accent),
          ),
          Positioned(
            left: center.dx - 105,
            top: center.dy - 58,
            width: 210,
            child: PotCenter(
              pot: state['pot'] as int? ?? 0,
              blindAmount: state['blindAmount'] as int? ?? 10,
              chaalAmount: state['chaalAmount'] as int? ?? 20,
              cap: state['cap'] as int? ?? 0,
            ),
          ),
          Positioned(
            left: center.dx - dealerW / 2,
            top: dealerTop,
            width: dealerW,
            height: dealerH,
            child: DealerHost(compact: dense),
          ),
          Positioned(
            left: center.dx + dealerW / 2 + 8,
            top: dealerTop + (dense ? 17 : 24),
            child: DealerTipButton(
              compact: dense,
              total: state['dealerTipTotal'] as int? ?? 0,
              onTap: onTipDealer,
            ),
          ),
        ];

        for (var i = 0; i < players.length; i++) {
          final p = players[i];
          final relative = (i - meIndex + players.length) % players.length;
          final angle = pi / 2 + (2 * pi * relative / players.length);
          var seatCenter = Offset(center.dx + cos(angle) * rx, center.dy + sin(angle) * ry);

          if (seatCenter.dy < center.dy - tableH * .27 && (seatCenter.dx - center.dx).abs() < seatW * .75) {
            seatCenter = Offset(center.dx + (relative.isEven ? tableW * .26 : -tableW * .26), seatCenter.dy + 3);
          }

          var left = seatCenter.dx - seatW / 2;
          var top = seatCenter.dy - seatH / 2;
          left = left.clamp(2.0, w - seatW - 2).toDouble();
          top = top.clamp(3.0, h - seatH - 3).toDouble();
          final finalCenter = Offset(left + seatW / 2, top + seatH / 2);
          final playerId = '${p['id']}';
          seatCenters[playerId] = finalCenter;

          children.add(
            Positioned(
              left: left,
              top: top,
              width: seatW,
              height: seatH,
              child: PlayerSeat(
                player: p,
                isMe: playerId == session.playerId,
                isTurn: playerId == currentPlayerId,
                isWinner: playerId == winnerId,
                timerFraction: playerId == currentPlayerId ? timerFraction : 0,
                timerSeconds: playerId == currentPlayerId ? timerSeconds : 0,
                accent: palette.accent,
                compact: dense,
              ),
            ),
          );

          if (p['folded'] != true) {
            final vector = center - finalCenter;
            final handW = dense ? 72.0 : 90.0;
            final handH = dense ? 38.0 : 48.0;
            Offset cardCenter;
            if (vector.dx.abs() > vector.dy.abs()) {
              cardCenter = finalCenter + Offset(vector.dx.sign * (seatW / 2 + handW / 2 - 8), 0);
            } else {
              cardCenter = finalCenter + Offset(0, vector.dy.sign * (seatH / 2 + handH / 2 - 6));
            }
            final cardLeft = (cardCenter.dx - handW / 2).clamp(2.0, w - handW - 2).toDouble();
            final cardTop = (cardCenter.dy - handH / 2).clamp(2.0, h - handH - 2).toDouble();
            final isMe = playerId == session.playerId;
            final handCards = isMe
                ? myCards
                : (revealed[playerId] ?? const <Map<String, dynamic>>[{}, {}, {}]);
            final faceUp = isMe ? mySeen : revealed.containsKey(playerId);

            children.add(
              Positioned(
                left: cardLeft,
                top: cardTop,
                width: handW,
                height: handH,
                child: SeatSideHand(
                  key: ValueKey('seat-hand-$playerId-${state['round']}-${faceUp ? 1 : 0}'),
                  cards: handCards,
                  faceUp: faceUp,
                  compact: dense,
                  isMe: isMe,
                ),
              ),
            );
          }
        }

        children.add(
          Positioned.fill(
            child: IgnorePointer(
              child: DealerDealLayer(
                key: ValueKey('deal-all-${state['round']}'),
                from: dealerCenter,
                destinations: seatCenters.values.toList(),
              ),
            ),
          ),
        );

        final lastAction = '${state['lastAction'] ?? ''}';
        final actorId = '${state['lastActorId'] ?? ''}';
        final lastBetAmount = state['lastBetAmount'] as int? ?? 0;
        final actorCenter = seatCenters[actorId];
        if ((lastAction == 'blind' || lastAction == 'chaal') && actorCenter != null && lastBetAmount > 0) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: ChipFlightLayer(
                  key: ValueKey('chips-${state['actionSeq']}'),
                  from: actorCenter,
                  to: center + const Offset(0, 5),
                  amount: lastBetAmount,
                ),
              ),
            ),
          );
        }

        final lastTipAmount = state['lastTipAmount'] as int? ?? 0;
        if (lastAction == 'tip' && actorCenter != null && lastTipAmount > 0) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: ChipFlightLayer(
                  key: ValueKey('tip-${state['actionSeq']}'),
                  from: actorCenter,
                  to: dealerCenter,
                  amount: lastTipAmount,
                ),
              ),
            ),
          );
          children.add(
            Positioned(
              left: center.dx - 44,
              top: max(0, dealerTop - 6),
              width: 88,
              child: DealerThanksBubble(amount: lastTipAmount),
            ),
          );
        }

        children.add(
          Positioned(
            left: center.dx - min(220.0, w * .30),
            top: center.dy + tableH * .10,
            width: min(440.0, w * .60),
            child: TableMessageBanner(
              message: '${state['message']}',
              actionSeq: state['actionSeq'] as int? ?? 0,
              accent: palette.accent,
            ),
          ),
        );

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

class SeatSideHand extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final bool faceUp;
  final bool compact;
  final bool isMe;

  const SeatSideHand({
    super.key,
    required this.cards,
    required this.faceUp,
    required this.compact,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = cards.length >= 3 ? cards.take(3).toList() : <Map<String, dynamic>>[...cards, ...List.generate(3 - cards.length, (_) => <String, dynamic>{})];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .82, end: 1),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Opacity(opacity: value.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: value, child: child)),
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(3, (index) {
          final card = normalized[index];
          final width = compact ? 27.0 : 34.0;
          final height = compact ? 37.0 : 46.0;
          final overlap = compact ? 19.0 : 25.0;
          return Positioned(
            left: index * overlap,
            top: (index - 1).abs() * (compact ? 2.0 : 3.0),
            child: Transform.rotate(
              angle: (index - 1) * .06,
              child: MiniPlayingCard(card: card, faceUp: faceUp, width: width, height: height, highlighted: isMe),
            ),
          );
        }),
      ),
    );
  }
}

class MiniPlayingCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final bool faceUp;
  final double width;
  final double height;
  final bool highlighted;

  const MiniPlayingCard({
    super.key,
    required this.card,
    required this.faceUp,
    required this.width,
    required this.height,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final rank = card['rank'] as int? ?? 2;
    final suit = card['suit'] as int? ?? 0;
    final rankLabel = rank <= 10 ? '$rank' : const {11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[rank]!;
    final suitLabel = const ['♠', '♥', '♦', '♣'][suit.clamp(0, 3).toInt()];
    final red = suit == 1 || suit == 2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faceUp ? const Color(0xFFFFF8E5) : const Color(0xFF641421),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: highlighted ? gold : (faceUp ? const Color(0xFFD7B45A) : const Color(0xFFE7B1B7)), width: highlighted ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2))],
      ),
      child: faceUp
          ? Text('$rankLabel$suitLabel', style: TextStyle(fontSize: width * .35, color: red ? const Color(0xFFB51F2A) : Colors.black, fontWeight: FontWeight.w900))
          : Stack(
              alignment: Alignment.center,
              children: [
                Container(margin: const EdgeInsets.all(4), decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), border: Border.all(color: gold.withValues(alpha: .65)))),
                Icon(Icons.style_rounded, size: width * .42, color: gold),
              ],
            ),
    );
  }
}

class DealerTipButton extends StatelessWidget {
  final bool compact;
  final int total;
  final VoidCallback onTap;

  const DealerTipButton({super.key, required this.compact, required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 5 : 6),
        decoration: BoxDecoration(
          color: const Color(0xE6131A14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: gold.withValues(alpha: .8)),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CasinoChip(color: Color(0xFFE4B530), size: 16),
            const SizedBox(width: 4),
            Text(compact ? 'TIP' : 'TIP DEALER', style: const TextStyle(fontSize: 8, color: gold, fontWeight: FontWeight.w900, letterSpacing: .6)),
            if (!compact && total > 0) ...[
              const SizedBox(width: 5),
              Text('$total', style: const TextStyle(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
  }
}

class DealerThanksBubble extends StatelessWidget {
  final int amount;
  const DealerThanksBubble({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .7, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (context, value, child) => Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xF20A120E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: Text('Thank you! +$amount', textAlign: TextAlign.center, style: const TextStyle(fontSize: 7.5, color: gold, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class PremiumTeenPattiTable extends StatelessWidget {
  final Color accent;
  const PremiumTeenPattiTable({super.key, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2D12), Color(0xFF171009), Color(0xFF070503)],
          stops: [0, .55, 1],
        ),
        border: Border.all(color: const Color(0xFFB7882C), width: 3.5),
        boxShadow: [
          const BoxShadow(color: Color(0xD9000000), blurRadius: 30, offset: Offset(0, 15)),
          BoxShadow(color: accent.withValues(alpha: .10), blurRadius: 28, spreadRadius: 2),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const RadialGradient(
            center: Alignment(0, -.15),
            radius: 1.05,
            colors: [Color(0xFF18805A), Color(0xFF0A5A3B), Color(0xFF03311F)],
          ),
          border: Border.all(color: const Color(0xFFFFD875).withValues(alpha: .72), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 12)],
        ),
        child: CustomPaint(painter: _PremiumFeltPainter(accent)),
      ),
    );
  }
}

class _PremiumFeltPainter extends CustomPainter {
  final Color accent;
  const _PremiumFeltPainter(this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final fiber = Paint()
      ..color = Colors.white.withValues(alpha: .018)
      ..strokeWidth = .55;
    for (double x = -size.height; x < size.width; x += 16) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), fiber);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFFD875).withValues(alpha: .28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(18, 18, size.width - 36, size.height - 36), Radius.circular(size.height / 2)),
      ring,
    );

    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [accent.withValues(alpha: .08), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width * .25));
    canvas.drawRect(Offset.zero & size, centerGlow);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: '3 PATTI',
        style: TextStyle(fontSize: 31, color: Color(0x15FFF0B8), fontWeight: FontWeight.w900, letterSpacing: 5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2 - 1));
  }

  @override
  bool shouldRepaint(covariant _PremiumFeltPainter oldDelegate) => oldDelegate.accent != accent;
}

class DealerHost extends StatelessWidget {
  final bool compact;
  const DealerHost({super.key, required this.compact});

  @override
  Widget build(BuildContext context) {
    final face = compact ? 42.0 : 50.0;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: compact ? 28 : 34,
          child: Container(
            width: compact ? 82 : 96,
            height: compact ? 48 : 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFB21F42), Color(0xFF681227)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(46), bottom: Radius.circular(12)),
              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)],
            ),
          ),
        ),
        Positioned(
          top: 0,
          child: Container(
            width: face,
            height: face,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF2D1514), Color(0xFF080505)]),
              border: Border.all(color: const Color(0xFFFFD875), width: 2),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 10)],
            ),
            child: Center(
              child: Container(
                width: face * .70,
                height: face * .70,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD1B5)),
                child: Icon(Icons.face_3_rounded, color: const Color(0xFF6B2D2F), size: compact ? 25 : 30),
              ),
            ),
          ),
        ),
        Positioned(
          left: compact ? 7 : 9,
          bottom: compact ? 9 : 11,
          child: Transform.rotate(
            angle: -.35,
            child: const _DealerHandWithDeck(),
          ),
        ),
        Positioned(
          right: compact ? 8 : 10,
          bottom: compact ? 13 : 15,
          child: Transform.rotate(
            angle: .28,
            child: Container(
              width: compact ? 29 : 34,
              height: 8,
              decoration: BoxDecoration(color: const Color(0xFFFFC5A4), borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ),
        Positioned(
          bottom: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xF2150B08),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFA87D26)),
            ),
            child: const Text('DEALER', style: TextStyle(fontSize: 7, color: gold, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }
}

class _DealerHandWithDeck extends StatelessWidget {
  const _DealerHandWithDeck();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 27, height: 8, decoration: BoxDecoration(color: const Color(0xFFFFC5A4), borderRadius: BorderRadius.circular(99))),
        Transform.rotate(
          angle: .18,
          child: Container(
            width: 20,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB3213E), Color(0xFF5E0D1D)]),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFFD875)),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
            ),
            child: const Icon(Icons.diamond_outlined, size: 10, color: Color(0xFFFFD875)),
          ),
        ),
      ],
    );
  }
}

class DealerDealLayer extends StatelessWidget {
  final Offset from;
  final List<Offset> destinations;

  const DealerDealLayer({super.key, required this.from, required this.destinations});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 1350 + destinations.length * 80),
      curve: Curves.linear,
      builder: (context, progress, _) => CustomPaint(
        painter: _DealerDealPainter(from: from, destinations: destinations, progress: progress),
      ),
    );
  }
}

class _DealerDealPainter extends CustomPainter {
  final Offset from;
  final List<Offset> destinations;
  final double progress;

  const _DealerDealPainter({required this.from, required this.destinations, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (destinations.isEmpty) return;
    final total = destinations.length * 3;
    for (var cardIndex = 0; cardIndex < 3; cardIndex++) {
      for (var i = 0; i < destinations.length; i++) {
        final order = cardIndex * destinations.length + i;
        final delay = order / max(1, total) * .73;
        final local = ((progress - delay) / .25).clamp(0.0, 1.0);
        if (local <= 0 || local >= 1) continue;
        final eased = Curves.easeOutCubic.transform(local);
        final target = destinations[i];
        final mid = Offset((from.dx + target.dx) / 2, min(from.dy, target.dy) - 22 - cardIndex * 4);
        final a = Offset.lerp(from, mid, eased)!;
        final b = Offset.lerp(mid, target, eased)!;
        final point = Offset.lerp(a, b, eased)!;
        final alpha = (1 - (local - .82).clamp(0.0, .18) / .18).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(point.dx, point.dy);
        canvas.rotate((target.dx - from.dx) * .0017 + (cardIndex - 1) * .07 + local * .1);
        final rect = RRect.fromRectAndRadius(const Rect.fromLTWH(-8, -11, 16, 22), const Radius.circular(3));
        canvas.drawRRect(rect, Paint()..color = const Color(0xFFA11634).withValues(alpha: alpha));
        canvas.drawRRect(rect, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = const Color(0xFFFFDB80).withValues(alpha: alpha));
        canvas.drawCircle(Offset.zero, 2.4, Paint()..color = Colors.white.withValues(alpha: .48 * alpha));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DealerDealPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.destinations != destinations || oldDelegate.from != from;
}

class PotCenter extends StatelessWidget {
  final int pot;
  final int blindAmount;
  final int chaalAmount;
  final int cap;

  const PotCenter({super.key, required this.pot, required this.blindAmount, required this.chaalAmount, required this.cap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 47,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(left: 27, top: 17, child: CasinoChipStack(color: Color(0xFFE6453B), count: 3)),
              Positioned(left: 57, top: 8, child: CasinoChipStack(color: Color(0xFF2D80DF), count: 5)),
              Positioned(left: 88, top: 14, child: CasinoChipStack(color: Color(0xFF39A94B), count: 4)),
              Positioned(left: 119, top: 5, child: CasinoChipStack(color: Color(0xFFE7B62C), count: 5)),
              Positioned(left: 150, top: 15, child: CasinoChipStack(color: Color(0xFF8A4FD0), count: 3)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xC9081A12),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFFFFD875).withValues(alpha: .48)),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 7)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('POT', style: TextStyle(fontSize: 8, color: Colors.white60, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(width: 7),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$pot', key: ValueKey(pot), style: const TextStyle(fontSize: 19, color: gold, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 5),
              const Text('CHIPS', style: TextStyle(fontSize: 8, color: Colors.white60, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text('BLIND $blindAmount  •  SEEN $chaalAmount  •  LIMIT ${_shortLimit(cap)}', style: const TextStyle(fontSize: 7.6, color: Colors.white54, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class CasinoChipStack extends StatelessWidget {
  final Color color;
  final int count;
  const CasinoChipStack({super.key, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 31,
      height: 38,
      child: Stack(
        children: List.generate(count, (i) => Positioned(bottom: i * 3.0, child: CasinoChip(color: color, size: 29))),
      ),
    );
  }
}

class CasinoChip extends StatelessWidget {
  final Color color;
  final double size;
  const CasinoChip({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: size, height: size, child: CustomPaint(painter: _CasinoChipPainter(color)));
  }
}

class _CasinoChipPainter extends CustomPainter {
  final Color color;
  const _CasinoChipPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    canvas.drawCircle(c, r, Paint()..color = Colors.black.withValues(alpha: .45));
    canvas.drawCircle(c, r - 1, Paint()..color = color);
    canvas.drawCircle(c, r * .68, Paint()..color = const Color(0xFF151515));
    canvas.drawCircle(c, r * .49, Paint()..color = color.withValues(alpha: .92));
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.4, size.width * .07)
      ..color = Colors.white.withValues(alpha: .88);
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r * .84), a, .22, false, edge);
    }
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0xFFFFE4A0).withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(covariant _CasinoChipPainter oldDelegate) => oldDelegate.color != color;
}

class ChipFlightLayer extends StatelessWidget {
  final Offset from;
  final Offset to;
  final int amount;

  const ChipFlightLayer({super.key, required this.from, required this.to, required this.amount});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeInOutCubic,
      builder: (context, value, _) {
        final mid = Offset((from.dx + to.dx) / 2, min(from.dy, to.dy) - 55);
        final a = Offset.lerp(from, mid, value)!;
        final b = Offset.lerp(mid, to, value)!;
        final point = Offset.lerp(a, b, value)!;
        return Stack(
          children: [
            Positioned(
              left: point.dx - 18,
              top: point.dy - 18,
              child: Transform.rotate(
                angle: value * pi * 2.8,
                child: const Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CasinoChip(color: Color(0xFFE84B3C), size: 30),
                    Positioned(left: 9, top: 5, child: CasinoChip(color: Color(0xFF2C83DF), size: 27)),
                    Positioned(left: 17, top: 10, child: CasinoChip(color: Color(0xFFE4B530), size: 23)),
                  ],
                ),
              ),
            ),
            if (value > .42 && value < .92)
              Positioned(
                left: point.dx + 20,
                top: point.dy - 10,
                child: Opacity(
                  opacity: (1 - ((value - .42) / .5)).clamp(0.0, 1.0),
                  child: Text('$amount', style: const TextStyle(fontSize: 11, color: gold, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 5)])),
                ),
              ),
          ],
        );
      },
    );
  }
}

class PlayerSeat extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool isMe;
  final bool isTurn;
  final bool isWinner;
  final double timerFraction;
  final int timerSeconds;
  final Color accent;
  final bool compact;

  const PlayerSeat({
    super.key,
    required this.player,
    required this.isMe,
    required this.isTurn,
    required this.isWinner,
    required this.timerFraction,
    required this.timerSeconds,
    required this.accent,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final folded = player['folded'] == true;
    final seen = player['seen'] == true;
    final vip = player['vip'] == true;
    final name = '${player['name'] ?? 'Player'}';
    final avatar = (player['avatar'] as int? ?? 1).clamp(1, 8).toInt();
    final avatarSize = compact ? 35.0 : 41.0;
    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isTurn ? 1.055 : 1,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: EdgeInsets.fromLTRB(compact ? 5 : 6, compact ? 5 : 6, compact ? 6 : 8, compact ? 5 : 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: isTurn
                    ? [const Color(0xF21C3B2A), const Color(0xF208100C)]
                    : [const Color(0xEA0D1711), const Color(0xEA040806)],
              ),
              border: Border.all(
                color: isWinner ? gold : (isTurn ? accent : const Color(0xFF705A27)),
                width: isTurn || isWinner ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(color: (isTurn ? accent : Colors.black).withValues(alpha: isTurn ? .38 : .42), blurRadius: isTurn ? 17 : 8),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFFFD969), Color(0xFF6E4A0A)]),
                    border: Border.all(color: isMe ? gold : Colors.white24, width: isMe ? 2 : 1),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
                  ),
                  child: ClipOval(child: Image.asset(_avatarAsset(avatar), fit: BoxFit.cover)),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isMe ? '$name • YOU' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: compact ? 8.4 : 9.4, color: Colors.white, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (vip)
                            Container(
                              margin: const EdgeInsets.only(left: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFF5B3A04), borderRadius: BorderRadius.circular(99), border: Border.all(color: gold.withValues(alpha: .7))),
                              child: const Text('VIP', style: TextStyle(fontSize: 6.5, color: Color(0xFFFFE39A), fontWeight: FontWeight.w900)),
                            ),
                          if (isWinner) const Icon(Icons.emoji_events_rounded, color: gold, size: 12),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const CasinoChip(color: Color(0xFFE4B530), size: 12),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${_money(player['chips'] as int? ?? 0)} CHIPS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: compact ? 7.2 : 8.2, color: const Color(0xFFFFDEA0), fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _PlayerStatusPill(folded: folded, seen: seen, compact: compact),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isTurn)
            Positioned(
              right: compact ? -22 : -25,
              top: compact ? 5 : 6,
              child: TurnTimerBadge(
                seconds: timerSeconds,
                fraction: timerFraction,
                accent: accent,
                size: compact ? 42 : 48,
              ),
            ),
          if (isTurn)
            Positioned(
              left: 8,
              bottom: compact ? -8 : -9,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: accent.withValues(alpha: .32), blurRadius: 8)],
                ),
                child: const Text('TURN', style: TextStyle(fontSize: 6.5, color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: .8)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerStatusPill extends StatelessWidget {
  final bool folded;
  final bool seen;
  final bool compact;
  const _PlayerStatusPill({required this.folded, required this.seen, required this.compact});

  @override
  Widget build(BuildContext context) {
    final label = folded ? 'PACKED' : (seen ? 'SEEN' : 'BLIND');
    final color = folded ? Colors.redAccent : (seen ? Colors.lightBlueAccent : Colors.lightGreenAccent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: .20))),
      child: Text(label, style: TextStyle(fontSize: compact ? 6.5 : 7.2, color: color, fontWeight: FontWeight.w900, letterSpacing: .45)),
    );
  }
}

class TurnTimerBadge extends StatelessWidget {
  final int seconds;
  final double fraction;
  final Color accent;
  final double size;

  const TurnTimerBadge({super.key, required this.seconds, required this.fraction, required this.accent, required this.size});

  @override
  Widget build(BuildContext context) {
    final danger = seconds <= 10;
    final color = danger ? Colors.redAccent : (seconds <= 25 ? Colors.amberAccent : accent);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xEF040806), boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8)]),
      child: CustomPaint(
        painter: _TurnTimerPainter(fraction: fraction, color: color),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$seconds', style: TextStyle(fontSize: size * .32, height: 1, color: Colors.white, fontWeight: FontWeight.w900)),
              Text('SEC', style: TextStyle(fontSize: size * .12, height: 1.1, color: color, fontWeight: FontWeight.w900, letterSpacing: .5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurnTimerPainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _TurnTimerPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 3;
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = Colors.white12);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -pi / 2,
      2 * pi * fraction,
      false,
      Paint()..style = PaintingStyle.stroke..strokeWidth = 4.2..strokeCap = StrokeCap.round..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _TurnTimerPainter oldDelegate) => oldDelegate.fraction != fraction || oldDelegate.color != color;
}

class SeatCardFan extends StatelessWidget {
  const SeatCardFan({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(left: 7, top: 7, child: Transform.rotate(angle: -.20, child: const _MiniBack())),
        const Positioned(left: 17, top: 3, child: _MiniBack()),
        Positioned(left: 27, top: 7, child: Transform.rotate(angle: .20, child: const _MiniBack())),
      ],
    );
  }
}

class _MiniBack extends StatelessWidget {
  const _MiniBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 29,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFB51B3A), Color(0xFF651022)]),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFEBC96F), width: .8),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
      ),
      child: const Center(child: Icon(Icons.diamond_outlined, size: 8, color: Color(0xFFFFDA82))),
    );
  }
}

class AnimatedDealHand extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final bool faceUp;
  final int round;
  final bool compact;

  const AnimatedDealHand({super.key, required this.cards, required this.faceUp, required this.round, required this.compact});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('my-hand-$round-$faceUp'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: faceUp ? 520 : 900),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final flip = faceUp ? (1 - value) * pi * .42 : 0.0;
        return Transform.translate(
          offset: Offset(0, -52 * (1 - value)),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, .001)..rotateY(flip),
            child: Transform.scale(scale: .68 + .32 * value, child: Opacity(opacity: value.clamp(0.0, 1.0).toDouble(), child: child)),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: List.generate(min(3, cards.length), (i) {
          final dx = (i - 1) * (compact ? 42.0 : 57.0);
          final angle = (i - 1) * .10;
          return Transform.translate(
            offset: Offset(dx, i == 1 ? -4 : 0),
            child: Transform.rotate(
              angle: angle,
              child: PlayingCardView(card: cards[i], faceUp: faceUp, compact: compact),
            ),
          );
        }),
      ),
    );
  }
}

class TableMessageBanner extends StatelessWidget {
  final String message;
  final int actionSeq;
  final Color accent;
  const TableMessageBanner({super.key, required this.message, required this.actionSeq, required this.accent});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey('$actionSeq-$message'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0x98030A07),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: accent.withValues(alpha: .20)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9.3, color: Color(0xFFFFE9B2), fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
        ),
      ),
    );
  }
}

class GameActionDock extends StatelessWidget {
  final bool enabled;
  final bool seen;
  final int activeCount;
  final bool canSideShow;
  final bool busy;
  final int betAmount;
  final VoidCallback onBet;
  final VoidCallback onSee;
  final VoidCallback onPack;
  final VoidCallback onShow;
  final VoidCallback onSideShow;

  const GameActionDock({
    super.key,
    required this.enabled,
    required this.seen,
    required this.activeCount,
    required this.canSideShow,
    required this.busy,
    required this.betAmount,
    required this.onBet,
    required this.onSee,
    required this.onPack,
    required this.onShow,
    required this.onSideShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: const LinearGradient(colors: [Color(0xF50E1812), Color(0xF5040806)]),
        border: Border.all(color: const Color(0xFFA77A25), width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18, offset: Offset(0, 7))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 10,
            child: _GameActionButton(
              label: seen ? 'SEEN' : 'SEE CARDS',
              subtitle: seen ? 'YOUR STATUS IS SEEN' : 'OPEN YOUR HAND',
              icon: seen ? Icons.visibility_rounded : Icons.style_rounded,
              color: const Color(0xFF1E6EA6),
              enabled: enabled && !seen,
              onTap: onSee,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 9,
            child: _GameActionButton(
              label: 'PACK',
              subtitle: 'LEAVE THIS HAND',
              icon: Icons.close_rounded,
              color: const Color(0xFF8E2E2C),
              enabled: enabled,
              onTap: onPack,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 15,
            child: _PrimaryBetButton(
              seen: seen,
              amount: betAmount,
              enabled: enabled,
              busy: busy,
              onTap: onBet,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 9,
            child: _GameActionButton(
              label: 'SHOW',
              subtitle: 'COMPARE HANDS',
              icon: Icons.emoji_events_rounded,
              color: const Color(0xFFA8750D),
              enabled: enabled && activeCount >= 2,
              onTap: onShow,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 10,
            child: _GameActionButton(
              label: 'SIDE SHOW',
              subtitle: 'SEEN VS SEEN',
              icon: Icons.compare_arrows_rounded,
              color: const Color(0xFF66358C),
              enabled: enabled && seen && activeCount >= 3 && canSideShow,
              onTap: onSideShow,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryBetButton extends StatelessWidget {
  final bool seen;
  final int amount;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _PrimaryBetButton({required this.seen, required this.amount, required this.enabled, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = seen ? const Color(0xFFB47A0F) : const Color(0xFF16863B);
    return AnimatedScale(
      scale: enabled ? 1 : .98,
      duration: const Duration(milliseconds: 180),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 1), color.withValues(alpha: .62)]),
            border: Border.all(color: enabled ? const Color(0xFFFFE59D) : Colors.white24, width: enabled ? 1.5 : 1),
            boxShadow: enabled ? [BoxShadow(color: color.withValues(alpha: .32), blurRadius: 12, spreadRadius: 1)] : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: const [
                    CasinoChip(color: Color(0xFFE84B3C), size: 26),
                    Positioned(left: 8, top: 3, child: CasinoChip(color: Color(0xFFE4B530), size: 22)),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        busy ? 'WAIT...' : (seen ? 'CHAAL' : 'BLIND'),
                        maxLines: 1,
                        style: const TextStyle(fontSize: 13, height: 1, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .8),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$amount CHIPS  •  ${seen ? '2X AUTO' : '1X'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 7.5, height: 1, color: const Color(0xCCFFFFFF), fontWeight: FontWeight.w900, letterSpacing: .35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _GameActionButton({required this.label, required this.subtitle, required this.icon, required this.color, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: enabled ? 1 : .30,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: LinearGradient(colors: [color.withValues(alpha: .96), color.withValues(alpha: .55)]),
            border: Border.all(color: Colors.white24),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.8, height: 1, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .35)),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 6.4, height: 1, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: .2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WinnerOverlay extends StatelessWidget {
  final bool won;
  final String message;
  final int payout;
  final int readyCount;
  final int playerCount;
  final bool alreadyReady;
  final VoidCallback? onAgain;
  final VoidCallback? onSwitch;
  final VoidCallback? onExit;

  const WinnerOverlay({
    super.key,
    required this.won,
    required this.message,
    required this.payout,
    required this.readyCount,
    required this.playerCount,
    required this.alreadyReady,
    required this.onAgain,
    required this.onSwitch,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xA8000000),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .6, end: 1),
          duration: const Duration(milliseconds: 480),
          curve: Curves.elasticOut,
          builder: (context, value, child) => Transform.scale(scale: value, child: child),
          child: Container(
            width: min(MediaQuery.sizeOf(context).width * .62, 620.0),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(colors: won ? const [Color(0xFF725006), Color(0xFF211603)] : const [Color(0xFF19211D), Color(0xFF070B09)]),
              border: Border.all(color: won ? gold : Colors.white24, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 30)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(won ? Icons.emoji_events_rounded : Icons.casino_rounded, size: 48, color: won ? gold : Colors.white60),
                const SizedBox(height: 6),
                Text(won ? 'YOU WIN!' : 'ROUND COMPLETE', style: TextStyle(fontSize: 26, color: won ? gold : Colors.white, fontWeight: FontWeight.w900)),
                if (won) Text('+$payout CHIPS', style: const TextStyle(fontSize: 15, color: Color(0xFF9CF585), fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                const SizedBox(height: 8),
                Text(
                  alreadyReady ? 'Waiting for other players • $readyCount/$playerCount ready' : '$readyCount/$playerCount ready for another round',
                  style: const TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAgain,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16863B),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: Icon(alreadyReady ? Icons.hourglass_top_rounded : Icons.refresh_rounded),
                        label: Text(alreadyReady ? 'WAITING' : 'NEW ROUND', style: const TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSwitch,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8CC8FF),
                          side: const BorderSide(color: Color(0xFF4D8FC9)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('SWITCH TABLE', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Color(0xFF9A4141)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('EXIT', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WaitingForPlayerOverlay extends StatelessWidget {
  const WaitingForPlayerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xE809120D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: gold.withValues(alpha: .75)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 18)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: gold)),
              SizedBox(width: 10),
              Text('SEAT OPEN • WAITING FOR NEXT PLAYER', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: .8)),
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
  final bool compact;

  const PlayingCardView({super.key, required this.card, required this.faceUp, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final rank = card['rank'] as int? ?? 2;
    final suit = card['suit'] as int? ?? 0;
    final rankLabel = rank <= 10 ? '$rank' : const {11: 'J', 12: 'Q', 13: 'K', 14: 'A'}[rank]!;
    final suitLabel = const ['♠', '♥', '♦', '♣'][suit];
    final red = suit == 1 || suit == 2;
    final width = compact ? 48.0 : 72.0;
    final height = compact ? 68.0 : 102.0;
    return Container(
      width: width,
      height: height,
      margin: EdgeInsets.symmetric(horizontal: compact ? 3 : 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: faceUp ? const Color(0xFFFFF9E9) : const Color(0xFF731422),
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
        border: Border.all(color: faceUp ? gold : const Color(0xFFE8B9B9), width: 1.4),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: faceUp
          ? Text('$rankLabel$suitLabel', style: TextStyle(color: red ? Colors.red.shade700 : Colors.black, fontWeight: FontWeight.w900, fontSize: compact ? 15 : 22))
          : const Icon(Icons.style_rounded, size: 26, color: gold),
    );
  }
}

String _shortLimit(int value) {
  if (value >= 1000) return '${(value / 1000).round()}K';
  return '$value';
}

class Api {
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 6)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 8;

  static AppSession? _session;
  static String? _token;
  static Future<void>? _bootstrapFuture;

  static void configureSession(AppSession session) {
    _session = session;
  }

  static Future<void> ensureSession() async {
    if (_token != null || _session == null) return;
    _bootstrapFuture ??= _bootstrap();
    try {
      await _bootstrapFuture;
    } finally {
      _bootstrapFuture = null;
    }
  }

  static Future<void> _bootstrap() async {
    final session = _session;
    if (session == null) return;
    final data = await _rawPost('/auth/bootstrap', {
      'playerId': session.playerId,
      'name': session.displayName,
      'avatar': session.avatarIndex,
    }, includeAuth: false);
    final token = data['token'];
    if (token is String && token.isNotEmpty) _token = token;
    final wallet = data['wallet'];
    if (wallet is Map) {
      final chips = wallet['chips'];
      if (chips is int) session.updateWallet(chips);
    }
  }

  static Future<Map<String, dynamic>> get(String path) async {
    await ensureSession();
    try {
      return await _rawGet(path);
    } on _ApiUnauthorized {
      _token = null;
      await ensureSession();
      return _rawGet(path);
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> payload) async {
    if (path != '/auth/bootstrap') await ensureSession();
    try {
      return await _rawPost(path, payload, includeAuth: path != '/auth/bootstrap');
    } on _ApiUnauthorized {
      if (path == '/auth/bootstrap') rethrow;
      _token = null;
      await ensureSession();
      return _rawPost(path, payload);
    }
  }

  static Future<Map<String, dynamic>> _rawGet(String path) async {
    final req = await _client.getUrl(Uri.parse('$apiBaseUrl$path'));
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (_token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode == 401) throw const _ApiUnauthorized();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
    }
    return data;
  }

  static Future<Map<String, dynamic>> _rawPost(String path, Map<String, dynamic> payload, {bool includeAuth = true}) async {
    final req = await _client.postUrl(Uri.parse('$apiBaseUrl$path'));
    req.headers.contentType = ContentType.json;
    req.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (includeAuth && _token != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    req.write(jsonEncode(payload));
    final res = await req.close();
    final body = await utf8.decoder.bind(res).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode == 401) throw const _ApiUnauthorized();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(data['error'] ?? 'HTTP ${res.statusCode}');
    }
    return data;
  }
}

class _ApiUnauthorized implements Exception {
  const _ApiUnauthorized();
}


BoxDecoration _panelDecoration() => BoxDecoration(
  color: const Color(0xFF0A1712),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFF66501E)),
);

String _avatarAsset(int value) => 'assets/avatars/avatar_${value.clamp(1, 8).toInt()}.png';

String _money(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

String _two(int n) => n.toString().padLeft(2, '0');
