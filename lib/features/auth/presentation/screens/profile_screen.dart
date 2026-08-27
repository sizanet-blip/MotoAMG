import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loc_motos/core/widgets/app_popup_menu.dart';
import 'package:loc_motos/features/auth/domain/entities/app_user.dart';
import 'package:loc_motos/features/auth/domain/entities/user_vehicle.dart';
import 'package:loc_motos/features/auth/domain/entities/vehicle_map_marker.dart';
import 'package:loc_motos/features/auth/presentation/providers/auth_providers.dart';
import 'package:loc_motos/features/auth/presentation/utils/auth_validators.dart';
import 'package:loc_motos/features/auth/presentation/widgets/reveal_recovery_key_dialog.dart';
import 'package:loc_motos/features/auth/presentation/widgets/vehicle_navigation_marker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  var _obscure = true;
  late List<UserVehicle> _vehicles;
  String? _activeVehicleId;

  AppUser get _user {
    final local = ref.watch(signedInUserProvider);
    final remote = ref.watch(authStateProvider).asData?.value;
    return resolveSessionUser(local, remote) ?? widget.user;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _name = TextEditingController(text: user.displayName);
    _phone = TextEditingController(text: user.phoneNumber ?? '');
    _vehicles = List<UserVehicle>.from(user.resolvedVehicles);
    _activeVehicleId = user.activeVehicle?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  String? _blankToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).updateProfile(
          displayName: _name.text,
          phoneNumber: _blankToNull(_phone.text),
          vehicles: _vehicles,
          activeVehicleId: _activeVehicleId,
          clearActiveVehicleId: _activeVehicleId == null,
        );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Perfil guardado.')),
    );
  }

  Future<void> _savePassword() async {
    if (!_passwordKey.currentState!.validate()) {
      return;
    }
    await ref.read(authActionControllerProvider.notifier).changePassword(
          currentPassword: _currentPassword.text,
          newPassword: _newPassword.text,
        );
    if (!mounted) {
      return;
    }
    if (ref.read(authActionControllerProvider).hasError) {
      return;
    }
    _currentPassword.clear();
    _newPassword.clear();
    _confirmPassword.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contraseña actualizada.')),
    );
  }

  Future<void> _editVehicle({UserVehicle? existing}) async {
    final result = await showModalBottomSheet<UserVehicle>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _VehicleEditorSheet(initial: existing),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      final index = _vehicles.indexWhere((v) => v.id == result.id);
      if (index >= 0) {
        _vehicles[index] = result;
      } else {
        _vehicles = [..._vehicles, result];
        _activeVehicleId ??= result.id;
      }
    });
  }

  void _deleteVehicle(String id) {
    setState(() {
      _vehicles = _vehicles.where((v) => v.id != id).toList();
      if (_activeVehicleId == id) {
        _activeVehicleId =
            _vehicles.isEmpty ? null : _vehicles.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final isLoading = ref.watch(authActionControllerProvider).isLoading;
    final error = ref.watch(authActionControllerProvider).asError?.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (error != null) ...[
            Text(
              '$error',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          Form(
            key: _profileKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre en el mapa',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.displayName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    border: OutlineInputBorder(),
                  ),
                  validator: AuthValidators.optionalPhone,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mis vehículos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _editVehicle(),
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'El vehículo activo define el tipo de ruta (moto/coche/camión) '
                  'y el combustible de las gasolineras.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                if (_vehicles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin vehículos. Las gasolineras mostrarán todos los precios.',
                    ),
                  )
                else
                  for (final vehicle in _vehicles) ...[
                    Card(
                      child: ListTile(
                        leading: Radio<String>(
                          value: vehicle.id,
                          groupValue: _activeVehicleId,
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  setState(() => _activeVehicleId = value);
                                },
                        ),
                        title: Text(vehicle.displayLabel),
                        subtitle: Text(
                          '${vehicle.kind.label} · ${vehicle.fuelType.label}'
                          '${vehicle.plate != null ? ' · ${vehicle.plate}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (vehicle.navigationPuckStyle != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: VehicleNavigationMarkerPreview(
                                  icon: vehicle.navigationPuckStyle!.icon,
                                  color: vehicle.navigationPuckStyle!.color,
                                  size: 32,
                                ),
                              ),
                            PopupMenuButton<String>(
                              tooltip: 'Opciones del vehículo',
                              offset: AppPopupMenus.offset,
                              elevation: AppPopupMenus.elevation,
                              shadowColor: AppPopupMenus.shadowColor,
                              surfaceTintColor:
                                  AppPopupMenus.surfaceTintOf(context),
                              color: AppPopupMenus.colorOf(context),
                              shape: AppPopupMenus.shapeOf(context),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  unawaited(_editVehicle(existing: vehicle));
                                } else if (action == 'delete') {
                                  _deleteVehicle(vehicle.id);
                                }
                              },
                              itemBuilder: (context) => [
                                appPopupMenuItem(
                                  value: 'edit',
                                  icon: Icons.edit_outlined,
                                  label: 'Editar',
                                  tint: Theme.of(context).colorScheme.primary,
                                ),
                                const PopupMenuDivider(height: 8),
                                appPopupMenuItem(
                                  value: 'delete',
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Eliminar',
                                  destructive: true,
                                  padding:
                                      const EdgeInsets.fromLTRB(8, 2, 8, 6),
                                ),
                              ],
                            ),
                          ],
                        ),
                        onTap: isLoading
                            ? null
                            : () => setState(
                                  () => _activeVehicleId = vehicle.id,
                                ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                if (_vehicles.isNotEmpty)
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () => setState(() => _activeVehicleId = null),
                    child: const Text('Ningún vehículo activo'),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: isLoading ? null : _saveProfile,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar perfil'),
                ),
              ],
            ),
          ),
          if (user.canChangePassword) ...[
            const SizedBox(height: 32),
            Text(
              'Cambiar contraseña',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Form(
              key: _passwordKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _currentPassword,
                    obscureText: _obscure,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Obligatoria' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPassword,
                    obscureText: _obscure,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: AuthValidators.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: _obscure,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => AuthValidators.confirmPassword(
                      v,
                      _newPassword.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: isLoading ? null : _savePassword,
                    child: const Text('Actualizar contraseña'),
                  ),
                ],
              ),
            ),
          ],
          if (user.isUsernameAccount) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: isLoading || user.username == null
                  ? null
                  : () => RevealRecoveryKeyDialog.show(
                        context,
                        username: user.username!,
                      ),
              child: const Text('Ver clave de recuperación'),
            ),
          ],
        ],
      ),
    );
  }
}

