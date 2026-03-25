import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<void> connect() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase
      await Firebase.initializeApp();
      _firestore = FirebaseFirestore.instance;

      // Enable offline persistence
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('Firebase Init Error: $e');
      rethrow;
    }
  }

  bool get isConnected => _isInitialized;

  // User operations
  Future<User?> loginUser(String email, String password) async {
    if (!_isInitialized) {
      // Try to initialize if not already done
      await connect();
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Authentication failed');
    } catch (e) {
      debugPrint('Error logging in user: $e');
      throw Exception('Failed to login: $e');
    }
  }

  Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    required String aadhaar,
    required String pan,
  }) async {
    if (!_isInitialized) {
      await connect();
    }

    try {
      // Create user in Firebase Auth
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // Create user document in Firestore with structured schema
        await _firestore!.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'displayName': name,
          'metadata': {
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          'kyc': {
            'aadhaar': aadhaar,
            'pan': pan,
          },
          'stats': {
            'totalScans': 0,
            'points': 0,
            'co2Saved': 0.0,
          }
        });
        
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuth error: ${e.code} - ${e.message}');
      throw Exception(e.message ?? 'Registration failed');
    } catch (e) {
      debugPrint('Error registering user: $e');
      throw Exception('Failed to register user: $e');
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    if (!_isInitialized || _firestore == null) return null;
    
    try {
      final doc = await _firestore!.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  Future<void> saveScanResult(Map<String, dynamic> scanData) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Structured Schema Assembly
    final structuredData = {
      'userId': user.uid,
      'userEmail': user.email,
      'item': {
        'type': scanData['type'],
        'description': scanData['description'],
        'detailedAnalysis': scanData['detailedAnalysis'],
      },
      'classification': {
        'tag': scanData['tag'],
        'confidence': scanData['confidence'],
      },
      'guidance': {
        'disposalInstructions': scanData['disposalInstructions'],
        'recyclingOptions': scanData['recyclingOptions'],
        'proTips': scanData['proTips'],
      },
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore!.collection('scan_history').add(structuredData);
      
      // Update user stats (Atomic + Upsert support)
      // Using .set with SetOptions(merge: true) to create the document if it doesn't exist
      await _firestore!.collection('users').doc(user.uid).set({
        'stats': {
          'totalScans': FieldValue.increment(1),
          'co2Saved': FieldValue.increment(0.2),
        },
        'metadata': {
          'lastUpdated': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving structured scan result: $e');
      throw Exception('Database update failed. Please try again.');
    }
  }

  Future<List<Map<String, dynamic>>> getScanHistory(String userEmail) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final querySnapshot = await _firestore!
          .collection('scan_history')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      debugPrint('Error getting scan history: $e');
      throw Exception('Failed to get scan history: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchScanHistory(String userId) {
    if (!_isInitialized || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!
        .collection('scan_history')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> deleteScanHistory(String scanId) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      await _firestore!.collection('scan_history').doc(scanId).delete();
    } catch (e) {
      debugPrint('Error deleting scan history: $e');
      throw Exception('Failed to delete scan history: $e');
    }
  }

  // Settings operations
  Future<void> saveUserSettings(
    String userEmail,
    Map<String, dynamic> settings,
  ) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      // Find user document
      final userQuery = await _firestore!
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;
        await _firestore!.collection('user_settings').doc(userId).set({
          'userEmail': userEmail,
          ...settings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving user settings: $e');
      throw Exception('Failed to save user settings: $e');
    }
  }

  Future<void> clearUserScanHistory(String userEmail) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      final querySnapshot = await _firestore!
          .collection('scan_history')
          .where('userEmail', isEqualTo: userEmail)
          .get();

      final batch = _firestore!.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error clearing user scan history: $e');
      throw Exception('Failed to clear scan history: $e');
    }
  }

  Future<void> deleteUserAccount() async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final uid = user.uid;
    final email = user.email ?? '';

    try {
      // 1. Delete scan history from Firestore
      final scanQuery = await _firestore!
          .collection('scan_history')
          .where('userId', isEqualTo: uid)
          .get();

      final batch = _firestore!.batch();
      for (var doc in scanQuery.docs) {
        batch.delete(doc.reference);
      }

      // 2. Delete user settings
      batch.delete(_firestore!.collection('user_settings').doc(uid));

      // 3. Delete user document
      batch.delete(_firestore!.collection('users').doc(uid));

      // Commit all Firestore deletions
      await batch.commit();

      // 4. Delete Auth User (Must be last because it signs the user out)
      try {
        await user.delete();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'requires-recent-login') {
          throw Exception('This operation is sensitive and requires recent authentication. Please log in again before deleting your account.');
        }
        rethrow;
      }
    } catch (e) {
      debugPrint('Error deleting user account: $e');
      throw Exception('Failed to delete account: $e');
    }
  }

  Future<void> updateUserPassword(String userEmail, String newPassword) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      // Find user document
      final userQuery = await _firestore!
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;
        await _firestore!.collection('users').doc(userId).update({
          'password': newPassword, // In production, this should be hashed
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      debugPrint('Error updating user password: $e');
      throw Exception('Failed to update password: $e');
    }
  }

  Future<void> updateUserName(String userEmail, String newName) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    try {
      // Find user document
      final userQuery = await _firestore!
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final userId = userQuery.docs.first.id;
        await _firestore!.collection('users').doc(userId).update({
          'name': newName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      debugPrint('Error updating user name: $e');
      throw Exception('Failed to update name: $e');
    }
  }

  Stream<Map<String, dynamic>> getUserStatsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _firestore == null) {
      return Stream.value({'scans': 0, 'disposed': 0, 'co2': 0.0});
    }

    return _firestore!
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return {'scans': 0, 'disposed': 0, 'co2': 0.0};
          
          final data = doc.data() as Map<String, dynamic>;
          final stats = data['stats'] as Map<String, dynamic>? ?? {};
          
          return {
            'scans': stats['totalScans'] ?? 0,
            'disposed': stats['totalScans'] ?? 0, // Logic: scans = disposed
            'co2': (stats['co2Saved'] ?? 0.0).toDouble(),
            'points': stats['points'] ?? 0,
          };
        });
  }
  Future<void> submitReport(Map<String, dynamic> reportData) async {
    if (!_isInitialized || _firestore == null) {
      throw Exception('Database not connected');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      await _firestore!.collection('reports').add({
        'userId': user.uid,
        'userEmail': user.email,
        ...reportData,
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error submitting report: $e');
      throw Exception('Failed to submit report: $e');
    }
  }

  // Notification operations
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? data,
  }) async {
    if (!_isInitialized || _firestore == null) return;

    try {
      await _firestore!.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type ?? 'general',
        'data': data ?? {},
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> watchNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _firestore == null) {
      return Stream.value([]);
    }

    return _firestore!
        .collection('notifications')
        .where('userId', isEqualTo: user.uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> markNotificationAsRead(String notifId) async {
    if (!_isInitialized || _firestore == null) return;
    try {
      await _firestore!.collection('notifications').doc(notifId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }
}
