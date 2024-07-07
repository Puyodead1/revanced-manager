import 'package:flutter/material.dart';
import 'package:revanced_manager/gen/strings.g.dart';
import 'package:revanced_manager/ui/views/settings/settings_viewmodel.dart';
import 'package:revanced_manager/ui/widgets/shared/haptics/haptic_switch_list_tile.dart';

class SUseDevPatches extends StatefulWidget {
  const SUseDevPatches({super.key});

  @override
  State<SUseDevPatches> createState() => _SUseDevPatchesState();
}

final _settingsViewModel = SettingsViewModel();

class _SUseDevPatchesState extends State<SUseDevPatches> {
  @override
  Widget build(BuildContext context) {
    return HapticSwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      title: Text(
        "Use Dev Patches",
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text("Enables the use of unstable dev patches"),
      value: _settingsViewModel.isUseDevPatches(),
      onChanged: (value) {
        setState(() {
          _settingsViewModel.setUseDevPatches(value);
        });
      },
    );
  }
}
