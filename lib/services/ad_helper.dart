import 'dart:io';

class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'Banner_Android';
    } else if (Platform.isIOS) {
      return 'Banner_iOS';
    } else {
      return 'unsupported'; // Web not supported
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'Interstitial_Android';
    } else if (Platform.isIOS) {
      return 'Interstitial_iOS';
    } else {
      return 'unsupported'; // Web not supported
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'Rewarded_Android';
    } else if (Platform.isIOS) {
      return 'Rewarded_iOS';
    } else {
      return 'unsupported'; // Web not supported
    }
  }

  static String get gameId {
    if (Platform.isAndroid) {
      return '5867680';
    } else if (Platform.isIOS) {
      return '5867681';
    } else {
      return 'unsupported'; // Web not supported
    }
  }
}