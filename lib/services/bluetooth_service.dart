import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

/// Service dédié à la gestion de la connexion Bluetooth
/// selon les meilleures pratiques Flutter
class BluetoothService {
  static BluetoothService? _instance;
  factory BluetoothService() {
    _instance ??= BluetoothService._internal();
    return _instance!;
  }
  BluetoothService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;
  List<BluetoothDevice> _devices = [];

  /// Obtient l'appareil actuellement connecté
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Vérifie si une connexion est en cours
  bool get isConnecting => _isConnecting;

  /// Obtient la liste des appareils connectés
  List<BluetoothDevice> get devices => _devices;

  /// Vérifie si l'imprimante est connectée
  Future<bool> isConnected() async {
    try {
      return await bluetooth.isConnected ?? false;
    } catch (e) {
      debugPrint('Erreur lors de la vérification de connexion: $e');
      return false;
    }
  }

  /// Initialise le service Bluetooth
  Future<List<BluetoothDevice>> scanDevices() async {
    try {
      _devices = await bluetooth.getBondedDevices();
      return _devices;
    } catch (e) {
      debugPrint('Erreur lors du scan Bluetooth: $e');
      return [];
    }
  }

  /// Se connecte à un appareil avec gestion d'erreurs robuste
  Future<bool> connectToDevice(
    BluetoothDevice device, {
    BuildContext? context,
  }) async {
    if (_isConnecting) {
      debugPrint('Connexion déjà en cours...');
      return false;
    }

    _isConnecting = true;

    try {
      // Vérifier si déjà connecté au même appareil
      if (_connectedDevice?.address == device.address && await isConnected()) {
        debugPrint('Déjà connecté à ${device.name}');
        return true;
      }

      // Déconnecter si connecté à un autre appareil
      if (await isConnected()) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      debugPrint('Tentative de connexion à ${device.name}');

      // Se connecter à l'appareil
      await bluetooth.connect(device);
      await Future.delayed(
        const Duration(seconds: 2),
      ); // Attendre la stabilisation

      // Vérifier si la connexion a réussi
      if (await isConnected()) {
        _connectedDevice = device;

        if (context != null) {
          _showSuccessMessage(
            context,
            'Connecté à ${device.name ?? 'l\'imprimante'}',
          );
        }

        debugPrint('Connexion réussie à ${device.name}');
        return true;
      } else {
        if (context != null) {
          _showErrorMessage(
            context,
            'Échec de la connexion à ${device.name ?? 'l\'imprimante'}',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Erreur critique lors de la connexion: $e');
      if (context != null) {
        _showErrorMessage(context, 'Erreur de connexion: $e');
      }
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  /// S'assure qu'une connexion est établie avant impression
  Future<bool> ensureConnection({BuildContext? context}) async {
    if (_connectedDevice == null) {
      if (context != null) {
        _showWarningMessage(context, 'Veuillez sélectionner une imprimante');
      }
      return false;
    }

    // Vérifier si déjà connecté
    if (await isConnected()) {
      return true;
    }

    // Tenter de se reconnecter
    debugPrint('Reconnexion automatique à ${_connectedDevice!.name}');
    return await connectToDevice(_connectedDevice!, context: context);
  }

  /// Déconnecte l'imprimante
  Future<void> disconnect() async {
    try {
      if (await isConnected()) {
        await bluetooth.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _connectedDevice = null;
      debugPrint('Déconnecté de l\'imprimante');
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
    }
  }

  /// Imprime des données avec gestion d'erreurs robuste
  Future<bool> printData(String data, {BuildContext? context}) async {
    try {
      if (!await isConnected()) {
        if (context != null) {
          _showWarningMessage(context, 'Veuillez connecter une imprimante');
        }
        return false;
      }
      await bluetooth.write(data);
      debugPrint('Données imprimées avec succès');
      if (context != null) {
        _showSuccessMessage(context, 'Impression réussie');
      }
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'impression: $e');

      if (context != null) {
        _showErrorMessage(context, 'Erreur d\'impression: $e');
      }
      return false;
    }
  }

  /// Imprime plusieurs étiquettes avec gestion de la connexion
  Future<bool> printMultipleLabels(
    String label,
    int count, {
    BuildContext? context,
  }) async {
    try {
      if (!await isConnected()) {
        if (context != null) {
          _showWarningMessage(context, 'Veuillez connecter une imprimante');
        }
        return false;
      }
      for (int i = 0; i < count; i++) {
        await bluetooth.write('$label\n');
        await Future.delayed(const Duration(milliseconds: 500));
      }
      if (context != null) {
        _showSuccessMessage(context, '$count étiquette(s) imprimée(s)');
      }
      return true;
    } catch (e) {
      debugPrint('Erreur lors de l\'impression multiple: $e');

      if (context != null) {
        _showErrorMessage(context, 'Erreur d\'impression multiple: $e');
      }
      return false;
    }
  }

  /// Affiche un message de succès
  void _showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Affiche un message d'erreur
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Affiche un message d'avertissement
  void _showWarningMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
