import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:poseit/providers/settings_provider.dart';
import 'package:poseit/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return CustomScrollView(
            slivers: [
              const SliverAppBar(
                floating: true,
                automaticallyImplyLeading: false,
                title: Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 8),

                  // Appearance Section
                  _SectionTitle(title: 'Appearance'),

                  // Dark Mode
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Switch between light and dark theme'),
                    secondary: Icon(
                      settings.isDarkMode
                          ? Icons.dark_mode
                          : Icons.light_mode,
                      color: AppTheme.primaryColor,
                    ),
                    value: settings.isDarkMode,
                    onChanged: (value) => settings.setDarkMode(value),
                  ),

                  // Grid Columns
                  ListTile(
                    leading: const Icon(Icons.grid_view,
                        color: AppTheme.primaryColor),
                    title: const Text('Grid Columns'),
                    subtitle: Text('${settings.gridColumns} columns'),
                    trailing: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 2, label: Text('2')),
                        ButtonSegment(value: 3, label: Text('3')),
                      ],
                      selected: {settings.gridColumns},
                      onSelectionChanged: (value) {
                        settings.setGridColumns(value.first);
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // Camera Section
                  _SectionTitle(title: 'Camera'),

                  // Timer Duration
                  ListTile(
                    leading: const Icon(Icons.timer,
                        color: AppTheme.primaryColor),
                    title: const Text('Timer Duration'),
                    subtitle:
                        Text(_timerLabel(settings.timerDuration)),
                    trailing: DropdownButton<int>(
                      value: settings.timerDuration,
                      underline: const SizedBox(),
                      items: SettingsProvider.timerOptions.map((seconds) {
                        return DropdownMenuItem(
                          value: seconds,
                          child: Text(_timerLabel(seconds)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settings.setTimerDuration(value);
                        }
                      },
                    ),
                  ),

                  // Overlay Opacity
                  ListTile(
                    leading: const Icon(Icons.opacity,
                        color: AppTheme.primaryColor),
                    title: const Text('Overlay Opacity'),
                    subtitle: Text(
                        '${(settings.overlayOpacity * 100).round()}%'),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Slider(
                      value: settings.overlayOpacity,
                      min: 0.2,
                      max: 0.8,
                      divisions: 12,
                      label:
                          '${(settings.overlayOpacity * 100).round()}%',
                      onChanged: (value) {
                        settings.setOverlayOpacity(value);
                      },
                    ),
                  ),

                  const Divider(indent: 16, endIndent: 16),

                  // About Section
                  _SectionTitle(title: 'About'),

                  // About
                  ListTile(
                    leading: const Icon(Icons.info_outline,
                        color: AppTheme.primaryColor),
                    title: const Text('About PoseIt'),
                    subtitle: const Text('Version 1.0.0'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'PoseIt',
                        applicationVersion: '1.0.0',
                        applicationIcon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.accentColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        children: [
                          const Text(
                            'PoseIt helps you strike the perfect pose for your photos. '
                            'Browse through curated poses, use the camera overlay to match '
                            'silhouettes, and capture stunning shots every time.',
                          ),
                        ],
                      );
                    },
                  ),

                  // Rate App
                  ListTile(
                    leading: const Icon(Icons.star_outline,
                        color: AppTheme.primaryColor),
                    title: const Text('Rate App'),
                    subtitle: const Text('Love PoseIt? Leave a review!'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Thanks! Store link coming soon.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),

                  // Share App
                  ListTile(
                    leading: const Icon(Icons.share,
                        color: AppTheme.primaryColor),
                    title: const Text('Share App'),
                    subtitle:
                        const Text('Tell your friends about PoseIt'),
                    onTap: () {
                      Share.share(
                        '📸 Check out PoseIt - the ultimate pose guide app! '
                        'Get perfect poses for your photos every time. '
                        'Download now: https://poseit.app',
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _timerLabel(int seconds) {
    if (seconds == 0) return 'Off';
    return '${seconds}s';
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
