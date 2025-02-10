import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config/api_config.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 通知初期化（必要に応じて初期化処理をサービスにまとめても良い）
  await NotificationService().init();
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => PomodoroModel(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SYUTYU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const TopPage(),
      routes: {
        '/timer': (context) => const TimerPage(),
        '/settings': (context) => const SettingsPage(),
      },
    );
  }
}

/// -------------------------------
/// PomodoroModel：アプリ全体の状態管理
/// -------------------------------
class PomodoroModel extends ChangeNotifier {
  // デフォルト設定（単位は秒）
  int workDuration = 25 * 60;
  //for debug 10 sec worktime
  //int workDuration = 10;
  int breakDuration = 5 * 60 ;
  int totalCycles = 4;

  // タイマー関連
  Timer? timer;
  int remainingTime = 0;
  bool isWorkMode = true;
  int currentCycle = 0;

  // メッセージ（作業中のメッセージは設定可能）
  String workMessage = "SYUTYU~~~！";

  // タイマー開始
  void startTimer() {
    currentCycle = 0;
    isWorkMode = true;
    remainingTime = workDuration;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime > 0) {
        remainingTime--;
        notifyListeners();
      } else {
        // タイマー終了時の処理
        NotificationService().showNotification(
          title: isWorkMode ? "作業終了" : "休憩終了",
          body: isWorkMode ? "休憩に移ります" : "作業を再開してください",
        );

        // 切り替え処理
        if (isWorkMode) {
          // 作業終了→休憩へ
          isWorkMode = false;
          remainingTime = breakDuration;
          // 音声再生（mp3ダウンロードして再生する処理の呼び出し例）
          AudioService().playTimerEndSound();
        } else {
          // 休憩終了→作業へ
          isWorkMode = true;
          // 音声再生（mp3ダウンロードして再生する処理の呼び出し例）
          AudioService().playTimerStartSound();
          currentCycle++;
          if (currentCycle >= totalCycles) {
            // 全サイクル終了
            timer.cancel();
            return;
          }
          remainingTime = workDuration;
        }
        notifyListeners();
      }
    });
  }

  void stopTimer() {
    timer?.cancel();
    notifyListeners();
  }

  // 設定の更新
  void updateSettings({required int work, required int breakTime, required int cycles}) {
    workDuration = work;
    breakDuration = breakTime;
    totalCycles = cycles;
    notifyListeners();
  }
}

/// -------------------------------
/// NotificationService：ローカル通知
/// -------------------------------
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }
  NotificationService._internal();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification({required String title, required String body}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('pomodoro_channel', 'Pomodoro Notifications',
            channelDescription: '通知チャンネル',
            importance: Importance.max,
            priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }
}

/// -------------------------------
/// AudioService：音声再生サービス
/// -------------------------------

class AudioService {
  final AudioPlayer _player = AudioPlayer();

  /// タイマー開始時の音声を再生する
  Future<void> playTimerStartSound() async {
    // 1～3のランダムな整数を生成
    int n = Random().nextInt(3) + 1;
    final url = 'http://$kApiHost//timerstart/$n.mp3';
    try {
      await _player.setUrl(url);
      _player.play();
    } catch (e) {
      print("Timer start sound error: $e");
    }
  }

  /// タイマー終了時の音声を再生する
  Future<void> playTimerEndSound() async {
    int n = Random().nextInt(3) + 1;
    final url = 'http://$kApiHost/$kVoicePath/timerend/$n.mp3';
    try {
      await _player.setUrl(url);
      _player.play();
    } catch (e) {
      print("Timer end sound error: $e");
    }
  }
  /// summary の音声を再生する
  /// [fileName] 例: "22_20250204.mp3"、[type] 例: "podcast", "tech" など
  Future<void> playSummarySound(String fileName, String type) async {
    String audioType = "summary";
    String audioPath = fileName;
    // ファイル名と type から MP3 URL を作成
    if (type == "podcast") {
      audioType = "podcast";
      audioPath = "ep$fileName";
    }
    final String url = 'http://$kApiHost/$kVoicePath/$audioType/$audioPath';
    try {
      await _player.setUrl(url);
      _player.play();
    } catch (e) {
      print("playSummarySound error: $e");
    }
  }
}


/// -------------------------------
/// TTSService：テキスト読み上げサービス
/// -------------------------------
class TTSService {
  final FlutterTts _flutterTts = FlutterTts();

  Future<void> speak(String text) async {
    await _flutterTts.setLanguage("ja-JP");
    await _flutterTts.speak(text);
  }
}

