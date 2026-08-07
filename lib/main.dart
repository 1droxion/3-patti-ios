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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: ink,
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
  final String playerId =
      'p-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(99999)}';
  final List<GameHistoryItem> history = [];

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
  int page = 0; // 0 lobby, 1 store, 2 history, 3 profile

  void goHome() => setState(() => page = 0);

  @override
  Widget build(BuildContext context) {
    final body = switch (page) {
      1 => StoreView(session: widget.session),
      2 => HistoryView(session: widget.session),
      3 => ProfileView(session: widget.session),
      _ => LobbyView(session: widget.session),
    };

    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        return Scaffold(
          key: scaffoldKey,
          endDrawer: AppMenu(session: widget.session),
          body: SafeArea(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF03110D), Color(0xFF00100B), Color(0xFF050706)],
                ),
              ),
              child: Column(
                children: [
                  AppHeader(
                    session: widget.session,
                    onHome: goHome,
                    onMenu: () => scaffoldKey.currentState?.openEndDrawer(),
                  ),
                  Expanded(child: body),
                  BottomDock(
                    active: page,
                    onStore: () => setState(() => page = 1),
                    onHistory: () => setState(() => page = 2),
                    onProfile: () => setState(() => page = 3),
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

class AppHeader extends StatelessWidget {
  final AppSession session;
  final VoidCallback onHome;
  final VoidCallback onMenu;

  const AppHeader({
    super.key,
    required this.session,
    required this.onHome,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xF2020907),
        border: Border(bottom: BorderSide(color: Color(0x557A5A10))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onHome,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFFFE07A), Color(0xFFB87400), Color(0xFF231600)],
                      ),
                      border: Border.all(color: gold, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: const Text('3', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Colors.black)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('3 PATTI', style: TextStyle(fontSize: 19, color: gold, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                      Text('SOCIAL', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 2.1)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('3 PATTI SOCIAL', style: TextStyle(fontSize: 25, color: gold, fontWeight: FontWeight.w900, letterSpacing: .8)),
              SizedBox(height: 2),
              Text('REAL PLAY. REAL PEOPLE.', style: TextStyle(fontSize: 10, color: Colors.white60, letterSpacing: 2.3, fontWeight: FontWeight.w700)),
            ],
          ),
          const Spacer(),
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WalletScreen(session: session))),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF07150F),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF9A6813)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded, color: gold, size: 33),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${_money(session.walletChips)}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      const Text('1 CHIP = ₹1', style: TextStyle(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E4D1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: goldDeep),
                    ),
                    child: const Icon(Icons.add_rounded, color: gold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.filledTonal(
            onPressed: onMenu,
            icon: const Icon(Icons.menu_rounded, color: gold, size: 30),
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              backgroundColor: const Color(0xFF0D130F),
              side: const BorderSide(color: Color(0xFF75500B)),
            ),
          ),
        ],
      ),
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
        final columns = constraints.maxWidth >= 700 ? 5 : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HeroPanel(),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.groups_rounded, color: gold, size: 20),
                  SizedBox(width: 8),
                  Text('CHOOSE PLAYERS', style: TextStyle(color: gold, fontWeight: FontWeight.w900, letterSpacing: .8)),
                ],
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: columns == 5 ? 1.62 : 1.45,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemBuilder: (context, index) {
                  final players = index + 2;
                  return TableChoiceCard(
                    players: players,
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MatchmakingScreen(
                          session: session,
                          playerCount: players,
                        ),
                      ));
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF8C6518)),
        gradient: const LinearGradient(
          colors: [Color(0xFF073B27), Color(0xFF06291E), Color(0xFF091812)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x3300FF66), blurRadius: 30, spreadRadius: -18)],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('CHOOSE YOUR TABLE', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: .5)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: const [
                    _InfoTag(icon: Icons.monetization_on_rounded, text: 'Boot: 10 Chips'),
                    _InfoTag(icon: Icons.emoji_events_rounded, text: 'Cap: 5,000 Chips'),
                    _InfoTag(icon: Icons.verified_user_rounded, text: 'Fair & Secure'),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Pick exactly how many players you want. Larger rooms begin when all seats are filled.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ],
            ),
          ),
          const Expanded(flex: 3, child: _CardArt()),
        ],
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: gold, size: 21),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(right: 54, top: 8, child: Transform.rotate(angle: -.12, child: const _MiniCard('A', '♠', Colors.black))),
          Positioned(right: 23, top: 4, child: Transform.rotate(angle: .10, child: const _MiniCard('A', '♥', Colors.red))),
          Positioned(right: 0, top: 14, child: Transform.rotate(angle: .20, child: const _MiniCard('A', '♣', Colors.black))),
          Positioned(right: 5, bottom: 0, child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(colors: [Color(0xFFFFDD6D), Color(0xFFB16D00), Color(0xFF5A3300)]),
              border: Border.all(color: const Color(0xFFFFE18B), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x88E2A326), blurRadius: 16)],
            ),
            child: const Icon(Icons.savings_rounded, color: Color(0xFF3D2500), size: 30),
          )),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String rank;
  final String suit;
  final Color color;

  const _MiniCard(this.rank, this.suit, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
      ),
      child: Text('$rank\n$suit', style: TextStyle(color: color, fontSize: 19, height: .9, fontWeight: FontWeight.w900)),
    );
  }
}

