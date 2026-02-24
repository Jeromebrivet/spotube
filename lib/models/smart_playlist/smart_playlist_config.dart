import 'package:auto_route/auto_route.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/titlebar/titlebar.dart';
import 'package:spotube/extensions/context.dart';
import 'package:spotube/models/smart_playlist/smart_playlist_config.dart';
import 'package:spotube/provider/smart_playlist/smart_playlist_provider.dart';

@RoutePage()
class SmartPlaylistPage extends HookConsumerWidget {
  static const name = "smart_playlist";

  const SmartPlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartPlaylist = ref.watch(smartPlaylistProvider);
    final notifier = ref.read(smartPlaylistProvider.notifier);

    // Local state for the builder form
    final selectedGenres = useState<List<SmartPlaylistGenre>>([]);
    final totalHours = useState<int>(2);
    final totalMinutes = useState<int>(0);
    final freshnessMode = useState<FreshnessMode>(FreshnessMode.mixed);
    final freshnessRatio = useState<double>(0.5);
    final antiRepetition = useState<bool>(true);
    final allowExplicit = useState<bool>(true);
    final genreSearchQuery = useState<String>('');
    final showAdvanced = useState<bool>(false);
    final showPresets = useState<bool>(true);

    // Calculate total duration
    final totalDuration = Duration(
      hours: totalHours.value,
      minutes: totalMinutes.value,
    );

