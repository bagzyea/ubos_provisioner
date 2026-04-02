import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    final bg = isDark ? scheme.surfaceContainerHigh : scheme.surface;
    final border = isDark ? scheme.outlineVariant.withAlpha(90) : scheme.outlineVariant;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

class TwoPaneLayout extends StatelessWidget {
  final String leftTitle;
  final String rightTitle;
  final Widget left;
  final Widget right;

  const TwoPaneLayout({
    super.key,
    required this.leftTitle,
    required this.rightTitle,
    required this.left,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 1180;
    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TitledCard(title: leftTitle, child: left),
          const SizedBox(height: 12),
          TitledCard(title: rightTitle, child: right),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: TitledCard(title: leftTitle, child: left)),
        const SizedBox(width: 12),
        Expanded(child: TitledCard(title: rightTitle, child: right)),
      ],
    );
  }
}

class TitledCard extends StatelessWidget {
  final String title;
  final Widget child;

  const TitledCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ConfigSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const ConfigSection({
    super.key,
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const KeyValueRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const LabeledField({super.key, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