class TableChoiceCard extends StatelessWidget {
  final int players;
  final VoidCallback onTap;

  const TableChoiceCard({super.key, required this.players, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(players);
    final fast = players <= 5;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: palette.accent.withValues(alpha: .85), width: players == 2 ? 2 : 1.2),
          gradient: LinearGradient(colors: [palette.top, palette.bottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            if (players == 2) BoxShadow(color: palette.accent.withValues(alpha: .28), blurRadius: 18),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: palette.accent.withValues(alpha: .13),
                  child: Icon(Icons.groups_rounded, color: palette.accent, size: 22),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$players', style: const TextStyle(fontSize: 27, height: 1, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 5),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 2),
                        child: Text('PLAYERS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white70)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (fast)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: palette.accent.withValues(alpha: .17), borderRadius: BorderRadius.circular(20)),
                  child: Text('FAST MATCH', style: TextStyle(fontSize: 8, color: palette.accent, fontWeight: FontWeight.w900)),
                ),
              ),
            const SizedBox(height: 5),
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Boot: 10 Chips   |   Cap: 5,000 Chips', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
            ),
            const SizedBox(height: 7),
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(colors: [palette.button1, palette.button2]),
                border: Border.all(color: palette.accent.withValues(alpha: .35)),
              ),
              child: const Text('JOIN TABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }
}

_TablePalette _paletteFor(int players) {
  if (players <= 5) {
    return const _TablePalette(
      top: Color(0xFF073A20),
      bottom: Color(0xFF04180F),
      accent: Color(0xFF68E85D),
      button1: Color(0xFF0D6B25),
      button2: Color(0xFF074214),
    );
  }
  if (players <= 8) {
    return const _TablePalette(
      top: Color(0xFF083A6B),
      bottom: Color(0xFF041A33),
      accent: Color(0xFF52AEFF),
      button1: Color(0xFF0B5AA7),
      button2: Color(0xFF06386C),
    );
  }
  return const _TablePalette(
    top: Color(0xFF513700),
    bottom: Color(0xFF211500),
    accent: Color(0xFFFFCC48),
    button1: Color(0xFF9E6800),
    button2: Color(0xFF654100),
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

class BottomDock extends StatelessWidget {
  final int active;
  final VoidCallback onStore;
  final VoidCallback onHistory;
  final VoidCallback onProfile;

  const BottomDock({
    super.key,
    required this.active,
    required this.onStore,
    required this.onHistory,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Color(0xF7040A08),
        border: Border(top: BorderSide(color: Color(0xFF64470E))),
      ),
      child: Row(
        children: [
          Expanded(child: _DockButton(icon: Icons.shopping_cart_outlined, label: 'STORE', selected: active == 1, onTap: onStore)),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
          Expanded(child: _DockButton(icon: Icons.history_rounded, label: 'HISTORY', selected: active == 2, onTap: onHistory)),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: Colors.white12),
          Expanded(child: _DockButton(icon: Icons.person_rounded, label: 'PROFILE', selected: active == 3, onTap: onProfile)),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DockButton({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? gold : Colors.white54, size: 25),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: selected ? gold : Colors.white54, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class AppMenu extends StatelessWidget {
  final AppSession session;

  const AppMenu({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: min(MediaQuery.sizeOf(context).width * .42, 360.0),
      backgroundColor: const Color(0xFF050A08),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('MENU', style: TextStyle(fontSize: 22, color: gold, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: gold)),
                ],
              ),
              const Divider(color: Color(0xFF5E4617)),
              _MenuTile(icon: Icons.account_balance_wallet_rounded, label: 'Wallet', onTap: () => _pushFromDrawer(context, WalletScreen(session: session))),
              _MenuTile(icon: Icons.upload_rounded, label: 'Withdraw', onTap: () => _pushFromDrawer(context, WithdrawScreen(session: session))),
              _MenuTile(icon: Icons.settings_rounded, label: 'Settings', onTap: () => _pushFromDrawer(context, SettingsScreen(session: session))),
              _MenuTile(icon: Icons.support_agent_rounded, label: 'Support', onTap: () => _pushFromDrawer(context, const SupportScreen())),
              _MenuTile(icon: Icons.gavel_rounded, label: 'Rules & fees', onTap: () => _pushFromDrawer(context, const RulesScreen())),
              const Spacer(),
              const Text('3 Patti Social • v0.3 prototype', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.white38)),
            ],
          ),
        ),
      ),
    );
  }

