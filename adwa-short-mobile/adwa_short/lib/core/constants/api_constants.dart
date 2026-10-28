class ApiConstants {
  ApiConstants._();

  static const String envApiKey = 'API_BASE_URL';
  static const String envAppEnv = 'APP_ENV';
  static const String envDefaultLocale = 'DEFAULT_LOCALE';
  static const String envHttpConnectTimeout = 'HTTP_CONNECT_TIMEOUT';
  static const String envHttpReadTimeout = 'HTTP_READ_TIMEOUT';
  static const String envHttpLogEnabled = 'HTTP_LOG_ENABLED';

  static const String fallbackBaseUrl = 'http://10.0.2.2:8000';

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String usersMe = '/users/me';

  static const String shelvesHome = '/shelves/home';
  static const String categories = '/categories';

  static String shortsFeed({String? cursor}) =>
      cursor == null ? '/shorts/feed' : '/shorts/feed?cursor=$cursor';

  static String seriesDetail(String id) => '/series/$id';
  static const String seriesList = '/series';
  static const String engagementView = '/engagement/view';
  static const String engagementLike = '/engagement/like';
  static const String engagementSave = '/engagement/save';
  static const String engagementComment = '/engagement/comment';
  static const String engagementHistory = '/engagement/history';
  static const String engagementSaved = '/engagement/saved';

  static String search(String q) => '/search?q=${Uri.encodeQueryComponent(q)}';

  static const String wallet = '/wallet';
  static const String walletDeposit = '/wallet/deposit';
  static const String coinsPackages = '/coins/packages';
  static const String coinsPurchase = '/coins/purchase';
  static const String passes = '/passes';
  static const String passesPurchase = '/passes/purchase';
  static const String activePass = '/passes/active';
  static const String subscriptionsPlans = '/subscriptions/plans';
  static const String subscriptionsSubscribe = '/subscriptions/subscribe';
  static const String activeSubscription = '/subscriptions/active';
  static const String subscriptionsUnsubscribe = '/subscriptions/unsubscribe';
  static const String userAccessDashboard = '/subscriptions/user-access';
  static const String adUnlocksRule = '/ad-unlocks/rule';
  static const String adUnlocksWatched = '/ad-unlocks/watched';
  static const String adsS2sCallback = '/api/v1/ads/callback';
  static String episodeAccessCheck(String id) => '/episodes/$id/access';

  // Commercial Bank of Ethiopia (CBE / CBE Birr) Automated Payments
  static const String cbeInitiate = '/api/v1/payments/cbe/initiate';
  static String cbeOrderStatus(String orderId) => '/api/v1/payments/cbe/order/$orderId';
  static String cbeSimulatePayment(String orderId) => '/api/v1/payments/cbe/simulate-payment/$orderId';

  static const String downloadTokens = '/downloads/tokens';
  static const String downloadFile = '/downloads/file';

  static const String loyaltyMyGrants = '/loyalty/my-grants';
  static const String loyaltyConfig = '/loyalty/config';
  static const String loyaltyStatus = '/loyalty/status';
  static const String loyaltyClaim = '/loyalty/claim';
  static const String loyaltyAdBonus = '/loyalty/ad-bonus';
  static const String devices = '/devices';
  static String deviceById(String id) => '/devices/$id';

  static const String ratings = '/ratings';
  static const String episodeRating = '/ratings/episode';
  static String episodeRatingById(String id) => '/ratings/episode/$id';
  static String ratingById(String id) => '/ratings/$id';
  static const String myRatings = '/ratings/my';
  static const String reviews = '/reviews';
  static const String episodeReviews = '/reviews/episode';
  static String episodeReviewsById(String id) => '/reviews/episode/$id';
  static String reviewById(String id) => '/reviews/$id';
  static const String adminReviews = '/admin/reviews';
  static const String appSettings = '/settings';
  static const String publicSettings = '/settings/public';

  static const String storageAccessToken = 'adwa_access_token';
  static const String storageRefreshToken = 'adwa_refresh_token';
  static const String storageDeviceId = 'adwa_device_id';
  static const String storageUserId = 'adwa_user_id';
  static const String storageUserPhone = 'adwa_user_phone';
  static const String storageDisplayName = 'adwa_display_name';

  static const String headerAuthorization = 'Authorization';
  static const String headerDeviceId = 'X-Device-Id';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';
  static const String contentTypeJson = 'application/json; charset=utf-8';

  static const String errorCodeMaxDeviceLimit = 'MAX_DEVICE_LIMIT_REACHED';
  static const String errorCodeTokenExpired = 'TOKEN_EXPIRED';
  static const String errorCodeInvalidCredentials = 'INVALID_CREDENTIALS';
}
