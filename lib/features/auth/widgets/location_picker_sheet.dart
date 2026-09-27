import 'package:flutter/material.dart';

import '../../../core/theme/bearly_theme.dart';
import '../data/psgc_service.dart';

class LocationPickerField extends StatelessWidget {
  const LocationPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onSelected,
  });

  final String label;
  final LocationOption? value;
  final List<LocationOption> items;
  final bool enabled;
  final ValueChanged<LocationOption> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled
          ? () async {
              final result = await showModalBottomSheet<LocationOption>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                showDragHandle: true,
                backgroundColor: BearlyColors.cream50,
                builder: (_) => LocationPickerSheet(
                  title: label,
                  items: items,
                  selected: value,
                ),
              );
              if (result != null) onSelected(result);
            }
          : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(
          value?.name ?? (enabled ? 'Select $label' : 'Select previous field first'),
          style: TextStyle(
            color: value == null ? BearlyColors.muted : BearlyColors.text,
          ),
        ),
      ),
    );
  }
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selected,
  });

  final String title;
  final List<LocationOption> items;
  final LocationOption? selected;

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = widget.items
        .where((item) => q.isEmpty || item.name.toLowerCase().contains(q))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.toLowerCase()}',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching locations.'))
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          trailing: item.code == widget.selected?.code
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: BearlyColors.brown900,
                                )
                              : null,
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
