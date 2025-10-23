import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nobox_chat/core/models/contact_detail_models.dart';
import 'package:nobox_chat/core/models/location_models.dart';
import 'package:nobox_chat/core/providers/contact_detail_provider.dart';
import 'package:nobox_chat/core/providers/theme_provider.dart';
import 'package:nobox_chat/core/services/address_service.dart';
import 'package:nobox_chat/core/services/contact_detail_service.dart';
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
  
  List<String> _categories = [];
  List<Country> _countries = [];
  List<StateRegion> _states = [];
  List<City> _cities = [];
  
  String? _selectedCategory;
  String? _selectedCountryId;
  String? _selectedStateId;
  String? _selectedCityId;
  
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
    
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    // Load categories and countries in parallel
    await Future.wait([
      _loadCategories(),
      _loadCountries(),
    ]);
    
    // Set category if exists
    if (widget.contact.category != null && _categories.contains(widget.contact.category)) {
      setState(() {
        _selectedCategory = widget.contact.category;
      });
    }
    
    // Load location data if contact has country
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
        state: selectedState.isNotEmpty ? selectedState : null,
        country: selectedCountry.isNotEmpty ? selectedCountry : null,
        city: selectedCity.isNotEmpty ? selectedCity : null,
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
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.8),
                          AppTheme.secondaryColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.contact.name.isNotEmpty 
                          ? widget.contact.name[0].toUpperCase()
                          : '?',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
                
                // Category Dropdown
                _buildDropdownField(
                  label: 'Category',
                  icon: Icons.category,
                  isDarkMode: isDarkMode,
                  value: _selectedCategory,
                  items: _categories,
                  itemBuilder: (category) => DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  ),
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
                _buildDropdownField(
                  label: 'Country',
                  icon: Icons.public,
                  isDarkMode: isDarkMode,
                  value: _selectedCountryId,
                  items: _countries,
                  itemBuilder: (country) => DropdownMenuItem<String>(
                    value: country.id,
                    child: Text(country.name),
                  ),
                  onChanged: _isLoadingCountries ? null : (value) {
                    setState(() {
                      _selectedCountryId = value;
                    });
                    if (value != null) {
                      _loadStates(value);
                    }
                  },
                  isLoading: _isLoadingCountries,
                  hint: 'Select a country',
                  itemCount: _countries.length,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'State / Province',
                  icon: Icons.map_outlined,
                  isDarkMode: isDarkMode,
                  value: _selectedStateId,
                  items: _states,
                  itemBuilder: (state) => DropdownMenuItem<String>(
                    value: state.id,
                    child: Text(state.name),
                  ),
                  onChanged: _selectedCountryId == null || _isLoadingStates ? null : (value) {
                    setState(() {
                      _selectedStateId = value;
                    });
                    if (value != null) {
                      _loadCities(value);
                    }
                  },
                  isLoading: _isLoadingStates,
                  hint: _selectedCountryId == null ? 'Select country first' : 'Select a state',
                  itemCount: _states.length,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  label: 'City',
                  icon: Icons.location_city_outlined,
                  isDarkMode: isDarkMode,
                  value: _selectedCityId,
                  items: _cities,
                  itemBuilder: (city) => DropdownMenuItem<String>(
                    value: city.id,
                    child: Text(city.name),
                  ),
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

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required bool isDarkMode,
    required String? value,
    required List<T> items,
    required DropdownMenuItem<String> Function(T) itemBuilder,
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
            if (itemCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$itemCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
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
          hint: Text(
            hint,
            style: TextStyle(
              color: isDarkMode 
                ? AppTheme.darkTextSecondary.withOpacity(0.5)
                : Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
          dropdownColor: isDarkMode ? AppTheme.darkSurface : Colors.white,
          style: TextStyle(
            fontSize: 15,
            color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: isDarkMode ? AppTheme.darkTextSecondary : Colors.grey.shade600,
          ),
          items: items.map(itemBuilder).toList(),
          onChanged: onChanged,
          isExpanded: true,
          menuMaxHeight: 300,
        ),
      ],
    );
  }
}