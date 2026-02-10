🛡️ Project Revoke: Technical PRD (Android MVP)

Version: 1.0 (Feb 2026)

Status: Draft / Ready for Implementation

Platform: Android (Primary)

Core Philosophy: Social accountability through friction, shame, and peer-governed access.
1. Executive Summary

Revoke is a social time-management application that replaces traditional "soft" app limits with a "hard" social locking mechanism. When a user runs out of time on a blacklisted app, they must beg their friends for more. Friends can approve, reject, or humiliate the user to discourage further use.
2. Technical Stack

    Frontend: Flutter (v3.x+)

    Backend: Firebase (Auth, Firestore for real-time state, Cloud Functions for logic, FCM for notifications)

    Native Bridge: Kotlin (MethodChannels for UsageStatsManager, SystemAlertWindow, and WallpaperManager)

    State Management: Riverpod (for reactive UI updates)

3. Functional Requirements
3.1 The "Monitor" (Core Engine)

    App Tracking: Use UsageStatsManager to poll the active package name and duration.

    The Blacklist: Users select apps to track (e.g., TikTok, Instagram, Twitter).

    Foreground Service: A persistent Android service that ensures the app isn't killed by the OS.

3.2 The "Blocker" (The Overlay)

    System Alert Window: When a limit is hit, trigger a full-screen Flutter overlay using TYPE_APPLICATION_OVERLAY.

    Hard Lock: The overlay must prevent "Back" button presses and "Recent Apps" navigation (via intent-based redirection if necessary).

3.3 The "Savage" Features (Social Hooks)
A. The Simp Protocol (Begging Mechanism)

    Logic: To send a "Time Request," the user must type a randomized, self-deprecating phrase (e.g., "I am a slave to the algorithm and I have no self-control").

    Validation: Regex-based matching. Request button is disabled until the text is 100% accurate.

B. Wallpaper Vandalism (The Shame Penalty)

    Logic: If a "Time Request" is rejected by a majority of the squad, the app uses WallpaperManager to change the user’s phone wallpaper to a "Loser" image uploaded by the friends.

    Frequency: Triggers immediately upon a failed vote.

C. Mutually Assured Destruction (MAD)

    Logic: Users join "Squads." If any squad member "Cheats" (uninstalls the app or forces it to stop—detected via heartbeat), all members lose 30% of their time allowance for the next 24 hours.

    Backend: Cloud Function monitors "Last Seen" timestamps in Firestore.

D. Bounty Hunter (Location + App Detection)

    Logic: If the user is at a "Work Geofence" but opens a "Leisure App," a "Bounty" is placed on their focus.

    Reward: Friends who vote to "Lock" the user earn "Discipline Points" (Gamified leaderboard).

4. Technical Architecture & Schema
4.1 Firestore Schema (Draft)
TypeScript

/users/{userId}
  - displayName: string
  - dailyAllowance: map { appId: duration }
  - currentStatus: "focus" | "begging" | "locked"
  - squadId: string

/squads/{squadId}
  - members: array[userId]
  - activeRequests: array[requestId]
  - penaltyPool: number

/requests/{requestId}
  - requesterId: userId
  - requestedMinutes: number
  - phraseToType: string
  - votes: map { userId: "approve" | "reject" }
  - status: "pending" | "approved" | "rejected"

5. Permissions (The "God Mode" Suite)

To function as intended on Android, the app requires:

    PACKAGE_USAGE_STATS: To see which apps are open.

    SYSTEM_ALERT_WINDOW: To draw the blocking overlay.

    SET_WALLPAPER: For the Vandalism feature.

    ACCESS_FINE_LOCATION: For Bounty Hunter geofencing.

    REQUEST_IGNORE_BATTERY_OPTIMIZATIONS: To keep the service alive.

6. Development Phases
Phase 1: The Cage (Local Blocking)

    Implement UsageStatsManager in Kotlin.

    Build the Flutter Overlay UI.

    Local timer logic (App closes when time > limit).

Phase 2: The Social Circle (Firebase Integration)

    Squad creation and friend invites.

    Real-time "Request for Time" flow with Push Notifications.

    Voting UI for friends.

Phase 3: The Punishment (Savage Logic)

    Implement Wallpaper Vandalism.

    Implement the Simp Protocol (Input validation).

    Implement MAD (Heartbeat monitoring).

7. Success Metrics

    Friction Score: Amount of time saved by users vs. baseline.

    Shame Engagement: Number of "Rejections" vs "Approvals" (The higher the rejections, the better the app is working).