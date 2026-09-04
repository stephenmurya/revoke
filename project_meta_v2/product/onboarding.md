# Revoke 2.0 Onboarding

Status: Canonical target flow. The current onboarding remains a release blocker; see ../engineering/status.md and the revival audit.

## Goal

Onboarding must explain the problem, establish behavioral reality where possible, create a first Commitment, and resume deterministically after Android settings detours. It must not force a Circle or Credit-backed Commitment.

## Target flow

1. Welcome and thesis.
2. Authentication.
3. Minimum Usage Access request for Reality Check where possible.
4. Reality Check: usage baseline, top distracting apps, and reliable high-usage periods; insufficient history is stated plainly.
5. Select apps/behavior to change.
6. Choose Reduce or Protect.
7. Configure the first Commitment: baseline/target/duration for Reduce, or protected window/cap for Protect.
8. Configure required enforcement permissions: Accessibility, overlay, exact alarms where needed, and battery/OEM guidance.
9. Explain Notice, Resist, and Revoke intervention levels.
10. Choose override authority: self, AI Warden if entitled, Circle, or no override.
11. Optionally create/join an Accountability Circle and set granular permissions.
12. Optionally preview Credit-backed Commitment capability; do not ask for Credits before the user understands the Commitment.
13. Review the full Commitment contract.
14. Show the primary Premium paywall before activation of paid functionality.
15. If Credit backing was selected, complete the required Credit purchase/lock flow before financially backed activation.
16. Activate only after server validation, immutable lease creation, native materialization, and synchronization acknowledgment.

## Persistence requirements

Persist semantic progress rather than only a page index, including at minimum:

- onboarding progress/state;
- baseline where applicable;
- target goal;
- Commitment draft;
- permission state and return-from-settings state;
- override policy;
- Circle choice and permissions;
- financial backing choice;
- accepted terms/product versions.

The state machine should expose states such as ACCOUNT_COMPLETE, USAGE_PERMISSION_REQUIRED, BASELINE_COMPLETE, COMMITMENT_DRAFTED, ENFORCEMENT_PERMISSIONS_REQUIRED, OVERRIDE_POLICY_COMPLETE, CREDIT_SETUP_COMPLETE, PAYWALL_REQUIRED, READY_TO_ACTIVATE, and COMPLETE.

## Trust and payment rules

No Circle creation, Credit backing, or Premium purchase is mandatory for ordinary Revoke use. The user must see amount, exact criteria, grace, verification health, and the rule that unverifiable evidence returns Credits before confirming a Credit-backed Commitment. Google Play policy compatibility is not assumed and must be validated before release.

