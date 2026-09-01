import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

String getMonthsButtonLabel(List<String> months) {
  if (months.isEmpty || months.contains('Tous')) {
    return 'Tous les mois';
  }
  const monthNames = {
    '01': 'Janvier',
    '02': 'Février',
    '03': 'Mars',
    '04': 'Avril',
    '05': 'Mai',
    '06': 'Juin',
    '07': 'Juillet',
    '08': 'Août',
    '09': 'Septembre',
    '10': 'Octobre',
    '11': 'Novembre',
    '12': 'Décembre',
  };
  const shortMonthNames = {
    '01': 'Jan',
    '02': 'Fév',
    '03': 'Mar',
    '04': 'Avr',
    '05': 'Mai',
    '06': 'Juin',
    '07': 'Juil',
    '08': 'Août',
    '09': 'Sept',
    '10': 'Oct',
    '11': 'Nov',
    '12': 'Déc',
  };

  if (months.length == 1) {
    return monthNames[months.first] ?? months.first;
  }

  final shortList = months.map((m) => shortMonthNames[m] ?? m).join(', ');
  return '${months.length} mois ($shortList)';
}

Future<List<String>?> showMultiMonthSelector({
  required BuildContext context,
  required List<String> currentSelected,
}) async {
  final monthsList = [
    {'val': 'Tous', 'label': 'Tous les mois'},
    {'val': '01', 'label': '01 - Janvier'},
    {'val': '02', 'label': '02 - Février'},
    {'val': '03', 'label': '03 - Mars'},
    {'val': '04', 'label': '04 - Avril'},
    {'val': '05', 'label': '05 - Mai'},
    {'val': '06', 'label': '06 - Juin'},
    {'val': '07', 'label': '07 - Juillet'},
    {'val': '08', 'label': '08 - Août'},
    {'val': '09', 'label': '09 - Septembre'},
    {'val': '10', 'label': '10 - Octobre'},
    {'val': '11', 'label': '11 - Novembre'},
    {'val': '12', 'label': '12 - Décembre'},
  ];

  List<String> tempSelected = List<String>.from(currentSelected);
  if (tempSelected.isEmpty) tempSelected = ['Tous'];

  return showDialog<List<String>>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Sélectionner les mois',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkCharcoal,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: monthsList.map((m) {
                    final val = m['val']!;
                    final label = m['label']!;
                    final isChecked = tempSelected.contains(val);

                    return CheckboxListTile(
                      dense: true,
                      activeColor: AppTheme.primary,
                      title: Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 13,
                          fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.darkCharcoal,
                        ),
                      ),
                      value: isChecked,
                      onChanged: (bool? checked) {
                        setModalState(() {
                          if (val == 'Tous') {
                            tempSelected = ['Tous'];
                          } else {
                            tempSelected.remove('Tous');
                            if (checked == true) {
                              tempSelected.add(val);
                            } else {
                              tempSelected.remove(val);
                            }
                            if (tempSelected.isEmpty) {
                              tempSelected = ['Tous'];
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setModalState(() => tempSelected = ['Tous']);
                },
                child: Text('Réinitialiser', style: GoogleFonts.ibmPlexSans(color: AppTheme.mutedText)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, tempSelected),
                child: Text(
                  tempSelected.contains('Tous') ? 'Appliquer (Tous)' : 'Appliquer (${tempSelected.length})',
                  style: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
