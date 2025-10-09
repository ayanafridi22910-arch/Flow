import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

class AppOpenAdManager {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  final String _adUnitId;

  AppOpenAdManager(this._adUnitId);

  /// Load an AppOpenAd.
  void loadAd() {
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('AppOpenAd failed to load: $error');
          }
        },
      ),
      
    );
  }

  /// Shows the ad if one exists and is ready to be shown.
  ///
  /// An ad can only be shown once. After an ad is shown, you must load a new one.
  void showAdIfAvailable() {
    if (_appOpenAd == null) {
      if (kDebugMode) {
        print('Tried to show ad before it was loaded.');
      }
      loadAd();
      return;
    }
    if (_isShowingAd) {
      if (kDebugMode) {
        print('Tried to show ad while already showing an ad.');
      }
      return;
    }

    // Set the full screen content callback.
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        if (kDebugMode) {
          print('$ad onAdShowedFullScreenContent');
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        if (kDebugMode) {
          print('$ad onAdFailedToShowFullScreenContent: $error');
        }
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        if (kDebugMode) {
          print('$ad onAdDismissedFullScreenContent');
        }
        ad.dispose();
        _appOpenAd = null;
        loadAd();
      },
    );
    _appOpenAd!.show();
  }
}
