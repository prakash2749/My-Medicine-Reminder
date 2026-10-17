import 'dart:convert';

typedef PolicyTranslation = Map<String, String>;

PolicyTranslation _translation(dynamic value) {
  final result = Map<String, String>.from(value as Map);
  if (['en', 'hi']
      .any((language) => result[language]?.trim().isNotEmpty != true)) {
    throw const FormatException('Policy translation is incomplete.');
  }
  return Map.unmodifiable(result);
}

class PolicySection {
  final String id;
  final PolicyTranslation title, body;
  PolicySection._(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = _translation(json['title']),
        body = _translation(json['body']);
}

class PolicyPage {
  final PolicyTranslation title;
  final List<PolicySection> sections;
  PolicyPage._(Map<String, dynamic> json)
      : title = _translation(json['title']),
        sections = List.unmodifiable((json['sections'] as List).map(
            (section) => PolicySection._(Map<String, dynamic>.from(section))));
}

class PolicyContent {
  static const assetPath = 'assets/policies.json';
  final String revision;
  final Map<String, PolicyPage> pages;
  PolicyContent._(this.revision, this.pages);

  factory PolicyContent.decode(String text) {
    final json = jsonDecode(text) as Map<String, dynamic>;
    if (json['schema'] != 1) {
      throw const FormatException('Unsupported policy schema.');
    }
    final pages = (json['pages'] as Map<String, dynamic>).map((key, value) =>
        MapEntry(key, PolicyPage._(Map<String, dynamic>.from(value))));
    if (pages.length != 2) {
      throw const FormatException('Unexpected policy page.');
    }
    for (final id in ['privacy', 'support']) {
      final page = pages[id];
      if (page == null ||
          page.sections.isEmpty ||
          page.sections.any((section) =>
              !RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(section.id)) ||
          page.sections.map((section) => section.id).toSet().length !=
              page.sections.length) {
        throw const FormatException('Policy page is incomplete.');
      }
    }
    final revision = json['revision'] as String;
    if (revision.trim().isEmpty) {
      throw const FormatException('Policy revision is missing.');
    }
    return PolicyContent._(revision, Map.unmodifiable(pages));
  }
}
