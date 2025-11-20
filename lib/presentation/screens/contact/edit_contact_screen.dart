import 'dart:convert';
import 'dart:io';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nobox_chat/core/models/contact_detail_models.dart';
import 'package:nobox_chat/core/models/location_models.dart';
import 'package:nobox_chat/core/providers/contact_detail_provider.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:nobox_chat/core/services/address_service.dart';
import 'package:nobox_chat/core/services/contact_detail_service.dart';
import 'package:nobox_chat/core/services/media_service.dart';
import 'package:nobox_chat/core/services/storage_service.dart';
import 'package:nobox_chat/core/theme/app_theme.dart';

class EditContactScreen extends ConsumerStatefulWidget {
  final ContactDetail contact;

  const EditContactScreen({
    super.key,
    required this.contact,
  });

  @override
  ConsumerState<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends ConsumerState<EditContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final AddressService _addressService = AddressService();
  final ContactDetailService _contactService = ContactDetailService();
  
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _postalController;
  
  List<String> _categories = [];
  List<Country> _countries = [];
  List<StateRegion> _states = [];
  List<City> _cities = [];
  
  String? _selectedCategory;
  String? _selectedCountryId;
  String? _selectedStateId;
  String? _selectedCityId;
  
  File? _selectedImageFile;
  String? _newPhotoBase64;
  
