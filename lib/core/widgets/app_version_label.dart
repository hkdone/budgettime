import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_version_provider.dart';

/// Affiche la version de l'app (ex. `v2.4.26`) depuis le build Flutter.
class AppVersionLabel extends ConsumerWidget {
  const AppVersionLabel({
    super.key,
    this.style,
    this.textAlign,
    this.prefix = 'v',
  });

  final TextStyle? style;
  final TextAlign? textAlign;
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);

    return versionAsync.when(
      data: (version) => Text(
        '$prefix$version',
        style: style,
        textAlign: textAlign,
      ),
      loading: () => Text(
        '${prefix}…',
        style: style,
        textAlign: textAlign,
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
