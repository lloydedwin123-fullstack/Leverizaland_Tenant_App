import 'package:flutter/material.dart';

class PropertyCard extends StatelessWidget {
  final String title;
  final String tenantName;
  final String rentText;
  final String? balanceText;
  final String? coverageText;
  final VoidCallback? onTap;

  const PropertyCard({
    super.key,
    required this.title,
    required this.tenantName,
    required this.rentText,
    this.balanceText,
    this.coverageText,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Tenant
              _buildInfoRow(context, Icons.person, 'Tenant:', tenantName),
              const SizedBox(height: 4),
              // Rent
              _buildInfoRow(context, Icons.payment, 'Rent Amount:', rentText),
              const SizedBox(height: 4),
              // Balance (optional)
              if (balanceText != null)
                _buildInfoRow(
                  context,
                  Icons.warning_amber_rounded,
                  'Balance:',
                  balanceText!,
                  valueColor: colorScheme.error,
                ),
              // Coverage (optional)
              if (coverageText != null && coverageText!.trim().isNotEmpty)
                _buildInfoRow(context, Icons.date_range, 'Coverage:', coverageText!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor}) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: colorScheme.onSurface.withOpacity(0.6)),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.6)),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
