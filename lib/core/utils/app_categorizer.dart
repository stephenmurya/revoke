enum AppCategory {
  social('Social'),
  games('Games'),
  entertainment('Entertainment'),
  education('Education'),
  health('Health'),
  productivity('Productivity'),
  news('News'),
  shopping('Shopping'),
  travel('Travel'),
  utilities('Utilities'),
  finance('Finance'),
  communication('Communication'),
  business('Business'),
  books('Books'),
  food('Food'),
  others('Others');

  final String label;
  const AppCategory(this.label);
}


class AppCategorizer {
  // ================================
  // 1. Exact Package Overrides
  // Highest priority
  // ================================

  static const Map<String, AppCategory> _packageOverrides = {
    // Social
    'com.instagram.android': AppCategory.social,
    'com.facebook.katana': AppCategory.social,
    'com.facebook.lite': AppCategory.social,
    'com.zhiliaoapp.musically': AppCategory.social,
    'com.snapchat.android': AppCategory.social,
    'com.twitter.android': AppCategory.social,
    'com.linkedin.android': AppCategory.social,
    'com.reddit.frontpage': AppCategory.social,
    'com.whatsapp': AppCategory.social,
    'com.whatsapp.w4b': AppCategory.productivity,

    // Entertainment
    'com.google.android.youtube': AppCategory.entertainment,
    'com.netflix.mediaclient': AppCategory.entertainment,
    'com.disney.disneyplus': AppCategory.entertainment,
    'com.hulu.plus': AppCategory.entertainment,
    'com.amazon.avod.thirdpartyclient': AppCategory.entertainment,
    'tv.twitch.android.app': AppCategory.entertainment,
    'com.spotify.music': AppCategory.entertainment,

    // Browsers / Utilities
    'com.android.chrome': AppCategory.utilities,
    'org.mozilla.firefox': AppCategory.utilities,
    'com.microsoft.emmx': AppCategory.utilities,
    'com.brave.browser': AppCategory.utilities,
    'com.opera.browser': AppCategory.utilities,

    // Shopping
    'com.amazon.mShop.android.shopping': AppCategory.shopping,
    'com.ebay.mobile': AppCategory.shopping,
    'com.contextlogic.wish': AppCategory.shopping,

    // Travel
    'com.ubercab': AppCategory.travel,
    'com.lyft.android': AppCategory.travel,
    'com.airbnb.android': AppCategory.travel,

    // Finance
'com.paypal.android.p2pmobile': AppCategory.finance,
'com.squareup.cash': AppCategory.finance,
'com.revolut.revolut': AppCategory.finance,
'com.robinhood.android': AppCategory.finance,
'com.coinbase.android': AppCategory.finance,

// Communication (separate from social)
'com.google.android.gm': AppCategory.communication,
'com.microsoft.office.outlook': AppCategory.communication,
'com.discord': AppCategory.communication,
'com.skype.raider': AppCategory.communication,
'com.slack': AppCategory.communication,

// Business
'com.microsoft.office.word': AppCategory.business,
'com.microsoft.office.excel': AppCategory.business,
'com.microsoft.office.powerpoint': AppCategory.business,
'com.google.android.apps.docs': AppCategory.business,
'com.google.android.apps.sheets': AppCategory.business,
'com.google.android.apps.slides': AppCategory.business,

// Books
'com.amazon.kindle': AppCategory.books,
'com.google.android.apps.books': AppCategory.books,
'org.readera': AppCategory.books,
'com.wattpad': AppCategory.books,

// Food
'com.ubercab.eats': AppCategory.food,
'com.dd.doordash': AppCategory.food,
'com.grubhub.android': AppCategory.food,
'com.yelp.android': AppCategory.food,

  };

  // ================================
  // 2. Keyword Heuristic Fallback
  // Only used if native category fails
  // ================================