    // Build config from current form state
    SmartPlaylistConfig buildConfig() {
      // Distribute duration evenly across genres if not manually set
      final genreCount = selectedGenres.value.length;
      final perGenreDuration = genreCount > 0
          ? Duration(
              milliseconds: totalDuration.inMilliseconds ~/ genreCount,
            )
          : totalDuration;

      final genres = selectedGenres.value.map((g) {
        return SmartPlaylistGenre(
          id: g.id,
          name: g.name,
          targetDuration: g.targetDuration.inMilliseconds > 0
              ? g.targetDuration
              : perGenreDuration,
        );
      }).toList();

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
      child: Column(
        children: [
          const PageWindowTitleBar(
            leading: BackButton(),
          ),
          Expanded(
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
                            const Icon(
                              SpotubeIcons.magic,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Smart Playlist',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Générez automatiquement une playlist parfaite '
                          'basée sur vos genres, durée et préférences.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .foreground
                                    .withOpacity(0.7),
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
                        GestureDetector(
                          onTap: () =>
                              showPresets.value = !showPresets.value,
                          child: Row(
                            children: [
                              Text(
                                'Presets rapides',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                showPresets.value
                                    ? SpotubeIcons.angleUp
                                    : SpotubeIcons.angleDown,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        if (showPresets.value) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: SmartPlaylistPresets.all.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final preset =
                                    SmartPlaylistPresets.all[index];
                                return _PresetCard(
                                  name: preset.name,
                                  emoji: preset.emoji,
                                  config: preset.config,
                                  onTap: () {
                                    final config = preset.config;
                                    selectedGenres.value =
                                        List.of(config.genres);
                                    totalHours.value =
                                        config.totalDuration.inHours;
                                    totalMinutes.value =
                                        config.totalDuration.inMinutes % 60;
                                    freshnessMode.value =
                                        config.freshnessMode;
                                    freshnessRatio.value =
                                        config.freshnessRatio;
                                    antiRepetition.value =
                                        config.antiRepetition;
                                    allowExplicit.value =
                                        config.allowExplicit;
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),

                // Duration Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(SpotubeIcons.clock, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Durée cible',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                // Hours
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('Heures',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton.outline(
                                            icon: const Icon(
                                                SpotubeIcons.remove),
                                            onPressed: totalHours.value > 0
                                                ? () => totalHours.value--
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            '${totalHours.value}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton.outline(
                                            icon:
                                                const Icon(SpotubeIcons.add),
                                            onPressed: totalHours.value < 8
                                                ? () => totalHours.value++
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  ':',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium,
                                ),
                                // Minutes
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('Minutes',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton.outline(
                                            icon: const Icon(
                                                SpotubeIcons.remove),
                                            onPressed: totalMinutes.value > 0
                                                ? () =>
                                                    totalMinutes.value -= 15
                                                : null,
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            '${totalMinutes.value.toString().padLeft(2, '0')}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium,
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton.outline(
                                            icon:
                                                const Icon(SpotubeIcons.add),
                                            onPressed: totalMinutes.value < 45
                                                ? () =>
                                                    totalMinutes.value += 15
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: Text(
                                _formatDuration(totalDuration),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),

                // Genre Selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(SpotubeIcons.music, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Genres',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                const Spacer(),
                                if (selectedGenres.value.isNotEmpty)
                                  Text(
                                    '${selectedGenres.value.length} sélectionné(s)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Selected genres chips
                            if (selectedGenres.value.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: selectedGenres.value.map((genre) {
                                  return Chip(
                                    trailing: GestureDetector(
                                      onTap: () {
                                        selectedGenres.value = selectedGenres
                                            .value
                                            .where((g) => g.id != genre.id)
                                            .toList();
                                      },
                                      child:
                                          const Icon(SpotubeIcons.close, size: 14),
                                    ),
                                    child: Text(genre.name),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Search field
                            TextField(
                              placeholder: const Text(
                                  'Rechercher un genre...'),
                              onChanged: (value) =>
                                  genreSearchQuery.value = value,
                            ),
                            const SizedBox(height: 8),

                            // Genre grid
                            SizedBox(
                              height: 200,
                              child: GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.5,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                                itemCount: SpotifyGenreSeeds.search(
                                  genreSearchQuery.value,
                                ).length,
                                itemBuilder: (context, index) {
                                  final genre = SpotifyGenreSeeds.search(
                                    genreSearchQuery.value,
                                  )[index];
                                  final isSelected = selectedGenres.value
                                      .any((g) => g.id == genre['id']);

                                  return GestureDetector(
                                    onTap: () {
                                      if (isSelected) {
                                        selectedGenres.value = selectedGenres
                                            .value
                                            .where(
                                                (g) => g.id != genre['id'])
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
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
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
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${genre['emoji']} ${genre['name']}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
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
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),

                // Freshness Mode
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(SpotubeIcons.calendar, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Fraîcheur',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _FreshnessChip(
                                  label: '🆕 Nouveautés',
                                  subtitle: 'Derniers 30 jours',
                                  isSelected: freshnessMode.value ==
                                      FreshnessMode.fresh,
                                  onTap: () => freshnessMode.value =
                                      FreshnessMode.fresh,
                                ),
                                _FreshnessChip(
                                  label: '🔀 Mix',
                                  subtitle:
                                      '${(freshnessRatio.value * 100).toInt()}% nouveau',
                                  isSelected: freshnessMode.value ==
                                      FreshnessMode.mixed,
                                  onTap: () => freshnessMode.value =
                                      FreshnessMode.mixed,
                                ),
                                _FreshnessChip(
                                  label: '⭐ Classiques',
                                  subtitle: 'Titres populaires',
                                  isSelected: freshnessMode.value ==
                                      FreshnessMode.classics,
                                  onTap: () => freshnessMode.value =
                                      FreshnessMode.classics,
                                ),
                                _FreshnessChip(
                                  label: '🎵 Tout',
                                  subtitle: 'Sans filtre',
                                  isSelected: freshnessMode.value ==
                                      FreshnessMode.all,
                                  onTap: () => freshnessMode.value =
                                      FreshnessMode.all,
                                ),
                              ],
                            ),

                            // Slider for mix ratio (only in mixed mode)
                            if (freshnessMode.value == FreshnessMode.mixed) ...[
                              const SizedBox(height: 16),
                              Text(
                                'Ratio nouveautés / classiques',
                                style:
                                    Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Classiques'),
                                  Expanded(
                                    child: Slider(
                                      value:
                                          SliderValue.single(freshnessRatio.value),
                                      onChanged: (value) => freshnessRatio
                                          .value = value.toDouble(),
                                      min: 0.0,
                                      max: 1.0,
                                    ),
                                  ),
                                  const Text('Nouveautés'),
                                ],
                              ),
                              Center(
                                child: Text(
                                  '${(freshnessRatio.value * 100).toInt()}% nouveautés · '
                                  '${((1 - freshnessRatio.value) * 100).toInt()}% classiques',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),

                // Advanced Options
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              showAdvanced.value = !showAdvanced.value,
                          child: Row(
                            children: [
                              Text(
                                'Options avancées',
                                style:
                                    Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                showAdvanced.value
                                    ? SpotubeIcons.angleUp
                                    : SpotubeIcons.angleDown,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                        if (showAdvanced.value) ...[
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Anti-répétition'),
                                      Switch(
                                        value: antiRepetition.value,
                                        onChanged: (v) =>
                                            antiRepetition.value = v,
                                      ),
                                    ],
                                  ),
                                  if (antiRepetition.value)
                                    Text(
                                      'Exclut les titres écoutés ces 7 derniers jours',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Contenu explicite'),
                                      Switch(
                                        value: allowExplicit.value,
                                        onChanged: (v) =>
                                            allowExplicit.value = v,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),

                // Generate Button
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Config summary
                        if (selectedGenres.value.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              buildConfig().summary,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .foreground
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
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
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(smartPlaylist.progressMessage),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(SpotubeIcons.magic),
                                      SizedBox(width: 8),
                                      Text('Générer la playlist'),
                                    ],
                                  ),
                          ),
                        ),

                        // Progress bar during generation
                        if (smartPlaylist.isGenerating) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: smartPlaylist.progress,
                          ),
                        ],

                        // Error display
                        if (smartPlaylist.error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            smartPlaylist.error!,
                            style: TextStyle(
                              color:
                                  Theme.of(context).colorScheme.destructive,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Generated Playlist Results
                if (smartPlaylist.generatedTracks.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),

                  // Results header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${smartPlaylist.generatedTracks.length} titres',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      Text(
                                        'Durée: ${smartPlaylist.durationDisplay}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      // Regenerate button
                                      IconButton.outline(
                                        icon: const Icon(
                                            SpotubeIcons.refresh),
                                        onPressed: () =>
                                            notifier.regenerate(),
                                      ),
                                      const SizedBox(width: 8),
                                      // Add to queue
                                      OutlineButton(
                                        onPressed: () =>
                                            notifier.addToQueue(),
                                        child: const Row(
                                          children: [
                                            Icon(SpotubeIcons.queue,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text('File'),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Play button
                                      PrimaryButton(
                                        onPressed: () =>
                                            notifier.playGenerated(),
                                        child: const Row(
                                          children: [
                                            Icon(SpotubeIcons.play,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text('Écouter'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              // Duration accuracy indicator
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: smartPlaylist.durationAccuracy
                                          .clamp(0.0, 1.0),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(smartPlaylist.durationAccuracy * 100).toStringAsFixed(0)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Track list
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track =
                            smartPlaylist.generatedTracks[index];
                        final duration = Duration(
                            milliseconds: track.durationMs);
                        final albumArt =
                            track.album.images.isNotEmpty
                                ? track.album.images.first.url
                                : null;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: albumArt != null
                                  ? Image.network(
                                      albumArt,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) => Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .muted,
                                        child: const Icon(
                                            SpotubeIcons.music),
                                      ),
                                    )
                                  : Container(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .muted,
                                      child:
                                          const Icon(SpotubeIcons.music),
                                    ),
                            ),
                          ),
                          title: Text(
                            track.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artists
                                .map((a) => a.name)
                                .join(', '),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall,
                          ),
                          trailing: Text(
                            '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                            style:
                                Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                      childCount: smartPlaylist.generatedTracks.length,
                    ),
                  ),
                ],

                // Bottom padding for player bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0 && d.inMinutes % 60 > 0) {
      return '${d.inHours}h${(d.inMinutes % 60).toString().padLeft(2, '0')}';
    } else if (d.inHours > 0) {
      return '${d.inHours}h00';
    } else {
      return '${d.inMinutes}min';
    }
  }
}

/// Preset card widget
class _PresetCard extends StatelessWidget {
  final String name;
  final String emoji;
  final SmartPlaylistConfig config;
  final VoidCallback onTap;

  const _PresetCard({
    required this.name,
    required this.emoji,
    required this.config,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationStr = config.totalDuration.inHours > 0
        ? '${config.totalDuration.inHours}h'
        : '${config.totalDuration.inMinutes}min';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.muted.withOpacity(0.15),
          border: Border.all(
            color: Theme.of(context).colorScheme.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              durationStr,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .foreground
                    .withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Freshness mode chip widget
class _FreshnessChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FreshnessChip({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .foreground
                    .withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

