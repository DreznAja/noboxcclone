import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quick_reply_models.dart';
import '../services/api_service.dart';

class QuickReplyState {
  final List<QuickReplyTemplate> templates;
  final List<QuickReplyTemplate> filteredTemplates;
  final bool isLoading;
  final String? error;
  final String? searchQuery;

  QuickReplyState({
    this.templates = const [],
    this.filteredTemplates = const [],
    this.isLoading = false,
    this.error,
    this.searchQuery,
  });

  QuickReplyState copyWith({
    List<QuickReplyTemplate>? templates,
    List<QuickReplyTemplate>? filteredTemplates,
    bool? isLoading,
    String? error,
    String? searchQuery,
  }) {
    return QuickReplyState(
      templates: templates ?? this.templates,
      filteredTemplates: filteredTemplates ?? this.filteredTemplates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class QuickReplyNotifier extends StateNotifier<QuickReplyState> {
  QuickReplyNotifier() : super(QuickReplyState());

  Future<void> loadTemplates() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await ApiService.getQuickReplyTemplates();
      
      if (response.isError) {
        state = state.copyWith(
          isLoading: false,
          error: response.error,
        );
        return;
      }
      
      final templates = response.data ?? [];
      state = state.copyWith(
        templates: templates,
        filteredTemplates: templates,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void searchTemplates(String query) {
    if (query.isEmpty) {
      state = state.copyWith(
        filteredTemplates: state.templates,
        searchQuery: '',
      );
      return;
    }

    // Remove "/" prefix if present
    final searchQuery = query.startsWith('/') ? query.substring(1) : query;
    
    final filtered = state.templates.where((template) {
      final commandMatch = template.command.toLowerCase().contains(searchQuery.toLowerCase());
      final contentMatch = template.content.toLowerCase().contains(searchQuery.toLowerCase());
      return commandMatch || contentMatch;
    }).toList();

    state = state.copyWith(
      filteredTemplates: filtered,
      searchQuery: searchQuery,
    );
  }

  void clearSearch() {
    state = state.copyWith(
      filteredTemplates: state.templates,
      searchQuery: '',
    );
  }
}

final quickReplyProvider = StateNotifierProvider<QuickReplyNotifier, QuickReplyState>((ref) {
  return QuickReplyNotifier();
});
