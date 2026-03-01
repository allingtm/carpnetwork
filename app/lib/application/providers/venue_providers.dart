import 'package:brick_core/query.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brick/models/venue.model.dart';
import '../../brick/repository.dart';

/// All venues from local cache for offline venue selection in catch form.
final venuesProvider = FutureProvider<List<Venue>>((ref) async {
  return Repository().get<Venue>(
    query: Query(
      orderBy: [const OrderBy('name', ascending: true)],
    ),
  );
});
