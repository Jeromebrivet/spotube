import 'dart:math';

import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/database/database.dart';
import 'package:spotube/provider/history/history.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/utils/common.dart';
import 'package:spotube/services/logger/logger.dart';

import 'package:spotube/models/smart_playlist/smart_playlist_config.dart';

/// State for the Smart Playlist generator
class SmartPlaylistState {
  final SmartPlaylistConfig config;
  final List<SpotubeFullTrackObject> generatedTracks;
  final Duration actualDuration;
  final bool isGenerating;
  final String? error;
  final double progress;
  final String progressMessage;

  const SmartPlaylistState({
    required this.config,
    this.generatedTracks = const [],
    this.actualDuration = Duration.zero,
    this.isGenerating = false,
    this.error,
    this.progress = 0.0,
    this.progressMessage = '',
  });

  SmartPlaylistState copyWith({
    SmartPlaylistConfig? config,
    List<SpotubeFullTrackObject>? generatedTracks,
    Duration? actualDuration,
    bool? isGenerating,
    String? error,
    double? progress,
    String? progressMessage,
  }) {
    return SmartPlaylistState(
      config: config ?? this.config,
      generatedTracks: generatedTracks ?? this.generatedTracks,
      actualDuration: actualDuration ?? this.actualDuration,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
      progress: progress ?? this.progress,
      progressMessage: progressMessage ?? this.progressMessage,
    );
  }

  /// Human-readable actual duration
  String get durationDisplay {
    final h = actualDuration.inHours;
    final m = actualDuration.inMinutes % 60;
    final s = actualDuration.inSeconds % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}m${s.toString().padLeft(2, '0')}s';
  }

  /// How close we are to the target duration
  double get durationAccuracy {
    if (config.totalDuration.inMilliseconds == 0) return 0;
    return actualDuration.inMilliseconds / config.totalDuration.inMilliseconds;
  }
}

class SmartPlaylistNotifier extends Notifier<SmartPlaylistState> {
  @override
  SmartPlaylistState build() {
    return SmartPlaylistState(
      config: SmartPlaylistConfig(
        genres: [],
        totalDuration: const Duration(hours: 2),
      ),
    );
  }

  /// Update the configuration
  void updateConfig(SmartPlaylistConfig config) {
    state = state.copyWith(config: config);
  }

  /// Get recently played track IDs for anti-repetition filtering
  Future<Set<String>> _getRecentlyPlayedIds() async {
    if (!state.config.antiRepetition) return {};

    try {
      final database = ref.read(databaseProvider);
      final cutoff = DateTime.now().subtract(
        Duration(days: state.config.antiRepetitionDays),
      );

      final history = await (database.select(database.historyTable)
            ..where((tbl) => tbl.type.equals(HistoryEntryType.track.name))
            ..where((tbl) => tbl.createdAt.isBiggerOrEqualValue(cutoff)))
          .get();

      return history.map((h) => h.itemId).toSet();
    } catch (e) {
      AppLogger.reportError(e, StackTrace.current);
      return {};
    }
  }

  /// Search tracks for a specific genre using the metadata plugin
  Future<List<SpotubeFullTrackObject>> _searchGenreTracks(
    String genreId,
    String genreName, {
    int limit = 50,
  }) async {
    try {
      final plugin = await ref.read(metadataPluginProvider.future);
      if (plugin == null) return [];

      // Strategy: search by genre keyword + filter by freshness
      // The metadata plugin abstracts over Spotify/MusicBrainz/etc.
      final searchQuery = _buildSearchQuery(genreName);

      final result = await plugin.search.tracks(
        searchQuery,
        offset: 0,
        limit: limit,
      );

      return result.items
          .whereType<SpotubeFullTrackObject>()
          .toList();
    } catch (e) {
      AppLogger.reportError(e, StackTrace.current);
      return [];
    }
  }

