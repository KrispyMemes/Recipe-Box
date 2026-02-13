class ShoppingListItemModel {
  const ShoppingListItemModel({
    required this.id,
    required this.weekStartDate,
    required this.itemName,
    this.quantityText,
    required this.checked,
    required this.sourceRecipeIds,
  });

  final String id;
  final String weekStartDate;
  final String itemName;
  final String? quantityText;
  final bool checked;
  final List<String> sourceRecipeIds;

  bool get isCustom => sourceRecipeIds.isEmpty;
}