/// -------------------------------
/// TopPage：トップ画面（タイマー開始、設定画面への遷移）
/// -------------------------------
class TopPage extends StatelessWidget {
  const TopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景色を #292F5B に設定
      backgroundColor: const Color(0xFFDAD7F8),
      appBar: AppBar(
        title: const Text("SYUTYU"),
        backgroundColor: const Color(0xFF4B4A5F), // アプリバーの背景色も合わせる
        foregroundColor: Colors.white ,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/cattop.png', width: 300, height: 300),
            const SizedBox(height: 20),
            // タイマー開始ボタン（後述する候補の色を使用）
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                
                foregroundColor: Colors.white, backgroundColor: const Color(0xFFE9A7BC), 
              ),
              onPressed: () {
                AudioService().playTimerStartSound();
                Provider.of<PomodoroModel>(context, listen: false).startTimer();
                Navigator.pushNamed(context, '/timer');
              },
              child: const Text("Start Timer"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: const Color(0xFF161518),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              child: const Text("settings"),
            ),
          ],
        ),
      ),
    );
  }
}


/// -------------------------------
/// TimerPage：タイマー画面
/// -------------------------------
class TimerPage extends StatefulWidget {
  const TimerPage({Key? key}) : super(key: key);

  @override
  State<TimerPage> createState() => _TimerPageState();
}
class _TimerPageState extends State<TimerPage> with SingleTickerProviderStateMixin {
  // 取得した記事データをリストとして保持する
  List<Map<String, dynamic>> _articles = [];
  // ListView のスクロール用コントローラー
  final ScrollController _scrollController = ScrollController();
  late Timer _timer;
  bool _showColon = true;
  Duration _remaining = const Duration(minutes: 25);
  
  // 追加：アニメーションコントローラーとランダム選択した画像のパス
  late AnimationController _floatingController;
  String _studyImage = '';
  String _restImage = '';

