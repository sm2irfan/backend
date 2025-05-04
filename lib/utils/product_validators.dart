import 'dart:convert';
import 'package:flutter/material.dart';

/// A utility class for product validation
class ProductValidators {
  // Predefined list of valid categories
  static const List<String> validCategories = [
    "Spices and Seasonings",
    "Flours and Grains",
    "Cooking Oils",
    "Sauces and Condiments",
    "Sweeteners and Spreads",
    "Baking Ingredients",
    "Dairy and Alternatives",
    "Beverages",
    "Snacks and Instant Foods",
    "Biscuits and Crackers",
    "Chocolates and Confectionery",
    "Ready-to-Eat",
    "Health & Nutrition",
    "Household Cleaning",
    "Baby Care",
    "Personal Care",
    "Frozen Foods",
    "Tissues and Disposables",
    "Stationery Items",
    "Others",
  ];

  /// Validates if a string is valid JSON format
  static ValidationResult validateJsonFormat(String value) {
    try {
      json.decode(value);
      return ValidationResult(isValid: true);
    } catch (e) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Value must be in valid JSON format',
      );
    }
  }

  /// Validates if discount is in valid range (0-100)
  static ValidationResult validateDiscount(String? discountStr) {
    if (discountStr == null || discountStr.isEmpty) {
      return ValidationResult(
        isValid: true,
      ); // Empty discount is valid (will be null)
    }

    final discount = int.tryParse(discountStr);
    if (discount == null) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Discount must be a valid number',
      );
    }

    if (discount < 0 || discount > 100) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Discount must be between 0 and 100',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validates if category is in the predefined list
  static ValidationResult validateCategory(String? category) {
    if (category == null || category.isEmpty) {
      return ValidationResult(isValid: true); // Empty category is valid
    }

    if (!validCategories.contains(category)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Category must be from the predefined list',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validates if a required field is not empty
  static ValidationResult validateRequiredField(
    String? value,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return ValidationResult(
        isValid: false,
        errorMessage: '$fieldName is required',
      );
    }
    return ValidationResult(isValid: true);
  }

  /// Validates all product fields and returns the first error encountered
  static ValidationResult validateProduct({
    required String price,
    String? discount,
    String? category1,
    String? category2,
    required String name,
    required String description,
    required String image,
  }) {
    // Check required fields
    final nameResult = validateRequiredField(name, 'Product name');
    if (!nameResult.isValid) {
      return nameResult;
    }

    final descriptionResult = validateRequiredField(description, 'Description');
    if (!descriptionResult.isValid) {
      return descriptionResult;
    }

    final imageResult = validateRequiredField(image, 'Image URL');
    if (!imageResult.isValid) {
      return imageResult;
    }

    // Check price JSON format
    final priceResult = validateJsonFormat(price);
    if (!priceResult.isValid) {
      return priceResult;
    }

    // Check discount range
    final discountResult = validateDiscount(discount);
    if (!discountResult.isValid) {
      return discountResult;
    }

    // Check category1
    final category1Result = validateCategory(category1);
    if (!category1Result.isValid) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Category 1: ${category1Result.errorMessage}',
      );
    }

    // Check category2
    final category2Result = validateCategory(category2);
    if (!category2Result.isValid) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Category 2: ${category2Result.errorMessage}',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Shows validation error if any in a SnackBar
  static void showValidationError(
    BuildContext context,
    ValidationResult result,
  ) {
    if (!result.isValid && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Represents a validation result with status and optional error message
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});
}