  void _pushFromDrawer(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Future<void>.delayed(Duration.zero, () {
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    });
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: gold),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right_rounded),
        tileColor: const Color(0xFF0A110E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF4D3913))),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 27, color: gold, fontWeight: FontWeight.w900)),
          Text(subtitle, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 14),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class WalletScreen extends StatelessWidget {
  final AppSession session;

  const WalletScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SimpleScreen(
      title: 'Wallet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricCard(label: 'DISPLAY BALANCE', value: '₹${_money(session.walletChips)}', helper: '${_money(session.walletChips)} chips • 1 chip = ₹1'),
          const SizedBox(height: 12),
          const _PrototypeNotice(),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: null, icon: Icon(Icons.add_card_rounded), label: Text('ADD CASH — NOT ENABLED')),
        ],
      ),
    );
  }
}

class WithdrawScreen extends StatelessWidget {
  final AppSession session;

  const WithdrawScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return SimpleScreen(
      title: 'Withdraw',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MetricCard(label: 'AVAILABLE DISPLAY BALANCE', value: '₹${_money(session.walletChips)}', helper: 'Prototype balance only'),
          const SizedBox(height: 12),
          const _PrototypeNotice(),
          const SizedBox(height: 12),
          const TextField(enabled: false, decoration: InputDecoration(labelText: 'Withdrawal amount', prefixText: '₹ ', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          const FilledButton(onPressed: null, child: Text('WITHDRAW — NOT ENABLED')),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final AppSession session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool sound = true;
  bool notifications = true;

  @override
  Widget build(BuildContext context) {
    return SimpleScreen(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(value: sound, onChanged: (v) => setState(() => sound = v), title: const Text('Game sound'), secondary: const Icon(Icons.volume_up_rounded, color: gold)),
          SwitchListTile(value: notifications, onChanged: (v) => setState(() => notifications = v), title: const Text('Notifications'), secondary: const Icon(Icons.notifications_rounded, color: gold)),
          const Divider(height: 28),
          const Text('DANGER ZONE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
            onPressed: _confirmDelete,
            icon: const Icon(Icons.delete_forever_rounded),
            label: const Text('DELETE ACCOUNT'),
          ),
        ],
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
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.session.resetAccount();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleScreen(
      title: 'Rules & fees',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RuleLine('1 chip = ₹1 in the planned cash-wallet model.'),
          _RuleLine('Boot starts at 10 chips.'),
          _RuleLine('Maximum table pot is 5,000 chips in this prototype.'),
          _RuleLine('Players compete against other players; the server deals the cards.'),
          _RuleLine('Prototype table fee: 5% of a settled pot. The winner receives the remaining payout.'),
          SizedBox(height: 16),
          Text(
            'Important: real deposits and withdrawals are not enabled in this build. Cash play must only be activated where the product is properly licensed and permitted.',
            style: TextStyle(color: Colors.amberAccent, height: 1.4),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle_rounded, color: greenAccent, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ]),
    );
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SimpleScreen(
      title: 'Support',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Support center', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text('Add your real support email, FAQ, and ticket system before public launch.', style: TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

class SimpleScreen extends StatelessWidget {
  final String title;
  final Widget child;

  const SimpleScreen({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ink,
      appBar: AppBar(title: Text(title), backgroundColor: const Color(0xFF05100C), foregroundColor: gold),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: child),
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
        backgroundColor: const Color(0xFF04100B),
        title: Text('${s['requestedPlayers']}-PLAYER TABLE', style: TextStyle(color: palette.accent, fontWeight: FontWeight.w900)),
        actions: [Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('${me['chips']} chips', style: const TextStyle(fontWeight: FontWeight.w800))))],
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
