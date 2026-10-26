import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/api_constants.dart';
import '../network/api_client.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/adwa_button.dart';
import '../../models/loyalty_grant.dart';

class AdService {
  AdService([this._api]);

  final ApiClient? _api;
  AdUnlockRule? _cachedRule;
  bool _sdkInitialized = false;

  /// Ensures Google Mobile Ads SDK is initialized.
  Future<void> ensureSdkInitialized() async {
    if (_sdkInitialized) return;
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _sdkInitialized = true;
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _sdkInitialized = true;
    } catch (e) {
      if (kDebugMode) print('Google Mobile Ads init note: $e');
    }
  }

  /// Resolves the test or production rewarded ad unit ID based on platform and rule.
  String resolveRewardedUnitId(AdUnlockRule rule) {
    if (rule.testMode || rule.rewardedUnitId == null || rule.rewardedUnitId!.isEmpty) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'ca-app-pub-3940256099942544/1712485313';
      }
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    return rule.rewardedUnitId!;
  }

  /// Fetches the active Super Admin ad unlock rule from FastAPI backend.
  Future<AdUnlockRule> getRule({bool forceRefresh = false}) async {
    if (_cachedRule != null && !forceRefresh) {
      return _cachedRule!;
    }
    if (_api == null) {
      _cachedRule = AdUnlockRule(
        adsRequired: 2,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );
      return _cachedRule!;
    }
    try {
      final rule = await _api.get<AdUnlockRule>(
        ApiConstants.adUnlocksRule,
        parser: (json) => json is Map<String, dynamic>
            ? AdUnlockRule.fromJson(json)
            : AdUnlockRule.fromJson({}),
      );
      _cachedRule = rule;
      return rule;
    } catch (e) {
      if (kDebugMode) print('Failed to fetch ad rule: $e');
      _cachedRule = AdUnlockRule(
        adsRequired: 2,
        episodesUnlocked: 1,
        provider: 'admob',
        rewardedUnitId: 'ca-app-pub-3940256099942544/5224354917',
        testMode: true,
      );
      return _cachedRule!;
    }
  }

  /// Triggers the fully automated multi-ad batch unlock flow for an episode.
  /// Entire batch is preloaded upon opening.
  /// Ads transition programmatically without manual close (X) or next interruptions.
  /// Upon final ad conclusion, sends verification to backend and opens video player.
  /// If ads fail to load or are unavailable, never grants free unlock; returns false.
  Future<bool> showRewardedAd(
    BuildContext context, {
    required String episodeId,
    String? episodeTitle,
    VoidCallback? onRewardEarned,
    bool simulateFailure = false,
  }) async {
    await ensureSdkInitialized();
    final rule = await getRule();
    if (!context.mounted) return false;

    // Show the silent, non-interactive batch overlay
    final bool? completed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.black.withValues(alpha: 0.95),
      pageBuilder: (dialogContext, _, __) {
        return RewardedAdBatchDialog(
          rule: rule,
          episodeTitle: episodeTitle ?? 'Episode $episodeId',
          adService: this,
          simulateFailure: simulateFailure,
        );
      },
    );

    if (completed != true) {
      return false;
    }

    // Entire batch concluded! Instantly record unlock and notify player
    try {
      final epIdNum = int.tryParse(episodeId);
      final adsWatched = rule.adsRequired > 0 ? rule.adsRequired : 1;

      if (_api != null) {
        await _api.post(
          ApiConstants.adUnlocksWatched,
          body: {
            'episode_id': epIdNum ?? episodeId,
            'ads_watched': adsWatched,
            'ad_network': rule.provider,
          },
          parser: (j) => j,
        );
      }

      onRewardEarned?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adsWatched > 1
                        ? 'Reward Granted! Episode unlocked after $adsWatched ads.'
                        : 'Reward Granted! Episode unlocked.',
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.bloodRedDark,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (kDebugMode) print('Failed to record ad batch unlock: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify ad completion'),
            backgroundColor: AppColors.bloodRedDark,
          ),
        );
      }
      return false;
    }
  }

  /// Attempts to load a live Google Mobile Ads rewarded video ad.
  /// Returns a Completer with the loaded RewardedAd or null on load failure.
  Future<RewardedAd?> loadLiveRewardedAd(AdUnlockRule rule) async {
    if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    final adUnitId = resolveRewardedUnitId(rule);
    final completer = Completer<RewardedAd?>();

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            if (kDebugMode) print('RewardedAd failed to load: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) print('RewardedAd load exception: $e');
      if (!completer.isCompleted) completer.complete(null);
    }

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }
}

