import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../application/providers/auth_providers.dart';
import '../../../application/providers/catch_providers.dart';
import '../../../application/providers/venue_providers.dart';
import '../../../application/services/moon_phase_service.dart';
import '../../../application/services/weather_service.dart';
import '../../../brick/models/catch_report.model.dart';
import '../../../brick/models/venue.model.dart';
import '../../theme/app_theme.dart';
import '../../widgets/photo_capture_widget.dart';

const _speciesList = [
  ('common', 'Common'),
  ('mirror', 'Mirror'),
  ('leather', 'Leather'),
  ('ghost', 'Ghost'),
  ('fully_scaled', 'Fully Scaled'),
  ('grass', 'Grass'),
];

const _baitTypes = [
  'Pop-up',
  'Bottom bait',
  'Wafter',
  'Pellet',
  'Tiger nut',
  'Particle',
  'Natural',
  'Other',
];

const _rigNames = [
  'Ronnie',
  'Chod',
  'German',
  'Blowback',
  'Zig',
  'D-rig',
  'Multi-rig',
  'Spinner',
  'Other',
];

const _leadArrangements = [
  'Inline',
  'Helicopter',
  'Chod',
  'Lead clip',
  'Running',
  'Method feeder',
  'Other',
];

class CatchFormScreen extends ConsumerStatefulWidget {
  final String groupId;

  const CatchFormScreen({super.key, required this.groupId});

  @override
  ConsumerState<CatchFormScreen> createState() => _CatchFormScreenState();
}

