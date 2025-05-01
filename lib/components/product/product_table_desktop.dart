// import 'package:flutter/material.dart';
// import 'product.dart';

// /// Desktop-specific implementation of product table
// class ProductTableDesktop {
//   /// Initialize desktop column widths
//   static List<double> initializeColumnWidths() {
//     List<double> columnWidths = List.filled(12, 120.0);

//     columnWidths[0] = 80.0; // ID column
//     columnWidths[1] = 120.0; // Created At column
//     columnWidths[2] = 70.0; // Image column
//     columnWidths[3] = 250.0; // Product name column
//     columnWidths[4] = 300.0; // Price column
//     columnWidths[5] = 350.0; // Description column
//     columnWidths[6] = 80.0; // Discount column
//     columnWidths[7] = 120.0; // Category 1
//     columnWidths[8] = 120.0; // Category 2
//     columnWidths[9] = 70.0; // Popular
//     columnWidths[10] = 150.0; // Matching Words
//     columnWidths[11] = 100.0; // Actions

//     return columnWidths;
//   }

//   /// Build the desktop table layout
//   static Widget buildTable({
//     required List<String> titles,
//     required List<double> columnWidths,
//     required double rowHeight,
//     required ScrollController verticalScrollController,
//     required Widget Function(String, int, TextStyle) buildColumnHeader,
//     required Widget Function(bool) buildTableRows,
//   }) {
//     final tableHeaderStyle = const TextStyle(
//       fontSize: 13.0,
//       fontWeight: FontWeight.bold,
//     );

//     return Column(
//       children: [
//         // Header row (fixed, no horizontal scroll)
//         Table(
//           border: TableBorder.all(color: Colors.grey),
//           columnWidths: columnWidths.asMap().map(
//             (i, w) => MapEntry(i, FixedColumnWidth(w)),
//           ),
//           defaultVerticalAlignment: TableCellVerticalAlignment.middle,
//           children: [
//             TableRow(
//               decoration: BoxDecoration(color: Colors.grey[200]),
//               children: List.generate(titles.length, (i) {
//                 return buildColumnHeader(titles[i], i, tableHeaderStyle);
//               }),
//             ),
//           ],
//         ),

//         // Scrollable data rows
//         Expanded(
//           child: SingleChildScrollView(
//             controller: verticalScrollController,
//             scrollDirection: Axis.vertical,
//             child: buildTableRows(false), // false indicates desktop
//           ),
//         ),
//       ],
//     );
//   }

//   /// Build desktop-friendly action buttons
//   static Widget buildActionButtons({
//     required BuildContext context,
//     required Product product,
//     required Function(Product) onEdit,
//     required Function(BuildContext, Product) onDelete,
//   }) {
//     // Fix overflow by using a SizedBox with constrained width and spacing
//     return SizedBox(
//       width: 90, // Fixed width to prevent overflow
//       child: Row(
//         mainAxisSize: MainAxisSize.min, // Take minimum space needed
//         mainAxisAlignment:
//             MainAxisAlignment.spaceEvenly, // Evenly distribute space
//         children: [
//           // Use smaller buttons with less padding
//           SizedBox(
//             width: 40,
//             height: 40,
//             child: IconButton(
//               padding: EdgeInsets.zero, // Remove padding
//               constraints: const BoxConstraints(), // Remove constraints
//               icon: const Icon(Icons.edit, size: 20),
//               onPressed: () => onEdit(product),
//             ),
//           ),
//           SizedBox(
//             width: 40,
//             height: 40,
//             child: IconButton(
//               padding: EdgeInsets.zero, // Remove padding
//               constraints: const BoxConstraints(), // Remove constraints
//               icon: const Icon(Icons.delete, size: 20, color: Colors.red),
//               onPressed: () => onDelete(context, product),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Get text style for desktop
//   static TextStyle getTextStyle() {
//     return const TextStyle(fontSize: 13.0);
//   }

//   /// Get appropriate row height for desktop
//   static double getRowHeight() {
//     return 100.0;
//   }

//   /// Get max width for text constraints based on column
//   static double getMaxWidthForColumn(int columnIndex) {
//     switch (columnIndex) {
//       case 3:
//         return 250.0; // Product name
//       case 5:
//         return 300.0; // Description
//       case 7:
//         return 120.0; // Category 1
//       case 8:
//         return 120.0; // Category 2
//       case 10:
//         return 150.0; // Matching Words
//       default:
//         return 120.0;
//     }
//   }

//   /// Get max lines for text based on column
//   static int getMaxLinesForColumn(int columnIndex) {
//     switch (columnIndex) {
//       case 3:
//         return 3; // Product name
//       case 5:
//         return 3; // Description
//       default:
//         return 1;
//     }
//   }
// }
