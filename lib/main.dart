import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  runApp(const ThreePattiApp());
}

class ThreePattiApp extends StatefulWidget {
  const ThreePattiApp({super.key});

  @override
  State<ThreePattiApp> createState() => _ThreePattiAppState();
}

class _ThreePattiAppState extends State<ThreePattiApp> {
  final session = AppSession();

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
  String displayName = 'Player';
  int walletChips = 10000;
  int navPage = 0; // 0 home, 1 store, 2 history, 3 profile, 4 wallet, 5 withdraw, 6 settings, 7 support, 8 rules
  final String playerId =
      'p-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
  final List<GameHistoryItem> history = [];

  void setPage(int value) {
    if (navPage == value) return;
    navPage = value;
    notifyListeners();
  }

  void updateName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    displayName = cleaned.length > 24 ? cleaned.substring(0, 24) : cleaned;
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
    navPage = 0;
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

  void goHome() => widget.session.setPage(0);

  Widget _pageFor(int page) => switch (page) {
        1 => StoreView(session: widget.session),
        2 => HistoryView(session: widget.session),
        3 => ProfileView(session: widget.session),
        4 => WalletView(session: widget.session),
        5 => WithdrawView(session: widget.session),
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
                              '₹${_money(session.walletChips)}',
                              key: ValueKey(session.walletChips),
                              style: TextStyle(fontSize: compact ? 14 : 16, height: 1, fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (!compact)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text('1 CHIP = ₹1', style: TextStyle(fontSize: 7.5, color: Colors.white54, fontWeight: FontWeight.w800, letterSpacing: .6)),
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



class LobbyView extends StatelessWidget {
  final AppSession session;

  const LobbyView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 340;
        final pad = compact ? 7.0 : 11.0;
        final heroHeight = compact ? 68.0 : 84.0;
        final roomWidth = compact ? 170.0 : 205.0;

        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              SizedBox(height: heroHeight, child: const PremiumHeroBanner()),
              SizedBox(height: compact ? 7 : 10),
              Row(
                children: [
                  const Icon(Icons.swipe_rounded, color: gold, size: 20),
                  const SizedBox(width: 7),
                  const Text(
                    'SWIPE TO CHOOSE A TABLE',
                    style: TextStyle(color: Color(0xFFFFE4A0), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: .8),
                  ),
                  const Spacer(),
                  _TierLegend(color: Color(0xFF76F06A), text: '5K'),
                  const SizedBox(width: 8),
                  _TierLegend(color: Color(0xFF62B9FF), text: '20K'),
                  const SizedBox(width: 8),
                  _TierLegend(color: Color(0xFFFFD45A), text: '50K'),
                ],
              ),
              SizedBox(height: compact ? 6 : 9),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 4 : 8),
                        itemCount: 9,
                        separatorBuilder: (_, __) => SizedBox(width: compact ? 14 : 20),
                        itemBuilder: (context, index) {
                          final players = index + 2;
                          return SizedBox(
                            width: roomWidth,
                            child: RoundRoomCard(
                              players: players,
                              compact: compact,
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => MatchmakingScreen(session: session, playerCount: players),
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
              SizedBox(height: compact ? 2 : 5),
              const Text(
                'Swipe left or right • Tap a room to enter matchmaking',
                style: TextStyle(color: Colors.white38, fontSize: 9.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
    );
  }
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
  final VoidCallback onTap;

  const RoundRoomCard({super.key, required this.players, required this.compact, required this.onTap});

  @override
  State<RoundRoomCard> createState() => _RoundRoomCardState();
}

class _RoundRoomCardState extends State<RoundRoomCard> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final players = widget.players;
    final palette = _paletteFor(players);
    final limit = _limitFor(players);
    final title = players == 2 ? '1 VS 1' : '$players';
    final subtitle = players == 2 ? 'DUEL' : 'PLAYERS';
    final diameter = widget.compact ? 158.0 : 190.0;

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
                  Positioned.fill(child: CustomPaint(painter: _CasinoRingPainter(palette.accent))),
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
                    _MenuTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', selected: activePage == 4, onTap: () => _select(context, 4)),
                    _MenuTile(icon: Icons.upload_rounded, label: 'Withdraw', selected: activePage == 5, onTap: () => _select(context, 5)),
                    _MenuTile(icon: Icons.settings_rounded, label: 'Settings', selected: activePage == 6, onTap: () => _select(context, 6)),
                    _MenuTile(icon: Icons.support_agent_rounded, label: 'Support', selected: activePage == 7, onTap: () => _select(context, 7)),
                    _MenuTile(icon: Icons.gavel_rounded, label: 'Rules & fees', selected: activePage == 8, onTap: () => _select(context, 8)),
                  ],
                ),
              ),
              const Text('3 Patti Social • v0.7', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.white30)),
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

class StoreView extends StatelessWidget {
  final AppSession session;

