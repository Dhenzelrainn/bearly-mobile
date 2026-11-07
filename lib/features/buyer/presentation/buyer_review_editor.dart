import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/bearly_theme.dart';
import '../../../core/widgets/product_thumbnail.dart';
import '../data/buyer_review_repository.dart';
import '../models/buyer_order_models.dart';

class BuyerReviewEditor extends StatefulWidget {
  const BuyerReviewEditor({
    super.key,
    required this.item,
    required this.repository,
    this.initialReview,
  });

  final BuyerOrderItemSnapshot item;
  final BuyerReviewRepository repository;
  final BuyerOrderReview? initialReview;

  @override
  State<BuyerReviewEditor> createState() => _BuyerReviewEditorState();
}

class _BuyerReviewEditorState extends State<BuyerReviewEditor> {
  late final TextEditingController _commentController = TextEditingController(
    text: widget.initialReview?.comment ?? '',
  );
  final ImagePicker _imagePicker = ImagePicker();
  int _rating = 0;
  XFile? _photo;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialReview?.rating ?? 0;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The photo could not be opened. Try again.');
      }
    }
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (_rating < 1) {
      setState(() => _error = 'Choose a star rating from 1 to 5.');
      return;
    }
    if (comment.isEmpty || comment.length > 500) {
      setState(() => _error = 'Write a review of up to 500 characters.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final photo = _photo;
      await widget.repository.submitReview(
        orderItemId: widget.item.id,
        rating: _rating,
        comment: comment,
        photoBytes: photo == null ? null : await photo.readAsBytes(),
        photoName: photo?.name,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = _messageFor(error);
        });
      }
    }
  }

  String _messageFor(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('409') || text.contains('conflict')) {
      return 'This order is not eligible yet. Refresh the order status and try again.';
    }
    if (text.contains('422') || text.contains('validation')) {
      return 'Check the star rating, review text, and optional photo, then try again.';
    }
    if (text.contains('404') || text.contains('not found')) {
      return 'Bearly could not verify this purchase. Refresh your order details.';
    }
    return 'Bearly could not save the review. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final existingPhoto = widget.initialReview?.photoUrl;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initialReview == null
                    ? 'Review this purchase'
                    : 'Update your review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.productName,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var star = 1; star <= 5; star++)
                    IconButton(
                      key: ValueKey('buyer-review-star-$star'),
                      tooltip: '$star star${star == 1 ? '' : 's'}',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _rating = star),
                      icon: Icon(
                        star <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: BearlyColors.gold,
                        size: 34,
                      ),
                    ),
                ],
              ),
              TextField(
                key: const ValueKey('buyer-review-comment'),
                controller: _commentController,
                enabled: !_saving,
                maxLength: 500,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Your review',
                  hintText: 'Share what you thought about the product.',
                  border: OutlineInputBorder(),
                ),
              ),
              if (existingPhoto != null &&
                  existingPhoto.isNotEmpty &&
                  _photo == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ProductThumbnail(imageUrl: existingPhoto, size: 48),
                      const SizedBox(width: 10),
                      const Text('Current review photo'),
                    ],
                  ),
                ),
              if (_photo case final photo?)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.image_outlined,
                        color: BearlyColors.brown500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove photo',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _photo = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _choosePhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add photo (optional)'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  key: const ValueKey('buyer-review-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('buyer-review-submit'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        widget.initialReview == null
                            ? 'Submit review'
                            : 'Save changes',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
