import 'package:flutter/material.dart';

/// Loads the first available image URL and advances through the remaining
/// candidates when a CDN or a patch-specific asset is unavailable.
class ResilientNetworkImage extends StatefulWidget {
  const ResilientNetworkImage({
    super.key,
    required this.urls,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final Iterable<String?> urls;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;

  @override
  State<ResilientNetworkImage> createState() => _ResilientNetworkImageState();
}

class _ResilientNetworkImageState extends State<ResilientNetworkImage> {
  late List<String> _urls;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _urls = _validUrls(widget.urls);
  }

  @override
  void didUpdateWidget(covariant ResilientNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _validUrls(widget.urls);
    if (!_sameUrls(_urls, next)) {
      _urls = next;
      _index = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _urls.length) return widget.fallback;
    return Image.network(
      _urls[_index],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Stack(fit: StackFit.expand, children: [widget.fallback, child]);
      },
      errorBuilder: (_, _, _) {
        if (_index + 1 < _urls.length) {
          final failedIndex = _index;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _index == failedIndex) {
              setState(() => _index = failedIndex + 1);
            }
          });
        }
        return widget.fallback;
      },
    );
  }
}

List<String> _validUrls(Iterable<String?> values) {
  final result = <String>[];
  for (final value in values) {
    final url = value?.trim() ?? '';
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        result.contains(url)) {
      continue;
    }
    result.add(url);
  }
  return result;
}

bool _sameUrls(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

String? communityDragonChampionIcon(int championId) => championId > 0
    ? 'https://raw.communitydragon.org/latest/plugins/'
          'rcp-be-lol-game-data/global/default/v1/champion-icons/'
          '$championId.png'
    : null;
