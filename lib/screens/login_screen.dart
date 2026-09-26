import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/services/api_service.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _imei1Controller = TextEditingController();
  final TextEditingController _imei2Controller = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final FocusNode _imei1FocusNode = FocusNode();
  final FocusNode _imei2FocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isLocalLocking = false;
  String? _errorMessage;
  Map<String, dynamic> _deviceInfo = {};

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchDeviceInfo();
    _checkAutoRedirect();
  }

  // ✅ অলরেডি লগইন করা থাকলে সরাসরি সরিয়ে দিবে
  void _checkAutoRedirect() {
    if (SharedPreferencesService.getIMEI().isNotEmpty) {
      Future.delayed(Duration.zero, () {
        if (SharedPreferencesService.isDeviceLocked()) {
          Navigator.pushReplacementNamed(context, RouteName.lockScreen);
        } else {
          Navigator.pushReplacementNamed(context, RouteName.homeScreen);
        }
      });
    }
  }

  @override
  void dispose() {
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _phoneController.dispose();
    _imei1FocusNode.dispose();
    _imei2FocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchDeviceInfo() async {
    try {
      _deviceInfo = await DeviceControlService.instance.getFullDeviceInfo();
      debugPrint('📱 [LOGIN] Device details: $_deviceInfo');

      final String imei1 =
          _deviceInfo['imei1']?.toString() ??
          _deviceInfo['imei']?.toString() ??
          SharedPreferencesService.getIMEI();

      final String imei2 =
          _deviceInfo['imei2']?.toString() ??
          SharedPreferencesService.getIMEI2();

      if (mounted) {
        setState(() {
          if (_imei1Controller.text.isEmpty && imei1.isNotEmpty) {
            _imei1Controller.text = imei1;
          }
          if (_imei2Controller.text.isEmpty && imei2.isNotEmpty) {
            _imei2Controller.text = imei2;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [LOGIN] Error getting device details: $e');
    }
  }

  Future<void> _scanIMEI(TextEditingController controller) async {
    final String? scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (scannedCode != null) {
      setState(() {
        // শুধু সংখ্যাগুলো নিবে (IMEI সাধারণত ১৫ ডিজিটের সংখ্যা হয়)
        String cleaned = scannedCode.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.length > 15) cleaned = cleaned.substring(0, 15);
        controller.text = cleaned;
      });
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final String inputImei1 = _imei1Controller.text.trim();
      final String inputImei2 = _imei2Controller.text.trim();
      final String inputPhone = _phoneController.text.trim();
      final String? fcmToken = SharedPreferencesService.getFCMToken();

      final trackData = {
        "imei": inputImei1,
        "imei2": inputImei2,
        "phone": inputPhone,
        "serialNumber": _deviceInfo['serialNumber'] ?? "",
        "batteryLevel":
            int.tryParse(
              _deviceInfo['batteryLevel']?.toString().replaceAll('%', '') ??
                  '85',
            ) ??
            85,
        "brand": _deviceInfo['brand'] ?? "Unknown",
        "model": _deviceInfo['model'] ?? "Unknown",
        "osVersion":
            _deviceInfo['osVersion'] ??
            _deviceInfo['androidVersion'] ??
            "Unknown",
        "appVersion": "1.0.0",
        "fcmToken": fcmToken ?? "NO_TOKEN",
      };

      final response = await _apiService.trackDevice(trackData);

      if (response != null) {
        await SharedPreferencesService.setIMEI(inputImei1);
        await SharedPreferencesService.setIMEI2(inputImei2);
        final applied = await DeviceControlService.instance.applyServerProfile(
          response,
        );
        DeviceControlService.instance.startLockStatusSync();

        if (response.isLocked) {
          if (!applied) {
            if (mounted) {
              setState(() {
                _errorMessage =
                    'Lock is pending. This APK must first be provisioned as '
                    'the Device Owner.';
              });
            }
            return;
          }
          debugPrint(
            '🔒 [LOGIN] Device is LOCKED. Redirecting to LockScreen...',
          );
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteName.lockScreen,
              (route) => false,
            );
          }
        } else {
          debugPrint('🔓 [LOGIN] Device is UNLOCKED. Proceeding to Home...');
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteName.homeScreen,
              (route) => false,
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = 'Login failed. Check your IMEI and Network.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login error: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _lockDeviceForLocalTest() async {
    if (_isLocalLocking) return;
    setState(() => _isLocalLocking = true);

    try {
      final adminEnabled = await DeviceControlService.instance
          .requestDeviceAdmin();
      if (!mounted) return;

      if (!adminEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable Device Admin in the system prompt to lock.'),
          ),
        );
        return;
      }

      final locked = await DeviceControlService.instance.applyServerProfile(
        DeviceControlService.instance.profile.copyWith(isLocked: true),
      );
      if (!locked && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Device lock failed.')));
      }
    } finally {
      if (mounted) setState(() => _isLocalLocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF051B36),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildLoginCard(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Image.asset("assets/icons/logo.png", color: Colors.white, height: 80),
        const SizedBox(height: 10),
        const Text(
          'SmartPay Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null) _buildError(),
          _buildField(
            _imei1Controller,
            _imei1FocusNode,
            'IMEI 1',
            Icons.phone_android,
            15,
            onScan: () => _scanIMEI(_imei1Controller),
          ),
          const SizedBox(height: 16),
          _buildField(
            _imei2Controller,
            _imei2FocusNode,
            'IMEI 2',
            Icons.phone_android,
            15,
            onScan: () => _scanIMEI(_imei2Controller),
          ),
          const SizedBox(height: 16),
          _buildField(
            _phoneController,
            _phoneFocusNode,
            'Phone Number',
            Icons.phone,
            11,
          ),
          const SizedBox(height: 24),
          _buildLoginButton(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLocalLocking ? null : _lockDeviceForLocalTest,
              icon: const Icon(Icons.lock),
              label: Text(
                _isLocalLocking
                    ? 'WAITING FOR DEVICE ADMIN'
                    : 'LOCK DEVICE (LOCAL TEST)',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _errorMessage!,
        style: TextStyle(color: Colors.red.shade700, fontSize: 12),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    FocusNode focusNode,
    String label,
    IconData icon,
    int length, {
    VoidCallback? onScan,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(length),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A6FB0)),
        suffixIcon: onScan != null
            ? IconButton(
                icon: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF1A6FB0),
                ),
                onPressed: onScan,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (val) => val == null || val.isEmpty
          ? 'Required'
          : (val.length < length ? 'Invalid' : null),
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A6FB0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'LOGIN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  String _scannedImei = '';

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan IMEI Barcode'),
        actions: [
          IconButton(
            tooltip: 'Turn flashlight on or off',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (_scannedImei.isNotEmpty) return;

              for (final barcode in capture.barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue == null) continue;

                final cleaned = rawValue.replaceAll(RegExp(r'[^0-9]'), '');
                if (cleaned.length >= 15) {
                  setState(() => _scannedImei = cleaned.substring(0, 15));
                  _scannerController.stop();
                  break;
                }
              }
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                color: Colors.black87,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _scannedImei.isEmpty
                          ? 'IMEI barcode camera-এর মধ্যে রাখুন'
                          : 'Scanned IMEI: $_scannedImei',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            child: const Text('CANCEL'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _scannedImei.isEmpty
                                ? null
                                : () => Navigator.pop(context, _scannedImei),
                            icon: const Icon(Icons.check),
                            label: const Text('OK'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
