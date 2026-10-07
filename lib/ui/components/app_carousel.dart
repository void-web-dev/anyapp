import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';

class AppCarousel extends StatefulWidget {
  const AppCarousel({
    super.key,
    required this.children,
    this.height = 180,
    this.viewportFraction = 0.9,
  });

  final List<Widget> children;
  final double height;
  final double viewportFraction;

  @override
  State<AppCarousel> createState() => _AppCarouselState();
}

class _AppCarouselState extends State<AppCarousel> {
  late final PageController _controller = PageController(
    viewportFraction: widget.viewportFraction,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.children.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: widget.children[index],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              size: AppButtonSize.icon,
              variant: AppButtonVariant.outline,
              onPressed: _page > 0
                  ? () => _controller.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              child: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 12),
            for (var index = 0; index < widget.children.length; index++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: index == _page ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: index == _page
                      ? context.colors.primary
                      : context.colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            const SizedBox(width: 12),
            AppButton(
              size: AppButtonSize.icon,
              variant: AppButtonVariant.outline,
              onPressed: _page < widget.children.length - 1
                  ? () => _controller.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    )
                  : null,
              child: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
