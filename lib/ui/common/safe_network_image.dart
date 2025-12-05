// lib/ui/common/safe_network_image.dart
//
// A "quiet" network image + precache helper that never throws for 404/IO
// errors or empty responses. It does *not* use Flutter's NetworkImage at all,
// so you won't see NetworkImageLoadException from these URLs.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Precaches a network image but NEVER throws (ignores 404/IO/decoding errors).
/// This fetches & decodes once, then disposes the image. It does *not* go
/// through Flutter's NetworkImage pipeline, so no NetworkImageLoadException.
Future<void> safePrecacheNetworkImage(
  BuildContext context,
  String? url, {
  double? cacheWidth,
  double? cacheHeight,
}) async {
  final String? parsedUrl = _normalizeUrl(url);
  if (parsedUrl == null) return;

  try {
    final Uint8List? bytes = await _fetchBytes(parsedUrl);
    if (bytes == null || bytes.isEmpty) return;

    final ui.Image img = await _decodeImage(
      bytes,
      targetWidth: cacheWidth?.round(),
      targetHeight: cacheHeight?.round(),
    );
    // We don't keep it around; this is just to warm network/decoding.
    img.dispose();
  } catch (_) {
    // Swallow everything – this is intentionally "safe".
  }
}

/// A rounded network image that falls back to a placeholder on error without
/// surfacing low-level network/decoding errors to the framework.
class SafeNetworkImage extends StatefulWidget {
  const SafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 10,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.loadingPlaceholder,
    this.errorPlaceholder,
    this.border,
    this.backgroundColor,
    this.alignment = Alignment.center,
    this.filterQuality,
  });

  /// Convenience ctor for non-cropping, letterboxed presentation.
  /// Uses `BoxFit.contain`, centers the image, and applies a light bg if none.
  const SafeNetworkImage.contain({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 10,
    this.placeholder,
    this.loadingPlaceholder,
    this.errorPlaceholder,
    this.border,
    Color? backgroundColor,
    this.alignment = Alignment.center,
    this.filterQuality,
  })  : fit = BoxFit.contain,
        backgroundColor = backgroundColor ?? const Color(0xFFF5F5F5);

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? loadingPlaceholder;
  final Widget? errorPlaceholder;
  final BoxBorder? border;
  final Color? backgroundColor;
  final Alignment alignment;
  final FilterQuality? filterQuality;

  @override
  State<SafeNetworkImage> createState() => _SafeNetworkImageState();
}

class _SafeNetworkImageState extends State<SafeNetworkImage> {
  ui.Image? _image;
  Object? _lastError;
  String? _normalizedUrl;
  bool _loading = false;

