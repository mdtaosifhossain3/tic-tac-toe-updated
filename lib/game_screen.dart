import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum Difficulty { easy, medium, hard }

class DBHelper {
  static Future<Database> initDb() async {
    return openDatabase(
      join(await getDatabasesPath(), 'tictactoe.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE scores(id INTEGER PRIMARY KEY, user INTEGER, ai INTEGER, draw INTEGER)',
        );
      },
      version: 1,
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool onTap = true;
  bool isWinner = false;
  List<String> items = ['', '', '', '', '', '', '', '', ''];
  String result = '';
  int userScore = 0;
  int aiScore = 0;
  int drawScore = 0;
  int itemFilled = 0;
  Difficulty currentDifficulty = Difficulty.medium;

  late Database db;
  late BannerAd _bannerAd;
  bool isBannerAddLoaded = false;
  InterstitialAd? _interstitialAd;

  void loadAd() {
    InterstitialAd.load(
        adUnitId: "ca-app-pub-2225408843963260/2264614336",
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('$ad loaded.');
            _interstitialAd = ad;
            _interstitialAd?.show();
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('InterstitialAd failed to load: $error');
          },
        ));
  }

  @override
  void initState() {
    super.initState();
    _initDb();
    Future.delayed(Duration.zero, () {
      _showDialog(isInitial: true);
    });
    _bannerAd = BannerAd(
      adUnitId: "ca-app-pub-2225408843963260/8857958754",
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            isBannerAddLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner Ad failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd.load();
  }

  Future<void> _initDb() async {
    db = await DBHelper.initDb();
    await _loadScores();
  }

  Future<void> _loadScores() async {
    final List<Map<String, dynamic>> maps = await db.query('scores');
    if (maps.isNotEmpty) {
      setState(() {
        userScore = maps[0]['user'];
        aiScore = maps[0]['ai'];
        drawScore = maps[0]['draw'];
      });
    } else {
      await db.insert('scores', {'user': 0, 'ai': 0, 'draw': 0});
    }
  }

  Future<void> _updateScores() async {
    await db.update('scores', {
      'user': userScore,
      'ai': aiScore,
      'draw': drawScore,
    });
  }

  Future<void> _resetScores() async {
    await db.update('scores', {'user': 0, 'ai': 0, 'draw': 0});
    setState(() {
      userScore = 0;
      aiScore = 0;
      drawScore = 0;
      items = List.filled(9, '');
      itemFilled = 0;
      result = '';
      onTap = true;
    });
  }

  // Function to send a message to the SMS app
  Future<void> sendStopMessage(context) async {
    const phoneNumber = '21213';
    const message = 'STOP atms';

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch SMS')),
      );
    }
  }

  String _getDifficultyText() {
    switch (currentDifficulty) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
    }
  }

  Color _getDifficultyColor() {
    switch (currentDifficulty) {
      case Difficulty.easy:
        return Colors.green;
      case Difficulty.medium:
        return Colors.orange;
      case Difficulty.hard:
        return Colors.red;
    }
  }

  double _getRandomMoveChance() {
    switch (currentDifficulty) {
      case Difficulty.easy:
        return 0.60; // 60% random moves (40% minimax)
      case Difficulty.medium:
        return 0.25; // 25% random moves (75% minimax)
      case Difficulty.hard:
        return 0.18; // 18% random moves (82% minimax)
    }
  }

  void _changeDifficulty() {
    setState(() {
      switch (currentDifficulty) {
        case Difficulty.easy:
          currentDifficulty = Difficulty.medium;
          break;
        case Difficulty.medium:
          currentDifficulty = Difficulty.hard;
          break;
        case Difficulty.hard:
          currentDifficulty = Difficulty.easy;
          break;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _bannerAd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xff1A2A33),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      isBannerAddLoaded
                          ? SizedBox(
                              width: _bannerAd.size.width.toDouble(),
                              height: _bannerAd.size.height.toDouble(),
                              child: AdWidget(ad: _bannerAd),
                            )
                          : const Text(
                              "Tic Tac Toe",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 40,
                                letterSpacing: 2,
                                fontFamily: 'Roboto',
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                      const SizedBox(height: 16),
                      // Difficulty selector
                      GestureDetector(
                        onTap: _changeDifficulty,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor().withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _getDifficultyColor(),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.settings,
                                color: _getDifficultyColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Difficulty: ${_getDifficultyText()}',
                                style: TextStyle(
                                  color: _getDifficultyColor(),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.touch_app,
                                color: _getDifficultyColor(),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _scoreCard("You", userScore, Colors.black87),
                          _scoreCard("AI", aiScore, Colors.black87),
                          _scoreCard("Draw", drawScore, Colors.black87),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * .06)
                    ],
                  ),
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                        backgroundBlendMode: BlendMode.overlay,
                      ),
                      child: GridView.builder(
                        itemCount: 9,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                        ),
                        itemBuilder: (context, index) {
                          bool isWinningTile =
                              _getWinningTiles().contains(index);
                          return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 1, end: items[index] != '' ? 1.08 : 1),
                            duration: const Duration(milliseconds: 200),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  decoration: BoxDecoration(
                                    color: items[index] == ''
                                        ? Colors.white.withValues(alpha: 0.18)
                                        : items[index] == '0'
                                            ? Colors.amber
                                                .withValues(alpha: 0.92)
                                            : Colors.cyan
                                                .withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(22),
                                    border: isWinningTile
                                        ? Border.all(
                                            color: Colors.greenAccent
                                                .withValues(alpha: 0.85),
                                            width: 4,
                                          )
                                        : null,
                                    boxShadow: [
                                      if (isWinningTile)
                                        BoxShadow(
                                          color: Colors.greenAccent
                                              .withValues(alpha: 0.5),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                        ),
                                      if (items[index] != '')
                                        const BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(22),
                                      onTap: () => _onButtonPressed(index),
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          transitionBuilder: (child, anim) =>
                                              ScaleTransition(
                                                  scale: anim, child: child),
                                          child: items[index] == ''
                                              ? const SizedBox.shrink(
                                                  key: ValueKey('empty'))
                                              : items[index] == '0'
                                                  ? Icon(
                                                      Icons
                                                          .radio_button_unchecked,
                                                      key: const ValueKey('o'),
                                                      size: 70,
                                                      color: Colors
                                                          .deepPurple.shade700,
                                                      shadows: const [
                                                        Shadow(
                                                          color: Colors.black26,
                                                          blurRadius: 12,
                                                          offset: Offset(2, 2),
                                                        ),
                                                      ],
                                                    )
                                                  : Icon(
                                                      Icons.close,
                                                      key: const ValueKey('x'),
                                                      size: 80,
                                                      color: Colors
                                                          .deepPurple.shade900,
                                                      shadows: const [
                                                        Shadow(
                                                          color: Colors.black26,
                                                          blurRadius: 12,
                                                          offset: Offset(2, 2),
                                                        ),
                                                      ],
                                                    ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xffA8BFC9),
        tooltip: "Reset Scores",
        child: const Icon(Icons.refresh, color: Colors.black45),
        onPressed: () async {
          await _resetScores();
          loadAd();
        },
      ),
    );
  }

  Widget _scoreCard(String label, int score, Color color) {
    return Card(
      color: label == "You"
          ? Colors.amber
          : label == "AI"
              ? Colors.cyan
              : Colors.grey,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 6),
        child: Column(
          children: [
            Icon(
              label == "You"
                  ? Icons.person_rounded
                  : label == "AI"
                      ? Icons.smart_toy_rounded
                      : Icons.compare_arrows,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              score.toString(),
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'RobotoMono',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onButtonPressed(int index) {
    if (!onTap || items[index] != '') return;

    setState(() {
      items[index] = '0';
      itemFilled++;
      onTap = false;
    });

    if (_checkWinCondition('0')) {
      setState(() {
        result = "User Wins!";
        userScore++;
      });
      _updateScores();
      _showDialog();
      return;
    } else if (itemFilled == 9) {
      setState(() {
        result = "It's a Draw!";
        drawScore++;
      });
      _updateScores();
      _showDialog();
      return;
    }

    // AI moves after a short delay
    Timer(const Duration(milliseconds: 350), () {
      _makeAIMove();
    });
  }

  void _makeAIMove() {
    if (_checkWinCondition('0') || _checkWinCondition('x') || itemFilled == 9) {
      onTap = false;
      return;
    }

    int bestMove;
    // Use difficulty-based random move chance
    if (Random().nextDouble() < _getRandomMoveChance()) {
      List<int> available = [];
      for (int i = 0; i < 9; i++) {
        if (items[i] == '') available.add(i);
      }
      bestMove = available[Random().nextInt(available.length)];
    } else {
      bestMove = _findBestMove();
    }

    setState(() {
      items[bestMove] = 'x';
      itemFilled++;
      onTap = true;
    });

    if (_checkWinCondition('x')) {
      setState(() {
        result = "AI Wins!";
        aiScore++;
        onTap = false;
      });
      _updateScores();
      _showDialog();
      return;
    } else if (itemFilled == 9) {
      setState(() {
        result = "It's a Draw!";
        drawScore++;
        onTap = false;
      });
      _updateScores();
      _showDialog();
      return;
    }
  }

  int _findBestMove() {
    int bestScore = -1000;
    int move = -1;
    for (int i = 0; i < 9; i++) {
      if (items[i] == '') {
        items[i] = 'x';
        int score = _minimax(0, false);
        items[i] = '';
        if (score > bestScore) {
          bestScore = score;
          move = i;
        }
      }
    }
    return move;
  }

  int _minimax(int depth, bool isMaximizing) {
    if (_checkWinCondition('x')) return 10 - depth;
    if (_checkWinCondition('0')) return depth - 10;
    if (!items.contains('')) return 0; // Draw

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < 9; i++) {
        if (items[i] == '') {
          items[i] = 'x';
          int score = _minimax(depth + 1, false);
          items[i] = '';
          bestScore = max(score, bestScore);
        }
      }
      return bestScore;
    } else {
      int bestScore = 1000;
      for (int i = 0; i < 9; i++) {
        if (items[i] == '') {
          items[i] = '0';
          int score = _minimax(depth + 1, true);
          items[i] = '';
          bestScore = min(score, bestScore);
        }
      }
      return bestScore;
    }
  }

  bool _checkWinCondition(String player) {
    List<List<int>> winConditions = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    return winConditions.any((line) =>
        items[line[0]] == player &&
        items[line[1]] == player &&
        items[line[2]] == player);
  }

  void _showDialog({bool isInitial = false}) {
    showDialog(
      barrierDismissible: false,
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1A2A33),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isInitial)
                const Text(
                  "Welcome to Tic Tac Toe Game",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xff24BCE7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!isInitial)
                Text(
                  result,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Color(0xff24BCE7),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffA8BFC9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () {
                  if (!isInitial) {
                    setState(() {
                      items = List.filled(9, '');
                      itemFilled = 0;
                      result = '';
                      onTap = true;
                    });
                  }
                  Navigator.of(context).pop();
                },
                child: Text(isInitial ? "Let's Play" : "Play Again",
                    style: const TextStyle(
                        color: Color(0xff1A2A33), fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  List<int> _getWinningTiles() {
    List<List<int>> winConditions = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];
    for (var line in winConditions) {
      if (items[line[0]] != '' &&
          items[line[0]] == items[line[1]] &&
          items[line[1]] == items[line[2]]) {
        return line;
      }
    }
    return [];
  }
}
