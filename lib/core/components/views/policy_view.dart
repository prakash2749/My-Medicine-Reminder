import 'package:flutter/material.dart';

import '../../l10n/app_copy.dart';
import '../../models/policy_content.dart';

class PolicyLink extends StatelessWidget {
  const PolicyLink({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        key: const Key('privacy-support-link'),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => const PolicyView())),
        icon: const Icon(Icons.privacy_tip_outlined),
        label: const AppText('Privacy and support'),
      );
}

class PolicyView extends StatefulWidget {
  const PolicyView({super.key});

  @override
  State<PolicyView> createState() => _PolicyViewState();
}

class _PolicyViewState extends State<PolicyView> {
  AssetBundle? _bundle;
  late Future<PolicyContent?> _content;
  String _page = 'privacy';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (_bundle == bundle) return;
    _bundle = bundle;
    _load();
  }

  void _load() {
    _content = _readContent();
  }

  Future<PolicyContent?> _readContent() async {
    try {
      // Failed loads must not stay in the bundle's string cache on Retry.
      return PolicyContent.decode(
          await _bundle!.loadString(PolicyContent.assetPath, cache: false));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language =
        Localizations.localeOf(context).languageCode == 'hi' ? 'hi' : 'en';
    return Scaffold(
      appBar: AppBar(title: const AppText('Privacy and support')),
      body: FutureBuilder<PolicyContent?>(
        future: _content,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasData) {
            return ListView(padding: const EdgeInsets.all(24), children: [
              const AppText('Could not open the offline notice. Please retry.'),
              TextButton(
                  onPressed: () => setState(_load),
                  child: const AppText('Retry')),
            ]);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final page = snapshot.data!.pages[_page]!;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Wrap(spacing: 12, runSpacing: 8, children: [
                for (final entry in snapshot.data!.pages.entries)
                  ChoiceChip(
                    key: ValueKey('policy-${entry.key}'),
                    selected: _page == entry.key,
                    label: Text(entry.value.title[language]!),
                    onSelected: (_) => setState(() => _page = entry.key),
                  ),
              ]),
            ),
            Expanded(
                child: ListView(
              key: ValueKey(_page),
              padding: const EdgeInsets.all(24),
              children: [
                if (snapshot.data!.revision.contains('draft'))
                  const AppText(
                      'Unpublished test notice. Operator and contact details are not configured.'),
                const SizedBox(height: 24),
                for (final section in page.sections) ...[
                  Semantics(
                    header: true,
                    child: Text(section.title[language]!,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 8),
                  Text(section.body[language]!),
                  const SizedBox(height: 24),
                ],
              ],
            )),
          ]);
        },
      ),
    );
  }
}
