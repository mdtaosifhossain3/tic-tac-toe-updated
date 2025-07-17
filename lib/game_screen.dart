import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

enum Difficulty { easy, medium, hard }

enum GameMode { playerVsAI, playerVsPlayer }

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
  List<String> items = [];
  String result = '';
  int userScore = 0;
  int aiScore = 0;
  int drawScore = 0;
  int itemFilled = 0;
  Difficulty currentDifficulty = Difficulty.medium;
  GameMode currentGameMode = GameMode.playerVsAI;
  int boardSize = 3;
  bool isPlayerXTurn = true; // For Player vs Player mode

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
    _initializeBoard();
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

  void _initializeBoard() {
    items = List.filled(boardSize * boardSize, "");
    itemFilled = 0;
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
      _initializeBoard();
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

  double _getRandomMoveChance() {
    switch (currentDifficulty) {
      case Difficulty.easy:
        return 0.60; // 60% random moves (40% minimax)
      case Difficulty.medium:
        return 0.22; // 22% random moves (78% minimax)
      case Difficulty.hard:
        return 0.17; // 16% random moves (83% minimax)
    }
  }

  // void _changeDifficulty() {
  //   setState(() {
  //     switch (currentDifficulty) {
  //       case Difficulty.easy:
  //         currentDifficulty = Difficulty.medium;
  //         break;
  //       case Difficulty.medium:
  //         currentDifficulty = Difficulty.hard;
  //         break;
  //       case Difficulty.hard:
  //         currentDifficulty = Difficulty.easy;
  //         break;
  //     }
  //   });
  // }

  // void _changeBoardSize() {
  //   setState(() {
  //     switch (boardSize) {
  //       case 3:
  //         boardSize = 4;
  //         break;
  //       case 4:
  //         boardSize = 5;
  //         break;
  //       case 5:
  //         boardSize = 6;
  //         break;
  //       case 6:
  //         boardSize = 3;
  //         break;
  //     }
  //     _initializeBoard();
  //     result = '';
  //     onTap = true;
  //   });
  // }

  @override
  void dispose() {
    super.dispose();
    _bannerAd.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Tic Tac Toe",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
              onPressed: () async {
                await _resetScores();
                loadAd();
              },
              icon: const Icon(
                Icons.refresh,
                color: Color(0xffA8BFC9),
              ))
        ],
      ),
      drawer: _buildDrawer(),
     // backgroundColor: const Color(0xff1A2A33),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xff1A2A33),
              Color(0xff24BCE7),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      isBannerAddLoaded
                          ? SizedBox(
                              width: _bannerAd.size.width.toDouble(),
                              height: _bannerAd.size.height.toDouble(),
                              child: AdWidget(ad: _bannerAd),
                            )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _scoreCard("You", userScore, Colors.black87),
                          _scoreCard("AI", aiScore, Colors.black87),
                          _scoreCard("Draw", drawScore, Colors.black87),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * .03)
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
                        itemCount: boardSize * boardSize,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: boardSize,
                          crossAxisSpacing: boardSize > 4 ? 8 : 18,
                          mainAxisSpacing: boardSize > 4 ? 8 : 18,
                        ),
                        itemBuilder: (context, index) {
                          bool isWinningTile = _getWinningTiles().contains(index);
                          double iconSize = boardSize > 4
                              ? 30
                              : boardSize > 3
                                  ? 50
                                  : 70;
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
                                            ? Colors.amber.withValues(alpha: 0.92)
                                            : Colors.cyan.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(
                                        boardSize > 4 ? 12 : 22),
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
                                      borderRadius: BorderRadius.circular(
                                          boardSize > 4 ? 12 : 22),
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
                                                      size: iconSize,
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
                                                      size: iconSize,
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

                  const SizedBox(height: 16),
                  // Current game info
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        // Text(
                        //   currentGameMode == GameMode.playerVsAI ? 'Player vs AI' : 'Player vs Player',
                        //   style: const TextStyle(
                        //     color: Colors.white,
                        //     fontSize: 16,
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                        //  const SizedBox(height: 4),
                        Text(
                          '${boardSize}x$boardSize • ${_getDifficultyText()}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: const Color(0xffA8BFC9),
      //   tooltip: "Reset Scores",
      //   child: const Icon(Icons.refresh, color: Colors.black45),
      //   onPressed: () async {
      //     await _resetScores();
      //     loadAd();
      //   },
      // ),
    );
  }

  Widget _scoreCard(String label, int score, Color color) {
    // String displayLabel = label;
    // if (currentGameMode == GameMode.playerVsPlayer) {
    //   if (label == "You") displayLabel = "Player O";
    //   if (label == "AI") displayLabel = "Player X";
    // }

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
                      ? (currentGameMode == GameMode.playerVsPlayer
                          ? Icons.person_outline_rounded
                          : Icons.smart_toy_rounded)
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

    if (currentGameMode == GameMode.playerVsPlayer) {
      // Player vs Player mode
      setState(() {
        items[index] = isPlayerXTurn ? 'x' : '0';
        itemFilled++;
        isPlayerXTurn = !isPlayerXTurn;
      });

      String currentPlayer = isPlayerXTurn ? '0' : 'x';
      String winner = isPlayerXTurn ? "Player O Wins!" : "Player X Wins!";

      if (_checkWinCondition(currentPlayer)) {
        setState(() {
          result = winner;
          if (currentPlayer == '0') {
            userScore++;
          } else {
            aiScore++; // Using aiScore for Player X
          }
          onTap = false;
        });
        _updateScores();
        _showDialog();
        return;
      } else if (itemFilled == boardSize * boardSize) {
        setState(() {
          result = "It's a Draw!";
          drawScore++;
          onTap = false;
        });
        _updateScores();
        _showDialog();
        return;
      }
    } else {
      // Player vs AI mode (original logic)
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
      } else if (itemFilled == boardSize * boardSize) {
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
  }

  void _makeAIMove() {
    // Only run AI move in Player vs AI mode
    if (currentGameMode != GameMode.playerVsAI) return;

    if (_checkWinCondition('0') ||
        _checkWinCondition('x') ||
        itemFilled == boardSize * boardSize) {
      onTap = false;
      return;
    }

    int bestMove;
    // Use difficulty-based random move chance
    if (Random().nextDouble() < _getRandomMoveChance()) {
      List<int> available = [];
      for (int i = 0; i < boardSize * boardSize; i++) {
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
    } else if (itemFilled == boardSize * boardSize) {
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
    for (int i = 0; i < boardSize * boardSize; i++) {
      if (items[i] == '') {
        items[i] = 'x';
        int score = _minimax(0, false, 0);
        items[i] = '';
        if (score > bestScore) {
          bestScore = score;
          move = i;
        }
      }
    }
    return move;
  }

  int _minimax(int depth, bool isMaximizing, int maxDepth) {
    // Limit depth for larger boards to prevent performance issues
    int depthLimit = boardSize <= 3
        ? 9
        : boardSize <= 4
            ? 4
            : 3;

    if (_checkWinCondition('x')) return 10 - depth;
    if (_checkWinCondition('0')) return depth - 10;
    if (!items.contains('') || depth >= depthLimit) {
      return 0; // Draw or depth limit
    }

    if (isMaximizing) {
      int bestScore = -1000;
      for (int i = 0; i < boardSize * boardSize; i++) {
        if (items[i] == '') {
          items[i] = 'x';
          int score = _minimax(depth + 1, false, maxDepth);
          items[i] = '';
          bestScore = max(score, bestScore);
        }
      }
      return bestScore;
    } else {
      int bestScore = 1000;
      for (int i = 0; i < boardSize * boardSize; i++) {
        if (items[i] == '') {
          items[i] = '0';
          int score = _minimax(depth + 1, true, maxDepth);
          items[i] = '';
          bestScore = min(score, bestScore);
        }
      }
      return bestScore;
    }
  }

  bool _checkWinCondition(String player) {
    // Check if we need 3, 4, 5, or 6 in a row based on board size
    int winLength = boardSize;

    // For larger boards, we can make it slightly easier (optional)
    if (boardSize > 4) {
      winLength = boardSize - 1; // 4 in a row for 5x5, 5 in a row for 6x6
    }

    // Check rows
    for (int row = 0; row < boardSize; row++) {
      for (int col = 0; col <= boardSize - winLength; col++) {
        bool win = true;
        for (int i = 0; i < winLength; i++) {
          if (items[row * boardSize + col + i] != player) {
            win = false;
            break;
          }
        }
        if (win) return true;
      }
    }

    // Check columns
    for (int col = 0; col < boardSize; col++) {
      for (int row = 0; row <= boardSize - winLength; row++) {
        bool win = true;
        for (int i = 0; i < winLength; i++) {
          if (items[(row + i) * boardSize + col] != player) {
            win = false;
            break;
          }
        }
        if (win) return true;
      }
    }

    // Check diagonals (top-left to bottom-right)
    for (int row = 0; row <= boardSize - winLength; row++) {
      for (int col = 0; col <= boardSize - winLength; col++) {
        bool win = true;
        for (int i = 0; i < winLength; i++) {
          if (items[(row + i) * boardSize + col + i] != player) {
            win = false;
            break;
          }
        }
        if (win) return true;
      }
    }

    // Check diagonals (top-right to bottom-left)
    for (int row = 0; row <= boardSize - winLength; row++) {
      for (int col = winLength - 1; col < boardSize; col++) {
        bool win = true;
        for (int i = 0; i < winLength; i++) {
          if (items[(row + i) * boardSize + col - i] != player) {
            win = false;
            break;
          }
        }
        if (win) return true;
      }
    }

    return false;
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
                  "Welcome to Tic Tac Toe \n Game",
                  textAlign: TextAlign.center,
                  style:  TextStyle(
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
                      _initializeBoard();
                      result = '';
                      onTap = true;
                      isPlayerXTurn = true; // Reset turn for Player vs Player
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
    // This is a simplified version - you could enhance it to show the exact winning line
    String winner = '';
    if (_checkWinCondition('0')) winner = '0';
    if (_checkWinCondition('x')) winner = 'x';

    if (winner == '') return [];

    // For simplicity, return empty list. You could implement full winning line detection here
    return [];
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xff1A2A33),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Drawer Header with Logo
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xff24BCE7).withValues(alpha: 0.8),
                    const Color(0xff1A2A33),
                  ],
                ),
              ),
              child:const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo placeholder - you can replace with your logo
                  // Container(
                  //   width: 80,
                  //   height: 80,
                  //   decoration: BoxDecoration(
                  //    // color: Colors.white,
                  //     borderRadius: BorderRadius.circular(40),
                  //     image: const DecorationImage(
                  //         image: AssetImage("assets/images/logo_without_bg.png"),),
                  //     // boxShadow: [
                  //     //   BoxShadow(
                  //     //     color: Colors.black.withValues(alpha: 0.3),
                  //     //     blurRadius: 10,
                  //     //     offset: const Offset(0, 5),
                  //     //   ),
                  //     // ],
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                   Text(
                    'Game Setting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  // const Text(
                  //   'Ultimate Game',
                  //   style: TextStyle(
                  //     color: Colors.white70,
                  //     fontSize: 14,
                  //     fontWeight: FontWeight.w500,
                  //   ),
                  // ),
                ],
              ),
            ),

            // Drawer Content
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Difficulty Section (only show for AI mode)
                  if (currentGameMode == GameMode.playerVsAI) ...[
                    _buildSectionTitle('Difficulty'),
                    const SizedBox(height: 12),
                    _buildDifficultyOption(
                        Difficulty.easy, 'Easy', Colors.green),
                    _buildDifficultyOption(
                        Difficulty.medium, 'Medium', Colors.orange),
                    _buildDifficultyOption(Difficulty.hard, 'Hard', Colors.red),
                  ],

                  const SizedBox(height: 30),

                  // Board Size Section
                  _buildSectionTitle('Board Size'),
                  const SizedBox(height: 12),
                  _buildBoardSizeOption(3, '3x3'),
                  _buildBoardSizeOption(4, '4x4'),
                  _buildBoardSizeOption(5, '5x5'),
                  _buildBoardSizeOption(6, '6x6'),

                  // Reset Button
                  // Container(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     onPressed: () async {
                  //       await _resetScores();
                  //     //  Navigator.pop(context);
                  //     },
                  //     icon: const Icon(Icons.refresh),
                  //     label: const Text('Reset Scores'),
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: const Color(0xffA8BFC9),
                  //       foregroundColor: const Color(0xff1A2A33),
                  //       padding: const EdgeInsets.symmetric(vertical: 12),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(8),
                  //       ),
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xff24BCE7),
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  // Widget _buildGameModeOption(GameMode mode, String title, IconData icon) {
  //   bool isSelected = currentGameMode == mode;
  //   return Container(
  //     margin: const EdgeInsets.only(bottom: 8),
  //     child: Material(
  //       color: Colors.transparent,
  //       child: InkWell(
  //         borderRadius: BorderRadius.circular(12),
  //         onTap: () {
  //           setState(() {
  //             currentGameMode = mode;
  //             _initializeBoard();
  //             result = '';
  //             onTap = true;
  //             isPlayerXTurn = true;
  //           });
  //         },
  //         child: Container(
  //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //           decoration: BoxDecoration(
  //             color: isSelected
  //                 ? const Color(0xff24BCE7).withValues(alpha: 0.2)
  //                 : Colors.transparent,
  //             borderRadius: BorderRadius.circular(12),
  //             border: Border.all(
  //               color: isSelected
  //                   ? const Color(0xff24BCE7)
  //                   : Colors.white.withValues(alpha: 0.3),
  //               width: 1.5,
  //             ),
  //           ),
  //           child: Row(
  //             children: [
  //               Icon(
  //                 icon,
  //                 color: isSelected ? const Color(0xff24BCE7) : Colors.white70,
  //                 size: 20,
  //               ),
  //               const SizedBox(width: 12),
  //               Text(
  //                 title,
  //                 style: TextStyle(
  //                   color:
  //                       isSelected ? const Color(0xff24BCE7) : Colors.white70,
  //                   fontSize: 16,
  //                   fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
  //                 ),
  //               ),
  //               const Spacer(),
  //               Radio<GameMode>(
  //                 value: mode,
  //                 groupValue: currentGameMode,
  //                 onChanged: (GameMode? value) {
  //                   setState(() {
  //                     currentGameMode = value!;
  //                     _initializeBoard();
  //                     result = '';
  //                     onTap = true;
  //                     isPlayerXTurn = true;
  //                   });
  //                 },
  //                 activeColor: const Color(0xff24BCE7),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildBoardSizeOption(int size, String title, ) {
    bool isSelected = boardSize == size;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          boardSize = size;
          _initializeBoard();
          result = '';
          onTap = true;
          isPlayerXTurn = true;
        });
      },
      child: Row(
        children: [
          Icon(
            Icons.grid_3x3,
            color: isSelected ? Colors.blue : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.white70,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Radio<int>(
            value: size,
            groupValue: boardSize,
            onChanged: (int? value) {
              setState(() {
                boardSize = value!;
                _initializeBoard();
                result = '';
                onTap = true;
                isPlayerXTurn = true;
              });
            },
            activeColor: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyOption(
      Difficulty difficulty, String title, Color color,) {
    bool isSelected = currentDifficulty == difficulty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              currentDifficulty = difficulty;

            });
          },
          child: Row(
            children: [
              Icon(
                Icons.speed,
                color: isSelected ? color : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? color : Colors.white70,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const Spacer(),
              Radio<Difficulty>(
                value: difficulty,
                groupValue: currentDifficulty,
                onChanged: (Difficulty? value) {
                  setState(() {
                    currentDifficulty = value!;
                  });
                },
                activeColor: color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
