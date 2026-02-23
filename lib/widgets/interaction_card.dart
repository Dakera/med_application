import 'package:flutter/material.dart';
import '../classes/interaction.dart';

class InteractionCard extends StatelessWidget {
  final Interaction interaction;

  const InteractionCard({
    super.key,
    required this.interaction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ListTile(
        title: Text('${interaction.drugA} + ${interaction.drugB}'),
        subtitle: Text('Severity: ${interaction.severity}'),
        leading: const Icon(Icons.warning, color: Colors.red),
      ),
    );
  }
}