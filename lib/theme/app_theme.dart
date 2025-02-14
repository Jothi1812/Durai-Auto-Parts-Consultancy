import 'package:flutter/material.dart';

class AppTheme {
    // Vibrant Color scheme
    static const Color primaryColor = Color(0xFF6C5CE7);      // Rich Purple
    static const Color secondaryColor = Color(0xFF00D2D3);    // Turquoise
    static const Color accentColor = Color(0xFFFF9F43);       // Orange
    static const Color backgroundColor = Color(0xFFF8F9FE);   // Light Background
    static const Color cardColor = Colors.white;
    static const Color errorColor = Color(0xFFFF6B6B);        // Coral Red
    static const Color successColor = Color(0xFF2ECC71);      // Emerald Green
    static const Color textPrimaryColor = Color(0xFF2D3436);
    static const Color textSecondaryColor = Color(0xFF636E72);

    // Gradients
    static const LinearGradient primaryGradient = LinearGradient(
        colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3), Color(0xFFFF9F43)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
    );

    static const LinearGradient accentGradient = LinearGradient(
        colors: [Color(0xFFFF9F43), Color(0xFFFF6B6B), Color(0xFF2ECC71)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
    );

    // Animation Durations
    static const Duration defaultDuration = Duration(milliseconds: 300);
    static const Duration longDuration = Duration(milliseconds: 500);

    // Animation Curves
    static const Curve defaultCurve = Curves.easeInOut;
    static const Curve bounceCurve = Curves.elasticOut;

    // Padding and Margins
    static const EdgeInsets defaultPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    static const EdgeInsets cardMargin = EdgeInsets.symmetric(vertical: 8, horizontal: 16);

    // Text Styles
    static const TextStyle titleTextStyle = TextStyle(
        color: textPrimaryColor,
        fontSize: 20,
        fontWeight: FontWeight.w600,
    );

    static const TextStyle bodyTextStyle = TextStyle(
        color: textSecondaryColor,
        fontSize: 16,
    );

    static ThemeData getTheme() {
        return ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: primaryColor,
                background: backgroundColor,
                secondary: secondaryColor,
            ),
            
            // AppBar theme with gradient
            appBarTheme: AppBarTheme(
                elevation: 0,
                centerTitle: true,
                backgroundColor: cardColor,
                foregroundColor: textPrimaryColor,
                titleTextStyle: titleTextStyle,
                systemOverlayStyle: null,
                scrolledUnderElevation: 2,
                shadowColor: primaryColor.withOpacity(0.2),
            ),
            
            // Enhanced Card theme
            cardTheme: CardTheme(
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                ),
                color: cardColor,
                margin: cardMargin,
            ),
            
            // Enhanced Input decoration
            inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: backgroundColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: primaryColor, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: errorColor),
                ),
                contentPadding: defaultPadding,
                prefixIconColor: primaryColor,
                suffixIconColor: primaryColor,
                hoverColor: primaryColor.withOpacity(0.05),
            ),
            
            // Enhanced Button theme
            elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shadowColor: primaryColor.withOpacity(0.3),
                ).copyWith(
                    elevation: MaterialStateProperty.resolveWith<double>(
                        (Set<MaterialState> states) {
                            if (states.contains(MaterialState.hovered)) return 4;
                            if (states.contains(MaterialState.pressed)) return 0;
                            return 2;
                        },
                    ),
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                        (Set<MaterialState> states) {
                            if (states.contains(MaterialState.pressed)) {
                                return Colors.white.withOpacity(0.2);
                            }
                            return null;
                        },
                    ),
                ),
            ),
            
            // Enhanced ListTile theme
            listTileTheme: ListTileThemeData(
                contentPadding: defaultPadding,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                ),
                tileColor: cardColor,
                selectedTileColor: primaryColor.withOpacity(0.1),
                horizontalTitleGap: 16,
            ),
            
            // Drawer theme with gradient
            drawerTheme: DrawerThemeData(
                backgroundColor: cardColor,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                    ),
                ),
                elevation: 10,
                shadowColor: primaryColor.withOpacity(0.2),
            ),
        );
    }

    // Custom Animations and Effects
    static Widget addShimmer(Widget child) {
        return ShaderMask(
            shaderCallback: (Rect bounds) {
                return const LinearGradient(
                    colors: [Colors.white, Colors.white54, Colors.white],
                    stops: [0.0, 0.5, 1.0],
                    begin: Alignment(-1.0, -0.5),
                    end: Alignment(1.0, 0.5),
                    tileMode: TileMode.clamp,
                ).createShader(bounds);
            },
            child: child,
        );
    }

    // Enhanced Card Decoration
    static BoxDecoration get cardDecoration => BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
            BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
            ),
            BoxShadow(
                color: primaryColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
            ),
        ],
    );

    // Gradient Card Decoration
    static BoxDecoration get gradientCardDecoration => BoxDecoration(
        gradient: primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
            BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
            ),
        ],
    );

    // Custom Animation Builders
    static Widget fadeInTransition({
        required Widget child,
        Duration duration = const Duration(milliseconds: 300),
    }) {
        return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: duration,
            curve: Curves.easeOut,
            builder: (context, value, child) {
                return Opacity(
                    opacity: value,
                    child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                    ),
                );
            },
            child: child,
        );
    }

    static Widget scaleTransition({
        required Widget child,
        Duration duration = const Duration(milliseconds: 300),
    }) {
        return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: duration,
            curve: Curves.easeOut,
            builder: (context, value, child) {
                return Transform.scale(
                    scale: value,
                    child: child,
                );
            },
            child: child,
        );
    }
}

// Custom Animated Container for Cards
class AnimatedCard extends StatelessWidget {
    final Widget child;
    final VoidCallback? onTap;
    final bool useGradient;

    const AnimatedCard({
        Key? key,
        required this.child,
        this.onTap,
        this.useGradient = false,
    }) : super(key: key);

    @override
    Widget build(BuildContext context) {
        return TweenAnimationBuilder<double>(
            tween: Tween(begin: 1.0, end: 1.0),
            duration: AppTheme.defaultDuration,
            builder: (context, scale, child) {
                return Transform.scale(
                    scale: scale,
                    child: Container(
                        decoration: useGradient 
                                ? AppTheme.gradientCardDecoration 
                                : AppTheme.cardDecoration,
                        child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                                onTap: onTap,
                                borderRadius: BorderRadius.circular(16),
                                child: child,
                            ),
                        ),
                    ),
                );
            },
            child: child,
        );
    }
}