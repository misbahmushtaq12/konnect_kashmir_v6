import 'package:flutter/material.dart';
import '../widgets/app_snack.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'ad_watch_dialog.dart';

/// Shows the credit balance and lets the user earn credits by watching ads.
class AdCreditsScreen extends StatefulWidget {
  const AdCreditsScreen({super.key});

  @override
  State<AdCreditsScreen> createState() => _AdCreditsScreenState();
}

class _AdCreditsScreenState extends State<AdCreditsScreen> {
  List<Map<String, dynamic>> _ads = [];
  Map<String, int> _counts = {};
  int? _credits;
  bool _loading = true;
  String? _claimingId;

  ApiService get _api {
    final auth = context.read<AuthProvider>();
    return ApiService(token: auth.accessToken, userId: auth.userId);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, dynamic>> ads = [];
    Map<String, int> counts = {};
    int? credits;
    try {
      final r = await Future.wait([
        _api.getAvailableAds(),
        _api.getUserAdViewCounts(),
        _api.getUserCredits(),
      ]);
      ads = r[0] as List<Map<String, dynamic>>;
      counts = r[1] as Map<String, int>;
      credits = r[2] as int?;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _ads = ads;
      _counts = counts;
      _credits = credits;
      _loading = false;
    });
  }

  int _reward(Map<String, dynamic> ad) =>
      (ad['credits_reward'] as num?)?.toInt() ?? 1;
  int _max(Map<String, dynamic> ad) =>
      (ad['max_views_per_user'] as num?)?.toInt() ?? 1;

  Future<void> _watch(Map<String, dynamic> ad) async {
    final id = ad['id'].toString();
    final claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdWatchDialog(ad: ad),
    );
    if (claimed != true || !mounted) return;

    setState(() => _claimingId = id);
    final result = await _api.claimAdCredits(id);
    if (!mounted) return;
    setState(() => _claimingId = null);

    if (result['success'] == false) {
      showAppSnack(context, (result['error'] ?? "Couldn't add credits. Try again.")
            .toString(), type: SnackType.error);
      return;
    }

    final reward = _reward(ad);
    setState(() {
      _counts[id] = (_counts[id] ?? 0) + 1;
      _credits = (result['newBalance'] as num?)?.toInt() ??
          ((_credits ?? 0) + reward);
    });
    showAppSnack(context, '+$reward credit${reward > 1 ? 's' : ''} added!', type: SnackType.success);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ad credits')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: Row(children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your balance',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: AppText.secondary)),
                        const SizedBox(height: 2),
                        Text(
                          _credits == null ? '—' : '$_credits credits',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800),
                        ),
                      ]),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Text('1 credit unlocks 1 provider contact.',
                style: TextStyle(
                    fontSize: AppText.caption,
                    color: cs.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 22),
            const Text('Watch & earn',
                style: TextStyle(fontSize: AppText.heading, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_loading)
              for (var i = 0; i < 2; i++) ...[
                const Skeleton(height: 84, radius: AppRadius.lg),
                const SizedBox(height: 10),
              ]
            else if (_ads.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(children: [
                  Icon(Icons.ondemand_video_outlined,
                      size: 48, color: cs.onSurface.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  const Text('No ads available right now',
                      style:
                          TextStyle(fontSize: AppText.body, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Check back later for new ways to earn credits.',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6))),
                ]),
              )
            else
              for (final ad in _ads) _adCard(ad),
          ],
        ),
      ),
    );
  }

  Widget _adCard(Map<String, dynamic> ad) {
    final cs = Theme.of(context).colorScheme;
    final id = ad['id'].toString();
    final watched = _counts[id] ?? 0;
    final max = _max(ad);
    final done = watched >= max;
    final reward = _reward(ad);
    final busy = _claimingId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: AppColors.primary, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((ad['title'] ?? 'Sponsored video').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: AppText.body)),
              const SizedBox(height: 3),
              Text('+$reward credit${reward > 1 ? 's' : ''} · $watched/$max watched',
                  style: TextStyle(
                      fontSize: AppText.caption,
                      color: cs.onSurface.withValues(alpha: 0.6))),
            ]),
          ),
          const SizedBox(width: 8),
          done
              ? const Icon(Icons.check_circle_rounded,
                  color: AppColors.success, size: 28)
              : busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4))
                  : ElevatedButton(
                      onPressed: () => _watch(ad),
                      style: AppButtons.compact(AppButtons.primary),
                      child: const Text('Watch'),
                    ),
        ]),
      ),
    );
  }
}
