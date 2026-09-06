# Revoke 2.0 Device and Release Test Matrix

Status: test plan prepared; execution requires physical devices, Play Console configuration, and OEM coverage.

## Device matrix

| Family | Minimum checks | Status |
| --- | --- | --- |
| AOSP/Pixel, Android 12+ | Accessibility bind, Usage Access, overlay, reboot, service death, force-stop, schedule enforcement | NOT VERIFIED |
| Samsung One UI | battery optimization, Accessibility recovery, blocker overlay, reboot, FCM/native approval | NOT VERIFIED |
| Xiaomi/HyperOS or MIUI | autostart/battery restrictions, Accessibility recovery, alarms, overlay | NOT VERIFIED |
| Oppo/ColorOS or equivalent | background limits, reboot, exact alarm behavior, FCM | NOT VERIFIED |
| Android 14/15/16 API 34–36 | notification/runtime behavior, target SDK 36, PendingIntent/exported components | NOT VERIFIED |
| small and large phone sizes | blocker layout, text scaling, long app names, dark/light themes | NOT VERIFIED |

## Scenario matrix

1. Create and activate a Protect daily-limit Commitment; verify native type 1 payload and block/reminder behavior.
2. Create and activate a Protect protected-period Commitment; verify native type 0 payload and time-bound recovery.
3. Create a Reduce plan; verify taper materialization and native synchronization.
4. Kill Flutter, force-stop the app, kill the monitor service, reboot, and remove/regrant permissions; verify recovery and fail-safe behavior.
5. Deliver an approved Circle/AI override while Flutter is dead; verify native receiver UID/package/expiry/idempotency checks and no duplicate unlock.
6. Repeat every-purchase disclosure and Premium/Credit purchase restore/reversal scenarios with a licensed Play tester.
7. Run clock/timezone changes, DST boundaries, offline evidence upload, duplicate retries, and account switch/delete/reinstall scenarios.

## Evidence required before release

Capture device model, Android/API level, OEM battery settings, app version, native logs, Firebase/FCM result, and pass/fail outcome for each scenario. Automated analysis/build success cannot substitute for this matrix.
