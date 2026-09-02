import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  // ── Supabase connection ───────────────────────────────────────────────────
  // URL and anon key are the public client credentials — safe to embed.
  // They can be overridden at build time via --dart-define if needed.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xtubsbcdjhgzskwcrigx.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh0dWJzYmNkamhnenNrd2NyaWd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM0MjM1MDIsImV4cCI6MjA5ODk5OTUwMn0.cklTATxU-il980DtZQVzS9TRV8OHWslk66v1ZUWJtBI',
  );
  // Service role key is SECRET — never hardcode it; keep env-only.
  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue: '',
  );

  // Initialize Supabase - call this in main()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
  }

  // Get Supabase client
  SupabaseClient get client => Supabase.instance.client;

  // Get current authenticated user
  User? get currentUser => client.auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Get current session
  Session? get currentSession => client.auth.currentSession;

  /// Sign in with email and password.
  /// Returns a map with 'role' and 'username' on success.
  /// Throws [AuthException] or [Exception] on failure.
  Future<Map<String, String>> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Authentification échouée. Veuillez réessayer.');
    }

    // Refresh the user to ensure we have the latest metadata from Supabase
    try {
      await client.auth.refreshSession();
    } catch (_) {}
    final refreshedUser = client.auth.currentUser ?? user;

    final role = getUserRole(refreshedUser);
    final userMeta = refreshedUser.userMetadata;
    final username =
        (userMeta?['username'] as String?)?.trim() ??
        (refreshedUser.appMetadata['username'] as String?)?.trim() ??
        email.split('@').first;

    // Ensure the resolved role is persisted into user_metadata if missing/unnormalized
    try {
      if ((userMeta?['role'] as String?) != role) {
        await client.auth.updateUser(
          UserAttributes(data: {...?userMeta, 'role': role}),
        );
      }
    } catch (_) {}

    // Log sign-in (use user_updated as it's a valid audit_action enum value)
    try {
      await _insertAuditLog(
        userId: refreshedUser.id,
        username: username,
        action: 'user_updated',
        description: 'Connexion utilisateur: $email ($role)',
        entityType: 'auth',
      );
    } catch (_) {}

    return {'role': role, 'username': username};
  }

  /// Resolves and normalizes the user's role from app_metadata, user_metadata, or email fallback.
  String getUserRole(User? user) {
    if (user == null) return 'User';

    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata;

    final rawRole =
        (appMeta['role'] as String?)?.trim() ??
        (userMeta?['role'] as String?)?.trim();

    if (rawRole != null && rawRole.isNotEmpty) {
      final cleaned = rawRole
          .toLowerCase()
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim();
      if (cleaned == 'super admin' || cleaned == 'superadmin') {
        return 'Super Admin';
      }
      if (cleaned == 'admin') {
        return 'Admin';
      }
      if (cleaned == 'user') {
        return 'User';
      }
      return rawRole.trim();
    }

    // Email-based fallback if role metadata was not set when user was created in Supabase
    final email = (user.email ?? '').toLowerCase();
    if (email.contains('superadmin') || email.contains('super_admin')) {
      return 'Super Admin';
    }
    if (email.contains('admin')) {
      return 'Admin';
    }

    return 'User';
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Listen to auth state changes.
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ---------------------------------------------------------------------------
  // Admin User Management (Secure Edge Function or fallback Admin API)
  // ---------------------------------------------------------------------------

  Dio get _adminDio {
    final key = supabaseServiceRoleKey;
    final url = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;
    final dio = Dio();
    dio.options.baseUrl = url;
    dio.options.headers = {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
    };
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    return dio;
  }

  /// List all users via Edge Function (or Admin API fallback).
  Future<List<Map<String, dynamic>>> listUsers() async {
    try {
      final res = await client.functions.invoke('admin-users', method: HttpMethod.get);
      if (res.status == 200 && res.data != null) {
        final data = res.data;
        if (data is Map && data['users'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['users'] as List).map(
              (u) => Map<String, dynamic>.from(u as Map),
            ),
          );
        }
      }
      if (res.data is Map && res.data['error'] != null) {
        throw Exception(res.data['error']);
      }
    } on FunctionException catch (e) {
      if (supabaseServiceRoleKey.isEmpty) {
        final reason = e.details?['error'] ?? e.reasonPhrase ?? 'Status ${e.status}';
        throw Exception('Erreur Edge Function: $reason');
      }
    } catch (e) {
      if (supabaseServiceRoleKey.isEmpty) {
        rethrow;
      }
    }

    if (supabaseServiceRoleKey.isNotEmpty) {
      try {
        final dio = _adminDio;
        final response = await dio.get(
          '/auth/v1/admin/users',
          queryParameters: {'page': 1, 'per_page': 200},
        );
        final data = response.data;
        if (data is Map && data['users'] is List) {
          return List<Map<String, dynamic>>.from(
            (data['users'] as List).map(
              (u) => Map<String, dynamic>.from(u as Map),
            ),
          );
        }
      } on DioException catch (e) {
        final msg = _extractDioError(e);
        throw Exception('Erreur lors du chargement des utilisateurs: $msg');
      }
    }
    throw Exception('Erreur lors du chargement des utilisateurs.');
  }

  /// Create a new user via Edge Function (or Admin API fallback).
  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String role,
    required String username,
    required String fullName,
  }) async {
    try {
      final res = await client.functions.invoke(
        'admin-users',
        method: HttpMethod.post,
        body: {
          'email': email,
          'password': password,
          'role': role,
          'username': username,
          'fullName': fullName,
        },
      );
      if (res.status == 200 && res.data != null) {
        final user = currentUser;
        if (user != null) {
          final uname =
              (user.userMetadata?['username'] as String?) ??
              user.email ??
              'superadmin';
          try {
            await _insertAuditLog(
              userId: user.id,
              username: uname,
              action: 'user_created',
              description: 'Création compte: $email ($role)',
              entityType: 'auth',
            );
          } catch (_) {}
        }
        return Map<String, dynamic>.from(res.data as Map);
      }
    } catch (_) {}

    if (supabaseServiceRoleKey.isNotEmpty) {
      try {
        final dio = _adminDio;
        final response = await dio.post(
          '/auth/v1/admin/users',
          data: {
            'email': email,
            'password': password,
            'email_confirm': true,
            'user_metadata': {
              'role': role,
              'username': username,
              'full_name': fullName,
            },
          },
        );
        final responseData = response.data;
        if (responseData is Map) {
          return Map<String, dynamic>.from(responseData);
        }
      } on DioException catch (e) {
        final msg = _extractDioError(e);
        throw Exception('Impossible de créer le compte: $msg');
      }
    }
    throw Exception('Impossible de créer le compte.');
  }

  /// Delete a user via Edge Function (or Admin API fallback).
  Future<void> deleteUser(String userId) async {
    try {
      final res = await client.functions.invoke(
        'admin-users',
        method: HttpMethod.delete,
        body: {'userId': userId},
      );
      if (res.status == 200) return;
    } catch (_) {}

    if (supabaseServiceRoleKey.isNotEmpty) {
      try {
        final dio = _adminDio;
        await dio.delete('/auth/v1/admin/users/$userId');
        return;
      } on DioException catch (e) {
        final msg = _extractDioError(e);
        throw Exception('Impossible de supprimer le compte: $msg');
      }
    }
  }

  /// Ban (disable) or unban (enable) a user via Edge Function.
  Future<void> setUserBanned({
    required String userId,
    required bool banned,
  }) async {
    try {
      final res = await client.functions.invoke(
        'admin-users',
        method: HttpMethod.put,
        body: {'userId': userId, 'banned': banned},
      );
      if (res.status == 200) return;
    } catch (_) {}

    if (supabaseServiceRoleKey.isNotEmpty) {
      try {
        final dio = _adminDio;
        await dio.put(
          '/auth/v1/admin/users/$userId',
          data: {'ban_duration': banned ? '876000h' : 'none'},
        );
        return;
      } on DioException catch (e) {
        final msg = _extractDioError(e);
        throw Exception(
          banned
              ? 'Impossible de désactiver le compte: $msg'
              : 'Impossible d\'activer le compte: $msg',
        );
      }
    }
  }

  /// Send a password reset email to the user.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception('Impossible d\'envoyer l\'email: ${e.message}');
    }
  }

  /// Update user metadata (role, username, full_name) via Edge Function.
  Future<void> updateUserMetadata({
    required String userId,
    required String role,
    required String username,
    required String fullName,
    required String email,
  }) async {
    try {
      final res = await client.functions.invoke(
        'admin-users',
        method: HttpMethod.put,
        body: {
          'userId': userId,
          'role': role,
          'username': username,
          'fullName': fullName,
          'email': email,
        },
      );
      if (res.status == 200) return;
    } catch (_) {}

    if (supabaseServiceRoleKey.isNotEmpty) {
      try {
        final dio = _adminDio;
        await dio.put(
          '/auth/v1/admin/users/$userId',
          data: {
            'email': email,
            'user_metadata': {
              'role': role,
              'username': username,
              'full_name': fullName,
            },
          },
        );
        return;
      } on DioException catch (e) {
        final msg = _extractDioError(e);
        throw Exception('Impossible de modifier le compte: $msg');
      }
    }
  }

  /// Extract a human-readable error message from a DioException.
  String _extractDioError(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['msg'] ??
                data['message'] ??
                data['error_description'] ??
                data['error'] ??
                e.message ??
                'Erreur inconnue')
            .toString();
      }
      if (data is String && data.isNotEmpty) return data;
    } catch (_) {}
    return e.message ?? 'Erreur inconnue';
  }

  // ---------------------------------------------------------------------------
  // Parks, Vehicles, Equipment, Maintenance, Alerts, Audit Logs, Dashboard Stats
  // ---------------------------------------------------------------------------

  // ── PARKS ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getParks() async {
    final response = await client
        .from('parks')
        .select()
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getParkById(String parkId) async {
    final response = await client
        .from('parks')
        .select()
        .eq('id', parkId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getParkByQrCode(String qrCode) async {
    final response = await client
        .from('parks')
        .select()
        .eq('qr_code', qrCode.trim())
        .maybeSingle();
    return response;
  }

  Stream<List<Map<String, dynamic>>> watchParks() {
    return client
        .from('parks')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true);
  }

  // ── VEHICLES ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVehicles({String? parkId}) async {
    List<Map<String, dynamic>> response = [];
    if (parkId != null && parkId.isNotEmpty) {
      try {
        final filtered = await client
            .from('vehicles')
            .select('*, parks(name)')
            .or('park_id.eq.$parkId,park_id.is.null')
            .order('name', ascending: true);
        response = List<Map<String, dynamic>>.from(filtered);
      } catch (_) {}
    }
    if (response.isEmpty) {
      final allVehicles = await client
          .from('vehicles')
          .select('*, parks(name)')
          .order('name', ascending: true);
      response = List<Map<String, dynamic>>.from(allVehicles);
    }
    return response;
  }

  Future<Map<String, dynamic>?> getVehicleById(String vehicleId) async {
    final response = await client
        .from('vehicles')
        .select('*, parks(name)')
        .eq('id', vehicleId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getVehicleByCode(String code) async {
    final cleanCode = code.trim();
    try {
      final res = await client
          .from('vehicles')
          .select('*, parks(name)')
          .eq('id', cleanCode)
          .maybeSingle();
      if (res != null) return res;
    } catch (_) {}

    try {
      final res = await client
          .from('vehicles')
          .select('*, parks(name)')
          .eq('matricule', cleanCode)
          .maybeSingle();
      if (res != null) return res;
    } catch (_) {}

    try {
      final res = await client
          .from('vehicles')
          .select('*, parks(name)')
          .ilike('name', cleanCode)
          .maybeSingle();
      if (res != null) return res;
    } catch (_) {}

    return null;
  }

  Stream<List<Map<String, dynamic>>> watchVehicles({String? parkId}) {
    if (parkId != null) {
      return client
          .from('vehicles')
          .stream(primaryKey: ['id'])
          .eq('park_id', parkId)
          .order('name', ascending: true);
    }
    return client
        .from('vehicles')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true);
  }

  Future<Map<String, dynamic>> createVehicle({
    required String name,
    required String vehicleType,
    required String matricule,
    required String status,
    String? parkId,
    String? insuranceStart,
    String? insuranceExpiry,
    String? inspectionExpiry,
    String? oilChangeDate,
    String generalRemark = '',
    String waterCapacity = '',
    String emulsifierCapacity = '',
    String powderCapacity = '',
    String cannonRange = '',
    String battery = '',
    String wheelRef = '',
    String affectation = '',
    String parcName = '',
  }) async {
    final data = {
      'name': name,
      'vehicle_type': vehicleType,
      'matricule': matricule,
      'status': status,
      'affectation': affectation,
      'parc_name': parcName,
      if (parkId != null) 'park_id': parkId,
      if (insuranceStart != null) 'insurance_start': insuranceStart,
      if (insuranceExpiry != null) 'insurance_expiry': insuranceExpiry,
      if (inspectionExpiry != null) 'inspection_expiry': inspectionExpiry,
      if (oilChangeDate != null) 'oil_change_date': oilChangeDate,
      'general_remark': generalRemark,
      'water_capacity': waterCapacity,
      'emulsifier_capacity': emulsifierCapacity,
      'powder_capacity': powderCapacity,
      'cannon_range': cannonRange,
      'battery': battery,
      'wheel_ref': wheelRef,
    };

    final response = await client
        .from('vehicles')
        .insert(data)
        .select()
        .single();

    final user = currentUser;
    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'vehicle_created',
          description: 'Création véhicule: $name',
          entityType: 'vehicle',
          entityId: response['id'] as String?,
        );
      } catch (_) {}
    }

    await syncAlertsFromFleet();
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateVehicle({
    required String vehicleId,
    required Map<String, dynamic> data,
  }) async {
    await client.from('vehicles').update(data).eq('id', vehicleId);
    syncAlertsFromFleet().catchError((_) {});

    final user = currentUser;
    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'vehicle_updated',
          description: 'Modification véhicule ID: $vehicleId',
          entityType: 'vehicle',
          entityId: vehicleId,
        );
      } catch (_) {}
    }
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await client.from('vehicles').delete().eq('id', vehicleId);
    await syncAlertsFromFleet();
  }

  // ── VEHICLE EQUIPMENT ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getVehicleEquipment(
    String vehicleId,
  ) async {
    final response = await client
        .from('vehicle_equipment')
        .select('*, equipment_definitions(name, category, unit)')
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchVehicleEquipment(String vehicleId) {
    return client
        .from('vehicle_equipment')
        .stream(primaryKey: ['id'])
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: true);
  }

  Future<void> updateEquipmentQuantity({
    required String vehicleEquipmentId,
    required int existingQuantity,
    required String vehicleId,
    required String vehicleName,
  }) async {
    await client
        .from('vehicle_equipment')
        .update({'existing_quantity': existingQuantity})
        .eq('id', vehicleEquipmentId);

    final user = currentUser;
    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'equipment_updated',
          description: 'Mise à jour équipements: $vehicleName',
          entityType: 'vehicle_equipment',
          entityId: vehicleId,
        );
      } catch (_) {}
    }
  }

  Future<void> upsertVehicleEquipment({
    required String vehicleId,
    required String equipmentDefinitionId,
    required int standardQuantity,
    required int existingQuantity,
  }) async {
    await client.from('vehicle_equipment').upsert({
      'vehicle_id': vehicleId,
      'equipment_definition_id': equipmentDefinitionId,
      'standard_quantity': standardQuantity,
      'existing_quantity': existingQuantity,
    }, onConflict: 'vehicle_id,equipment_definition_id');
  }

  Future<void> addVehicleEquipmentItem({
    required String vehicleId,
    required String designation,
    required String category,
    required int standardQuantity,
    required int existingQuantity,
    String unit = 'unité',
  }) async {
    final defs = await client
        .from('equipment_definitions')
        .select()
        .eq('name', designation);

    String defId;
    if (defs.isNotEmpty) {
      defId = defs.first['id'] as String;
    } else {
      final newDef = await client
          .from('equipment_definitions')
          .insert({
            'name': designation,
            'category': category.isNotEmpty ? category : 'Équipement incendie',
            'unit': unit,
            'default_standard': standardQuantity,
          })
          .select()
          .single();
      defId = newDef['id'] as String;
    }

    await client.from('vehicle_equipment').upsert({
      'vehicle_id': vehicleId,
      'equipment_definition_id': defId,
      'standard_quantity': standardQuantity,
      'existing_quantity': existingQuantity,
    }, onConflict: 'vehicle_id,equipment_definition_id');

    await syncAlertsFromFleet();
  }

  Future<void> updateVehicleEquipmentItem({
    required String vehicleEquipmentId,
    required String equipmentDefinitionId,
    required String designation,
    required int standardQuantity,
    required int existingQuantity,
  }) async {
    await client.from('vehicle_equipment').update({
      'standard_quantity': standardQuantity,
      'existing_quantity': existingQuantity,
    }).eq('id', vehicleEquipmentId);

    if (designation.isNotEmpty && equipmentDefinitionId.isNotEmpty) {
      try {
        await client
            .from('equipment_definitions')
            .update({'name': designation})
            .eq('id', equipmentDefinitionId);
      } catch (_) {}
    }

    await syncAlertsFromFleet();
  }

  Future<void> deleteVehicleEquipmentItem(String vehicleEquipmentId) async {
    await client
        .from('vehicle_equipment')
        .delete()
        .eq('id', vehicleEquipmentId);
    await syncAlertsFromFleet();
  }

  // ── EQUIPMENT DEFINITIONS ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getEquipmentDefinitions({
    bool? activeOnly,
  }) async {
    var query = client.from('equipment_definitions').select();
    if (activeOnly == true) {
      query = query.eq('active', true);
    }
    final response = await query.order('category', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchEquipmentDefinitions() {
    return client
        .from('equipment_definitions')
        .stream(primaryKey: ['id'])
        .order('category', ascending: true);
  }

  Future<Map<String, dynamic>> createEquipmentDefinition({
    required String name,
    required String category,
    required String unit,
    required int defaultStandard,
    String description = '',
  }) async {
    final response = await client
        .from('equipment_definitions')
        .insert({
          'name': name,
          'category': category,
          'unit': unit,
          'default_standard': defaultStandard,
          'description': description,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<void> updateEquipmentDefinition({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await client.from('equipment_definitions').update(data).eq('id', id);
  }

  Future<void> deleteEquipmentDefinition(String id) async {
    await client.from('equipment_definitions').delete().eq('id', id);
  }

  // ── FIXED EQUIPMENT ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFixedEquipment({String? parkId}) async {
    List<Map<String, dynamic>> response = [];
    if (parkId != null && parkId.isNotEmpty) {
      try {
        final filtered = await client
            .from('fixed_equipment')
            .select()
            .or('park_id.eq.$parkId,park_id.is.null')
            .order('name', ascending: true);
        response = List<Map<String, dynamic>>.from(filtered);
      } catch (_) {}
    }
    if (response.isEmpty) {
      final allFixed = await client
          .from('fixed_equipment')
          .select()
          .order('name', ascending: true);
      response = List<Map<String, dynamic>>.from(allFixed);
    }
    return response;
  }

  Stream<List<Map<String, dynamic>>> watchFixedEquipment({String? parkId}) {
    if (parkId != null) {
      return client
          .from('fixed_equipment')
          .stream(primaryKey: ['id'])
          .eq('park_id', parkId)
          .order('name', ascending: true);
    }
    return client
        .from('fixed_equipment')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true);
  }

  Future<Map<String, dynamic>> createFixedEquipment({
    required String name,
    required String category,
    required String location,
    required String status,
    String? parkId,
    String? lastInspection,
    Map<String, dynamic>? usdDetails,
  }) async {
    final data = {
      'name': name,
      'category': category,
      'location': location,
      'status': status,
      if (parkId != null) 'park_id': parkId,
      if (lastInspection != null && lastInspection.isNotEmpty)
        'last_inspection': lastInspection,
      if (usdDetails != null) 'usd_details': usdDetails,
    };

    final response = await client
        .from('fixed_equipment')
        .insert(data)
        .select()
        .single();

    final user = currentUser;
    if (user != null) {
      try {
        final username =
            (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'equipment_created',
          description: 'Ajout équipement fixe: $name ($category)',
          entityType: 'equipment',
        );
      } catch (_) {}
    }
    return response;
  }

  Future<void> updateFixedEquipment({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    await client.from('fixed_equipment').update(data).eq('id', id);

    final user = currentUser;
    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'equipment_updated',
          description: 'Modification équipement fixe: ${data['name'] ?? id}',
          entityType: 'equipment',
          entityId: id,
        );
      } catch (_) {}
    }
  }

  Future<void> deleteFixedEquipment(String id) async {
    await client.from('fixed_equipment').delete().eq('id', id);
  }

  // ── PV DIVERS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPvDivers() async {
    try {
      final response = await client
          .from('pv_divers')
          .select('id, date, equipe, description, pdf_name, created_at')
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await client
            .from('fixed_equipment')
            .select()
            .eq('category', 'PV_DIVERS')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response.map((item) {
          final details = item['usd_details'];
          if (details is Map<String, dynamic>) {
            return {
              'id': item['id'],
              'date': details['date'] ?? item['last_inspection'] ?? '',
              'equipe': details['equipe'] ?? item['location'] ?? '',
              'description': details['description'] ?? item['name'] ?? '',
              'pdf_name': details['pdf_name'] ?? '',
            };
          }
          return {
            'id': item['id'],
            'date': item['last_inspection'] ?? '',
            'equipe': item['location'] ?? '',
            'description': item['name'] ?? '',
          };
        }));
      } catch (_) {
        return [];
      }
    }
  }

  Future<String?> getPvDiversPdfData(String id) async {
    try {
      final res = await client
          .from('pv_divers')
          .select('pdf_data')
          .eq('id', id)
          .maybeSingle();
      if (res != null && res['pdf_data'] != null) {
        return res['pdf_data'] as String;
      }
    } catch (_) {}

    try {
      final res = await client
          .from('fixed_equipment')
          .select('usd_details')
          .eq('id', id)
          .maybeSingle();
      if (res != null && res['usd_details'] is Map) {
        final details = res['usd_details'] as Map;
        return details['pdf_data'] as String?;
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>> createPvDivers({
    required String date,
    required String equipe,
    required String description,
    String? pdfName,
    String? pdfData,
  }) async {
    final data = {
      'date': date,
      'equipe': equipe,
      'description': description,
      if (pdfName != null) 'pdf_name': pdfName,
      if (pdfData != null) 'pdf_data': pdfData,
    };

    try {
      final res = await client
          .from('pv_divers')
          .insert(data)
          .select()
          .single();
      return res;
    } catch (_) {
      final fallbackData = {
        'name': description,
        'category': 'PV_DIVERS',
        'location': equipe,
        'status': 'operational',
        'last_inspection': date,
        'usd_details': data,
      };
      final res = await client
          .from('fixed_equipment')
          .insert(fallbackData)
          .select()
          .single();
      return {'id': res['id'], ...data};
    }
  }

  Future<void> updatePvDivers({
    required String id,
    required Map<String, dynamic> data,
  }) async {
    try {
      await client.from('pv_divers').update(data).eq('id', id);
    } catch (_) {
      try {
        await client.from('fixed_equipment').update({
          'usd_details': data,
          'name': data['description'] ?? '',
          'location': data['equipe'] ?? '',
          'last_inspection': data['date'] ?? '',
        }).eq('id', id);
      } catch (_) {}
    }
  }

  Future<void> deletePvDivers(String id) async {
    try {
      await client.from('pv_divers').delete().eq('id', id);
    } catch (_) {
      try {
        await client.from('fixed_equipment').delete().eq('id', id);
      } catch (_) {}
    }
  }

  // ── MAINTENANCE RECORDS ───────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMaintenanceRecords(
    String vehicleId,
  ) async {
    final response = await client
        .from('maintenance_records')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('maintenance_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchMaintenanceRecords(String vehicleId) {
    return client
        .from('maintenance_records')
        .stream(primaryKey: ['id'])
        .eq('vehicle_id', vehicleId)
        .order('maintenance_date', ascending: false);
  }

  Future<List<Map<String, dynamic>>> getMaintenanceRecordsForEquipment(
    String equipmentId,
  ) async {
    final response = await client
        .from('maintenance_records')
        .select()
        .eq('equipment_id', equipmentId)
        .order('maintenance_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchMaintenanceRecordsForEquipment(
    String equipmentId,
  ) {
    return client
        .from('maintenance_records')
        .stream(primaryKey: ['id'])
        .eq('equipment_id', equipmentId)
        .order('maintenance_date', ascending: false);
  }

  Future<Map<String, dynamic>> createMaintenanceRecord({
    String? vehicleId,
    String? equipmentId,
    required String vehicleName,
    required String maintenanceDate,
    required String maintenanceType,
    required String description,
    String provider = '',
    String responsible = '',
    String observation = '',
    String? nextMaintenanceDate,
    String maintenanceStatus = 'Terminé',
  }) async {
    final user = currentUser;
    final data = <String, dynamic>{
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (equipmentId != null) 'equipment_id': equipmentId,
      'maintenance_date': maintenanceDate,
      'maintenance_type': maintenanceType,
      'description': description,
      'provider': provider,
      'responsible': responsible,
      'observation': observation,
      'maintenance_status': maintenanceStatus,
      if (nextMaintenanceDate != null && nextMaintenanceDate.isNotEmpty)
        'next_maintenance_date': nextMaintenanceDate,
      if (user != null) 'created_by': user.id,
    };

    final response = await client
        .from('maintenance_records')
        .insert(data)
        .select()
        .single();

    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'maintenance_added',
          description: 'Ajout maintenance $maintenanceType: $vehicleName',
          entityType: 'maintenance',
          entityId: vehicleId,
        );
      } catch (_) {}
    }

    return Map<String, dynamic>.from(response);
  }

  Future<void> updateMaintenanceRecord({
    required String recordId,
    required String vehicleName,
    required Map<String, dynamic> data,
  }) async {
    await client.from('maintenance_records').update(data).eq('id', recordId);

    final user = currentUser;
    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'maintenance_updated',
          description: 'Modification maintenance: $vehicleName',
          entityType: 'maintenance',
          entityId: recordId,
        );
      } catch (_) {}
    }
  }

  Future<void> deleteMaintenanceRecord(String recordId) async {
    await client.from('maintenance_records').delete().eq('id', recordId);
  }

  // ── ALERTS ────────────────────────────────────────────────────────────────

  Future<void> syncAlertsFromFleet() async {
    try {
      final vehicles = await client.from('vehicles').select();
      final fixedEquipments = await client.from('fixed_equipment').select();
      final existingAlerts = await client.from('alerts').select();

      final existingAlertsList =
          List<Map<String, dynamic>>.from(existingAlerts);
      final now = DateTime.now();

      final expectedAlerts = <Map<String, dynamic>>[];

      for (final v in vehicles) {
        final vehicleId = v['id'] as String;
        final name = (v['name'] as String?) ?? 'Véhicule';
        final matricule = (v['matricule'] as String?) ?? '';
        final status = (v['status'] as String?) ?? 'operational';

        // 1. Insurance expiry
        final insStr = v['insurance_expiry'] as String?;
        if (insStr != null && insStr.isNotEmpty) {
          try {
            final date = DateTime.parse(insStr);
            final diff = date.difference(now).inDays;
            if (diff < 0) {
              expectedAlerts.add({
                'vehicle_id': vehicleId,
                'category': 'insurance',
                'severity': 'critical',
                'title': 'Assurance expirée',
                'subtitle':
                    'Assurance de $name expirée depuis le ${_formatDateStr(insStr)}',
                'vehicle_name': name,
                'detail': 'Matricule: $matricule',
              });
            } else if (diff <= 30) {
              expectedAlerts.add({
                'vehicle_id': vehicleId,
                'category': 'insurance',
                'severity': 'warning',
                'title': 'Échéance assurance proche',
                'subtitle':
                    'Assurance de $name expire dans $diff jours (${_formatDateStr(insStr)})',
                'vehicle_name': name,
                'detail': 'Matricule: $matricule',
              });
            }
          } catch (_) {}
        }

        // 2. Inspection expiry
        final inspStr = v['inspection_expiry'] as String?;
        if (inspStr != null && inspStr.isNotEmpty) {
          try {
            final date = DateTime.parse(inspStr);
            final diff = date.difference(now).inDays;
            if (diff < 0) {
              expectedAlerts.add({
                'vehicle_id': vehicleId,
                'category': 'inspection',
                'severity': 'critical',
                'title': 'Contrôle technique expiré',
                'subtitle':
                    'Contrôle technique de $name expiré depuis le ${_formatDateStr(inspStr)}',
                'vehicle_name': name,
                'detail': 'Matricule: $matricule',
              });
            } else if (diff <= 30) {
              expectedAlerts.add({
                'vehicle_id': vehicleId,
                'category': 'inspection',
                'severity': 'warning',
                'title': 'Échéance contrôle technique',
                'subtitle':
                    'Contrôle technique de $name expire dans $diff jours (${_formatDateStr(inspStr)})',
                'vehicle_name': name,
                'detail': 'Matricule: $matricule',
              });
            }
          } catch (_) {}
        }

        // 3. Oil change date (Vidange)
        final oilStr = v['oil_change_date'] as String?;
        if (oilStr != null && oilStr.isNotEmpty) {
          try {
            final date = DateTime.parse(oilStr);
            final diff = date.difference(now).inDays;
            if (diff < 0) {
              expectedAlerts.add({
                'vehicle_id': vehicleId,
                'category': 'maintenance',
                'severity': 'warning',
                'title': 'Vidange à effectuer',
                'subtitle':
                    'Vidange de $name en retard depuis le ${_formatDateStr(oilStr)}',
                'vehicle_name': name,
                'detail': 'Matricule: $matricule',
              });
            }
          } catch (_) {}
        }

        // 4. Vehicle status
        if (status == 'out_of_service') {
          expectedAlerts.add({
            'vehicle_id': vehicleId,
            'category': 'maintenance',
            'severity': 'critical',
            'title': 'Véhicule Hors Service',
            'subtitle': '$name est actuellement hors service',
            'vehicle_name': name,
            'detail': 'Statut: Hors service',
          });
        } else if (status == 'maintenance') {
          expectedAlerts.add({
            'vehicle_id': vehicleId,
            'category': 'maintenance',
            'severity': 'warning',
            'title': 'Véhicule en Maintenance',
            'subtitle': '$name est actuellement en maintenance',
            'vehicle_name': name,
            'detail': 'Statut: En maintenance',
          });
        }

        // 5. Missing equipment on vehicle
        final missingCount = (v['missing_equipment_count'] as int?) ?? 0;
        if (missingCount > 0) {
          expectedAlerts.add({
            'vehicle_id': vehicleId,
            'category': 'equipment',
            'severity': 'warning',
            'title': 'Équipement(s) manquant(s)',
            'subtitle': '$missingCount équipement(s) manquant(s) sur $name',
            'vehicle_name': name,
            'detail': 'Matricule: $matricule',
          });
        }
      }

      for (final fe in fixedEquipments) {
        final status = (fe['status'] as String?) ?? 'operational';
        final name = (fe['name'] as String?) ?? 'Équipement fixe';
        final location = (fe['location'] as String?) ?? '';

        if (status == 'out_of_service') {
          expectedAlerts.add({
            'vehicle_id': null,
            'category': 'equipment',
            'severity': 'critical',
            'title': 'Équipement Fixe Hors Service',
            'subtitle': '$name ($location) est hors service',
            'vehicle_name': name,
            'detail': 'Emplacement: $location',
          });
        } else if (status == 'maintenance') {
          expectedAlerts.add({
            'vehicle_id': null,
            'category': 'equipment',
            'severity': 'warning',
            'title': 'Équipement Fixe en Maintenance',
            'subtitle': '$name ($location) est en maintenance',
            'vehicle_name': name,
            'detail': 'Emplacement: $location',
          });
        }
      }

      for (final expected in expectedAlerts) {
        final vehicleId = expected['vehicle_id'];
        final category = expected['category'];
        final title = expected['title'];

        final existingIndex = existingAlertsList.indexWhere(
          (a) =>
              a['vehicle_id'] == vehicleId &&
              a['category'] == category &&
              a['title'] == title,
        );

        if (existingIndex == -1) {
          await client.from('alerts').insert(expected);
        } else {
          final existing = existingAlertsList[existingIndex];
          if (existing['subtitle'] != expected['subtitle'] ||
              existing['severity'] != expected['severity']) {
            await client.from('alerts').update({
              'subtitle': expected['subtitle'],
              'severity': expected['severity'],
              'vehicle_name': expected['vehicle_name'],
            }).eq('id', existing['id']);
          }
        }
      }

      for (final existing in existingAlertsList) {
        if (existing['dismissed'] == true) continue;
        final vehicleId = existing['vehicle_id'];
        final category = existing['category'];
        final title = existing['title'];

        final stillValid = expectedAlerts.any(
          (e) =>
              e['vehicle_id'] == vehicleId &&
              e['category'] == category &&
              e['title'] == title,
        );

        if (!stillValid) {
          await client.from('alerts').delete().eq('id', existing['id']);
        }
      }
    } catch (_) {}
  }

  String _formatDateStr(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<List<Map<String, dynamic>>> getAlerts({bool? dismissed}) async {
    await syncAlertsFromFleet();
    var query = client.from('alerts').select('*, vehicles(name, matricule)');
    if (dismissed != null) {
      query = query.eq('dismissed', dismissed);
    }
    final response = await query.order('severity', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchAlerts({bool? dismissed}) {
    if (dismissed != null) {
      return client
          .from('alerts')
          .stream(primaryKey: ['id'])
          .eq('dismissed', dismissed)
          .order('created_at', ascending: false);
    }
    return client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> dismissAlert(String alertId) async {
    final user = currentUser;
    await client
        .from('alerts')
        .update({
          'dismissed': true,
          'dismissed_by': user?.id,
          'dismissed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', alertId);

    if (user != null) {
      final username =
          (user.userMetadata?['username'] as String?) ?? user.email ?? 'admin';
      try {
        await _insertAuditLog(
          userId: user.id,
          username: username,
          action: 'alert_dismissed',
          description: 'Alerte ignorée',
          entityType: 'alert',
          entityId: alertId,
        );
      } catch (_) {}
    }
  }

  Future<void> restoreAlert(String alertId) async {
    await client
        .from('alerts')
        .update({
          'dismissed': false,
          'dismissed_by': null,
          'dismissed_at': null,
        })
        .eq('id', alertId);
  }

  // ── AUDIT LOGS ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    final response = await client
        .from('audit_logs')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchAuditLogs({int limit = 20}) {
    return client
        .from('audit_logs')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<void> _insertAuditLog({
    required String userId,
    required String username,
    required String action,
    required String description,
    String entityType = '',
    String? entityId,
  }) async {
    try {
      await client.from('audit_logs').insert({
        'user_id': userId,
        'username': username,
        'action': action,
        'description': description,
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
      });
    } catch (_) {
      // Audit log failures should not break main operations
    }
  }

  // ── DASHBOARD STATS ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final results = await Future.wait([
        client.from('vehicles').select('status, missing_equipment_count'),
        client.from('alerts').select('severity, category').eq('dismissed', false),
        client.from('parks').select('id'),
        client.from('fixed_equipment').select('id'),
      ]);

      final vehicles = results[0] as List;
      final alerts = results[1] as List;
      final parks = results[2] as List;
      final fixedEquip = results[3] as List;

      final total = vehicles.length;
      final operational = vehicles
          .where((v) => v['status'] == 'operational')
          .length;
      final maintenance = vehicles
          .where((v) => v['status'] == 'maintenance')
          .length;
      final outOfService = vehicles
          .where((v) => v['status'] == 'out_of_service')
          .length;
      final totalMissing = vehicles.fold<int>(
        0,
        (sum, v) => sum + ((v['missing_equipment_count'] as int?) ?? 0),
      );
      final criticalAlerts = alerts
          .where((a) => a['severity'] == 'critical')
          .length;
      final warningAlerts = alerts
          .where((a) => a['severity'] == 'warning')
          .length;
      final expiredDocs = alerts
          .where(
            (a) =>
                a['category'] == 'insurance' || a['category'] == 'inspection',
          )
          .length;

      return {
        'total': total,
        'operational': operational,
        'maintenance': maintenance,
        'outOfService': outOfService,
        'totalMissing': totalMissing,
        'criticalAlerts': criticalAlerts,
        'warningAlerts': warningAlerts,
        'expiredDocs': expiredDocs,
        'totalAlerts': alerts.length,
        'parksCount': parks.length,
        'fixedEquipmentCount': fixedEquip.length,
      };
    } catch (e) {
      return {
        'total': 0,
        'operational': 0,
        'maintenance': 0,
        'outOfService': 0,
        'totalMissing': 0,
        'criticalAlerts': 0,
        'warningAlerts': 0,
        'expiredDocs': 0,
        'totalAlerts': 0,
        'parksCount': 0,
        'fixedEquipmentCount': 0,
      };
    }
  }

  // ── SYSTEM SETTINGS & PRESENCE ──────────────────────────────────────────────
  Future<Map<String, dynamic>> getSystemSettings() async {
    try {
      final res = await client
          .from('system_settings')
          .select()
          .eq('id', 'default')
          .maybeSingle();
      if (res != null) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return {
      'username': 'Super Admin',
      'organisation': 'Sonatrach-TRC RTH-HSE',
      'site': 'Hassi Messaoud',
    };
  }

  Future<void> updateSystemSettings({
    required String username,
    required String organisation,
    required String site,
  }) async {
    await client.from('system_settings').upsert({
      'id': 'default',
      'username': username,
      'organisation': organisation,
      'site': site,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> pingPresence({
    required String deviceId,
    required String role,
    required String userName,
  }) async {
    try {
      await client.from('user_presences').upsert({
        'device_id': deviceId,
        'role': role,
        'user_name': userName,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<int> getActivePresencesCount() async {
    try {
      final cutoff =
          DateTime.now().subtract(const Duration(seconds: 45)).toIso8601String();
      final res = await client
          .from('user_presences')
          .select('device_id')
          .gte('last_seen', cutoff);
      final count = (res as List).length;
      return count > 0 ? count : 1;
    } catch (_) {
      return 1;
    }
  }

  // ── USER PROFILES ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getUserProfile(
    String userIdOrName, {
    String defaultUsername = '',
    String defaultRole = 'Admin',
  }) async {
    final queryKey = userIdOrName.trim();
    if (queryKey.isEmpty) {
      return {
        'username': defaultUsername.isNotEmpty ? defaultUsername : 'Utilisateur',
        'role': defaultRole,
        'organisation': 'Sonatrach-TRC RTH-HSE',
        'site': 'Hassi Messaoud',
      };
    }
    try {
      final resList = await client
          .from('user_profiles')
          .select()
          .or('user_id.eq.$queryKey,username.eq.$queryKey,full_name.eq.$queryKey')
          .limit(1);

      if (resList.isNotEmpty) {
        final profile = Map<String, dynamic>.from(resList.first);
        return {
          'user_id': profile['user_id'] ?? profile['id'] ?? queryKey,
          'username': profile['username'] ?? profile['full_name'] ?? defaultUsername,
          'role': profile['role'] ?? defaultRole,
          'organisation': profile['organisation'] ?? 'Sonatrach-TRC RTH-HSE',
          'site': profile['site'] ?? 'Hassi Messaoud',
        };
      }
    } catch (_) {}

    return {
      'user_id': queryKey,
      'username': defaultUsername.isNotEmpty ? defaultUsername : queryKey,
      'role': defaultRole,
      'organisation': 'Sonatrach-TRC RTH-HSE',
      'site': 'Hassi Messaoud',
    };
  }

  Future<void> updateUserProfile({
    required String key,
    required String username,
    required String role,
    required String organisation,
    required String site,
  }) async {
    final targetKey = key.trim();
    if (targetKey.isEmpty) return;

    try {
      final existing = await client
          .from('user_profiles')
          .select()
          .or('user_id.eq.$targetKey,username.eq.$targetKey,full_name.eq.$targetKey')
          .limit(1);

      if (existing.isNotEmpty) {
        final rowId = existing.first['id'];
        await client.from('user_profiles').update({
          'user_id': targetKey,
          'username': username,
          'full_name': username,
          'role': role,
          'organisation': organisation,
          'site': site,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', rowId);
        return;
      }
    } catch (_) {}

    await client.from('user_profiles').insert({
      'user_id': targetKey,
      'username': username,
      'full_name': username,
      'role': role,
      'organisation': organisation,
      'site': site,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
