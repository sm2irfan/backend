// import 'package:flutter/material.dart';
// import 'product.dart';

// /// Mobile-specific implementation of product table
// class ProductTableMobile {
//   /// Initialize mobile column widths
//   static List<double> initializeColumnWidths() {
//     List<double> columnWidths = List.filled(12, 120.0);

//     columnWidths[0] = 50.0; // ID column
//     columnWidths[1] = 80.0; // Created At column
//     columnWidths[2] = 50.0; // Image column
//     columnWidths[3] = 150.0; // Product name column
//     columnWidths[4] = 70.0; // Price column
//     columnWidths[5] = 150.0; // Description column
//     columnWidths[6] = 60.0; // Discount column
//     columnWidths[7] = 80.0; // Category 1
//     columnWidths[8] = 80.0; // Category 2
//     columnWidths[9] = 50.0; // Popular
//     columnWidths[10] = 100.0; // Matching Words
//     columnWidths[11] = 100.0; // Actions - Increased for mobile

//     return columnWidths;
//   }

//   /// Build the mobile table layout
//   static Widget buildTable({
//     required List<String> titles,
//     required List<double> columnWidths,
//     required double rowHeight,
//     required ScrollController verticalScrollController,
//     required Widget Function(String, int, TextStyle) buildColumnHeader,
//     required Widget Function(bool) buildTableRows,
//   }) {
//     final tableHeaderStyle = const TextStyle(
//       fontSize: 11.0,
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
//             child: buildTableRows(true), // true indicates mobile
//           ),
//         ),
//       ],
//     );
//   }

//   /// Build mobile-friendly action buttons
//   static Widget buildActionButtons({
//     required BuildContext context,
//     required Product product,
//     required Function(Product) onEdit,
//     required Function(BuildContext, Product) onDelete,
//   }) {
//     return Padding(
//       padding: EdgeInsets.zero,
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Edit button (smaller on mobile)
//           GestureDetector(
//             onTap: () => onEdit(product),
//             child: Container(
//               width: 36,
//               height: 36,
//               padding: const EdgeInsets.all(8),
//               child: const Icon(Icons.edit, size: 18),
//             ),
//           ),
//           // Delete button (smaller on mobile)
//           GestureDetector(
//             onTap: () => onDelete(context, product),
//             child: Container(
//               width: 36,
//               height: 36,
//               padding: const EdgeInsets.all(8),
//               child: const Icon(Icons.delete, size: 18, color: Colors.red),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   /// Get text style for mobile
//   static TextStyle getTextStyle() {
//     return const TextStyle(fontSize: 11.0);
//   }

//   /// Get appropriate row height for mobile
//   static double getRowHeight() {
//     return 60.0;
//   }

//   /// Get max width for text constraints based on column
//   static double getMaxWidthForColumn(int columnIndex) {
//     switch (columnIndex) {
//       case 3:
//         return 150.0; // Product name
//       case 5:
//         return 150.0; // Description
//       case 7:
//         return 80.0; // Category 1
//       case 8:
//         return 80.0; // Category 2
//       case 10:
//         return 100.0; // Matching Words
//       default:
//         return 120.0;
//     }
//   }

//   /// Get max lines for text based on column
//   static int getMaxLinesForColumn(int columnIndex) {
//     switch (columnIndex) {
//       case 3:
//         return 2; // Product name
//       case 5:
//         return 2; // Description
//       default:
//         return 1;
//     }
//   }
// }
