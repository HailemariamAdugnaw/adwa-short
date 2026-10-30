import 'package:flutter/material.dart';

/// Clean, structured "Description" section matching the ADWA SHORT reference design.
///
/// Features a "Description" title header followed by numbered rules (1, 2, 3, 4)
/// formatted with bold lead titles and compact, readable slate-gray explanatory body text,
/// plus an optional agreement footer line.
class MonetizationDescriptionSection extends StatelessWidget {
  const MonetizationDescriptionSection({
    super.key,
    this.title = 'Description',
    required this.rules,
    this.footerPrefix,
    this.footerLink,
    this.onFooterTap,
  });

  final String title;
  final List<DescriptionRule> rules;
  final String? footerPrefix;
  final String? footerLink;
  final VoidCallback? onFooterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8FA3BF),
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          ...rules.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final rule = entry.value;

            return Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12.0,
                    height: 1.42,
                    color: Color(0xFF8A99AC),
                  ),
                  children: [
                    TextSpan(
                      text: '$index. ${rule.title}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9AAEC4),
                      ),
                    ),
                    TextSpan(
                      text: rule.body,
                      style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF7E8FAD),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (footerPrefix != null && footerLink != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onFooterTap,
              behavior: HitTestBehavior.opaque,
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF6B7D96),
                  ),
                  children: [
                    TextSpan(text: footerPrefix),
                    TextSpan(
                      text: footerLink,
                      style: const TextStyle(
                        color: Color(0xFF8FA3BF),
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DescriptionRule {
  const DescriptionRule({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}
