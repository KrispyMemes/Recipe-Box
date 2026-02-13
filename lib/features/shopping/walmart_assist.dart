class WalmartAssist {
  static const String _searchBaseUrl = 'https://www.walmart.com/search?q=';
  static const String walmartHomeUrl = 'https://www.walmart.com/';

  static String buildSearchUrl(String shoppingItemName) {
    final String query = normalizeQuery(shoppingItemName);
    return '$_searchBaseUrl${Uri.encodeQueryComponent(query)}';
  }

  static String normalizeQuery(String rawName) {
    String value = rawName.trim();
    if (value.isEmpty) {
      return '';
    }

    value = value.replaceAll(RegExp(r'^[\-\*\u2022\s]+'), '');
    value = value.replaceFirst(RegExp(r'[\(\[\{].*$'), '');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();

    return value.isEmpty ? rawName.trim() : value;
  }
}
