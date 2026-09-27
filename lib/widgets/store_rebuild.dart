import 'package:flutter/widgets.dart';

/// Rebuilds a pushed screen whenever [rebuildSource] notifies.
///
/// Routes pushed onto a Navigator cache their page, so a screen that shows
/// store data (or theme colors) must listen for changes itself.
mixin RebuildOn<T extends StatefulWidget> on State<T> {
  Listenable get rebuildSource;

  @override
  void initState() {
    super.initState();
    rebuildSource.addListener(_onChanged);
  }

  @override
  void dispose() {
    rebuildSource.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }
}
