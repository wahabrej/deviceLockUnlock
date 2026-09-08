import 'package:devicelocunlock/services/device_control_service.dart';
import 'package:flutter/material.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isRemoving = false;

  Future<void> _removeManagement() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Developer: Remove Lock?'),
        content: const Text('This will disable Device Owner and let you uninstall the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isRemoving = true);
      await DeviceControlService.instance.removeManagement();
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Management removed. You can uninstall now.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Management Remove Button (Dev Only)
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.white24),
                onPressed: _removeManagement,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 80, color: Colors.red),
                    const SizedBox(height: 24),
                    const Text(
                      "DEVICE LOCKED",
                      style: TextStyle(
                        color: Colors.white, 
                        fontSize: 28, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "This device has been locked due to overdue EMI. Please contact your provider to unlock.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 40),
                    if (_isRemoving)
                      const CircularProgressIndicator(color: Colors.red),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
