import 'package:flutter/material.dart';

/// The glyphs a user shelf can wear (Kuber's `IconMapper`). A shelf stores the
/// string id, never a code point, so the catalogue can grow or change fonts.
/// Every entry is a const reference so icon tree-shaking keeps working.
abstract final class ShelfIcons {
  static const String defaultId = 'bookmark';

  static const List<String> keys = <String>[
    'bookmark', 'book', 'menu_book', 'auto_stories', 'school', 'edit', 'history_edu', 'translate',
    'chat', 'forum', 'record_voice_over', 'lightbulb', 'psychology', 'science', 'biotech', 'calculate',
    'public', 'flight', 'map', 'hiking', 'park', 'eco', 'pets', 'water_drop',
    'restaurant', 'local_cafe', 'music_note', 'palette', 'theater_comedy', 'movie', 'sports_soccer', 'fitness_center',
    'favorite', 'medical_services', 'gavel', 'account_balance', 'payments', 'work', 'business_center', 'computer',
    'rocket_launch', 'star', 'bolt', 'flag', 'home', 'newspaper', 'mic', 'emoji_objects',
    'diamond', 'extension', 'sentiment_satisfied', 'workspace_premium',
  ];

  static const Map<String, IconData> _icons = <String, IconData>{
    'bookmark': Icons.bookmark_rounded,
    'book': Icons.book_rounded,
    'menu_book': Icons.menu_book_rounded,
    'auto_stories': Icons.auto_stories_rounded,
    'school': Icons.school_rounded,
    'edit': Icons.edit_rounded,
    'history_edu': Icons.history_edu_rounded,
    'translate': Icons.translate_rounded,
    'chat': Icons.chat_bubble_rounded,
    'forum': Icons.forum_rounded,
    'record_voice_over': Icons.record_voice_over_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'psychology': Icons.psychology_rounded,
    'science': Icons.science_rounded,
    'biotech': Icons.biotech_rounded,
    'calculate': Icons.calculate_rounded,
    'public': Icons.public_rounded,
    'flight': Icons.flight_rounded,
    'map': Icons.map_rounded,
    'hiking': Icons.hiking_rounded,
    'park': Icons.park_rounded,
    'eco': Icons.eco_rounded,
    'pets': Icons.pets_rounded,
    'water_drop': Icons.water_drop_rounded,
    'restaurant': Icons.restaurant_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'music_note': Icons.music_note_rounded,
    'palette': Icons.palette_rounded,
    'theater_comedy': Icons.theater_comedy_rounded,
    'movie': Icons.movie_rounded,
    'sports_soccer': Icons.sports_soccer_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'favorite': Icons.favorite_rounded,
    'medical_services': Icons.medical_services_rounded,
    'gavel': Icons.gavel_rounded,
    'account_balance': Icons.account_balance_rounded,
    'payments': Icons.payments_rounded,
    'work': Icons.work_rounded,
    'business_center': Icons.business_center_rounded,
    'computer': Icons.computer_rounded,
    'rocket_launch': Icons.rocket_launch_rounded,
    'star': Icons.star_rounded,
    'bolt': Icons.bolt_rounded,
    'flag': Icons.flag_rounded,
    'home': Icons.home_rounded,
    'newspaper': Icons.newspaper_rounded,
    'mic': Icons.mic_rounded,
    'emoji_objects': Icons.emoji_objects_rounded,
    'diamond': Icons.diamond_rounded,
    'extension': Icons.extension_rounded,
    'sentiment_satisfied': Icons.sentiment_satisfied_rounded,
    'workspace_premium': Icons.workspace_premium_rounded,
  };

  static const Map<String, String> _labels = <String, String>{
    'bookmark': 'Bookmark', 'book': 'Book', 'menu_book': 'Open book', 'auto_stories': 'Stories',
    'school': 'School', 'edit': 'Writing', 'history_edu': 'History', 'translate': 'Languages',
    'chat': 'Chat', 'forum': 'Talk', 'record_voice_over': 'Speaking', 'lightbulb': 'Idea',
    'psychology': 'Mind', 'science': 'Science', 'biotech': 'Biology', 'calculate': 'Maths',
    'public': 'World', 'flight': 'Travel', 'map': 'Map', 'hiking': 'Outdoors',
    'park': 'Trees', 'eco': 'Nature', 'pets': 'Animals', 'water_drop': 'Water',
    'restaurant': 'Food', 'local_cafe': 'Cafe', 'music_note': 'Music', 'palette': 'Art',
    'theater_comedy': 'Theatre', 'movie': 'Film', 'sports_soccer': 'Sport', 'fitness_center': 'Fitness',
    'favorite': 'Heart', 'medical_services': 'Health', 'gavel': 'Law', 'account_balance': 'Politics',
    'payments': 'Money', 'work': 'Work', 'business_center': 'Business', 'computer': 'Tech',
    'rocket_launch': 'Launch', 'star': 'Star', 'bolt': 'Energy', 'flag': 'Flag',
    'home': 'Home', 'newspaper': 'News', 'mic': 'Speech', 'emoji_objects': 'Bright',
    'diamond': 'Gem', 'extension': 'Puzzle', 'sentiment_satisfied': 'Mood', 'workspace_premium': 'Award',
  };

  /// The glyph for [id], or the default shelf glyph for null or an unknown id.
  static IconData of(String? id) => _icons[id] ?? _icons[defaultId]!;

  static String labelOf(String? id) => _labels[id] ?? _labels[defaultId]!;
}