  const StoreView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Emerald Table', Icons.table_restaurant_rounded, 'Table theme'),
      ('Royal Blue Table', Icons.style_rounded, 'Table theme'),
      ('Gold Avatar Frame', Icons.account_circle_rounded, 'Profile cosmetic'),
      ('Card Back Pack', Icons.layers_rounded, 'Card cosmetic'),
    ];
    return PageFrame(
      title: 'STORE',
      subtitle: 'Cosmetics and non-wagering upgrades',
      child: GridView.count(
        crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 4 : 2,
        childAspectRatio: 1.45,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$2, color: gold, size: 34),
                const Spacer(),
                Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(item.$3, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 8),
                const Text('COMING SOON', style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          );
        }).toList(),
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
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: _panelDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(radius: 35, backgroundColor: Color(0xFF173326), child: Icon(Icons.person_rounded, size: 42, color: gold)),
                const SizedBox(height: 12),
                Text(session.displayName, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                Text('Player ID: ${session.playerId}', style: const TextStyle(fontSize: 10, color: Colors.white38)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on_rounded, color: gold),
                    const SizedBox(width: 6),
                    Text('${_money(session.walletChips)} chips', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('EDIT DISPLAY NAME'),
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
      title: 'WALLET',
      subtitle: 'Balance and account funding',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricCard(label: 'DISPLAY BALANCE', value: '₹${_money(session.walletChips)}', helper: '${_money(session.walletChips)} chips • 1 chip = ₹1'),
              const SizedBox(height: 12),
              const _PrototypeNotice(),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: null, icon: const Icon(Icons.add_card_rounded), label: const Text('ADD CASH — NOT ENABLED')),
            ],
          ),
        ),
      ),
    );
  }
}