/// Fully automated multi-ad batch queue dialog.
/// Preloads the entire batch of N ads in the background upon opening.
/// Programmatically launches index i + 1 the instant index i completes (onUserEarnedReward).
/// Eliminates manual close/next interruptions between ads.
/// Dismisses overlay and opens video player only when the final ad concludes.
/// Strict: If ads fail to load or are unavailable, displays error and NEVER unlocks for free.
class RewardedAdBatchDialog extends StatefulWidget {
  const RewardedAdBatchDialog({
    super.key,
    required this.rule,
    required this.episodeTitle,
    required this.adService,
    this.simulateFailure = false,
  });

  final AdUnlockRule rule;
  final String episodeTitle;
  final AdService adService;
  final bool simulateFailure;

  @override
  State<RewardedAdBatchDialog> createState() => _RewardedAdBatchDialogState();
}

class _RewardedAdBatchDialogState extends State<RewardedAdBatchDialog> {
  static const int _secondsPerAd = 6;
  late int _totalAdsRequired;
  int _currentAdIndex = 1;
  int _completedAds = 0;
  int _secondsRemaining = _secondsPerAd;
  Timer? _countdownTimer;
  bool _isShowingLiveAd = false;
  bool _isWaitingForAd = false;
  bool _liveAdIncomplete = false;
  bool _isBatchFinished = false;
  String? _adLoadError;
  int _pendingLoads = 0;

  // Preloaded queue of live RewardedAds for continuous, automated playback
  final List<RewardedAd> _preloadedAds = [];

