import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:io' show Platform;

class AdsHelper {
  // Interstitial Ad Unit ID - Your production ad unit ID
  static const String interstitialAdUnitId =
      'ca-app-pub-5301423854650604/7937860729';

  static InterstitialAd? _interstitialAd;
  static bool _isInterstitialAdLoaded = false;
  static bool _adsDisabled = false;

  // Load interstitial ad (non-blocking)
  static Future<void> loadInterstitialAd() async {
    if (_adsDisabled) {
      print('Ads are disabled for this environment.');
      return;
    }

    print('Loading interstitial ad...');

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoaded = true;
            print('InterstitialAd successfully loaded');
          },
          onAdFailedToLoad: (LoadAdError error) {
            _isInterstitialAdLoaded = false;
            print('InterstitialAd failed to load: ${error.message}');
            print('Error code: ${error.code}');

            // Disable ads if JavascriptEngine error occurs
            if (error.message.contains('JavascriptEngine')) {
              _adsDisabled = true;
              print(
                'JavascriptEngine not available. Disabling ads for this session.',
              );
            }
          },
        ),
      );
    } catch (e) {
      print('Exception while loading ad: $e');
      _isInterstitialAdLoaded = false;

      // Disable ads if there's an exception
      if (e.toString().contains('JavascriptEngine')) {
        _adsDisabled = true;
        print('JavascriptEngine error detected. Disabling ads.');
      }
    }
  }

  // Show interstitial ad (non-blocking, always returns immediately)
  static Future<void> showInterstitialAd() async {
    try {
      if (_adsDisabled) {
        print('Ads disabled - skipping ad display');
        return;
      }

      if (_isInterstitialAdLoaded && _interstitialAd != null) {
        print('Showing interstitial ad...');

        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            print('Ad dismissed');
            ad.dispose();
            _interstitialAd = null;
            _isInterstitialAdLoaded = false;
            // Preload next ad
            Future.delayed(const Duration(seconds: 1), () {
              loadInterstitialAd();
            });
          },
          onAdFailedToShowFullScreenContent:
              (InterstitialAd ad, AdError error) {
                print('Ad failed to show: ${error.message}');
                ad.dispose();
                _interstitialAd = null;
                _isInterstitialAdLoaded = false;
              },
          onAdShowedFullScreenContent: (InterstitialAd ad) {
            print('Ad showed full screen content');
          },
        );

        // Show ad with timeout
        await _interstitialAd!.show().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Ad show timeout');
            _interstitialAd?.dispose();
            _interstitialAd = null;
            _isInterstitialAdLoaded = false;
          },
        );
      } else {
        print('Ad not ready - skipping display');
      }
    } catch (e) {
      print('Exception while showing ad: $e');
      // Silence the error and continue
    }
  }

  // Dispose resources
  static void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
  }
}
