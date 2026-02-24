import 'dart:math';

import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/models/database/database.dart';
import 'package:spotube/models/metadata/metadata.dart';
import 'package:spotube/models/smart_playlist/smart_playlist_config.dart';
import 'package:spotube/provider/audio_player/audio_player.dart';
import 'package:spotube/provider/database/database.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/provider/metadata_plugin/metadata_plugin_provider.dart';
import 'package:spotube/services/logger/logger.dart';

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

  String get durationDisplay {
    final h = actualDuration.inHours;
    final m = actualDuration.inMinutes % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}min';
  }

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

  void updateConfig(SmartPlaylistConfig config) {
    state = state.copyWith(config: config);
  }

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

  Future<List<SpotubeFullTrackObject>> _searchGenreTracks(
    String genreName, {
    int limit = 50,
  }) async {
    try {
      final plugin = await ref.read(metadataPluginProvider.future);     
      final result = await plugin.search.tracks(
        genreName,
        offset: 0,
        limit: limit,
      );
      return result.items.whereType<SpotubeFullTrackObject>().toList();
    } catch (e) {
      AppLogger.reportError(e, StackTrace.current);
      return [];
    }
  }

  List<SpotubeFullTrackObject> _filterTracks(
    List<SpotubeFullTrackObject> tracks,
    Set<String> recentIds,
  ) {
    final config = state.config;
    final freshCutoff = DateTime.now().subtract(
      Duration(days: config.freshnessDaysThreshold),
    );

    return tracks.where((track) {
      if (config.antiRepetition && recentIds.contains(track.id)) return false;
      if (!config.allowExplicit && track.explicit) return false;
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

  List<SpotubeFullTrackObject> _selectTracksForDuration(
    List<SpotubeFullTrackObject> available,
    Duration targetDuration,
  ) {
    if (available.isEmpty) return [];
    final random = Random();
    final sorted = List.of(available)..shuffle(random);

    final maxDuration = targetDuration +
        Duration(
          milliseconds: (targetDuration.inMilliseconds * 0.10).toInt(),
        );
    final selected = <SpotubeFullTrackObject>[];
    var currentDuration = Duration.zero;

    for (final track in sorted) {
      if (currentDuration >= targetDuration) break;
      if (currentDuration + Duration(milliseconds: track.durationMs) >
          maxDuration) {
        continue;
      }
      selected.add(track);
      currentDuration += Duration(milliseconds: track.durationMs);
    }
    return selected;
  }

  Future<void> generate() async {
    final config = state.config;
    if (config.genres.isEmpty) {
      state = state.copyWith(error: 'Select at least one genre');
      return;
    }

    state = state.copyWith(
      isGenerating: true,
      error: null,
      progress: 0.0,
      progressMessage: 'Initializing...',
      generatedTracks: [],
    );

    try {
      state = state.copyWith(
        progress: 0.1,
        progressMessage: 'Checking history...',
      );
      final recentIds = await _getRecentlyPlayedIds();

      final allTracks = <String, List<SpotubeFullTrackObject>>{};
      final totalGenres = config.genres.length;

      for (int i = 0; i < totalGenres; i++) {
        final genre = config.genres[i];
        state = state.copyWith(
          progress: 0.1 + (0.6 * (i / totalGenres)),
          progressMessage: 'Searching ${genre.name}...',
        );

        final tracks = <SpotubeFullTrackObject>[];
        final primary = await _searchGenreTracks(genre.name, limit: 50);
        tracks.addAll(primary);

        if (config.freshnessMode == FreshnessMode.mixed) {
          final fresh = await _searchGenreTracks(
            '${genre.name} ${DateTime.now().year}',
            limit: 30,
          );
          tracks.addAll(fresh);
        }

        final seen = <String>{};
        final unique = tracks.where((t) {
          if (seen.contains(t.id)) return false;
          seen.add(t.id);
          return true;
        }).toList();

        allTracks[genre.id] = _filterTracks(unique, recentIds);
      }

      state = state.copyWith(
        progress: 0.8,
        progressMessage: 'Building playlist...',
      );

      final selectedTracks = <SpotubeFullTrackObject>[];
      final genreCount = config.genres.length;
      final perGenreDuration = Duration(
        milliseconds: config.totalDuration.inMilliseconds ~/ genreCount,
      );

      for (final genre in config.genres) {
        final available = allTracks[genre.id] ?? [];
        final genreDuration = genre.targetDuration.inMilliseconds > 0
            ? genre.targetDuration
            : perGenreDuration;
        selectedTracks.addAll(
          _selectTracksForDuration(available, genreDuration),
        );
      }

      // Shuffle blocks for variety
      if (config.genres.length > 1) {
        final blockSize = 3;
        final blocks = <List<SpotubeFullTrackObject>>[];
        for (int i = 0; i < selectedTracks.length; i += blockSize) {
          blocks.add(selectedTracks.sublist(
            i,
            min(i + blockSize, selectedTracks.length),
          ));
        }
        blocks.shuffle(Random());
        selectedTracks
          ..clear()
          ..addAll(blocks.expand((b) => b));
      }

      final actualDuration = Duration(
        milliseconds: selectedTracks.fold<int>(
          0,
          (sum, track) => sum + track.durationMs,
        ),
      );

      state = state.copyWith(
        isGenerating: false,
        generatedTracks: selectedTracks,
        actualDuration: actualDuration,
        progress: 1.0,
        progressMessage: 'Done!',
      );
    } catch (e, stack) {
      AppLogger.reportError(e, stack);
      state = state.copyWith(
        isGenerating: false,
        error: 'Generation error: $e',
      );
    }
  }

  Future<void> playGenerated() async {
    if (state.generatedTracks.isEmpty) return;
    final audioPlayer = ref.read(audioPlayerProvider.notifier);
    await audioPlayer.load(state.generatedTracks, autoPlay: true);
  }

  Future<void> addToQueue() async {
    if (state.generatedTracks.isEmpty) return;
    final audioPlayer = ref.read(audioPlayerProvider.notifier);
    await audioPlayer.addTracks(state.generatedTracks);
  }

  Future<void> regenerate() async => await generate();
}

final smartPlaylistProvider =
    NotifierProvider<SmartPlaylistNotifier, SmartPlaylistState>(
  () => SmartPlaylistNotifier(),
);

class SmartPlaylistPresets {
  static SmartPlaylistConfig workout2h() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
              id: 'work-out',
              name: 'Workout',
              targetDuration: Duration(hours: 1)),
          const SmartPlaylistGenre(
              id: 'edm', name: 'EDM', targetDuration: Duration(hours: 1)),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.mixed,
      );

  static SmartPlaylistConfig chillEvening() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
              id: 'chill',
              name: 'Chill',
              targetDuration: Duration(hours: 1)),
          const SmartPlaylistGenre(
              id: 'lo-fi',
              name: 'Lo-Fi',
              targetDuration: Duration(minutes: 30)),
          const SmartPlaylistGenre(
              id: 'jazz',
              name: 'Jazz',
              targetDuration: Duration(minutes: 30)),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.all,
      );

  static SmartPlaylistConfig newReleases() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
              id: 'pop', name: 'Pop', targetDuration: Duration(hours: 1)),
          const SmartPlaylistGenre(
              id: 'hip-hop',
              name: 'Hip-Hop',
              targetDuration: Duration(hours: 1)),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.fresh,
      );

  static SmartPlaylistConfig roadTrip() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
              id: 'rock', name: 'Rock', targetDuration: Duration(hours: 1)),
          const SmartPlaylistGenre(
              id: 'indie',
              name: 'Indie',
              targetDuration: Duration(hours: 1)),
          const SmartPlaylistGenre(
              id: 'pop', name: 'Pop', targetDuration: Duration(hours: 1)),
        ],
        totalDuration: const Duration(hours: 3),
        freshnessMode: FreshnessMode.mixed,
      );

  static SmartPlaylistConfig frenchVibes() => SmartPlaylistConfig(
        genres: [
          const SmartPlaylistGenre(
              id: 'french',
              name: 'French',
              targetDuration: Duration(hours: 2)),
        ],
        totalDuration: const Duration(hours: 2),
        freshnessMode: FreshnessMode.mixed,
      );

  static List<({String name, String emoji, SmartPlaylistConfig config})>
      get all => [
            (name: 'Workout 2h', emoji: '💪', config: workout2h()),
            (name: 'Chill', emoji: '🌙', config: chillEvening()),
            (name: 'New', emoji: '🆕', config: newReleases()),
            (name: 'Road Trip', emoji: '🚗', config: roadTrip()),
            (name: 'French', emoji: '🇫🇷', config: frenchVibes()),
          ];
}
