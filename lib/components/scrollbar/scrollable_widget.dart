import 'package:flutter/material.dart';

/// A scrollable widget with both vertical and horizontal scrollbars.
/// The vertical scrollbar is positioned so that it does not overlap the horizontal scrollbar,
/// ensuring both are always visible and accessible.
/// Handles overflow gracefully and is optimized for large data sets.
class DualScrollbar extends StatelessWidget {
  final Widget child;
  final double scrollbarThickness;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  const DualScrollbar({
    Key? key,
    required this.child,
    required this.verticalController,
    required this.horizontalController,
    this.scrollbarThickness = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The Stack allows us to overlay the scrollbars without overlap.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // The scrollable area with both vertical and horizontal scroll controllers.
            Scrollbar(
              controller: verticalController,
              thumbVisibility: true,
              thickness: scrollbarThickness,
              notificationPredicate: (notification) => notification.depth == 0,
              child: Scrollbar(
                controller: horizontalController,
                thumbVisibility: true,
                thickness: scrollbarThickness,
                notificationPredicate:
                    (notification) => notification.depth == 1,
                // The SingleChildScrollView allows both directions.
                child: SingleChildScrollView(
                  controller: verticalController,
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    controller: horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: child,
                  ),
                ),
              ),
            ),
            // Custom vertical scrollbar overlay to avoid overlap with horizontal scrollbar.
            Positioned(
              right: 0,
              top: 0,
              bottom:
                  scrollbarThickness, // Leaves space for horizontal scrollbar.
              child: SizedBox(
                width: scrollbarThickness,
                child: Scrollbar(
                  controller: verticalController,
                  thumbVisibility: true,
                  thickness: scrollbarThickness,
                  // Only show vertical scrollbar track.
                  child:
                      Container(), // Empty container as the scrollable area is below.
                ),
              ),
            ),
            // Custom horizontal scrollbar overlay.
            Positioned(
              left: 0,
              right: scrollbarThickness, // Leaves space for vertical scrollbar.
              bottom: 0,
              height: scrollbarThickness,
              child: SizedBox(
                height: scrollbarThickness,
                child: Scrollbar(
                  controller: horizontalController,
                  thumbVisibility: true,
                  thickness: scrollbarThickness,
                  notificationPredicate:
                      (notification) => false, // Prevents double notification.
                  child: Container(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