  static const Map<AppCategory, List<String>> _keywords = {
  AppCategory.social: [
    'social',
    'community',
    'forum',
    'timeline',
    'feed',
    'stories',
    'status',
    'followers',
    'friends',
    'profile',
    'like',
    'share',
    'reels',
    'live',
  ],

  AppCategory.communication: [
    'chat',
    'messenger',
    'message',
    'mail',
    'email',
    'inbox',
    'voip',
    'call',
    'dialer',
    'sms',
    'mms',
    'videochat',
    'conference',
    'meet',
    'zoom',
  ],

  AppCategory.games: [
    'game',
    'gaming',
    'puzzle',
    'arcade',
    'battle',
    'clash',
    'shooter',
    'rpg',
    'fps',
    'strategy',
    'simulator',
    'adventure',
    'casino',
    'slots',
    'chess',
    'sudoku',
  ],

  AppCategory.entertainment: [
    'video',
    'stream',
    'media',
    'player',
    'tv',
    'movie',
    'series',
    'show',
    'drama',
    'anime',
    'music',
    'podcast',
    'radio',
    'entertainment',
    'theatre',
  ],

  AppCategory.education: [
    'learn',
    'edu',
    'course',
    'academy',
    'school',
    'university',
    'college',
    'class',
    'lesson',
    'tutorial',
    'quiz',
    'exam',
    'study',
    'flashcard',
    'vocab',
    'brain',
    'math',
    'coding',
    'language',
  ],

  AppCategory.health: [
    'health',
    'fitness',
    'workout',
    'wellness',
    'med',
    'medical',
    'doctor',
    'clinic',
    'hospital',
    'therapy',
    'mental',
    'fasting',
    'diet',
    'calorie',
    'exercise',
    'yoga',
    'run',
    'step',
    'sleep',
    'tracker',
  ],

  AppCategory.productivity: [
    'task',
    'todo',
    'planner',
    'reminder',
    'calendar',
    'schedule',
    'notes',
    'memo',
    'organizer',
    'focus',
    'timer',
    'pomodoro',
    'habit',
    'checklist',
  ],

  AppCategory.business: [
    'business',
    'enterprise',
    'workspace',
    'crm',
    'erp',
    'invoice',
    'billing',
    'payroll',
    'inventory',
    'logistics',
    'warehouse',
    'sales',
    'analytics',
    'dashboard',
    'reporting',
  ],

  AppCategory.finance: [
    'bank',
    'finance',
    'wallet',
    'crypto',
    'coin',
    'blockchain',
    'invest',
    'trading',
    'loan',
    'pay',
    'microfinance',
    'savings',
    'budget',
    'money',
    'expense',
    'tax',
    'stock',
    'forex',
    'fund',
  ],

  AppCategory.news: [
    'news',
    'journal',
    'times',
    'post',
    'press',
    'headline',
    'magazine',
    'media',
    'breaking',
    'report',
    'politics',
  ],

  AppCategory.shopping: [
    'shop',
    'store',
    'mall',
    'buy',
    'cart',
    'checkout',
    'retail',
    'market',
    'deal',
    'coupon',
    'discount',
    'ecommerce',
    'order',
  ],

  AppCategory.travel: [
    'travel',
    'trip',
    'flight',
    'hotel',
    'booking',
    'map',
    'navigation',
    'route',
    'taxi',
    'ride',
    'transport',
    'bus',
    'train',
    'airline',
  ],

  AppCategory.food: [
    'food',
    'restaurant',
    'delivery',
    'menu',
    'dining',
    'eat',
    'cafe',
    'kitchen',
    'recipe',
    'cook',
    'bakery',
    'grocery',
    'chef',
  ],

  AppCategory.books: [
    'book',
    'reader',
    'ebook',
    'novel',
    'kindle',
    'audiobook',
    'library',
    'literature',
    'story',
    'poetry',
  ],

  AppCategory.utilities: [
    'tool',
    'utility',
    'browser',
    'file',
    'cleaner',
    'recorder',
    'scanner',
    'webcam',
    'widget',
    'manager',
    'calculator',
    'converter',
    'flashlight',
    'vpn',
    'compress',
    'extract',
  ],
};


  // ================================
  // Public API (unchanged)
  // ================================

  static AppCategory categorize(String packageName, int nativeCategory) {
    final pkg = packageName.toLowerCase();

    // 1. Exact package override
    final override = _packageOverrides[pkg];
    if (override != null) {
      return override;
    }

    // 2. Native category mapping
    final nativeMapped = _mapNativeCategory(nativeCategory);
    if (nativeMapped != AppCategory.others) {
      return nativeMapped;
    }

    // 3. Keyword heuristic fallback
    final keywordMatch = _matchKeywords(pkg);
    if (keywordMatch != null) {
      return keywordMatch;
    }

    return AppCategory.others;
  }

  // ================================
  // Native Category Mapping
  // ================================

  static AppCategory _mapNativeCategory(int nativeCategory) {
    switch (nativeCategory) {
      case 0: // CATEGORY_GAME
        return AppCategory.games;

      case 1: // CATEGORY_AUDIO
      case 2: // CATEGORY_VIDEO
      case 3: // CATEGORY_IMAGE
        return AppCategory.entertainment;

      case 4: // CATEGORY_SOCIAL
        return AppCategory.social;

      case 5: // CATEGORY_NEWS
        return AppCategory.news;

      case 6: // CATEGORY_MAPS
        return AppCategory.travel;

      case 7: // CATEGORY_PRODUCTIVITY
        return AppCategory.productivity;

      case 8: // CATEGORY_ACCESSIBILITY
        return AppCategory.utilities;

      case 9: // CATEGORY_FINANCE
        return AppCategory.finance;

      case 10: // CATEGORY_COMMUNICATION
        return AppCategory.communication;

      default:
        return AppCategory.others;
    }
  }

  // ================================
  // Keyword Matching
  // ================================

  static AppCategory? _matchKeywords(String packageName) {
    for (final entry in _keywords.entries) {
      final category = entry.key;
      final words = entry.value;

      for (final word in words) {
        if (packageName.contains(word)) {
          return category;
        }
      }
    }
    return null;
  }
}
