import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class AdWatchDialog extends StatefulWidget {
  final Map<String, dynamic> ad;
  const AdWatchDialog({Key? key, required this.ad}) : super(key: key);

  @override
  State<AdWatchDialog> createState() => _AdWatchDialogState();
}

class _AdWatchDialogState extends State<AdWatchDialog> {
  late YoutubePlayerController _controller;

  static const int _requiredSeconds = 30;
  int _watchedSeconds = 0;
  bool _rewardReady = false;
  bool _isFullScreen = false;
  Timer? _watchTimer;

  double get _progress =>
      (_watchedSeconds / _requiredSeconds).clamp(0.0, 1.0);
  int get _percentage => (_progress * 100).round().clamp(0, 100);
  int get _remaining =>
      (_requiredSeconds - _watchedSeconds).clamp(0, _requiredSeconds);

  String _extractVideoId(String url) =>
      YoutubePlayer.convertUrlToId(url) ?? '';

  @override
  void initState() {
    super.initState();
    final videoId = _extractVideoId(widget.ad['url'] as String? ?? '');
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: true,
        captionLanguage: 'en',
        forceHD: false,
        useHybridComposition: true,
      ),
    );
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_controller.value.isPlaying && !_rewardReady) {
        setState(() {
          _watchedSeconds =
              (_watchedSeconds + 1).clamp(0, _requiredSeconds);
          if (_watchedSeconds >= _requiredSeconds) {
            _rewardReady = true;
            _watchTimer?.cancel();
          }
        });
      }
    });
  }

  @override
  @override
  void dispose() {
    _watchTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _claimReward() => Navigator.of(context).pop(true);
  void _closeDialog() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final dialogBg = isDark ? const Color(0xFF1A1A1A) : cs.surface;
    final titleColor = cs.onSurface;
    final subtitleColor = cs.onSurface.withOpacity(0.5);
    final rewardBadgeBg = isDark
        ? const Color(0xFF0E3D2E)
        : cs.primary.withOpacity(0.12);
    final teal = cs.primary;
    final progressBg = isDark ? Colors.grey[800]! : Colors.grey[200]!;
    final waitBtnBg = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final waitBtnFg = isDark ? Colors.white : Colors.black87;
    final timerTextColor = cs.onSurface.withOpacity(0.55);

    final int reward = widget.ad['reward'] as int? ??
        widget.ad['credits_reward'] as int? ??
        1;
    final String title = widget.ad['title'] as String? ?? 'Ad';

    return YoutubePlayerBuilder(
      onEnterFullScreen: () {
        setState(() => _isFullScreen = true);
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onExitFullScreen: () {
        setState(() => _isFullScreen = false);
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      player: YoutubePlayer(
        controller: _controller,
        showVideoProgressIndicator: true,
        progressIndicatorColor: Colors.red,
        progressColors: ProgressBarColors(
          playedColor: Colors.red,
          handleColor: Colors.redAccent,
          backgroundColor: cs.onSurface.withOpacity(0.15),
          bufferedColor: cs.onSurface.withOpacity(0.25),
        ),
        onReady: () => _controller.play(),
      ),
      builder: (context, player) {
        if (_isFullScreen) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: player),
          );
        }
        return Dialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          insetPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Watch to earn credits',
                            style: TextStyle(
                                fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: rewardBadgeBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '+$reward',
                        style: TextStyle(
                          color: teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _closeDialog,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close,
                            color: subtitleColor, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ── YouTube Player ──────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: player,
              ),

              // ── Progress & Claim ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_outlined,
                                color: timerTextColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _rewardReady
                                  ? 'Done!'
                                  : 'Watch for ${_remaining}s',
                              style: TextStyle(
                                  color: timerTextColor, fontSize: 13),
                            ),
                          ],
                        ),
                        Text(
                          '$_percentage%',
                          style: TextStyle(
                            color: titleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 6,
                        backgroundColor: progressBg,
                        valueColor:
                        AlwaysStoppedAnimation<Color>(teal),
                      ),
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _rewardReady
                            ? ElevatedButton.icon(
                          key: const ValueKey('claim'),
                          onPressed: _claimReward,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.celebration,
                              size: 18, color: Colors.white),
                          label: const Text(
                            'Claim Reward  🎉',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                            : ElevatedButton.icon(
                          key: const ValueKey('wait'),
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: waitBtnBg,
                            disabledBackgroundColor: waitBtnBg,
                            padding: const EdgeInsets.symmetric(
                                vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10)),
                          ),
                          icon: Icon(
                              Icons.access_time_outlined,
                              size: 18,
                              color: waitBtnFg),
                          label: Text(
                            'Please wait...  $_remaining',
                            style: TextStyle(
                              color: waitBtnFg,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}