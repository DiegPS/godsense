import 'package:flutter/material.dart';
import 'package:flutter_consistent_ui/flutter_consistent_ui.dart';

import 'gs_tokens.dart';

/// Scrollable feature content below the shared application navigation.
class GsFeaturePage extends StatelessWidget {
  const GsFeaturePage({
    super.key,
    required this.children,
    this.scrollController,
  });

  final List<Widget> children;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => UiPage(
    // Keep the viewport at the edges and the scrollbar outside card surfaces.
    padding: EdgeInsets.zero,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth > GsSizes.maxPageWidth
            ? (constraints.maxWidth - GsSizes.maxPageWidth) / 2
            : 0.0;
        // Center the cards inside a viewport that still reaches the window edge.
        return ListView(
          controller: scrollController,
          padding:
              GsSizes.pageInsets(context) +
              EdgeInsets.symmetric(horizontal: extra),
          children: children,
        );
      },
    ),
  );
}
