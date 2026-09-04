# Onboarding Flow Audit

## SCREENS FOUND
1. **SplashScreen (`lib/features/splash/splash_screen.dart`)**
   - **What it does:** Initial routing decision point.
   - **Navigation trigger:** Auto-routes based on `AuthService.currentUser` and `app_router.dart` logic.
   - **Issues:** None directly in the screen, but router logic creates unreachable states.
2. **OnboardingScreen (`lib/features/auth/onboarding_screen.dart`)**
   - **What it does:** A `PageView` orchestrating 8 steps of onboarding (Auth, Alias, Permissions, Accessibility, Delusion, Reality, Vow, Recruitment).
   - **Navigation trigger:** Internal `_nextPage()` calls or `_jumpToShareSquadStep()` after Google Auth.
   - **Issues:** See "WHAT IS PRESENT BUT BROKEN".
3. **AccessibilityDisclosureScreen (`lib/features/auth/accessibility_disclosure_screen.dart`)**
   - **What it does:** Explains why accessibility is needed and checks permission status.
   - **Navigation trigger:** "Grant Accessibility Access" calls native settings.
   - **Issues:** None.
4. **PermissionScreen (`lib/features/permissions/permission_screen.dart`)**
   - **What it does:** Standalone screen to grant Usage Stats, Overlay, and Exact Alarms.
   - **Navigation trigger:** "Continue" calls `context.go('/home')` or equivalent depending on router.
   - **Issues:** None directly.

## NAVIGATION GRAPH
1. **Splash Screen**
   - If not authenticated -> `/onboarding` (Step 0: Auth)
   - If authenticated, no squad, no nickname -> `/onboarding` (Step 1: Alias)
   - If authenticated, has nickname, no squad -> `/onboarding?step=share_squad` (Step 7: Recruitment)
   - If authenticated, has squad -> `/home`

2. **Onboarding PageView Flow (Intended)**
   - Step 0 (Auth) -> Sign in -> Step 1 (Alias)
   - Step 1 (Alias) -> Submit Nickname -> Step 2 (Permissions)
   - Step 2 (Permissions) -> If all granted -> Step 3 (Accessibility) OR if not granted -> Opens `/permissions` screen.
   - Step 3 (Accessibility) -> Grant -> Step 4 (Delusion)
   - Step 4 (Delusion) -> Estimate Hours -> Step 5 (Reality)
   - Step 5 (Reality) -> Accept Truth -> Step 6 (Vow)
   - Step 6 (Vow) -> Lock Daily Goal -> Step 7 (Recruitment)
   - Step 7 (Recruitment) -> Join/Create Squad -> `/home`

## WHAT IS PRESENT BUT BROKEN
1. **The "Delusion / Reality / Vow" Bypass:**
   If a user completes Step 1 (Alias), they have a nickname. If they then lack permissions on Step 2 and are routed to `/permissions`, the global `app_router.dart` will intercept them upon return. Because they now have a nickname but no squad, the router forces them to `/onboarding?step=share_squad`. This completely skips Step 3, 4, 5, and 6. The user never sees the Reality Check or Vow.
2. **The "Vow" Step Saves Nothing:**
   In `_buildStepVow`, the "LOCK IT IN" button has a comment `// Save goal logic here if needed` but simply calls `_nextPage()`. The user's chosen `_goalHours` is entirely discarded.
3. **App Restart Bypass:**
   If a user hard-closes the app during Step 4, 5, or 6, restarting the app sends them to Splash. Splash sees they have a nickname and routes them to `/onboarding?step=share_squad`, permanently skipping the middle steps.

## WHAT IS ABSENT
1. **Goal Storage Logic:** The backend/local storage logic for the user's daily limit vow is entirely missing.
2. **Post-Permission Resume Logic:** The onboarding flow lacks the ability to resume at the exact step the user left off if they background the app or route to settings. It relies on a simplistic `hasNickname` check.
