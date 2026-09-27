import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';

enum DocumentSource {
  camera,
  gallery,
  pdf,
}

class DocumentSourceSheet extends StatelessWidget {
  const DocumentSourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload document',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Take a clear photo, choose an existing image, or attach a PDF.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _SourceTile(
              icon: Icons.photo_camera_outlined,
              title: 'Take a photo',
              subtitle: 'Use your camera to capture the document.',
              onTap: () => Navigator.pop(context, DocumentSource.camera),
            ),
            _SourceTile(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle: 'Select an existing JPG or PNG image.',
              onTap: () => Navigator.pop(context, DocumentSource.gallery),
            ),
            _SourceTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Choose PDF',
              subtitle: 'Select a PDF file up to 5 MB.',
              onTap: () => Navigator.pop(context, DocumentSource.pdf),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: BearlyColors.lineSoft),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: BearlyColors.cream100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: BearlyColors.brown900),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
