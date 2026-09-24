import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/theme/bearly_theme.dart';

class SpriteAtlasImage extends StatefulWidget {
  const SpriteAtlasImage({
    super.key,
    required this.assetPath,
    required this.cell,
    required this.rows,
    this.columns = 4,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  final String assetPath;
  final int cell;
  final int rows;
  final int columns;
  final BorderRadius borderRadius;

  @override
  State<SpriteAtlasImage> createState() => _SpriteAtlasImageState();
}

class _SpriteAtlasImageState extends State<SpriteAtlasImage> {
  ImageStream? _stream;
  ImageInfo? _imageInfo;
  bool _failed = false;
  late final ImageStreamListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener(
      _handleImage,
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SpriteAtlasImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _imageInfo = null;
    _failed = false;
    final stream = AssetImage(widget.assetPath).resolve(createLocalImageConfiguration(context));
    _stream = stream;
    stream.addListener(_listener);
  }

  void _handleImage(ImageInfo info, bool synchronousCall) {
    if (mounted) setState(() => _imageInfo = info);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: ColoredBox(
        color: BearlyColors.cream200,
        child: _failed
            ? const Center(child: Icon(Icons.image_not_supported_outlined, color: BearlyColors.muted))
            : _imageInfo == null
                ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                : CustomPaint(
                    painter: _SpritePainter(
                      image: _imageInfo!.image,
                      cell: widget.cell,
                      rows: widget.rows,
                      columns: widget.columns,
                    ),
                    child: const SizedBox.expand(),
                  ),
      ),
    );
  }
}

class _SpritePainter extends CustomPainter {
  const _SpritePainter({required this.image, required this.cell, required this.rows, required this.columns});
  final ui.Image image;
  final int cell;
  final int rows;
  final int columns;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCell = (rows * columns) - 1;
    final safeCell = cell < 0 ? 0 : (cell > maxCell ? maxCell : cell);
    final column = safeCell % columns;
    final row = safeCell ~/ columns;
    final sourceWidth = image.width / columns;
    final sourceHeight = image.height / rows;
    final src = Rect.fromLTWH(column * sourceWidth, row * sourceHeight, sourceWidth, sourceHeight);
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant _SpritePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.cell != cell || oldDelegate.rows != rows || oldDelegate.columns != columns;
}
