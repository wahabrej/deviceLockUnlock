import 'package:devicelocunlock/core/routes/Routes_name.dart';
import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:devicelocunlock/services/shared_preferences_service.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isAdminActive = false;
  bool _isLoading = false;
  bool _isLoadingInfo = true;
  String _errorMessage = '';

  String _deviceModel = 'Loading...';
  String _imeiNumber = 'Loading...';
  String _androidVersion = 'Loading...';
  String _batteryLevel = 'Loading...';
  String _storageUsed = 'Loading...';

  @override
  void initState() {
    super.initState();
    DeviceControlService.instance.addListener(_onServiceChange);
    _checkAdminStatus();
    _getRealDeviceInfo();
    _checkInitialLockStatus();
  }

  @override
  void dispose() {
    DeviceControlService.instance.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) {
      final service = DeviceControlService.instance;
      if (service.isLocked) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteName.lockScreen,
          (route) => false,
        );
      }
    }
  }

  Future<void> _checkInitialLockStatus() async {
    final isLocked = await DeviceControlService.instance.isDeviceLocked();
    if (isLocked && mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteName.lockScreen,
        (route) => false,
      );
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      final active = await DeviceControlService.instance.checkAdminStatus();
      if (mounted) setState(() => _isAdminActive = active);
    } catch (_) {}
  }

  Future<void> _getRealDeviceInfo() async {
    setState(() => _isLoadingInfo = true);
    try {
      final info = await DeviceControlService.instance.getFullDeviceInfo();
      if (info.isNotEmpty && mounted) {
        final savedImei = SharedPreferencesService.getIMEI();
        setState(() {
          _deviceModel = info['model']?.toString() ?? 'Unknown';
          _imeiNumber = savedImei.isNotEmpty
              ? savedImei
              : info['imei']?.toString() ?? 'Unknown';
          _androidVersion = info['androidVersion']?.toString() ?? 'Unknown';
          _batteryLevel = info['batteryLevel']?.toString() ?? 'N/A';
          _storageUsed = info['storageUsed']?.toString() ?? 'N/A';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Error loading device info');
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _activateAdmin() async {
    setState(() => _isLoading = true);
    final result = await DeviceControlService.instance.activateAdmin();
    if (mounted) {
      setState(() {
        _isAdminActive = result;
        _isLoading = false;
      });
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Admin Activated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  // ✅ টেস্টিংয়ের জন্য অ্যাপ ম্যানেজমেন্ট রিমুভ ও আনইনস্টল করা
  Future<void> _removeAndUninstall() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall App?'),
        content: const Text(
          'This will disable Device Owner and open the Uninstall screen. Only use this for Testing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('UNINSTALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      // নেটিভ সাইডে ম্যানেজমেন্ট রিমুভ করবে এবং সরাসরি আনইনস্টল ডায়ালগ খুলবে
      await DeviceControlService.instance.removeManagement();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('SmartPay Management'),
          backgroundColor: const Color(0xFF1A6FB0),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _getRealDeviceInfo,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAdminStatus(),
                const SizedBox(height: 16),
                _buildInfoCard(),
                const SizedBox(height: 30),
                const Text(
                  'This device is currently monitored by admin.\nIf you fail to pay EMI, the device will be blocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 60),

                // ✅ আনইনস্টল বাটন (টেস্টিং এর জন্য)
                if (!_isLoading)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _removeAndUninstall,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('UNINSTALL APP (DEBUG)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  const CircularProgressIndicator(color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isAdminActive ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAdminActive
              ? Colors.green.shade300
              : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAdminActive ? Icons.check_circle : Icons.warning,
            color: _isAdminActive ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isAdminActive
                  ? 'Device security is active'
                  : 'Security activation required!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isAdminActive
                    ? Colors.green.shade800
                    : Colors.orange.shade800,
              ),
            ),
          ),
          if (!_isAdminActive)
            ElevatedButton(
              onPressed: _activateAdmin,
              child: const Text('Activate'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _infoRow(Icons.smartphone, 'Model', _deviceModel),
            const Divider(),
            _infoRow(Icons.numbers, 'IMEI', _imeiNumber),
            const Divider(),
            _infoRow(Icons.android, 'Android', _androidVersion),
            const Divider(),
            _infoRow(Icons.battery_std, 'Battery', _batteryLevel),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