  /// Build optimized search query based on freshness mode
  String _buildSearchQuery(String genreName) {
    final config = state.config;
    
    return switch (config.freshnessMode) {
      FreshnessMode.fresh => 'genre:$genreName year:${DateTime.now().year}',
      FreshnessMode.classics => 'genre:$genreName',
      FreshnessMode.mixed => 'genre:$genreName',
      FreshnessMode.all => 'genre:$genreName',
    };
  }

  /// Filter tracks based on configuration
  List<SpotubeFullTrackObject> _filterTracks(
    List<SpotubeFullTrackObject> tracks,
    Set<String> recentIds,
  ) {
    final config = state.config;
    final now = DateTime.now();
    final freshCutoff = now.subtract(
      Duration(days: config.freshnessDaysThreshold),
    );

    return tracks.where((track) {
      // Anti-repetition filter
      if (config.antiRepetition && recentIds.contains(track.id)) {
        return false;
      }

      // Explicit content filter
      if (!config.allowExplicit && track.explicit) {
        return false;
      }

      // Freshness filter for "fresh" mode
      if (config.freshnessMode == FreshnessMode.fresh) {
        final releaseDate = DateTime.tryParse(
          track.album.releaseDate ?? '1970-01-01',
        );
        if (releaseDate != null && releaseDate.isBefore(freshCutoff)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Select tracks to fill a target duration intelligently
  List<SpotubeFullTrackObject> _selectTracksForDuration(
    List<SpotubeFullTrackObject> available,
    Duration targetDuration, {
    FreshnessMode? freshnessOverride,
  }) {
    if (available.isEmpty) return [];

    final config = state.config;
    final mode = freshnessOverride ?? config.freshnessMode;
    final random = Random();

    // Sort strategy based on mode
    List<SpotubeFullTrackObject> sorted;
    switch (mode) {
      case FreshnessMode.fresh:
        // Sort by release date, newest first
        sorted = List.of(available)
          ..sort((a, b) {
            final dateA =
                DateTime.tryParse(a.album.releaseDate ?? '1970-01-01') ??
                    DateTime(1970);
            final dateB =
                DateTime.tryParse(b.album.releaseDate ?? '1970-01-01') ??
                    DateTime(1970);
            return dateB.compareTo(dateA);
          });
        break;
      case FreshnessMode.classics:
        // Shuffle for variety among established tracks
        sorted = List.of(available)..shuffle(random);
        break;
      case FreshnessMode.mixed:
      case FreshnessMode.all:
        // Shuffle for maximum variety
        sorted = List.of(available)..shuffle(random);
        break;
    }

    // Greedy fill: pick tracks until we reach the target duration
    // Allow 10% overshoot for a natural ending
    final maxDuration = targetDuration + Duration(
      milliseconds: (targetDuration.inMilliseconds * 0.10).toInt(),
    );
    final selected = <SpotubeFullTrackObject>[];
    var currentDuration = Duration.zero;

    for (final track in sorted) {
      if (currentDuration >= targetDuration) break;
      if (currentDuration + Duration(milliseconds: track.durationMs) > maxDuration) {
        continue; // Skip if it would overshoot too much
      }

      selected.add(track);
      currentDuration += Duration(milliseconds: track.durationMs);
    }

    return selected;
  }

  /// Main generation method
  Future<void> generate() async {
    final config = state.config;

    if (config.genres.isEmpty) {
      state = state.copyWith(error: 'Sélectionnez au moins un genre');
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      error: null,
      progress: 0.0,
      progressMessage: 'Initialisation...',
      generatedTracks: [],
    );

    try {
      // Step 1: Get recently played IDs for anti-repetition
      state = state.copyWith(
        progress: 0.1,
        progressMessage: 'Vérification de l\'historique...',
      );
      final recentIds = await _getRecentlyPlayedIds();

      // Step 2: For each genre, search and collect tracks
      final allTracks = <String, List<SpotubeFullTrackObject>>{};
      final totalGenres = config.genres.length;

      for (int i = 0; i < totalGenres; i++) {
        final genre = config.genres[i];
        state = state.copyWith(
          progress: 0.1 + (0.6 * (i / totalGenres)),
          progressMessage: 'Recherche ${genre.name}...',
        );

        // Search with multiple queries for better coverage
        final tracks = <SpotubeFullTrackObject>[];

        // Primary search
        final primary = await _searchGenreTracks(
          genre.id,
          genre.name,
          limit: 50,
        );
        tracks.addAll(primary);

        // If in mixed mode, also search for new releases specifically
        if (config.freshnessMode == FreshnessMode.mixed) {
          final fresh = await _searchGenreTracks(
            genre.id,
            '${genre.name} ${DateTime.now().year}',
            limit: 30,
          );
          tracks.addAll(fresh);
        }

        // Deduplicate by track ID
        final seen = <String>{};
        final unique = tracks.where((t) {
          if (seen.contains(t.id)) return false;
          seen.add(t.id);
          return true;
        }).toList();

        allTracks[genre.id] = _filterTracks(unique, recentIds);
      }

      // Step 3: Select tracks per genre to match duration targets
      state = state.copyWith(
        progress: 0.8,
        progressMessage: 'Construction de la playlist...',
      );

      final selectedTracks = <SpotubeFullTrackObject>[];

      for (final genre in config.genres) {
        final available = allTracks[genre.id] ?? [];
        final genreDuration = genre.targetDuration;

        if (config.freshnessMode == FreshnessMode.mixed) {
          // Split: X% new, rest classics
          final freshDuration = Duration(
            milliseconds:
                (genreDuration.inMilliseconds * config.freshnessRatio).toInt(),
          );
          final classicDuration = genreDuration - freshDuration;

          // Separate fresh and classic tracks
          final freshCutoff = DateTime.now().subtract(
            Duration(days: config.freshnessDaysThreshold),
          );
          final freshTracks = available.where((t) {
            final rd = DateTime.tryParse(t.album.releaseDate ?? '1970-01-01');
            return rd != null && rd.isAfter(freshCutoff);
          }).toList();
          final classicTracks = available.where((t) {
            final rd = DateTime.tryParse(t.album.releaseDate ?? '1970-01-01');
            return rd == null || rd.isBefore(freshCutoff);
          }).toList();

          selectedTracks.addAll(
            _selectTracksForDuration(
              freshTracks,
              freshDuration,
              freshnessOverride: FreshnessMode.fresh,
            ),
          );
          selectedTracks.addAll(
            _selectTracksForDuration(
              classicTracks,
              classicDuration,
              freshnessOverride: FreshnessMode.classics,
            ),
          );
        } else {
          selectedTracks.addAll(
            _selectTracksForDuration(available, genreDuration),
          );
        }
      }

      // Step 4: Final shuffle within each genre block for variety,
      // but keep genre groups together for a natural flow
      // Actually, let's do a smart interleave if multiple genres
      final finalPlaylist = config.genres.length > 1
          ? _interleaveGenres(selectedTracks, config.genres)
          : selectedTracks;

      // Calculate actual duration
      final actualDuration = Duration(
        milliseconds: finalPlaylist.fold<int>(
          0,
          (sum, track) => sum + track.durationMs,
        ),
      );

      state = state.copyWith(
        isGenerating: false,
        generatedTracks: finalPlaylist,
        actualDuration: actualDuration,
        progress: 1.0,
        progressMessage: 'Terminé !',
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = state.copyWith(
        isGenerating: false,
        error: 'Erreur lors de la génération: $e',
      );
    }
  }

  /// Interleave tracks from different genres for a smooth multi-genre flow
  List<SpotubeFullTrackObject> _interleaveGenres(
    List<SpotubeFullTrackObject> tracks,
    List<SmartPlaylistGenre> genres,
  ) {
    // For simplicity, just shuffle the whole list
    // A more sophisticated approach would group by genre and
    // alternate blocks of 2-3 tracks
    final result = List.of(tracks);
    final random = Random();
    
    // Fisher-Yates shuffle with genre-aware blocks
    // Group tracks by their position in the genre list
    if (genres.length <= 1) {
      result.shuffle(random);
      return result;
    }

    // Create blocks of 2-3 tracks and shuffle the blocks
    final blockSize = 3;
    final blocks = <List<SpotubeFullTrackObject>>[];
    for (int i = 0; i < result.length; i += blockSize) {
      blocks.add(
        result.sublist(i, min(i + blockSize, result.length)),
      );
    }
    blocks.shuffle(random);

    return blocks.expand((block) => block).toList();
  }

  /// Load the generated playlist into the audio player
  Future<void> playGenerated() async {
    if (state.generatedTracks.isEmpty) return;

    final audioPlayer = ref.read(audioPlayerProvider.notifier);
    await audioPlayer.load(
      state.generatedTracks,
      autoPlay: true,
    );
  }

  /// Add generated playlist to queue without replacing current playback
  Future<void> addToQueue() async {
    if (state.generatedTracks.isEmpty) return;

    final audioPlayer = ref.read(audioPlayerProvider.notifier);
    await audioPlayer.addTracks(state.generatedTracks);
  }

  /// Regenerate with the same config (different shuffle/selection)
  Future<void> regenerate() async {
    await generate();
  }
}

final smartPlaylistProvider =
    NotifierProvider<SmartPlaylistNotifier, SmartPlaylistState>(
  () => SmartPlaylistNotifier(),
);

/// Quick presets for common use cases
class SmartPlaylistPresets {
  static SmartPlaylistConfig workout2h() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'work-out',
            name: 'Workout',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'edm',
            name: 'EDM',
            targetDuration: Duration(hours: 1),
          ),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.mixed,
        freshnessRatio: 0.6,
      );

  static SmartPlaylistConfig chillEvening() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'chill',
            name: 'Chill',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'lo-fi',
            name: 'Lo-Fi',
            targetDuration: Duration(minutes: 30),
          ),
          const SmartPlaylistGenre(
            id: 'jazz',
            name: 'Jazz',
            targetDuration: Duration(minutes: 30),
          ),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.all,
      );

  static SmartPlaylistConfig newReleases() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'pop',
            name: 'Pop',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'hip-hop',
            name: 'Hip-Hop',
            targetDuration: Duration(hours: 1),
          ),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.fresh,
        freshnessDaysThreshold: 14,
      );