class _VehicleEditorSheet extends StatefulWidget {
  const _VehicleEditorSheet({this.initial});

  final UserVehicle? initial;

  @override
  State<_VehicleEditorSheet> createState() => _VehicleEditorSheetState();
}

class _VehicleEditorSheetState extends State<_VehicleEditorSheet> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _year;
  late final TextEditingController _color;
  late final TextEditingController _plate;
  late VehicleKind _kind;
  late VehicleFuelType _fuel;
  VehicleMapIcon? _mapIcon;
  late Color _mapColor;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    _brand = TextEditingController(text: v?.brand ?? '');
    _model = TextEditingController(text: v?.model ?? '');
    _year = TextEditingController(text: v?.year ?? '');
    _color = TextEditingController(text: v?.color ?? '');
    _plate = TextEditingController(text: v?.plate ?? '');
    _kind = v?.kind ?? VehicleKind.motorcycle;
    _fuel = v?.fuelType ?? VehicleFuelType.gasolina95;
    _mapIcon = v?.mapIcon;
    _mapColor = VehicleMapColors.tryParseHex(v?.mapColorHex) ??
        VehicleMapColors.defaultFor(
          _mapIcon ?? VehicleMapIcon.motorcycle,
        );
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _year.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  String? _blankToNull(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final id = widget.initial?.id ??
        'v_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.pop(
      context,
      UserVehicle(
        id: id,
        kind: _kind,
        fuelType: _fuel,
        brand: _blankToNull(_brand.text),
        model: _blankToNull(_model.text),
        year: _blankToNull(_year.text),
        color: _blankToNull(_color.text),
        plate: _blankToNull(_plate.text)?.toUpperCase(),
        mapIcon: _mapIcon,
        mapColorHex:
            _mapIcon == null ? null : VehicleMapColors.toHex(_mapColor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final colors = Theme.of(context).colorScheme;
    final suggested = _kind.suggestedMapIcons;
    final otherIcons = VehicleMapIcon.values
        .where((icon) => !suggested.contains(icon))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? 'Nuevo vehículo' : 'Editar vehículo',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VehicleKind>(
                // ignore: deprecated_member_use
                value: _kind,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final kind in VehicleKind.values)
                    DropdownMenuItem(value: kind, child: Text(kind.label)),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _kind = value;
                    if (_mapIcon != null &&
                        !value.suggestedMapIcons.contains(_mapIcon)) {
                      _mapIcon = value.suggestedMapIcons.first;
                      _mapColor = VehicleMapColors.defaultFor(_mapIcon!);
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VehicleFuelType>(
                // ignore: deprecated_member_use
                value: _fuel,
                decoration: const InputDecoration(
                  labelText: 'Combustible',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final fuel in VehicleFuelType.values)
                    DropdownMenuItem(value: fuel, child: Text(fuel.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _fuel = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Icono en el mapa (navegación)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Silueta del vehículo en el mapa (cenital). '
                'Si no eliges ninguno, se usa el punto GPS azul habitual.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MapIconChoice(
                    selected: _mapIcon == null,
                    color: colors.surfaceContainerHighest,
                    materialIcon: Icons.gps_fixed_rounded,
                    label: 'Por defecto',
                    onTap: () => setState(() => _mapIcon = null),
                    selectedBorder: colors.primary,
                  ),
                  for (final icon in suggested)
                    _MapIconChoice(
                      selected: _mapIcon == icon,
                      color: _mapIcon == icon
                          ? _mapColor
                          : const Color(0xFF607D8B),
                      vehicleIcon: icon,
                      label: icon.label,
                      onTap: () => setState(() {
                        final firstPick = _mapIcon == null;
                        _mapIcon = icon;
                        if (firstPick) {
                          _mapColor = VehicleMapColors.defaultFor(icon);
                        }
                      }),
                      selectedBorder: colors.primary,
                    ),
                  for (final icon in otherIcons)
                    _MapIconChoice(
                      selected: _mapIcon == icon,
                      color: _mapIcon == icon
                          ? _mapColor
                          : const Color(0xFF78909C),
                      vehicleIcon: icon,
                      label: icon.label,
                      onTap: () => setState(() {
                        final firstPick = _mapIcon == null;
                        _mapIcon = icon;
                        if (firstPick) {
                          _mapColor = VehicleMapColors.defaultFor(icon);
                        }
                      }),
                      selectedBorder: colors.primary,
                    ),
                ],
              ),
              if (_mapIcon != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Color del vehículo',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final color in VehicleMapColors.palette)
                      InkWell(
                        onTap: () => setState(() => _mapColor = color),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _mapColor.toARGB32() == color.toARGB32()
                                  ? colors.onSurface
                                  : Colors.white54,
                              width: _mapColor.toARGB32() == color.toARGB32()
                                  ? 3
                                  : 1,
                            ),
                          ),
                          child: _mapColor.toARGB32() == color.toARGB32()
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: VehicleNavigationMarkerPreview(
                    icon: _mapIcon!,
                    color: _mapColor,
                    size: 72,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                validator: AuthValidators.optionalBikeField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _model,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                validator: AuthValidators.optionalBikeField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  border: OutlineInputBorder(),
                ),
                validator: AuthValidators.optionalBikeYear,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _color,
                decoration: const InputDecoration(
                  labelText: 'Color (descripción)',
                  border: OutlineInputBorder(),
                ),
                validator: AuthValidators.optionalBikeField,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _plate,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Matrícula',
                  border: OutlineInputBorder(),
                ),
                validator: AuthValidators.optionalPlate,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                child: const Text('Guardar vehículo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapIconChoice extends StatelessWidget {
  const _MapIconChoice({
    required this.selected,
    required this.color,
    required this.label,
    required this.onTap,
    required this.selectedBorder,
    this.materialIcon,
    this.vehicleIcon,
  });

  final bool selected;
  final Color color;
  final IconData? materialIcon;
  final VehicleMapIcon? vehicleIcon;
  final String label;
  final VoidCallback onTap;
  final Color selectedBorder;

  @override
  Widget build(BuildContext context) {
    final vehicle = vehicleIcon;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 76,
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? selectedBorder : Colors.black12,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? selectedBorder.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            if (vehicle != null)
              VehicleNavigationMarkerPreview(
                icon: vehicle,
                color: color,
                size: 40,
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Icon(materialIcon, color: Colors.white, size: 20),
              ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
