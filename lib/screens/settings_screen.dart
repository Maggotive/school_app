import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:playgroup_pals/screens/manage_assessment_templates_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  final _schoolNameController = TextEditingController();
  final _annualFeeController = TextEditingController();
  final _registrationFeeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  String? _logoUrl;
  XFile? _imageFile;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _schoolNameController.dispose();
    _annualFeeController.dispose();
    _registrationFeeController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final docRef = FirebaseFirestore.instance.collection('users/$userId/settings').doc('app_settings');
    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      _schoolNameController.text = data['schoolName'] ?? '';
      _annualFeeController.text = data['annualFee']?.toString() ?? '';
      _registrationFeeController.text = data['registrationFee']?.toString() ?? '';
      _bankNameController.text = data['bankName'] ?? '';
      _accountNumberController.text = data['accountNumber'] ?? '';
      _branchCodeController.text = data['branchCode'] ?? '';
      if (mounted) {
        setState(() {
          _logoUrl = data['logoUrl'];
        });
      }
    }
    if (mounted) {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null && mounted) {
      setState(() {
        _imageFile = image;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isLoading = true; });

    String? uploadedLogoUrl = _logoUrl;
    if (_imageFile != null) {
      try {
        final storageRef = FirebaseStorage.instance.ref().child('logos/$userId/logo.png');
        await storageRef.putFile(File(_imageFile!.path));
        uploadedLogoUrl = await storageRef.getDownloadURL();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading logo: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }

    final settingsData = {
      'schoolName': _schoolNameController.text.trim(),
      'annualFee': double.tryParse(_annualFeeController.text) ?? 0.0,
      'registrationFee': double.tryParse(_registrationFeeController.text) ?? 0.0,
      'bankName': _bankNameController.text.trim(),
      'accountNumber': _accountNumberController.text.trim(),
      'branchCode': _branchCodeController.text.trim(),
      'logoUrl': uploadedLogoUrl,
    };

    await FirebaseFirestore.instance.collection('users/$userId/settings').doc('app_settings').set(settingsData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!')),
      );
      setState(() {
        _isLoading = false;
        _logoUrl = uploadedLogoUrl;
        _imageFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      // --- NEW: Bottom action bar for the save button ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: const Text('Save Settings'),
                onPressed: _saveSettings,
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- MODIFIED: Organized into themed cards ---
                  _buildSectionCard(
                    context: context,
                    title: 'School Information',
                    children: [
                      TextFormField(
                        controller: _schoolNameController,
                        decoration: const InputDecoration(
                          labelText: 'School Name',
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Please enter a school name.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _annualFeeController,
                        decoration: const InputDecoration(
                          labelText: 'Annual School Fees',
                          prefixIcon: Icon(Icons.attach_money_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a fee.';
                          if (double.tryParse(value) == null) return 'Please enter a valid number.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _registrationFeeController,
                        decoration: const InputDecoration(
                          labelText: 'Registration Fee (Once-off)',
                          prefixIcon: Icon(Icons.app_registration_rounded),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a fee.';
                          if (double.tryParse(value) == null) return 'Please enter a valid number.';
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'Assessments',
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit_note_outlined),
                        label: const Text('Manage Report Templates'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const ManageAssessmentTemplatesScreen(),
                          ));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'Bank Details for Statements',
                    children: [
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          prefixIcon: Icon(Icons.account_balance_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accountNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _branchCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Branch Code',
                          prefixIcon: Icon(Icons.numbers_outlined),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'School Logo',
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 100,
                              height: 100,
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: _imageFile != null
                                  ? Image.file(File(_imageFile!.path), fit: BoxFit.cover)
                                  : _logoUrl != null
                                      ? Image.network(_logoUrl!, fit: BoxFit.cover)
                                      : const Center(child: Icon(Icons.image_not_supported_outlined)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickLogo,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Upload Logo'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                   const SizedBox(height: 80), // Padding for bottom action bar
                ],
              ),
            ),
    );
  }

  // --- NEW: Helper widget to create themed section cards ---
  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
