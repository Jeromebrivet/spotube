import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart' show ListTile, LinearProgressIndicator;
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/models/smart_playlist/smart_playlist_config.dart';
import 'package:spotube/provider/smart_playlist/smart_playlist_provider.dart';
import 'package:spotube/utils/platform.dart';

@RoutePage()
class SmartPlaylistPage extends HookConsumerWidget {
  static const name = "smart_playlist";

  const SmartPlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartPlaylist = ref.watch(smartPlaylistProvider);
    final notifier = ref.read(smartPlaylistProvider.notifier);

    final selectedGenres = useState<List<SmartPlaylistGenre>>([]);
    final totalHours = useState<int>(2);
    final totalMinutes = useState<int>(0);
    final freshnessMode = useState<FreshnessMode>(FreshnessMode.mixed);
    final freshnessRatio = useState<double>(0.5);
    final antiRepetition = useState<bool>(true);
    final allowExplicit = useState<bool>(true);
    final genreSearchQuery = useState<String>('');

    final totalDuration = Duration(
      hours: totalHours.value,
      minutes: totalMinutes.value,
    );

    SmartPlaylistConfig buildConfig() {
      final genreCount = selectedGenres.value.length;
      final perGenreDuration = genreCount > 0
          ? Duration(
              milliseconds: totalDuration.inMilliseconds ~/ genreCount)
          : totalDuration;

      final genres = selectedGenres.value
          .map((g) => SmartPlaylistGenre(
                id: g.id,
                name: g.name,
                targetDuration: g.targetDuration.inMilliseconds > 0
                    ? g.targetDuration
                    : perGenreDuration,
              ))
          .toList();

      return SmartPlaylistConfig(
        genres: genres,
        totalDuration: totalDuration,
        freshnessMode: freshnessMode.value,
        freshnessRatio: freshnessRatio.value,
        antiRepetition: antiRepetition.value,
        allowExplicit: allowExplicit.value,
      );
    }

