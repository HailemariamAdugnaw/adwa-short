import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Highly tuned vertical video snap-scroll physics for short-form video feeds
/// (matching TikTok, GoodShort, and ShortMax).
///
/// Features:
/// 1. Low flick velocity threshold (~60 px/s vs Flutter default >200 px/s)
///    allowing effortless light flicks to snap forward or backward.
/// 2. Reduced drag commit ratio (~18% of screen height vs Flutter default 50%)
///    so short, gentle drags automatically snap to the next video without springing back.
/// 3. Critically damped, snappy spring dynamics (stiffness: 260, damping: 28)
///    delivering a crisp ~200ms transition without sluggish delay or wobble.
/// 4. Elastic boundary bounce when combined with [BouncingScrollPhysics].
class SmoothVideoSnapScrollPhysics extends PageScrollPhysics {
  const SmoothVideoSnapScrollPhysics({super.parent});

  @override
  SmoothVideoSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SmoothVideoSnapScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => const SpringDescription(
        mass: 0.8,
        stiffness: 260.0,
        damping: 28.0,
      );

  @override
  Tolerance toleranceFor(ScrollMetrics metrics) {
    return const Tolerance(
      velocity: 60.0,
      distance: 0.5,
    );
  }

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics && position.page != null) {
      return position.page!;
    }
    final viewport = position.viewportDimension;
    return viewport > 0 ? (position.pixels / viewport) : 0.0;
  }

  double _getPixels(ScrollMetrics position, double page) {
    return page * position.viewportDimension;
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // Let parent handle overscroll bouncing when pulling past the ends
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final viewport = position.viewportDimension;
    if (viewport <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    final double currentPage = _getPage(position);
    final int basePage = currentPage.floor();
    final double pageFraction = currentPage - basePage;

    double targetPage;

    // 1. Light Flick / Fling Handling
    if (velocity.abs() > tolerance.velocity) {
      if (velocity < -tolerance.velocity) {
        // Flick downward: navigate to previous page
        targetPage =
            pageFraction > 0.05 ? basePage.toDouble() : (basePage - 1).toDouble();
      } else {
        // Flick upward: navigate to next page
        targetPage =
            pageFraction < 0.95 ? (basePage + 1).toDouble() : (basePage + 2).toDouble();
      }
    } else {
      // 2. Slow / Short Drag Handling (No Fling)
      // Check userScrollDirection if available to support symmetric ~18% commit in both directions
      if (position is ScrollPosition &&
          position.userScrollDirection == ScrollDirection.forward) {
        // Dragging downward (toward previous page)
        if ((1.0 - pageFraction) > 0.18) {
          targetPage = basePage.toDouble();
        } else {
          targetPage = (basePage + 1).toDouble();
        }
      } else {
        // Dragging upward (toward next page) or fallback
        if (pageFraction > 0.18) {
          targetPage = (basePage + 1).toDouble();
        } else {
          targetPage = basePage.toDouble();
        }
      }
    }

    final minPage = (position.minScrollExtent / viewport).roundToDouble();
    final maxPage = (position.maxScrollExtent / viewport).roundToDouble();
    targetPage = targetPage.clamp(minPage, maxPage);

    final double targetPixels = _getPixels(position, targetPage);
    if (targetPixels != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }
}
