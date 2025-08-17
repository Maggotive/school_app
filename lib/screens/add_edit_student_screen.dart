import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AddEditStudentScreen extends StatefulWidget {
  final String? studentId;
  final int year;

  const AddEditStudentScreen({Key? key, this.studentId, required this.year}) : super(key: key);

  @override
  AddEditStudentScreenState createState() => AddEditStudentScreenState();
}

class AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final String userId = FirebaseAuth.instance.currentUser!.uid;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Controllers for each field
  final _studentNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _fatherContactController = TextEditingController();
  final _fatherEmailController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _motherContactController = TextEditingController();
  final _motherEmailController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool get _isContactPickerSupported {
    if (kIsWeb) return false; // Contact picker not supported on web
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    if (widget.studentId != null) {
      _isEditMode = true;
      _loadStudentData();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    _studentNameController.dispose();
    _dobController.dispose();
    _allergiesController.dispose();
    _fatherNameController.dispose();
    _fatherContactController.dispose();
    _fatherEmailController.dispose();
    _motherNameController.dispose();
    _motherContactController.dispose();
    _motherEmailController.dispose();
    _emergencyNameController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users/$userId/students')
          .doc(widget.studentId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _studentNameController.text = data['studentName'] ?? '';
        _dobController.text = data['dateOfBirth'] ?? '';
        _allergiesController.text = data['allergies'] ?? '';
        _fatherNameController.text = data['fatherName'] ?? '';
        _fatherContactController.text = data['fatherContact'] ?? '';
        _fatherEmailController.text = data['fatherEmail'] ?? '';
        _motherNameController.text = data['motherName'] ?? '';
        _motherContactController.text = data['motherContact'] ?? '';
        _motherEmailController.text = data['motherEmail'] ?? '';
        _emergencyNameController.text = data['emergencyContactName'] ?? '';
        _emergencyContactController.text = data['emergencyContactNumber'] ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading student data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _pickContact(TextEditingController nameController, TextEditingController numberController) async {
    final status = await Permission.contacts.status;

    if (status.isGranted) {
      await _openContactPicker(nameController, numberController);
    } else if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('Contact permission has been permanently denied. Please go to your device settings to enable it for this app.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
              ),
            ],
          ),
        );
      }
    } else {
      final result = await Permission.contacts.request();
      if (result.isGranted) {
        await _openContactPicker(nameController, numberController);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission to access contacts was denied.')),
          );
        }
      }
    }
  }
  
  Future<void> _openContactPicker(TextEditingController nameController, TextEditingController numberController) async {
      Contact? contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        String name = contact.displayName;
        String number = contact.phones.isNotEmpty ? contact.phones.first.number : '';
        
        String formattedNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
        if (formattedNumber.startsWith('27')) {
          formattedNumber = '0${formattedNumber.substring(2)}';
        }
        if (formattedNumber.length > 10) {
           formattedNumber = formattedNumber.substring(formattedNumber.length - 10);
        }

        setState(() {
          nameController.text = name;
          numberController.text = formattedNumber;
        });
      }
  }

  Future<void> _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final studentData = {
        'studentName': _studentNameController.text.trim(),
        'dateOfBirth': _dobController.text.trim(),
        'allergies': _allergiesController.text.trim(),
        'fatherName': _fatherNameController.text.trim(),
        'fatherContact': _fatherContactController.text.trim(),
        'fatherEmail': _fatherEmailController.text.trim(),
        'motherName': _motherNameController.text.trim(),
        'motherContact': _motherContactController.text.trim(),
        'motherEmail': _motherEmailController.text.trim(),
        'emergencyContactName': _emergencyNameController.text.trim(),
        'emergencyContactNumber': _emergencyContactController.text.trim(),
        'year': widget.year,
      };

      try {
        if (_isEditMode) {
          await FirebaseFirestore.instance
              .collection('users/$userId/students')
              .doc(widget.studentId)
              .update(studentData);
        } else {
          await FirebaseFirestore.instance
              .collection('users/$userId/students')
              .add(studentData);
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving student: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // --- NEW: Themed Text Field Builder ---
  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool isNumeric = false,
      bool isRequired = true,
      bool isEmail = false,
      Widget? suffixIcon}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
      keyboardType: isNumeric
          ? TextInputType.phone
          : (isEmail ? TextInputType.emailAddress : TextInputType.text),
      validator: (value) {
        if (isRequired && (value == null || value.trim().isEmpty)) {
          return 'Please enter $label';
        }
        if (isNumeric &&
            value != null &&
            value.isNotEmpty &&
            (value.length != 10 || int.tryParse(value) == null)) {
          return 'Must be 10 digits.';
        }
        if (isEmail &&
            value != null &&
            value.isNotEmpty &&
            !value.contains('@')) {
          return 'Please enter a valid email.';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Student' : 'Add Student for ${widget.year}'),
      ),
      // --- MODIFIED: Added a bottom navigation bar for the save button ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(_isEditMode ? 'Save Changes' : 'Add Student'),
                onPressed: _saveStudent,
              ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- MODIFIED: Form fields are now grouped into themed cards ---
                  _buildSectionCard(
                    context: context,
                    title: 'Student Information',
                    children: [
                      _buildTextField(
                        controller: _studentNameController,
                        label: 'Student Full Name',
                        icon: Icons.child_care_outlined,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dobController,
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        readOnly: true,
                        validator: (value) => (value == null || value.isEmpty)
                            ? 'This field is required.'
                            : null,
                        onTap: () async {
                          FocusScope.of(context).requestFocus(FocusNode());
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _dobController.text.isNotEmpty
                                ? (DateFormat('dd-MM-yyyy')
                                        .tryParse(_dobController.text) ??
                                    DateTime.now())
                                : DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            String formattedDate =
                                DateFormat('dd-MM-yyyy').format(pickedDate);
                            setState(() {
                              _dobController.text = formattedDate;
                            });
                          }
                                                },
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _allergiesController,
                        label: 'Allergies (or None)',
                        icon: Icons.warning_amber_rounded,
                        isRequired: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'Father / Guardian 1',
                    children: [
                      _buildTextField(
                        controller: _fatherNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _fatherContactController,
                        label: 'Contact Number',
                        icon: Icons.phone_outlined,
                        isNumeric: true,
                        suffixIcon: _isContactPickerSupported
                            ? IconButton(
                                icon: const Icon(Icons.contact_phone_outlined),
                                onPressed: () => _pickContact(
                                    _fatherNameController,
                                    _fatherContactController))
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _fatherEmailController,
                        label: 'Email (Optional)',
                        icon: Icons.email_outlined,
                        isRequired: false,
                        isEmail: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'Mother / Guardian 2',
                    children: [
                       _buildTextField(
                        controller: _motherNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _motherContactController,
                        label: 'Contact Number',
                        icon: Icons.phone_outlined,
                        isNumeric: true,
                        suffixIcon: _isContactPickerSupported
                            ? IconButton(
                                icon: const Icon(Icons.contact_phone_outlined),
                                onPressed: () => _pickContact(
                                    _motherNameController,
                                    _motherContactController))
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _motherEmailController,
                        label: 'Email (Optional)',
                        icon: Icons.email_outlined,
                        isRequired: false,
                        isEmail: true,
                      ),
                    ],
                  ),
                   const SizedBox(height: 24),
                  _buildSectionCard(
                    context: context,
                    title: 'Emergency Contact',
                    children: [
                       _buildTextField(
                        controller: _emergencyNameController,
                        label: 'Full Name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emergencyContactController,
                        label: 'Contact Number',
                        icon: Icons.phone_outlined,
                        isNumeric: true,
                        suffixIcon: _isContactPickerSupported
                            ? IconButton(
                                icon: const Icon(Icons.contact_phone_outlined),
                                onPressed: () => _pickContact(
                                    _emergencyNameController,
                                    _emergencyContactController))
                            : null,
                      ),
                    ],
                  ),
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
