import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;

  bool _isOffline = false;
  bool _showSyncing = false;
  Timer? _syncingTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check initial state
    Connectivity().checkConnectivity().then(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none) ||
        results.isEmpty;

    if (offline && !_isOffline) {
      // Going offline
      _syncingTimer?.cancel();
      setState(() {
        _isOffline = true;
        _showSyncing = false;
      });
      _animController.forward();
    } else if (!offline && _isOffline) {
      // Coming back online — show "syncing" briefly
      setState(() {
        _isOffline = false;
        _showSyncing = true;
      });
      _syncingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          _animController.reverse();
          setState(() => _showSyncing = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    _animController.dispose();
    _syncingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            if (_slideAnimation.value <= -0.99 && !_isOffline && !_showSyncing) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: FractionalTranslation(
                translation: Offset(0, _slideAnimation.value),
                child: child,
              ),
            );
          },
          child: Material(
            color: _showSyncing ? AppColors.reedGreen : AppColors.goldenHour,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      _showSyncing ? Icons.sync : Icons.cloud_off,
                      size: 16,
                      color: _showSyncing ? Colors.white : AppColors.slate,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showSyncing
                          ? 'Back online — syncing...'
                          : "You're offline — catches save locally",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _showSyncing ? Colors.white : AppColors.slate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