    return SafeArea(
      bottom: false,
      child: Scaffold(
        headers: [
          if (kTitlebarVisible)
            const TitleBar(automaticallyImplyLeading: false),
        ],
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(SpotubeIcons.magic, size: 28),
                        const SizedBox(width: 12),
                        const Text(
                          'Smart Playlist',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Generate a playlist based on genres, duration and freshness.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .foreground
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Quick Presets
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Presets',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: SmartPlaylistPresets.all.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final preset = SmartPlaylistPresets.all[index];
                          return GestureDetector(
                            onTap: () {
                              final c = preset.config;
                              selectedGenres.value = List.of(c.genres);
                              totalHours.value = c.totalDuration.inHours;
                              totalMinutes.value =
                                  c.totalDuration.inMinutes % 60;
                              freshnessMode.value = c.freshnessMode;
                            },
                            child: Container(
                              width: 100,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Theme.of(context)
                                    .colorScheme
                                    .muted
                                    .withOpacity(0.15),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .border,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(preset.emoji,
                                      style:
                                          const TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    preset.name,
                                    style: const TextStyle(fontSize: 11),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Duration Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .muted
                        .withOpacity(0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(SpotubeIcons.clock, size: 18),
                          SizedBox(width: 8),
                          Text('Target Duration',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton.outline(
                            icon: const Icon(SpotubeIcons.remove, size: 16),
                            onPressed: totalHours.value > 0
                                ? () => totalHours.value--
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text('${totalHours.value}h',
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          IconButton.outline(
                            icon: const Icon(SpotubeIcons.add, size: 16),
                            onPressed: totalHours.value < 8
                                ? () => totalHours.value++
                                : null,
                          ),
                          const SizedBox(width: 24),
                          IconButton.outline(
                            icon: const Icon(SpotubeIcons.remove, size: 16),
                            onPressed: totalMinutes.value > 0
                                ? () => totalMinutes.value -= 15
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${totalMinutes.value.toString().padLeft(2, '0')}m',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outline(
                            icon: const Icon(SpotubeIcons.add, size: 16),
                            onPressed: totalMinutes.value < 45
                                ? () => totalMinutes.value += 15
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Genre Selector
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .muted
                        .withOpacity(0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(SpotubeIcons.music, size: 18),
                          const SizedBox(width: 8),
                          const Text('Genres',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (selectedGenres.value.isNotEmpty)
                            Text(
                              '${selectedGenres.value.length} selected',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selected genres
                      if (selectedGenres.value.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedGenres.value.map((genre) {
                            return Chip(
                              trailing: GestureDetector(
                                onTap: () {
                                  selectedGenres.value = selectedGenres
                                      .value
                                      .where((g) => g.id != genre.id)
                                      .toList();
                                },
                                child: const Icon(SpotubeIcons.close,
                                    size: 12),
                              ),
                              child: Text(genre.name),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Genre grid
                      SizedBox(
                        height: 180,
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemCount:
                              SpotifyGenreSeeds.search(genreSearchQuery.value)
                                  .length,
                          itemBuilder: (context, index) {
                            final genre = SpotifyGenreSeeds.search(
                                genreSearchQuery.value)[index];
                            final isSelected = selectedGenres.value
                                .any((g) => g.id == genre['id']);

                            return GestureDetector(
                              onTap: () {
                                if (isSelected) {
                                  selectedGenres.value = selectedGenres
                                      .value
                                      .where((g) => g.id != genre['id'])
                                      .toList();
                                } else {
                                  selectedGenres.value = [
                                    ...selectedGenres.value,
                                    SmartPlaylistGenre(
                                      id: genre['id']!,
                                      name: genre['name']!,
                                      targetDuration: Duration.zero,
                                    ),
                                  ];
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: isSelected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .muted
                                          .withOpacity(0.1),
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${genre['emoji']} ${genre['name']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Freshness Mode
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context)
                        .colorScheme
                        .muted
                        .withOpacity(0.1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(SpotubeIcons.clock, size: 18),
                          SizedBox(width: 8),
                          Text('Freshness',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildFreshnessChip(context, '🆕 New',
                              freshnessMode, FreshnessMode.fresh),
                          _buildFreshnessChip(context, '🔀 Mix',
                              freshnessMode, FreshnessMode.mixed),
                          _buildFreshnessChip(context, '⭐ Classics',
                              freshnessMode, FreshnessMode.classics),
                          _buildFreshnessChip(context, '🎵 All',
                              freshnessMode, FreshnessMode.all),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // Generate Button
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (selectedGenres.value.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          buildConfig().summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .foreground
                                .withOpacity(0.5),
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        onPressed: smartPlaylist.isGenerating ||
                                selectedGenres.value.isEmpty ||
                                totalDuration.inMinutes < 5
                            ? null
                            : () {
                                notifier.updateConfig(buildConfig());
                                notifier.generate();
                              },
                        child: smartPlaylist.isGenerating
                            ? Text(smartPlaylist.progressMessage)
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(SpotubeIcons.magic, size: 18),
                                  SizedBox(width: 8),
                                  Text('Generate Playlist'),
                                ],
                              ),
                      ),
                    ),
                    if (smartPlaylist.error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        smartPlaylist.error!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.destructive,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Results
            if (smartPlaylist.generatedTracks.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '${smartPlaylist.generatedTracks.length} tracks - ${smartPlaylist.durationDisplay}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton.outline(
                        icon: const Icon(SpotubeIcons.refresh, size: 16),
                        onPressed: () => notifier.regenerate(),
                      ),
                      const SizedBox(width: 8),
                      OutlineButton(
                        onPressed: () => notifier.addToQueue(),
                        child: const Text('Queue'),
                      ),
                      const SizedBox(width: 8),
                      PrimaryButton(
                        onPressed: () => notifier.playGenerated(),
                        child: const Row(
                          children: [
                            Icon(SpotubeIcons.play, size: 14),
                            SizedBox(width: 4),
                            Text('Play'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = smartPlaylist.generatedTracks[index];
                    final duration =
                        Duration(milliseconds: track.durationMs);
                    final albumArt = track.album.images.isNotEmpty
                        ? track.album.images.first.url
                        : null;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: albumArt != null
                              ? Image.network(
                                  albumArt,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(SpotubeIcons.music),
                                )
                              : const Icon(SpotubeIcons.music),
                        ),
                      ),
                      title: Text(
                        track.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artists.map((a) => a.name).join(', '),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                  childCount: smartPlaylist.generatedTracks.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildFreshnessChip(
    BuildContext context,
    String label,
    ValueNotifier<FreshnessMode> current,
    FreshnessMode mode,
  ) {
    final isSelected = current.value == mode;
    return GestureDetector(
      onTap: () => current.value = mode,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Theme.of(context).colorScheme.muted.withOpacity(0.1),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
