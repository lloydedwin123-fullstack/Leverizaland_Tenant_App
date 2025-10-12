import 'package:flutter/material.dart';

class PropertyCard extends StatelessWidget {
  final String title;                // e.g., "Opal 1" or "ADL Building"
  final String tenantName;           // "Vacant" or actual name
  final String rentText;             // formatted "₱.."
  final String? balanceText;         // formatted "₱.." (null to hide)
  final String? coverageText;        // e.g., "January to March 2025"
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
    final Color? balanceColor = (balanceText == null)
        ? null
        : const Color(0xFFB33A3A); // soft, non-irritating red

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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              // Tenant
              Text('Tenant: $tenantName'),
              // Rent
              Text('Rent Amount: $rentText'),
              // Balance (optional)
              if (balanceText != null)
                Text(
                  'Balance: $balanceText',
                  style: TextStyle(
                    color: balanceColor,
                    fontWeight: FontWeight.w700, // slightly bolder than normal
                  ),
                ),
              // Coverage (optional)
              if (coverageText != null && coverageText!.trim().isNotEmpty)
                Text('Coverage: $coverageText'),
            ],
          ),
        ),
      ),
    );
  }
}