  // Simple token to ignore late results from an outdated request.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _normalizedUrl = _normalizeUrl(widget.url);
    _startLoad();
  }

  @override
  void didUpdateWidget(covariant SafeNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool urlChanged = widget.url != oldWidget.url;
    if (urlChanged) {
      _normalizedUrl = _normalizeUrl(widget.url);
      _startLoad();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  void _startLoad() {
    final String? url = _normalizedUrl;
    _loadToken++;
    final int token = _loadToken;

    if (url == null) {
      setState(() {
        _image?.dispose();
        _image = null;
        _lastError = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _lastError = null;
    });

    // Fire-and-forget async load – everything is caught inside.
    () async {
      try {
        final Uint8List? bytes = await _fetchBytes(url);
        if (!mounted || token != _loadToken) return;

        // Empty or null bytes: treat as error but don't throw.
        if (bytes == null || bytes.isEmpty) {
          setState(() {
            _image?.dispose();
            _image = null;
            _loading = false;
            _lastError = 'empty-image-bytes';
          });
          return;
        }

        final ui.Image img = await _decodeImage(
          bytes,
          targetWidth: widget.width?.round(),
          targetHeight: widget.height?.round(),
        );

        if (!mounted || token != _loadToken) {
          img.dispose();
          return;
        }

        setState(() {
          _image?.dispose();
          _image = img;
          _loading = false;
          _lastError = null;
        });
      } catch (e) {
        if (!mounted || token != _loadToken) return;
        setState(() {
          _image?.dispose();
          _image = null;
          _loading = false;
          _lastError = e;
        });
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final Color fallbackColor =
        widget.backgroundColor ?? Colors.white.withValues(alpha: 0.06);

    // Sanitize width/height so we never pass Infinity/NaN into layout.
    final double? safeWidth =
        (widget.width != null && widget.width!.isFinite && widget.width! > 0)
            ? widget.width
            : null;
    final double? safeHeight =
        (widget.height != null && widget.height!.isFinite && widget.height! > 0)
            ? widget.height
            : null;

    double fallbackSide = 48;
    if (safeWidth != null && safeHeight != null) {
      fallbackSide = safeWidth < safeHeight ? safeWidth : safeHeight;
    } else if (safeWidth != null) {
      fallbackSide = safeWidth;
    } else if (safeHeight != null) {
      fallbackSide = safeHeight;
    }
    if (!fallbackSide.isFinite || fallbackSide <= 0) {
      fallbackSide = 48;
    }

    Widget defaultPlaceholder() => Container(
          width: safeWidth,
          height: safeHeight,
          decoration: BoxDecoration(
            color: fallbackColor,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.border,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.image_not_supported_outlined,
            size: fallbackSide * 0.45,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        );

    final Widget loading =
        widget.loadingPlaceholder ?? widget.placeholder ?? defaultPlaceholder();
    final Widget errorWidget =
        widget.errorPlaceholder ?? widget.placeholder ?? defaultPlaceholder();
    final Widget emptyWidget = widget.placeholder ?? defaultPlaceholder();

    final String? normalizedUrl = _normalizedUrl;
    if (normalizedUrl == null) {
      return emptyWidget;
    }

    Widget child;
    if (_image != null) {
      child = RawImage(
        image: _image,
        width: safeWidth,
        height: safeHeight,
        fit: widget.fit,
        alignment: widget.alignment,
        filterQuality: widget.filterQuality ?? FilterQuality.low,
      );
    } else if (_lastError != null) {
      child = errorWidget;
    } else if (_loading) {
      child = loading;
    } else {
      // No URL / not loading / no image – treat like empty.
      child = emptyWidget;
    }

    Widget clipped = ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: child,
    );

    if (widget.border == null && widget.backgroundColor == null) {
      return clipped;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        border: widget.border,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: clipped,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String? _normalizeUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('http')) return null;

  final Uri? uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) return null;
  final String host = uri.host.toLowerCase();
  if (host.isEmpty) return null;

  // Legacy seed data pointed at example.com — skip to avoid noisy calls.
  if (host == 'example.com') return null;

  return uri.toString();
}

Future<Uint8List?> _fetchBytes(String url) async {
  try {
    final Uri uri = Uri.parse(url);
    final HttpClient client = HttpClient()..autoUncompress = true;
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        // For 404/500/etc we just bail quietly.
        return null;
      }
      // Use Flutter helper to collect bytes efficiently.
      final Uint8List bytes =
          await consolidateHttpClientResponseBytes(response);
      return bytes;
    } finally {
      client.close(force: true);
    }
  } catch (_) {
    // Swallow network/IO issues.
    return null;
  }
}

Future<ui.Image> _decodeImage(
  Uint8List bytes, {
  int? targetWidth,
  int? targetHeight,
}) async {
  final ui.ImmutableBuffer buffer =
      await ui.ImmutableBuffer.fromUint8List(bytes);
  final ui.ImageDescriptor descriptor =
      await ui.ImageDescriptor.encoded(buffer);
  final ui.Codec codec = await descriptor.instantiateCodec(
    targetWidth: targetWidth,
    targetHeight: targetHeight,
  );
  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;

  codec.dispose();
  descriptor.dispose();
  buffer.dispose();

  return image;
}