class WithdrawView extends StatelessWidget {
  final AppSession session;
  const WithdrawView({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'WITHDRAW',
      subtitle: 'Withdrawal center',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricCard(label: 'AVAILABLE DISPLAY BALANCE', value: '₹${_money(session.walletChips)}', helper: 'Prototype balance only'),
              const SizedBox(height: 12),
              const _PrototypeNotice(),
              const SizedBox(height: 12),
              const TextField(enabled: false, decoration: InputDecoration(labelText: 'Withdrawal amount', prefixText: '₹ ', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              FilledButton(onPressed: null, child: const Text('WITHDRAW — NOT ENABLED')),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsView extends StatefulWidget {
  final AppSession session;
  const SettingsView({super.key, required this.session});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool sound = true;
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    return PageFrame(
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
                SwitchListTile(value: sound, onChanged: (v) => setState(() => sound = v), title: const Text('Game sound'), secondary: const Icon(Icons.volume_up_rounded, color: gold)),
                SwitchListTile(value: notifications, onChanged: (v) => setState(() => notifications = v), title: const Text('Notifications'), secondary: const Icon(Icons.notifications_rounded, color: gold)),
                const Divider(height: 22),
                const Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 10)),
                const SizedBox(height: 7),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('DELETE ACCOUNT'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
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
    if (ok == true) widget.session.resetAccount();
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
                _RuleLine('1 chip = ₹1 in the planned cash-wallet model.'),
                _RuleLine('Boot starts at 10 chips.'),
                _RuleLine('Table limits: 2-5 players = 5K, 6-8 players = 20K, 9-10 players = 50K.'),
                _RuleLine('Players compete against other players; the server deals the cards.'),
                _RuleLine('Prototype table fee: 5% of a settled pot. The winner receives the remaining payout.'),
                SizedBox(height: 12),
                Text(
                  'Important: real deposits and withdrawals are not enabled in this build. Cash play must only be activated where the product is properly licensed and permitted.',
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

  const MatchmakingScreen({super.key, required this.session, required this.playerCount});

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
        'playerCount': widget.playerCount,
      });
      roomId = state['roomId'] as String;
      _consume(state);
      poller?.cancel();
      poller = Timer.periodic(const Duration(milliseconds: 900), (_) => _poll());
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
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF04100B),
        foregroundColor: gold,
        title: const Text('MATCHMAKING', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
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
      body: SafeArea(
        child: Center(
          child: Container(
            width: min(MediaQuery.sizeOf(context).width * .75, 720.0),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(colors: [palette.top, palette.bottom]),
              border: Border.all(color: palette.accent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(error == null ? Icons.groups_rounded : Icons.cloud_off_rounded, size: 54, color: palette.accent),
                const SizedBox(height: 14),
                Text('Finding ${widget.playerCount}-player table', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(error ?? '$joined / ${widget.playerCount} players ready', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(error ?? message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                if (error == null) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: joined / widget.playerCount, color: palette.accent, backgroundColor: Colors.white12),
                ] else ...[
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () { setState(() => error = null); _join(); }, child: const Text('TRY AGAIN')),
                  const SizedBox(height: 7),
                  Text(apiBaseUrl, style: const TextStyle(fontSize: 9, color: Colors.white30)),
                ],
                const SizedBox(height: 12),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
              ],
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

class _TableScreenState extends State<TableScreen> {
  Timer? poller;
  Map<String, dynamic>? state;
  String? error;
  bool busy = false;
  int? recordedRound;

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
      final s = await Api.get('/state?roomId=${Uri.encodeComponent(widget.roomId)}&playerId=${Uri.encodeComponent(widget.session.playerId)}');
      if (mounted) {
        setState(() { state = s; error = null; });
        _syncWallet(s);
        _recordIfComplete(s);
      }
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
        'playerId': widget.session.playerId,
        'action': action,
      });
      if (mounted) {
        setState(() { state = s; error = null; });
        _syncWallet(s);
        _recordIfComplete(s);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
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

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s == null) {
      return Scaffold(backgroundColor: ink, body: Center(child: error == null ? const CircularProgressIndicator(color: gold) : Text(error!)));
    }

    final players = (s['players'] as List).cast<Map<String, dynamic>>();
    final me = players.firstWhere((p) => p['id'] == widget.session.playerId);
    final cards = (s['myCards'] as List).cast<Map<String, dynamic>>();
    final seen = s['mySeen'] == true || s['status'] == 'showdown';
    final showdown = s['status'] == 'showdown';
    final winnerId = s['winnerId'];
    final palette = _paletteFor(s['requestedPlayers'] as int? ?? 2);

    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFF04100B),
        title: Text('${s['requestedPlayers']}-PLAYER TABLE', style: TextStyle(fontSize: 16, color: palette.accent, fontWeight: FontWeight.w900)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 8), child: Center(child: Text('${me['chips']} chips', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)))),
          TextButton.icon(
            onPressed: () {
              widget.session.setPage(0);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_rounded, color: gold, size: 19),
            label: const Text('HOME', style: TextStyle(color: gold, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const RadialGradient(colors: [Color(0xFF14553B), Color(0xFF06301F), Color(0xFF03140E)], radius: 1.2),
                    border: Border.all(color: palette.accent.withValues(alpha: .7)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 6,
                        runSpacing: 6,
                        children: players.where((p) => p['id'] != widget.session.playerId).map((p) {
                          final isWinner = p['id'] == winnerId;
                          return Chip(
                            avatar: CircleAvatar(child: Icon(isWinner ? Icons.emoji_events : Icons.person, size: 15)),
                            label: Text('${p['name']} • ${p['chips']}${p['folded'] == true ? ' • PACK' : ''}'),
                          );
                        }).toList(),
                      ),
                      const Spacer(),
                      const Text('POT', style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700)),
                      Text('${s['pot']} chips', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: gold)),
                      Text('Cap ${s['cap']} • Next chaal ${s['currentBet']}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      const SizedBox(height: 14),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: cards.map((c) => PlayingCardView(card: c, faceUp: seen)).toList()),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Text('${s['message']}', textAlign: TextAlign.center, style: TextStyle(fontWeight: winnerId == widget.session.playerId ? FontWeight.w900 : FontWeight.w600)),
                      ),
                      if (showdown) ...[
                        const SizedBox(height: 6),
                        Text('Winner payout: ${s['lastPayout'] ?? 0} • Table fee: ${s['lastFee'] ?? 0}', style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: min(MediaQuery.sizeOf(context).width * .23, 245.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: _panelDecoration(),
                      child: Column(children: [
                        const Text('YOUR SEAT', style: TextStyle(color: gold, fontSize: 10, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text(widget.session.displayName, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('${me['chips']} chips', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      ]),
                    ),
                    const Spacer(),
                    if (!showdown) ...[
                      OutlinedButton(onPressed: busy ? null : () => _action('pack'), child: const Text('PACK')),
                      const SizedBox(height: 7),
                      FilledButton.tonal(onPressed: busy || seen ? null : () => _action('see'), child: const Text('SEE CARDS')),
                      const SizedBox(height: 7),
                      FilledButton(onPressed: busy ? null : () => _action('chaal'), child: Text('CHAAL ${s['currentBet']}')),
                      const SizedBox(height: 7),
                      FilledButton.tonal(onPressed: busy ? null : () => _action('show'), child: const Text('SHOW')),
                    ] else
                      FilledButton(onPressed: busy ? null : () { recordedRound = null; _action('new'); }, child: const Text('PLAY AGAIN')),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 10)),
                    ],
                  ],
                ),
              ),
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
        color: faceUp ? const Color(0xFFFFF9E9) : const Color(0xFF61111B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: faceUp ? gold : const Color(0xFFE8B9B9), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: faceUp
          ? Text('$rankLabel$suitLabel', style: TextStyle(color: red ? Colors.red.shade700 : Colors.black, fontWeight: FontWeight.w900, fontSize: 22))
          : const Icon(Icons.style_rounded, size: 30, color: gold),
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

BoxDecoration _panelDecoration() => BoxDecoration(
  color: const Color(0xFF0A1712),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: const Color(0xFF66501E)),
);

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
