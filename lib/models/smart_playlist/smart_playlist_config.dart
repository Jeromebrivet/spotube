/// Smart Playlist Configuration Model
/// Pure data model - no UI code here

class SmartPlaylistGenre {
  final String id;
  final String name;
  final Duration targetDuration;

  const SmartPlaylistGenre({
    required this.id,
    required this.name,
    required this.targetDuration,
  });
}

enum FreshnessMode { fresh, mixed, classics, all }

class SmartPlaylistConfig {
  final List<SmartPlaylistGenre> genres;
  final Duration totalDuration;
  final FreshnessMode freshnessMode;
  final double freshnessRatio;
  final int freshnessDaysThreshold;
  final bool antiRepetition;
  final int antiRepetitionDays;
  final bool allowExplicit;

  const SmartPlaylistConfig({
    required this.genres,
    required this.totalDuration,
    this.freshnessMode = FreshnessMode.mixed,
    this.freshnessRatio = 0.5,
    this.freshnessDaysThreshold = 30,
    this.antiRepetition = true,
    this.antiRepetitionDays = 7,
    this.allowExplicit = true,
  });

  String get summary {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes % 60;
    final durationStr = hours > 0
        ? '${hours}h${minutes > 0 ? '${minutes}m' : ''}'
        : '${minutes}m';
    final genreStr = genres.map((g) => g.name).join(', ');
    return '$durationStr - $genreStr';
  }

  SmartPlaylistConfig copyWith({
    List<SmartPlaylistGenre>? genres,
    Duration? totalDuration,
    FreshnessMode? freshnessMode,
    double? freshnessRatio,
    int? freshnessDaysThreshold,
    bool? antiRepetition,
    int? antiRepetitionDays,
    bool? allowExplicit,
  }) {
    return SmartPlaylistConfig(
      genres: genres ?? this.genres,
      totalDuration: totalDuration ?? this.totalDuration,
      freshnessMode: freshnessMode ?? this.freshnessMode,
      freshnessRatio: freshnessRatio ?? this.freshnessRatio,
      freshnessDaysThreshold:
          freshnessDaysThreshold ?? this.freshnessDaysThreshold,
      antiRepetition: antiRepetition ?? this.antiRepetition,
      antiRepetitionDays: antiRepetitionDays ?? this.antiRepetitionDays,
      allowExplicit: allowExplicit ?? this.allowExplicit,
    );
  }
}

class SpotifyGenreSeeds {
  static const List<Map<String, String>> genres = [
    {'id': 'acoustic', 'name': 'Acoustic', 'emoji': '🎸'},
    {'id': 'afrobeat', 'name': 'Afrobeat', 'emoji': '🌍'},
    {'id': 'alt-rock', 'name': 'Alt Rock', 'emoji': '🎸'},
    {'id': 'ambient', 'name': 'Ambient', 'emoji': '🌊'},
    {'id': 'blues', 'name': 'Blues', 'emoji': '🎷'},
    {'id': 'chill', 'name': 'Chill', 'emoji': '😎'},
    {'id': 'classical', 'name': 'Classical', 'emoji': '🎻'},
    {'id': 'club', 'name': 'Club', 'emoji': '🪩'},
    {'id': 'country', 'name': 'Country', 'emoji': '🤠'},
    {'id': 'dance', 'name': 'Dance', 'emoji': '💃'},
    {'id': 'deep-house', 'name': 'Deep House', 'emoji': '🏠'},
    {'id': 'disco', 'name': 'Disco', 'emoji': '🕺'},
    {'id': 'drum-and-bass', 'name': 'Drum & Bass', 'emoji': '🥁'},
    {'id': 'dubstep', 'name': 'Dubstep', 'emoji': '🔊'},
    {'id': 'edm', 'name': 'EDM', 'emoji': '⚡'},
    {'id': 'electro', 'name': 'Electro', 'emoji': '🎹'},
    {'id': 'electronic', 'name': 'Electronic', 'emoji': '🤖'},
    {'id': 'folk', 'name': 'Folk', 'emoji': '🪕'},
    {'id': 'french', 'name': 'French', 'emoji': '🇫🇷'},
    {'id': 'funk', 'name': 'Funk', 'emoji': '🎶'},
    {'id': 'hip-hop', 'name': 'Hip-Hop', 'emoji': '🎤'},
    {'id': 'house', 'name': 'House', 'emoji': '🏠'},
    {'id': 'indie', 'name': 'Indie', 'emoji': '🎵'},
    {'id': 'indie-pop', 'name': 'Indie Pop', 'emoji': '🌈'},
    {'id': 'jazz', 'name': 'Jazz', 'emoji': '🎷'},
    {'id': 'k-pop', 'name': 'K-Pop', 'emoji': '🇰🇷'},
    {'id': 'latin', 'name': 'Latin', 'emoji': '💃'},
    {'id': 'lo-fi', 'name': 'Lo-Fi', 'emoji': '📻'},
    {'id': 'metal', 'name': 'Metal', 'emoji': '🤘'},
    {'id': 'pop', 'name': 'Pop', 'emoji': '🎵'},
    {'id': 'punk', 'name': 'Punk', 'emoji': '🏴'},
    {'id': 'r-n-b', 'name': 'R&B', 'emoji': '🎙️'},
    {'id': 'rap', 'name': 'Rap', 'emoji': '🎤'},
    {'id': 'reggae', 'name': 'Reggae', 'emoji': '🇯🇲'},
    {'id': 'reggaeton', 'name': 'Reggaeton', 'emoji': '🔥'},
    {'id': 'rock', 'name': 'Rock', 'emoji': '🎸'},
    {'id': 'soul', 'name': 'Soul', 'emoji': '❤️'},
    {'id': 'techno', 'name': 'Techno', 'emoji': '🎛️'},
    {'id': 'trance', 'name': 'Trance', 'emoji': '🌀'},
    {'id': 'trap', 'name': 'Trap', 'emoji': '🔊'},
    {'id': 'trip-hop', 'name': 'Trip-Hop', 'emoji': '🌙'},
    {'id': 'work-out', 'name': 'Workout', 'emoji': '💪'},
  ];

  static List<Map<String, String>> search(String query) {
    if (query.isEmpty) return genres;
    final lower = query.toLowerCase();
    return genres
        .where((g) => g['name']!.toLowerCase().contains(lower))
        .toList();
  }
}
