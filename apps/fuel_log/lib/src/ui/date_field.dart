import 'package:flutter/material.dart';

import 'format.dart';

class DateField extends StatelessWidget {
  const DateField({super.key, required this.controller, required this.label, this.fieldKey});
  final TextEditingController controller;
  final String label;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => TextFormField(
    key: fieldKey,
    controller: controller,
    keyboardType: TextInputType.datetime,
    decoration: InputDecoration(
      labelText: label,
      hintText: 'YYYY-MM-DD',
      suffixIcon: IconButton(
        icon: const Icon(Icons.calendar_today),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: parseIsoDate(controller.text) ?? DateTime.now(),
            firstDate: DateTime(1990),
            lastDate: DateTime(2100),
          );
          if (d != null) controller.text = isoDate(d);
        },
      ),
    ),
    validator: (v) => parseIsoDate(v ?? '') == null ? 'Use a date like 2026-09-01' : null,
  );
}
