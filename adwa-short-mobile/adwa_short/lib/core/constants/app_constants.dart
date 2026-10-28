class AppConstants {
  AppConstants._();

  static const String appName = 'ADWA SHORT';
  static const String appTagline = 'Premium Short Drama';
  static const String appVersion = '1.0.0';

  static const double posterAspectRatio = 2 / 3;
  static const double bannerAspectRatio = 16 / 9;
  static const double posterCardWidth = 130;
  static const double bannerHeight = 220;
  static const double shelfHorizontalPadding = 16;
  static const double shelfItemSpacing = 12;
  static const int shortsPageThreshold = 3;

  static const Duration engagementPingInterval = Duration(seconds: 15);
  static const Duration splashMinDisplay = Duration(seconds: 2);
  static const Duration tokenRefreshLeeway = Duration(seconds: 30);

  static const int defaultPageSize = 20;

}

class AppStrings {
  AppStrings._();

  static const String appName = 'ADWA SHORT';
  static const String tagline = 'Premium Short Drama';

  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String save = 'Save';
  static const String saved = 'Saved';
  static const String saving = 'Saving…';
  static const String loading = 'Loading…';
  static const String seeAll = 'See All';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String close = 'Close';
  static const String done = 'Done';
  static const String error = 'Something went wrong';
  static const String empty = 'Nothing here yet';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String free = 'Free';

  static const String login = 'Log In';
  static const String register = 'Register';
  static const String logout = 'Log Out';
  static const String logoutConfirm = 'Are you sure you want to log out?';
  static const String phone = 'Phone';
  static const String password = 'Password';
  static const String displayName = 'Display Name';
  static const String noAccount = "Don't have an account? ";
  static const String haveAccount = 'Already have an account? ';
  static const String welcomeBack = 'Welcome back';
  static const String createAccount = 'Create your account';
  static const String loginSubtitle = 'Log in to continue streaming';
  static const String registerSubtitle = 'Join ADWA SHORT in seconds';
  static const String phoneHint = 'e.g. 0912345678';
  static const String loginSuccess = 'Logged in successfully';
  static const String registerSuccess = 'Account created successfully';

  static const String errPhoneRequired = 'Phone number is required';
  static const String errPhoneInvalid = 'Enter a valid phone number';
  static const String errPasswordRequired = 'Password is required';
  static const String errPasswordShort = 'Password must be at least 6 characters';
  static const String errDisplayNameRequired = 'Display name is required';

  static const String navHome = 'Home';
  static const String navShorts = 'Shorts';
  static const String navMyList = 'My List';
  static const String navProfile = 'Profile';

  static const String homeSearchHint = 'Search series, actors, tags…';
  static const String homeGreeting = 'Welcome to ADWA SHORT';

  static const String shortsEmpty = 'No shorts available right now';
  static const String watchNow = 'Watch Now';
  static const String episodes = 'Episodes';
  static const String comments = 'Comments';
  static const String likesCount = 'Likes';
  static const String commentHint = 'Add a comment…';

  static const String episodesCount = 'Episodes';
  static const String cast = 'Cast & Crew';
  static const String moreLikeThis = 'More Like This';
  static const String locked = 'Locked';

  static const String unlockEpisode = 'Unlock this Episode';
  static const String unlockSubtitle = 'Choose how you want to continue watching';
  static const String watchAd = 'Watch Ad to Unlock';
  static const String payWithCoins = 'Pay with Coins';
  static const String buyPass = 'Buy a Time Pass';
  static const String subscribe = 'Subscribe';
  static const String adUnlockHint = 'Watch a short ad and continue';
  static const String coinCostHint = 'Deduct from your coin balance';
  static const String passHint = 'Unlimited access for a limited time';
  static const String subscriptionHint = 'Best value for binge-watchers';
  static const String adsWatchedProgress = 'Ad %a of %b';
  static const String unlocked = 'Unlocked';

  static const String watchHistory = 'Watch History';
  static const String savedVideos = 'Saved Videos';
  static const String historyEmpty = 'You have not watched anything yet';
  static const String savedEmpty = 'You have not saved any series yet';

  static const String userId = 'User ID';
  static const String walletBalance = 'Wallet Balance';
  static const String birr = 'ETB';
  static const String coins = 'Coins';
  static const String coinTopUp = 'Coin Top-Up';
  static const String myWallet = 'My Wallet';
  static const String buyTimePass = 'Buy Time Pass';
  static const String subscriptions = 'Subscriptions';
  static const String loyaltyRewards = 'Loyalty Rewards';
  static const String myDevices = 'My Devices';
  static const String settings = 'Settings';

  static const String depositWallet = 'Deposit Wallet';
  static const String depositWalletHint = 'Commercial Bank of Ethiopia (CBE Birr)';
  static const String transactionHistory = 'Transaction History';
  static const String noTransactions = 'No transactions yet';
  static const String buyCoins = 'Buy Coins';
  static const String coinPackages = 'Coin Packages';
  static const String timePasses = 'Time Passes';
  static const String subscriptionPlans = 'Subscription Plans';

  static const String revokeDevice = 'Revoke';
  static const String revokeDeviceConfirm =
      'Revoke access for this device? The user will be logged out immediately.';
  static const String thisDevice = 'This device';
  static const String noDevices = 'No other active devices';

  static const String errDeviceLimitTitle = 'Device limit reached';
  static const String errDeviceLimitBody =
      'This account has reached its device limit. Please log out from another device.';
  static const String errTokenExpired =
      'Your session has expired. Please log in again.';
  static const String errNetwork =
      'Network error. Check your connection and try again.';
  static const String errUnauthorized = 'You need to log in to continue.';

  static const String language = 'Language';
  static const String notifications = 'Notifications';
  static const String videoQuality = 'Video Quality';
  static const String clearCache = 'Clear Cache';
  static const String cacheCleared = 'Cache cleared';
  static const String about = 'About';
  static const String autoPlay = 'Auto-play next episode';
  static const String dataSaver = 'Data Saver';
}
