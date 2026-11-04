// Written by factory/prepare.py for each app (which backend and whether push is on).
// This default (data on the phone, no push) lets the engine run on its own.
import 'backend.dart';
import 'backend_local.dart';
import 'config.dart';

export 'push_none.dart';

Backend createBackend(AlphaConfig config) => LocalBackend(config);
