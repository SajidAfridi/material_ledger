import 'yorks_v1_rental_screens.dart';

/// Compatibility route name for the normalized R38.4 property workspace.
class RentalUnitDetailScreen extends YorksV1RentalPropertyScreen {
  const RentalUnitDetailScreen({super.key, required String unitId})
    : super(propertyId: unitId);
}