  static SmartPlaylistConfig roadTrip() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'rock',
            name: 'Rock',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'indie',
            name: 'Indie',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'pop',
            name: 'Pop',
            targetDuration: Duration(hours: 1),
          ),
        ],
        totalDuration: const Duration(hours: 3),
        freshnessMode: FreshnessMode.mixed,
        freshnessRatio: 0.3,
      );

  static SmartPlaylistConfig deepFocus() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'ambient',
            name: 'Ambient',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'classical',
            name: 'Classical',
            targetDuration: Duration(hours: 1),
          ),
          const SmartPlaylistGenre(
            id: 'piano',
            name: 'Piano',
            targetDuration: Duration(minutes: 30),
          ),
        ],
        totalDuration: const Duration(hours: 2, minutes: 30),
        freshnessMode: FreshnessMode.all,
        allowExplicit: false,
      );

  static SmartPlaylistConfig frenchVibes() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
            id: 'french',
            name: 'French',
            targetDuration: Duration(hours: 2),
          ),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.mixed,
        freshnessRatio: 0.5,
        market: 'FR',
      );

  static List<({String name, String emoji, SmartPlaylistConfig config})>
      get all => [
            (
              name: 'Workout 2h',
              emoji: '💪',
              config: workout2h(),
            ),
            (
              name: 'Soirée Chill',
              emoji: '🌙',
              config: chillEvening(),
            ),
            (
              name: 'Nouveautés',
              emoji: '🆕',
              config: newReleases(),
            ),
            (
              name: 'Road Trip 3h',
              emoji: '🚗',
              config: roadTrip(),
            ),
            (
              name: 'Focus Profond',
              emoji: '🧠',
              config: deepFocus(),
            ),
            (
              name: 'French Vibes',
              emoji: '🇫🇷',
              config: frenchVibes(),
            ),
          ];
}