  bool get _isMobile {
    if (kIsWeb) return false;
    final bool isTestEnv = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTestEnv) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    _totalAdsRequired = widget.rule.adsRequired > 0 ? widget.rule.adsRequired : 1;
    if (widget.simulateFailure) {
      _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
    } else if (_isMobile) {
      _initMobileBatch();
    } else if (Platform.environment.containsKey('FLUTTER_TEST')) {
      _startTestCountdown();
    } else {
      _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
    }
  }

  void _initMobileBatch() {
    setState(() {
      _liveAdIncomplete = false;
      _adLoadError = null;
      _isWaitingForAd = true;
      _pendingLoads = _totalAdsRequired;
    });

    // 1. Silent Automated Preloading: Preload the entire batch of N ads concurrently
    _preloadEntireBatch();
  }

  void _preloadEntireBatch() {
    if (widget.simulateFailure) {
      _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
      return;
    }
    for (int i = 0; i < _totalAdsRequired; i++) {
      widget.adService.loadLiveRewardedAd(widget.rule).then((ad) {
        if (!mounted || _isBatchFinished) {
          ad?.dispose();
          return;
        }
        _pendingLoads--;
        if (ad != null) {
          _preloadedAds.add(ad);
          // If we are waiting for an ad to present, trigger it immediately
          if (_isWaitingForAd && !_isShowingLiveAd && !_isBatchFinished) {
            _presentNextAdInQueue();
          }
        } else {
          // If live ad failed to load and nothing queued or in-flight, fail strictly
          if (_preloadedAds.isEmpty &&
              _pendingLoads == 0 &&
              !_isShowingLiveAd &&
              !_isBatchFinished) {
            _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
          }
        }
      }).catchError((e) {
        if (!mounted || _isBatchFinished) return;
        _pendingLoads--;
        if (kDebugMode) print('Preload error for ad: $e');
        if (_preloadedAds.isEmpty &&
            _pendingLoads == 0 &&
            !_isShowingLiveAd &&
            !_isBatchFinished) {
          _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
        }
      });
    }
  }

  void _onAdLoadFailed(String message) {
    if (!mounted || _isBatchFinished) return;
    _disposePreloadedAds();
    _countdownTimer?.cancel();
    setState(() {
      _isWaitingForAd = false;
      _isShowingLiveAd = false;
      _liveAdIncomplete = false;
      _adLoadError = message;
    });
  }

  Future<void> _presentNextAdInQueue() async {
    if (!mounted || _isBatchFinished) return;

    if (_preloadedAds.isEmpty) {
      if (_pendingLoads == 0) {
        _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
        return;
      }
      setState(() {
        _isWaitingForAd = true;
        _isShowingLiveAd = false;
      });
      return;
    }

    final int adIndex = _completedAds + 1;
    final liveAd = _preloadedAds.removeAt(0);

    setState(() {
      _isShowingLiveAd = true;
      _isWaitingForAd = false;
      _liveAdIncomplete = false;
      _currentAdIndex = adIndex;
    });

    bool adAdvanced = false;
    bool userEarnedReward = false;

    // Helper to advance the queue the instant an ad finishes playing
    void advanceQueue({required bool fromReward}) {
      if (adAdvanced || _isBatchFinished) return;
      adAdvanced = true;
      _completedAds++;

      if (_completedAds >= _totalAdsRequired) {
        // Final ad in the batch (e.g., Ad 3 of 3) concludes!
        // Dismiss ad overlay entirely, send verification request, and automatically open video player
        _isBatchFinished = true;
        _disposePreloadedAds();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        // Intermediate ad (index i < N):
        // Programmatically invoke .show() on index i + 1 immediately without user interaction!
        _isShowingLiveAd = false;
        _presentNextAdInQueue();
      }
    }

    liveAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) {
          print('Rewarded ad presented: Ad $adIndex of $_totalAdsRequired');
        }
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (userEarnedReward) {
          advanceQueue(fromReward: true);
        } else if (!_isBatchFinished) {
          // Closed early before reward callback: do not grant completion!
          setState(() {
            _liveAdIncomplete = true;
            _isShowingLiveAd = false;
          });
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _isShowingLiveAd = false;
        if (kDebugMode) print('Failed to show rewarded ad $adIndex: $error');
        if (_preloadedAds.isNotEmpty) {
          _presentNextAdInQueue();
        } else if (_pendingLoads > 0) {
          setState(() {
            _isWaitingForAd = true;
          });
        } else {
          // Strictly fail without countdown bypass!
          _onAdLoadFailed('Ad unavailable. Please check your connection or try again later');
        }
      },
    );

    await liveAd.show(onUserEarnedReward: (ad, reward) {
      userEarnedReward = true;
      advanceQueue(fromReward: true);
    });
  }

  void _startTestCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _liveAdIncomplete = false;
      _secondsRemaining = _secondsPerAd;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _onTestAdFinished();
      }
    });
  }

  void _onTestAdFinished() {
    _completedAds++;

    if (_completedAds >= _totalAdsRequired) {
      // Entire batch concluded! Automatically pop and return to player
      _isBatchFinished = true;
      _disposePreloadedAds();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Automatically advance to index i + 1 programmatically
      _currentAdIndex = _completedAds + 1;
      _secondsRemaining = _secondsPerAd;
      setState(() {});
      _startTestCountdown();
    }
  }

  void _retryBatch() {
    setState(() {
      _adLoadError = null;
      _completedAds = 0;
      _currentAdIndex = 1;
    });
    if (_isMobile) {
      _initMobileBatch();
    } else if (Platform.environment.containsKey('FLUTTER_TEST') && !widget.simulateFailure) {
      _startTestCountdown();
    } else {
      _initMobileBatch();
    }
  }

  void _disposePreloadedAds() {
    for (final ad in _preloadedAds) {
      try {
        ad.dispose();
      } catch (_) {}
    }
    _preloadedAds.clear();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _disposePreloadedAds();
    super.dispose();
  }

  void _confirmCancelBatch() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Text('Cancel Ad Unlock?', style: AppTextStyles.h3),
        content: Text(
          'Unlocking this episode requires watching all $_totalAdsRequired ads in this continuous session.\n\n'
          'Watched so far: $_completedAds of $_totalAdsRequired.',
          style: AppTextStyles.body2.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Continue Watching', style: TextStyle(color: AppColors.bloodRed, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              Navigator.of(context).pop(false);
            },
            child: const Text('Exit (Remain Locked)', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_adLoadError != null) {
            Navigator.of(context).pop(false);
          } else {
            _confirmCancelBatch();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Silent Deep Black Background
              const Positioned.fill(
                child: ColoredBox(color: AppColors.black),
              ),

              // Center: Error state, Incomplete state, or Minimal buffer
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _adLoadError != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.bloodRed.withValues(alpha: 0.15),
                                border: Border.all(color: AppColors.bloodRed, width: 2),
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.bloodRed,
                                size: 38,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Ad Unavailable',
                              style: AppTextStyles.h2,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _adLoadError!,
                              style: AppTextStyles.body2.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            AdwaButton(
                              label: 'Try Again',
                              icon: Icons.refresh_rounded,
                              size: AdwaButtonSize.sm,
                              onPressed: _retryBatch,
                            ),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _liveAdIncomplete
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.bloodRed.withValues(alpha: 0.15),
                                    border: Border.all(color: AppColors.bloodRed, width: 2),
                                  ),
                                  child: const Icon(Icons.replay_rounded, color: AppColors.white, size: 32),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Ad Incomplete',
                                  style: AppTextStyles.h2,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please watch the full ad to unlock playback.',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                AdwaButton(
                                  label: 'Resume Ad',
                                  icon: Icons.play_arrow_rounded,
                                  size: AdwaButtonSize.sm,
                                  onPressed: _retryBatch,
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Minimal silent Blood Red buffer indicator
                                const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: CircularProgressIndicator(
                                    color: AppColors.bloodRed,
                                    strokeWidth: 2.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _totalAdsRequired > 1
                                      ? 'Loading ad $_currentAdIndex of $_totalAdsRequired...'
                                      : 'Loading ad...',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                ),
              ),

              // Subtle Exit Button at top right
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 24),
                  onPressed: () {
                    if (_adLoadError != null) {
                      Navigator.of(context).pop(false);
                    } else {
                      _confirmCancelBatch();
                    }
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