  @override
  void initState() {
    super.initState();
    // ...既存の初期化処理...

    // 画像をランダムに選択
    _studyImage = Random().nextBool() 
      ? 'assets/images/studycat1.png'
      : 'assets/images/studycat2.png';
    
    // 画像をランダムに選択
    _restImage = Random().nextBool() 
      ? 'assets/images/coffeecat1.png'
      : 'assets/images/coffeecat2.png';


    // ふわふわ浮くエフェクトのためのアニメーションコントローラー
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timer.cancel();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = Provider.of<PomodoroModel>(context);

    // 現在時刻を MM/DD HH:mm 形式にフォーマット
    final now = DateTime.now();
    final formattedTime =
        '${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // タイマーの進捗率の計算
    int totalTime = pomodoro.isWorkMode ? pomodoro.workDuration : pomodoro.breakDuration;
    double percent = (totalTime - pomodoro.remainingTime) / totalTime;

    return Scaffold(
      appBar: AppBar(
        title: const Text("SYUTYU - Timer"),
        backgroundColor: const Color(0xFF4B4A5F), // アプリバーの背景色も合わせる
        foregroundColor: Colors.white ,
      ),
      body: Column(
        children: [
          // 上部（40%）：タイマー領域
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                // 背景画像
                Positioned.fill(
                  child: Image.network(
                    'http://$kApiHost/$kBkImgPath/image_1.png',
                    fit: BoxFit.cover,
                  ),
                ),
                // 右上：現在時刻（白い半透明の角丸ボックス）
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      formattedTime,
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                // 右下：円形プログレス表示（背景色：Colors.black.withOpacity(0.5)＋白い枠）
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: Colors.black.withOpacity(0.5), width: 0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircularPercentIndicator(
                        radius: 100.0,
                        lineWidth: 10.0,
                        percent: percent.clamp(0.0, 1.0),
                        center: Text(
                          _formatTimeMMss(pomodoro.remainingTime),
                          style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        progressColor: pomodoro.isWorkMode ? Colors.green : Colors.blue,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 上部と下部の間にマージン
          const SizedBox(height: 16),
          // ※ 休憩中の場合にのみ「記事を読む」ボタンと記事一覧を表示
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: pomodoro.isWorkMode
                    // 作業中の場合は従来のメッセージ表示（またはお好みの内容）
                    ? Column(
                        children: [
                          Text(
                          pomodoro.workMessage,
                          style: const TextStyle(fontSize: 16),
                        ),
                          SizedBox(
                            height: 300, // 画像表示エリアの高さ調整
                            child: AnimatedBuilder(
                              animation: _floatingController,
                              builder: (context, child) {
                                // 縦方向に上下に動かすシンプルなアニメーション
                                final offsetY = 10 * sin(_floatingController.value * 2 * pi);
                                return Transform.translate(
                                  offset: Offset(0, offsetY),
                                  child: child,
                                );
                              },
                              child: Image.asset(
                                _studyImage,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ],
                      )
                    // 休憩中の場合：記事を読むボタンと記事一覧（チャット風UI）
                    : Column(
                        children: [
                          // 画像表示ウィジェット（ふわふわ浮遊エフェクト付き）
                          SizedBox(
                            height: 150, // 画像表示エリアの高さ調整
                            child: AnimatedBuilder(
                              animation: _floatingController,
                              builder: (context, child) {
                                // 縦方向に上下に動かすシンプルなアニメーション
                                final offsetY = 10 * sin(_floatingController.value * 2 * pi);
                                return Transform.translate(
                                  offset: Offset(0, offsetY),
                                  child: child,
                                );
                              },
                              child: Image.asset(
                                _restImage,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 既存のスクロール可能な記事リスト部分
                          Expanded(
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _scrollController,
                                itemCount: _articles.length,
                                itemBuilder: (context, index) {
                                  return _buildArticleWidget(_articles[index]);
                                },
                              ),
                            ),
                          ),
                          // 「記事を読む」ボタンをリストの最後に配置
                          ElevatedButton(
                            onPressed: fetchArticle,
                            child: const Text("記事を読む"),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 残り時間を MM:ss 形式にフォーマットする
  String _formatTimeMMss(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// 「記事を読む」ボタン押下時に記事データを取得し、リストの末尾に追加する
  Future<void> fetchArticle() async {
    try {
      // 今日の日付を YYYYMMDD 形式に変換
      final now = DateTime.now();
      final key =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      // API URL の変更
      final url = 'http://$kApiHost:$kApiPort/data?key=$key:*';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        // APIは記事データがJSON配列で返る前提
        final List<dynamic> articles = jsonDecode(response.body);
        if (articles.isNotEmpty) {
          // ランダムに1件選ぶ
          final randomIndex = Random().nextInt(articles.length);
          final article = articles[randomIndex];

          // PomodoroModelから現在の残り時間を取得してフォーマット
          final pomodoro =
              Provider.of<PomodoroModel>(context, listen: false);

          // 記事データを取得
          final articleMap = Map<String, dynamic>.from(article);

          setState(() {
            // ここではリストの末尾に追加（表示は reverse:true で最新記事が上部に）
            _articles.add(articleMap);
          });
          // 自動スクロール
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.bounceInOut,
          );
          AudioService().playSummarySound(article['output_fname'], article['topic']);
        } else {
          setState(() {
            _articles.add({"error": "記事が見つかりませんでした"});
          });
        }
      } else {
        setState(() {
          _articles.add({
            "error": "記事の取得に失敗しました (HTTP ${response.statusCode})"
          });
        });
      }
    } catch (e) {
      setState(() {
        _articles.add({"error": "記事の取得中にエラーが発生しました: $e"});
      });
    }
  }


  /// 取得した記事データを表示するウィジェット  
  /// 記事のタイトルはリンクとして表示（url_launcherを利用）
  Widget _buildArticleWidget(Map<String, dynamic> article) {
    final String? title = article['title'];
    final String? url = article['url'];
    // タイマーの時間情報（MM:SS）を取得。なければ空文字列にする
    final String topicInfo = article['topic'] != null ? ' (${article['topic']})' : '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && url != null)
            InkWell(
              onTap: () => _launchURL(url),
              child: Text(
                // タイトルに時間情報を追加して表示
                title + topicInfo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          if (article.containsKey("summary"))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "${article["summary"]}",
                style: const TextStyle(fontSize: 14),
              ),
            ),
          if (article.containsKey("error"))
            Text(
              article["error"],
              style: const TextStyle(fontSize: 14, color: Colors.red),
            ),
        ],
      ),
    );
  }


  /// URLを開くためのヘルパー関数（url_launcherパッケージを利用）
  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }
}


/// -------------------------------
/// SettingsPage：設定画面
/// -------------------------------
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController workController;
  late TextEditingController breakController;
  late TextEditingController cycleController;

  @override
  void initState() {
    super.initState();
    final pomodoro = Provider.of<PomodoroModel>(context, listen: false);
    workController = TextEditingController(text: (pomodoro.workDuration ~/ 60).toString());
    breakController = TextEditingController(text: (pomodoro.breakDuration ~/ 60).toString());
    cycleController = TextEditingController(text: pomodoro.totalCycles.toString());
  }

  @override
  void dispose() {
    workController.dispose();
    breakController.dispose();
    cycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pomodoro = Provider.of<PomodoroModel>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text("設定")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: workController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "作業時間（分）"),
            ),
            TextField(
              controller: breakController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "休憩時間（分）"),
            ),
            TextField(
              controller: cycleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "繰り返し回数"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                int work = int.tryParse(workController.text) ?? 25;
                int breakTime = int.tryParse(breakController.text) ?? 5;
                int cycles = int.tryParse(cycleController.text) ?? 4;
                pomodoro.updateSettings(
                  work: work * 60,
                  breakTime: breakTime * 60,
                  cycles: cycles,
                );
                Navigator.pop(context);
              },
              child: const Text("設定を保存"),
            ),
          ],
        ),
      ),
    );
  }
}
