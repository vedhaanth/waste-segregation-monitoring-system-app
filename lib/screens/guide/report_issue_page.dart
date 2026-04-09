import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/database_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ReportIssuePage extends StatefulWidget {
  final String initialType;
  final String? initialDescription;
  final File? initialImage;

  const ReportIssuePage({
    super.key, 
    this.initialType = 'Garbage Heaps',
    this.initialDescription,
    this.initialImage,
  });

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedType = 'Garbage Heaps';
  File? _image;
  bool _isLoading = false;
  Position? _currentPosition;

  final List<String> _reportTypes = [
    'Garbage Heaps',
    'Construction Waste',
    'Open Burning',
    'Dead Animals',
    'Blocked Drains',
    'E-Waste dumping',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    _image = widget.initialImage;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _image = File(pickedFile.path));
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a photo of the issue')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String locationStr = _currentPosition != null
          ? 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}'
          : 'Location not provided';

      // 1. Submit to database
      await DatabaseService().submitReport({
        'type': _selectedType,
        'description': _descriptionController.text.trim(),
        'location_url': locationStr,
        'imagePath': _image!.path,
      });

      if (!mounted) return;

      // 2. Capture message before clearing
      final String reportMessage = '''
*WASTE MANAGEMENT REPORT*
Type: $_selectedType
Description: ${_descriptionController.text.trim()}
Location: $locationStr
Reporter: ${DatabaseService().getCurrentUser()?.displayName ?? 'User'}
Sent from BinBrain Smart Waste App
''';

      // 3. Now clear for next time
      _descriptionController.clear();

      // 3. Show success dialog and offer optional sharing
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Icon(Icons.check_circle, color: Colors.green, size: 48),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Report Submitted!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Your report has been successfully sent to the admin for review.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to previous screen
              },
              child: const Text('DONE'),
            ),
          ],
        ),
      );

    } catch (e) {
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showShareOptions(String reportMessage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Share Report via',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('WhatsApp'),
              onTap: () async {
                Navigator.pop(context);
                final String url = "whatsapp://send?text=${Uri.encodeComponent(reportMessage)}";
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                } else {
                  _showError('WhatsApp not installed');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.blue),
              title: const Text('Email'),
              onTap: () async {
                Navigator.pop(context);
                final Uri emailUri = Uri(
                  scheme: 'mailto',
                  path: '',
                  query: 'subject=Waste Report: $_selectedType&body=${Uri.encodeComponent(reportMessage)}',
                );
                await launchUrl(emailUri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.orange),
              title: const Text('SMS / Message'),
              onTap: () async {
                Navigator.pop(context);
                final Uri smsUri = Uri(
                  scheme: 'sms',
                  path: '1913',
                  queryParameters: {'body': reportMessage},
                );
                await launchUrl(smsUri);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blueGrey),
              title: const Text('System Share'),
              onTap: () {
                Navigator.pop(context);
                Share.share(reportMessage);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Report'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Details',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Provide information about the waste issue you encountered.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),

                    // Report Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Issue Type',
                        prefixIcon: const Icon(Icons.category_outlined),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      items: _reportTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Location Status Indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _currentPosition != null 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentPosition != null ? Colors.green : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _currentPosition != null ? Icons.location_on : Icons.location_searching,
                            color: _currentPosition != null ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentPosition != null ? 'Location Captured' : 'Fetching Location...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _currentPosition != null ? Colors.green[800] : Colors.orange[800],
                                  ),
                                ),
                                if (_currentPosition != null)
                                  Text(
                                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}',
                                    style: TextStyle(fontSize: 12, color: Colors.green[700]),
                                  )
                                else
                                  Text(
                                    'Please ensure GPS is enabled for accurate reporting.',
                                    style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                                  ),
                              ],
                            ),
                          ),
                          if (_currentPosition == null)
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(Icons.refresh, color: Colors.orange),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Image Picker
                    Text(
                      'Attach Photo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('Camera'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('Gallery'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.gallery);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 48, color: primaryColor),
                                  const SizedBox(height: 8),
                                  Text('Tap to add photo',
                                      style: TextStyle(color: primaryColor)),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the location and severity of the issue...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'SUBMIT REPORT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
