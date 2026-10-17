import '../../providers/app_preferences.dart';
import '../l10n/app_copy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

/// Centralized reusable AppBar for all pages in the app.
/// Eliminates code repetition for logo, branding, title styling, current user info,
/// logout, and theme toggling.
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final String? subtitle;
  final bool showLogo;
  final bool showThemeToggle;
  final bool showCurrentUser;
  final bool showLogout;
  final List<Widget>? actions;
  final Widget? leading;

  const CustomAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.showLogo = true,
    this.showThemeToggle = true,
    this.showCurrentUser = true,
    this.showLogout = true,
    this.actions,
    this.leading,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String effectiveTitle = title ?? '';
    String? effectiveSubtitle = subtitle;
    String userInitial = 'U';

    if (showCurrentUser) {
      final authProvider = context.watch<AuthProvider>();
      final user = authProvider.user;
      final userEmail = user?.email ?? 'user@notify.app';
      final metadataName = (user?.userMetadata?['full_name'] as String?) ??
          (user?.userMetadata?['name'] as String?);

      final displayName = (metadataName != null && metadataName.isNotEmpty)
          ? metadataName
          : (user?.email != null && user!.email!.isNotEmpty
              ? user.email!.split('@').first
              : 'User');

      effectiveTitle = title ?? displayName;
      effectiveSubtitle = subtitle ?? userEmail;
      userInitial =
          effectiveTitle.isNotEmpty ? effectiveTitle[0].toUpperCase() : 'U';
    }

    final guest = context.watch<AppPreferences?>()?.guestEnabled == true &&
        context.watch<AuthProvider>().user == null;
    if (guest && showCurrentUser) {
      effectiveTitle = context.tr('Local guest');
      effectiveSubtitle = context.tr('On this device only');
      userInitial = 'G';
    }
    Widget? leadingWidget = leading;
    if (leadingWidget == null && showCurrentUser) {
      leadingWidget = Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary,
            child: Text(
              userInitial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }

    return AppBar(
      leading: leadingWidget,
      leadingWidth: (leadingWidget != null && showCurrentUser) ? 52 : null,
      titleSpacing: showCurrentUser ? 12 : NavigationToolbar.kMiddleSpacing,
      centerTitle: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo && !showCurrentUser) ...[
            Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                AppAssets.appIcon,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.medication,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveTitle,
                  style: TextStyle(
                    fontSize: showCurrentUser ? 16 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (effectiveSubtitle != null && effectiveSubtitle.isNotEmpty)
                  Text(
                    effectiveSubtitle,
                    style: TextStyle(
                      fontSize: showCurrentUser ? 12 : 11,
                      fontWeight: FontWeight.normal,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (showThemeToggle)
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return IconButton(
                icon: Icon(
                  themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: context.tr('Toggle Theme'),
                onPressed: () => themeProvider.toggleTheme(),
              );
            },
          ),
        if (showLogout || showCurrentUser)
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 20),
            tooltip: context.tr('Log out'),
            onPressed: () async {
              final settings = context.read<AppPreferences?>();
              if (guest && settings != null) await settings.setGuest(false);
              if (!context.mounted) return;
              await context.read<AuthProvider>().signOut();
              if (context.mounted) {
                context.go(AppRoutes.authGate);
              }
            },
          ),
        ...?actions,
        const SizedBox(width: 4),
      ],
    );
  }
}
