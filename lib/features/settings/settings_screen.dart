import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_controller.dart';
import '../../shared/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(appProvider);
    return StudioScaffold(
      tab: 2,
      child: ListView(
        children: [
          const SizedBox(height: 16),
          const Eyebrow('A quieter studio', accent: true),
          const SizedBox(height: 12),
          Text(
            'Make yourself at home.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SectionTitle('Appearance'),
          Surface(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: app.theme,
                  decoration: const InputDecoration(labelText: 'App theme'),
                  items: const [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text('Follow device'),
                    ),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (v) =>
                      safely(context, () => app.setPreference('theme', v!)),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion'),
                  subtitle: const Text(
                    'Device accessibility settings are also respected.',
                  ),
                  value: app.reduceMotion,
                  onChanged: (v) => safely(
                    context,
                    () => app.setPreference('reduceMotion', '$v'),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle('A note on compatibility'),
          const Tip(
            'Text is a tiny canvas. More columns preserve more shapes but create longer messages. Conversion is not lossless and cannot recover detail missing from the source.',
          ),
          const SizedBox(height: 12),
          const Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Every destination is a little different',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Profiles use adjustable estimates for width and message length, not guaranteed platform limits. Font metrics, Unicode glyphs, spaces, line wrapping, account tiers, and app versions can all change the result.',
                ),
                SizedBox(height: 12),
                Text(
                  'Only Discord has an optional documented code-block wrapper in this app. Other profiles send plain text. The destination preview is an approximation of available width, not an exact third-party rendering.',
                ),
                SizedBox(height: 12),
                Text(
                  'Budgets conservatively count UTF-16 units, including newlines, wrappers, and labels. Character counts report Unicode code points. Splits always keep whole rows; separate messages may interrupt visual continuity.',
                ),
              ],
            ),
          ),
          const SectionTitle('Your images stay yours'),
          const Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No accounts, analytics, or uploads',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Images, thumbnails, text, and preferences live in app storage. Sharing opens your operating system’s share sheet; you choose where anything goes. Removing the app removes its local collection. Keep .txt exports for backup.',
                ),
                SizedBox(height: 12),
                Text(
                  'PNG, JPEG, and WebP are decoded locally. Animated images use the first frame. HEIC, SVG, RAW, and PDF are not supported. Limits: 24 MB encoded, 16 megapixels, 240 columns, and 160,000 cells.',
                ),
              ],
            ),
          ),
          const SectionTitle('Working with type'),
          const Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A good starting point',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Use a clearly lit subject with a simple background. Try High detail for a portrait, Silhouette for logos, and Smooth shading for gradients. Braille stores a 2 × 4 dot grid in each character. Dithering helps tones but can add noise.',
                ),
                SizedBox(height: 12),
                Text(
                  'The preview uses a bundled monospace font at a 0.5 cell aspect ratio by default. Adjust cell aspect for your target font. Dark preview paper changes display colors only; Invert changes the exported glyphs.',
                ),
                SizedBox(height: 12),
                Text(
                  'Custom ramps run from light to dense. Use printable ASCII, box/block, or Braille glyphs. Combining marks and emoji are excluded because their cell widths are unreliable.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Center(child: Eyebrow('GLYPHICA · OFFLINE BY DESIGN · 1.0.0')),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
