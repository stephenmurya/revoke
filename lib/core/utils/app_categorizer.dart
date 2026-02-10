enum AppCategory {
  social('SOCIAL'),
  games('GAMES'),
  entertainment('ENTERTAINMENT'),
  education('EDUCATION'),
  health('HEALTH'),
  productivity('PRODUCTIVITY'),
  news('NEWS'),
  shopping('SHOPPING'),
  travel('TRAVEL'),
  utilities('UTILITIES'),
  others('OTHERS');

  final String label;
  const AppCategory(this.label);
}

class AppCategorizer {
  static AppCategory categorize(String packageName, int nativeCategory) {
    packageName = packageName.toLowerCase();

    // Priority 1: Hardcoded popular apps
    if (packageName.contains('instagram') ||
        packageName.contains('facebook') ||
        packageName.contains('tiktok') ||
        packageName.contains('twitter') ||
        packageName.contains('snapchat') ||
        packageName.contains('linkedin') ||
        packageName.contains('reddit')) {
      return AppCategory.social;
    }

    if (packageName.contains('youtube') ||
        packageName.contains('netflix') ||
        packageName.contains('disneyplus') ||
        packageName.contains('hulu') ||
        packageName.contains('primevideo') ||
        packageName.contains('twitch')) {
      return AppCategory.entertainment;
    }

    if (packageName.contains('chrome') ||
        packageName.contains('browser') ||
        packageName.contains('safari')) {
      return AppCategory.utilities;
    }

    // Priority 2: Native API categories
    // Constants from ApplicationInfo:
    // CATEGORY_GAME = 0
    // CATEGORY_AUDIO = 1
    // CATEGORY_VIDEO = 2
    // CATEGORY_IMAGE = 3
    // CATEGORY_SOCIAL = 4
    // CATEGORY_NEWS = 5
    // CATEGORY_MAPS = 6
    // CATEGORY_PRODUCTIVITY = 7
    // CATEGORY_ACCESSIBILITY = 8

    switch (nativeCategory) {
      case 0:
        return AppCategory.games;
      case 1:
      case 2:
      case 3:
        return AppCategory.entertainment;
      case 4:
        return AppCategory.social;
      case 5:
        return AppCategory.news;
      case 6:
        return AppCategory.travel;
      case 7:
        return AppCategory.productivity;
      default:
        return AppCategory.others;
    }
  }
}
