// Prints the Supabase SQL (or Firestore rules) Alpha makes for a schema preset. Used by the database tests.
//   dart tool/gen_sql.dart <preset> [prefix] [admin-email] [--rules]
// ignore_for_file: avoid_print
import 'package:alpha/generator/firestore_rules.dart';
import 'package:alpha/generator/presets.dart';
import 'package:alpha/generator/sql_generator.dart';

void main(List<String> args) {
  final id = args.isEmpty ? 'store' : args[0];
  final prefix = args.length > 1 ? args[1] : 'demo';
  final admin = args.length > 2 && !args[2].startsWith('--') ? args[2] : 'owner@example.com';
  final preset = schemaPresets.firstWhere((p) => p.id == id);
  if (args.contains('--rules')) {
    print(FirestoreRulesGenerator(prefix, preset.build()).build());
    return;
  }
  print(SqlGenerator(prefix, preset.build(), admins: [admin]).build());
}
