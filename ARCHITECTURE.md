# Architecture & State Management Guide

## 📁 Component-Driven Project Folder Structure

In this structure:
- All pages/screens live inside `core/components/views/<page_name>/`
- Each page encapsulates its own `widgets/` and `models/`
- Reusable UI elements (like the centralized `CustomAppBar`) live in `core/components/`
- State management lives in `providers/`

```
lib/
├── core/                                # Core shared functionality
│   ├── components/                      # Reusable components & views
│   │   ├── custom_app_bar.dart          # 🌟 Centralized AppBar (with logo & theme toggle)
│   │   ├── custom_button.dart           # Reusable styled button
│   │   │
│   │   └── views/                       # 📄 Page views
│   │       ├── medicine/                # Medicine page
│   │       │   ├── models/
│   │       │   │   └── medicine_reminder_model.dart # Page-specific data model
│   │       │   ├── widgets/
│   │       │   │   ├── add_medicine_sheet.dart      # Bottom sheet modal
│   │       │   │   └── medicine_card.dart           # Reminder item card
│   │       │   └── medicine_view.dart               # Main Medicine page view
│   │       │
│   │       └── splash/                  # Splash page
│   │           └── splash_view.dart                 # Animated brand splash screen
│   │
│   ├── config/                          # App & Supabase environment configuration
│   │   └── app_config.dart
│   ├── constants/                       # Style tokens, assets, colors, strings
│   │   ├── app_assets.dart              # Logo & asset image references
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   ├── routes/                          # Application routes
│   │   └── app_routes.dart
│   ├── services/                        # External SDK services (e.g., Supabase)
│   │   └── supabase_service.dart
│   └── theme/                           # Material 3 light & dark theme
│       └── app_theme.dart
│
├── providers/                           # 🧠 State Management (ChangeNotifiers)
│   ├── app_providers.dart               # MultiProvider registry aggregator
│   ├── auth_provider.dart               # Supabase authentication session state
│   ├── medicine_reminder_provider.dart  # Medicine reminders state & CRUD mutations
│   └── theme_provider.dart              # Light / Dark mode state
│
└── main.dart                            # Application root with MultiProvider
```

---

## 🌟 Key Architecture Principles

### 1. `views/` Located Inside `components/`
All routed screen views are located in [core/components/views/](file:///d:/Personal/My-Medicine-Reminder/lib/core/components/views/).
Each page has its own subfolder containing:
- Its main screen view (`<page_name>_view.dart`)
- Sub-`widgets/` specific to that page
- Page `models/`

### 2. Centralized `CustomAppBar`
Use [CustomAppBar](file:///d:/Personal/My-Medicine-Reminder/lib/core/components/custom_app_bar.dart) to avoid repeating the brand logo, theme switcher, and header styles across pages:
```dart
appBar: const CustomAppBar(
  title: AppStrings.medicinesTitle,
  subtitle: AppStrings.appTagline,
)
```

### 3. Dedicated `providers/`
All `ChangeNotifier` state classes live in [providers/](file:///d:/Personal/My-Medicine-Reminder/lib/providers/) and are registered centrally in `AppProviders.providers` for `MultiProvider`.