class _CatchFormScreenState extends ConsumerState<CatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Form values
  String? _species;
  final _weightLbController = TextEditingController();
  final _weightOzController = TextEditingController();
  final _fishNameController = TextEditingController();
  String? _selectedVenueId;
  final _swimController = TextEditingController();
  final _castingDistanceController = TextEditingController();

  // Bait
  String? _baitType;
  final _baitBrandController = TextEditingController();
  final _baitProductController = TextEditingController();
  final _baitSizeController = TextEditingController();
  final _baitColourController = TextEditingController();

  // Rig
  String? _rigName;
  final _hookSizeController = TextEditingController();
  final _hooklinkMaterialController = TextEditingController();
  final _hooklinkLengthController = TextEditingController();
  String? _leadArrangement;

  // Weather (auto-populated)
  double? _airPressureMb;
  String? _windDirection;
  int? _windSpeedMph;
  double? _airTempC;
  final _waterTempController = TextEditingController();
  String? _cloudCover;
  String? _rain;
  String? _moonPhase;
  bool _weatherLoading = false;

  // Other
  final _notesController = TextEditingController();
  DateTime _caughtAt = DateTime.now();

  // Photos
  final List<String> _photoLocalPaths = [];

  @override
  void dispose() {
    _weightLbController.dispose();
    _weightOzController.dispose();
    _fishNameController.dispose();
    _swimController.dispose();
    _castingDistanceController.dispose();
    _baitBrandController.dispose();
    _baitProductController.dispose();
    _baitSizeController.dispose();
    _baitColourController.dispose();
    _hookSizeController.dispose();
    _hooklinkMaterialController.dispose();
    _hooklinkLengthController.dispose();
    _waterTempController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _moonPhase = MoonPhaseService.calculate(_caughtAt);
  }

  Future<void> _fetchWeather(Venue venue) async {
    if (venue.locationLat == null || venue.locationLng == null) return;

    setState(() => _weatherLoading = true);
    try {
      final weather = await WeatherService.fetch(
        lat: venue.locationLat!,
        lng: venue.locationLng!,
      );
      if (weather != null && mounted) {
        setState(() {
          _airPressureMb = weather.airPressureMb;
          _windDirection = weather.windDirection;
          _windSpeedMph = weather.windSpeedMph;
          _airTempC = weather.airTempC;
          _cloudCover = weather.cloudCover;
          _rain = weather.rain;
        });
      }
    } catch (_) {
      // Weather is optional — catch still saves without it
    } finally {
      if (mounted) setState(() => _weatherLoading = false);
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _caughtAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_caughtAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _caughtAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      _moonPhase = MoonPhaseService.calculate(_caughtAt);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_species == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a species')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final user = ref.read(currentUserProvider);
      final now = DateTime.now();
      final id = const Uuid().v4();

      final report = CatchReport(
        id: id,
        groupId: widget.groupId,
        userId: user!.id,
        venueId: _selectedVenueId ?? '',
        fishSpecies: _species!,
        fishWeightLb: int.tryParse(_weightLbController.text) ?? 0,
        fishWeightOz: int.tryParse(_weightOzController.text) ?? 0,
        fishName: _fishNameController.text.isEmpty ? null : _fishNameController.text,
        swim: _swimController.text.isEmpty ? null : _swimController.text,
        castingDistanceWraps: int.tryParse(_castingDistanceController.text),
        baitType: _baitType,
        baitBrand: _baitBrandController.text.isEmpty ? null : _baitBrandController.text,
        baitProduct: _baitProductController.text.isEmpty ? null : _baitProductController.text,
        baitSizeMm: int.tryParse(_baitSizeController.text),
        baitColour: _baitColourController.text.isEmpty ? null : _baitColourController.text,
        rigName: _rigName,
        hookSize: int.tryParse(_hookSizeController.text),
        hooklinkMaterial: _hooklinkMaterialController.text.isEmpty
            ? null
            : _hooklinkMaterialController.text,
        hooklinkLengthInches: int.tryParse(_hooklinkLengthController.text),
        leadArrangement: _leadArrangement,
        airPressureMb: _airPressureMb,
        windDirection: _windDirection,
        windSpeedMph: _windSpeedMph,
        airTempC: _airTempC,
        waterTempC: double.tryParse(_waterTempController.text),
        cloudCover: _cloudCover,
        rain: _rain,
        moonPhase: _moonPhase,
        caughtAt: _caughtAt,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        createdAt: now,
        updatedAt: now,
      );

      final repo = ref.read(catchRepositoryProvider);
      await repo.saveCatch(report);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Catch saved!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving catch: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final venues = ref.watch(venuesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Catch')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Species
            _sectionHeader('Species *'),
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(hintText: 'Select species'),
              items: _speciesList
                  .map((s) => DropdownMenuItem(value: s.$1, child: Text(s.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _species = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Weight
            _sectionHeader('Weight *'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightLbController,
                    decoration: const InputDecoration(
                      labelText: 'Pounds',
                      suffixText: 'lb',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (int.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightOzController,
                    decoration: const InputDecoration(
                      labelText: 'Ounces',
                      suffixText: 'oz',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final oz = int.tryParse(v);
                      if (oz == null || oz < 0 || oz > 15) return '0–15';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Named fish
            TextFormField(
              controller: _fishNameController,
              decoration: const InputDecoration(
                labelText: 'Named fish (optional)',
                hintText: 'e.g. Big Lin, The Burghfield Common',
              ),
            ),
            const SizedBox(height: 16),

            // Venue
            _sectionHeader('Venue *'),
            venues.when(
              data: (list) => DropdownButtonFormField<String>(
                initialValue: _selectedVenueId,
                decoration: const InputDecoration(hintText: 'Select venue'),
                items: list
                    .map((v) => DropdownMenuItem(value: v.id, child: Text(v.name)))
                    .toList(),
                onChanged: (id) {
                  setState(() => _selectedVenueId = id);
                  if (id != null) {
                    final venue = list.firstWhere((v) => v.id == id);
                    _fetchWeather(venue);
                  }
                },
                validator: (v) => v == null ? 'Required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Failed to load venues'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _swimController,
              decoration: const InputDecoration(
                labelText: 'Swim number (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _castingDistanceController,
              decoration: const InputDecoration(
                labelText: 'Casting distance (optional)',
                suffixText: 'wraps',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),

            // Bait section
            _sectionHeader('Bait'),
            DropdownButtonFormField<String>(
              initialValue: _baitType,
              decoration: const InputDecoration(hintText: 'Bait type'),
              items: _baitTypes
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _baitType = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baitBrandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _baitProductController,
                    decoration: const InputDecoration(labelText: 'Product'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baitSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Size',
                      suffixText: 'mm',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _baitColourController,
                    decoration: const InputDecoration(labelText: 'Colour'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Rig section
            _sectionHeader('Rig'),
            DropdownButtonFormField<String>(
              initialValue: _rigName,
              decoration: const InputDecoration(hintText: 'Rig name'),
              items: _rigNames
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _rigName = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hookSizeController,
                    decoration: const InputDecoration(labelText: 'Hook size'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _hooklinkMaterialController,
                    decoration: const InputDecoration(labelText: 'Hooklink material'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hooklinkLengthController,
                    decoration: const InputDecoration(
                      labelText: 'Hooklink length',
                      suffixText: 'inches',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _leadArrangement,
                    decoration: const InputDecoration(hintText: 'Lead arrangement'),
                    items: _leadArrangements
                        .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                        .toList(),
                    onChanged: (v) => setState(() => _leadArrangement = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date/time
            _sectionHeader('Caught at *'),
            InkWell(
              onTap: _pickDateTime,
              child: InputDecorator(
                decoration: const InputDecoration(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_caughtAt.day}/${_caughtAt.month}/${_caughtAt.year} '
                      '${_caughtAt.hour.toString().padLeft(2, '0')}:'
                      '${_caughtAt.minute.toString().padLeft(2, '0')}',
                    ),
                    const Icon(Icons.calendar_today, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Weather (auto-populated)
            _sectionHeader('Weather'),
            if (_weatherLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            _weatherInfoRow('Air pressure', _airPressureMb != null ? '${_airPressureMb!.toStringAsFixed(1)} mb' : null),
            _weatherInfoRow('Wind', _windSpeedMph != null ? '$_windSpeedMph mph $_windDirection' : null),
            _weatherInfoRow('Air temp', _airTempC != null ? '${_airTempC!.toStringAsFixed(1)} °C' : null),
            _weatherInfoRow('Cloud cover', _cloudCover),
            _weatherInfoRow('Rain', _rain),
            _weatherInfoRow('Moon phase', _moonPhase),
            const SizedBox(height: 8),
            TextFormField(
              controller: _waterTempController,
              decoration: const InputDecoration(
                labelText: 'Water temp (manual)',
                suffixText: '°C',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),

            // Photos
            _sectionHeader('Photos'),
            PhotoCaptureWidget(
              catchReportId: null, // Not yet saved
              groupId: widget.groupId,
              photoPaths: _photoLocalPaths,
              onPhotosChanged: (paths) {
                setState(() {
                  _photoLocalPaths
                    ..clear()
                    ..addAll(paths);
                });
              },
            ),
            const SizedBox(height: 24),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save Catch'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  Widget _weatherInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.slate.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Text(
            value ?? '—',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
