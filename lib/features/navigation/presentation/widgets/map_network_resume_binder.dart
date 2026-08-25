import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/features/navigation/presentation/providers/navigation_providers.dart';

/// Al volver a primer plano, relee la conectividad (sin sondeos periódicos).
class MapNetworkResumeBinder extends ConsumerStatefulWidget {
  const MapNetworkResumeBinder({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MapNetworkResumeBinder> createState() =>
      _MapNetworkResumeBinderState();
}

class _MapNetworkResumeBinderState extends ConsumerState<MapNetworkResumeBinder>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(mapNetworkAvailableProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