  bool _isSaving = false;
  bool _isLoadingCategories = false;
  bool _isLoadingCountries = false;
  bool _isLoadingStates = false;
  bool _isLoadingCities = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.contact.name);
    _addressController = TextEditingController(text: widget.contact.address ?? '');
    _postalController = TextEditingController(text: widget.contact.zipCode ?? '');
    
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadCategories(),
      _loadCountries(),
    ]);
    
    if (widget.contact.category != null && _categories.contains(widget.contact.category)) {
      setState(() {
        _selectedCategory = widget.contact.category;
      });
    }
    
    if (widget.contact.country != null && widget.contact.country!.isNotEmpty) {
      final matchingCountry = _countries.where(
        (c) => c.name.toLowerCase() == widget.contact.country!.toLowerCase()
      ).firstOrNull;
      
      if (matchingCountry != null) {
        setState(() {
          _selectedCountryId = matchingCountry.id;
        });
        
        await _loadStates(matchingCountry.id, clearSelection: false);
        
        if (widget.contact.state != null && widget.contact.state!.isNotEmpty) {
          final matchingState = _states.where(
            (s) => s.name.toLowerCase() == widget.contact.state!.toLowerCase()
          ).firstOrNull;
          
          if (matchingState != null) {
            setState(() {
              _selectedStateId = matchingState.id;
            });
            
            await _loadCities(matchingState.id, clearSelection: false);
            
            if (widget.contact.city != null && widget.contact.city!.isNotEmpty) {
              final matchingCity = _cities.where(
                (c) => c.name.toLowerCase() == widget.contact.city!.toLowerCase()
              ).firstOrNull;
              
              if (matchingCity != null) {
                setState(() {
                  _selectedCityId = matchingCity.id;
                });
              }
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _postalController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    final categories = await _contactService.getContactCategories();
    
    setState(() {
      _categories = categories;
      _isLoadingCategories = false;
    });
  }

  Future<void> _loadCountries() async {
    setState(() {
      _isLoadingCountries = true;
    });

    final countries = await _addressService.getCountries();
    
    setState(() {
      _countries = countries;
      _isLoadingCountries = false;
    });
  }

  Future<void> _loadStates(String countryId, {bool clearSelection = true}) async {
    setState(() {
      _isLoadingStates = true;
      _states = [];
      _cities = [];
      if (clearSelection) {
        _selectedStateId = null;
        _selectedCityId = null;
      }
    });

    final states = await _addressService.getStates(countryId);
    
    setState(() {
      _states = states;
      _isLoadingStates = false;
    });
  }

  Future<void> _loadCities(String stateId, {bool clearSelection = true}) async {
    setState(() {
      _isLoadingCities = true;
      _cities = [];
      if (clearSelection) {
        _selectedCityId = null;
      }
    });

    final cities = await _addressService.getCities(stateId);
    
    setState(() {
      _cities = cities;
      _isLoadingCities = false;
    });
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.contact.country != null && widget.contact.country!.isNotEmpty) {
      if (_selectedCountryId == null) {
        _showSnackBar('Please select a country', isError: true);
        return;
      }
    }
    
    if (widget.contact.state != null && widget.contact.state!.isNotEmpty) {
      if (_selectedStateId == null) {
        _showSnackBar('Please select a state', isError: true);
        return;
      }
    }
    
    if (widget.contact.city != null && widget.contact.city!.isNotEmpty) {
      if (_selectedCityId == null) {
        _showSnackBar('Please select a city', isError: true);
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final selectedCountry = _countries.firstWhere(
        (c) => c.id == _selectedCountryId,
        orElse: () => Country(id: '', name: ''),
      ).name;
      
      final selectedState = _states.firstWhere(
        (s) => s.id == _selectedStateId,
        orElse: () => StateRegion(id: '', name: '', countryId: ''),
      ).name;
      
      final selectedCity = _cities.firstWhere(
        (c) => c.id == _selectedCityId,
        orElse: () => City(id: '', name: '', stateId: ''),
      ).name;
      
      final success = await ref.read(contactDetailProvider.notifier).updateContact(
        contactId: widget.contact.id,
        name: _nameController.text.trim(),
        category: _selectedCategory,
        address: _addressController.text.trim(),
        zipCode: _postalController.text.trim().isNotEmpty ? _postalController.text.trim() : null,
        state: selectedState.isNotEmpty ? selectedState : null,
        country: selectedCountry.isNotEmpty ? selectedCountry : null,
        city: selectedCity.isNotEmpty ? selectedCity : null,
        photoBase64: _newPhotoBase64,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Contact updated successfully', isError: false);
        Navigator.pop(context, true);
      } else {
        _showSnackBar('Failed to update contact', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

Future<void> _changeProfilePhoto() async {
  final isDarkMode = ref.watch(themeProvider).isDarkMode;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Change Profile Photo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: Icon(
              Icons.camera_alt,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black87,
            ),
            title: Text(
              'Take Photo',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black87,
              ),
            ),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          ListTile(
            leading: Icon(
              Icons.photo_library,
              color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black87,
            ),
            title: Text(
              'Choose from Gallery',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black87,
              ),
            ),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          if (widget.contact.image != null && widget.contact.image!.isNotEmpty || _selectedImageFile != null)
            // ListTile(
            //   leading: const Icon(
            //     Icons.delete,
            //     color: Colors.red,
            //   ),
            //   title: const Text(
            //     'Remove Photo',
            //     style: TextStyle(
            //       fontSize: 16,
            //       color: Colors.red,
            //     ),
            //   ),
            //   onTap: () => Navigator.pop(context, null),
            // ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );

    // ✅ PERBAIKAN: Jika user close bottom sheet (source == null), langsung return
  if (source == null || !mounted) return;
  
  // // Handle remove photo
  // if (source == null) {
  //   if (widget.contact.image != null && widget.contact.image!.isNotEmpty || _selectedImageFile != null) {
  //     final confirmed = await showDialog<bool>(
  //       context: context,
  //       builder: (context) => AlertDialog(
  //         backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
  //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         title: const Text('Remove Photo'),
  //         content: const Text('Are you sure you want to remove the profile photo?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, false),
  //             child: const Text('Cancel'),
  //           ),
  //           ElevatedButton(
  //             onPressed: () => Navigator.pop(context, true),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Colors.red,
  //               foregroundColor: Colors.white,
  //             ),
  //             child: const Text('Remove'),
  //           ),
  //         ],
  //       ),
  //     );

  //     if (confirmed == true) {
  //       setState(() {
  //         _selectedImageFile = null;
  //         _newPhotoBase64 = '';
  //       });
  //       _showSnackBar('Profile photo will be removed when you save', isError: false);
  //     }
  //   }
  //   return;
  // }

  // ✅ PERBAIKAN: Upload dengan proper loading state management
  await _uploadProfilePhoto(source, isDarkMode);
}

// ✅ TAMBAHAN: Method terpisah untuk upload dengan loading management yang lebih baik
Future<void> _uploadProfilePhoto(ImageSource source, bool isDarkMode) async {
  try {
    // Step 1: Pick image DULU, baru show loading
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    // User cancel? langsung return
    if (image == null || !mounted) return;

    // Step 2: Show loading SETELAH image dipilih
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Uploading photo...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppTheme.darkTextPrimary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Step 3: Convert to base64
    final bytes = await File(image.path).readAsBytes();
    final base64Image = base64Encode(bytes);
    
    print('📤 Uploading to TemporaryUpload - Size: ${base64Image.length} characters');

    // Step 4: Upload menggunakan MediaService
    final uploadResponse = await MediaService.uploadBase64(
      filename: image.name,
      mimetype: 'image/jpeg',
      base64Data: base64Image,
    );

    // Step 5: Close loading dialog
    if (mounted) Navigator.pop(context);

    // Step 6: Handle hasil upload
    if (!uploadResponse.isError && uploadResponse.data != null) {
      final uploadedFile = uploadResponse.data!;
      
      print('✅ Upload successful! Filename: ${uploadedFile.filename}');

      if (mounted) {
        setState(() {
          _selectedImageFile = File(image.path);
          _newPhotoBase64 = uploadedFile.filename;
        });

        _showSnackBar('Profile photo selected. Click Save to apply changes.', isError: false);
      }
    } else {
      throw Exception(uploadResponse.error ?? 'Upload failed');
    }

  } catch (e) {
    // Pastikan loading dialog tertutup jika ada error
    if (mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst || !route.willHandlePopInternally);
    }
    
    print('❌ Error uploading photo: $e');
    
    if (mounted) {
      _showSnackBar('Failed to upload photo: ${e.toString()}', isError: true);
    }
  }
}

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Map<String, String> _getAuthHeaders() {
    final token = StorageService.getToken();
    return {
      'Authorization': 'Bearer $token',
      'User-Agent': 'NoboxChat/1.0',
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? AppTheme.darkBackground : const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Contact',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _saveContact,
                icon: const Icon(Icons.check, size: 18, color: Colors.white),
                label: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode 
                      ? Colors.black.withOpacity(0.2)
                      : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Builder(
                    builder: (context) {
                      final hasImage = _selectedImageFile != null || (widget.contact.image != null && widget.contact.image!.isNotEmpty);
                      final headers = _getAuthHeaders();
                      
                      ImageProvider? backgroundImage;
                      if (_selectedImageFile != null) {
                        backgroundImage = FileImage(_selectedImageFile!);
                      } else if (widget.contact.image != null && widget.contact.image!.isNotEmpty) {
                        backgroundImage = CachedNetworkImageProvider(
                          widget.contact.image!,
                          headers: headers,
                        );
                      }
                      
                      return Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.primaryColor,
                            backgroundImage: backgroundImage,
                            child: !hasImage
                              ? Text(
                                  widget.contact.name.isNotEmpty 
                                    ? widget.contact.name[0].toUpperCase()
                                    : '?',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _changeProfilePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDarkMode ? AppTheme.darkSurface : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Basic Information Card
            _buildSectionCard(
              isDarkMode: isDarkMode,
              title: 'Basic Information',
              icon: Icons.person_outline,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  isDarkMode: isDarkMode,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Category Dropdown with Search
                _buildSearchableDropdownField<String>(
                  label: 'Category',
                  icon: Icons.category,
                  isDarkMode: isDarkMode,
                  value: _selectedCategory,
                  items: _categories,
                  itemLabel: (category) => category,
                  itemValue: (category) => category,
                  onChanged: _isLoadingCategories ? null : (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  isLoading: _isLoadingCategories,
                  hint: 'Select a category',
                  itemCount: _categories.length,
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Location Information Card
            _buildSectionCard(
              isDarkMode: isDarkMode,
              title: 'Location Details',
              icon: Icons.location_on_outlined,
              children: [
                _buildTextField(
                  controller: _addressController,
                  label: 'Street Address',
                  icon: Icons.home_outlined,
                  isDarkMode: isDarkMode,
                  maxLines: 3,
                  hint: 'Enter full address',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _postalController,
                  label: 'Postal Code',
                  icon: Icons.markunread_mailbox_outlined,
                  isDarkMode: isDarkMode,
                  hint: 'Enter postal code',
                ),
                const SizedBox(height: 16),
                
                // Country Dropdown with Search
                _buildSearchableDropdownField<Country>(
                  label: 'Country',
                  icon: Icons.public,
                  isDarkMode: isDarkMode,
                  value: _selectedCountryId,
                  items: _countries,
                  itemLabel: (country) => country.name,
                  itemValue: (country) => country.id,
                  onChanged: _isLoadingCountries ? null : (value) {
                    setState(() {
                      _selectedCountryId = value;
                    });
                    if (value != null) {
                      final country = _countries.firstWhere((c) => c.id == value);
                      _loadStates(country.id);
                    }
                  },
                  isLoading: _isLoadingCountries,
                  hint: 'Select a country',
                  itemCount: _countries.length,
                ),
                
                const SizedBox(height: 16),
                
                // State Dropdown with Search
                _buildSearchableDropdownField<StateRegion>(
                  label: 'State / Province',
                  icon: Icons.map_outlined,
                  isDarkMode: isDarkMode,
                  value: _selectedStateId,
                  items: _states,
                  itemLabel: (state) => state.name,
                  itemValue: (state) => state.id,
                  onChanged: _selectedCountryId == null || _isLoadingStates ? null : (value) {
                    setState(() {
                      _selectedStateId = value;
                    });
                    if (value != null) {
                      final state = _states.firstWhere((s) => s.id == value);
                      _loadCities(state.id);
                    }
                  },
                  isLoading: _isLoadingStates,
                  hint: _selectedCountryId == null ? 'Select country first' : 'Select a state',
                  itemCount: _states.length,
                ),
                
                const SizedBox(height: 16),
                
                // City Dropdown with Search
                _buildSearchableDropdownField<City>(
                  label: 'City',
                  icon: Icons.location_city_outlined,
                  isDarkMode: isDarkMode,
                  value: _selectedCityId,
                  items: _cities,
                  itemLabel: (city) => city.name,
                  itemValue: (city) => city.id,
                  onChanged: _selectedStateId == null || _isLoadingCities ? null : (value) {
                    setState(() {
                      _selectedCityId = value;
                    });
                  },
                  isLoading: _isLoadingCities,
                  hint: _selectedStateId == null ? 'Select state first' : 'Select a city',
                  itemCount: _cities.length,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Changes will be saved to the contact record',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDarkMode,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode 
              ? Colors.black.withOpacity(0.2)
              : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 15,
            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: isDarkMode 
                ? AppTheme.darkTextSecondary.withOpacity(0.7)
                : Colors.grey.shade500,
              size: 20,
            ),
            hintText: hint,
            hintStyle: TextStyle(
              color: isDarkMode 
                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                : Colors.grey.shade400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDarkMode 
              ? AppTheme.darkBackground.withOpacity(0.5)
              : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.errorColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

Widget _buildSearchableDropdownField<T>({
  required String label,
  required IconData icon,
  required bool isDarkMode,
  required String? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required String Function(T) itemValue,
  required void Function(String?)? onChanged,
  required bool isLoading,
  required String hint,
  required int itemCount,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          // if (itemCount > 0) ...[
          //   const SizedBox(width: 8),
          //   Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          //     decoration: BoxDecoration(
          //       color: AppTheme.primaryColor.withOpacity(0.1),
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     child: Text(
          //       '$itemCount',
          //       style: const TextStyle(
          //         fontSize: 11,
          //         fontWeight: FontWeight.w600,
          //         color: AppTheme.primaryColor,
          //       ),
          //     ),
          //   ),
          // ],
        ],
      ),
      const SizedBox(height: 8),
      DropdownSearch<T>(
        items: items,
        itemAsString: itemLabel,
        selectedItem: value != null 
          ? items.where((item) => itemValue(item) == value).firstOrNull
          : null,
        onChanged: (T? selectedItem) {
          if (selectedItem != null) {
            onChanged?.call(itemValue(selectedItem));
          } else {
            onChanged?.call(null);
          }
        },
        enabled: onChanged != null && !isLoading,
        dropdownDecoratorProps: DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDarkMode 
                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                : Colors.grey.shade400,
              fontSize: 14,
            ),
            prefixIcon: isLoading 
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
              : Icon(
                  icon,
                  color: isDarkMode 
                    ? AppTheme.darkTextSecondary.withOpacity(0.7)
                    : Colors.grey.shade500,
                  size: 20,
                ),
            filled: true,
            fillColor: isDarkMode 
              ? AppTheme.darkBackground.withOpacity(0.5)
              : Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.shade200,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.1) 
                  : Colors.grey.shade200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode 
                  ? Colors.white.withOpacity(0.05) 
                  : Colors.grey.shade100,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          constraints: const BoxConstraints(maxHeight: 200), // Batasi tinggi dropdown
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search...',
              hintStyle: TextStyle(
                color: isDarkMode 
                  ? AppTheme.darkTextSecondary.withOpacity(0.5)
                  : Colors.grey.shade400,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDarkMode 
                  ? AppTheme.darkTextSecondary 
                  : Colors.grey.shade500,
                size: 20,
              ),
              filled: true,
              fillColor: isDarkMode 
                ? AppTheme.darkBackground.withOpacity(0.5)
                : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode 
                    ? Colors.white.withOpacity(0.1) 
                    : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          menuProps: MenuProps(
            backgroundColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context, item, isSelected) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              ),
              child: Text(
                itemLabel(item),
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            );
          },
          emptyBuilder: (context, searchEntry) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 48,
                    color: isDarkMode 
                      ? AppTheme.darkTextSecondary.withOpacity(0.5)
                      : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDarkMode 
                        ? AppTheme.darkTextSecondary 
                        : AppTheme.textSecondary, 
                    ),
                  ),
                ],
              ),
            ),
          ),
          searchDelay: const Duration(milliseconds: 300),
        ),
        dropdownButtonProps: DropdownButtonProps(
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade600,
          ),
        ),
      ),
    ],
  );
}
}