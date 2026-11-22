# Earn Your Time — Product and technical specification

## Product goal

Earn Your Time is an Android-first, offline app that automatically exchanges foreground time in selected productive apps for additional time in selected distracting apps. It is not a Pomodoro timer and must not require manually starting a focus session.

## User-configurable rules

- The user chooses one or more **productive apps** (for example, KineMaster and Canva).
- The user chooses one or more **distracting apps** (for example, YouTube, Instagram and TikTok).
- The user sets a **daily entertainment allowance** in minutes.
- The user sets a **reward ratio**: productive minutes converted into entertainment minutes. The ratio must be editable (for example 1 productive minute = 1 entertainment minute).
- Settings must be editable later without losing the current day's usage unexpectedly.

No fixed numeric defaults are assumed by this specification. The first-run setup should ask the user to configure both values before protection is enabled.

## Daily accounting model

At the beginning of each local calendar day:

- Start the day with the configured daily allowance.
- Reset today's distracting-app usage and today's earned reward to zero.
- Expire all unused allowance/reward from the previous day. Nothing carries over.
- Productive time and reward credits earned today count only toward today's allowance.

During the day:

- Foreground time in any selected productive app earns credit automatically according to the configured ratio.
- Foreground time in any selected distracting app spends available entertainment time.
- Remaining entertainment time = daily allowance + rewards earned today - distracting-app time used today.
- If remaining time reaches zero, selected distracting apps are blocked until more productive time is earned or the next local day begins.
- Productive apps, the Earn Your Time app, Android system UI, launcher, lock screen, phone idle time and screen-off time must not earn or spend credits.
- Time must be counted once only; switching between productive apps must not double-count.
- Use elapsed/monotonic time for intervals and local calendar date only for daily rollover. Handle time-zone and daylight-saving changes safely.

## Blocking and platform limitations

- Use Android Usage Access to identify foreground app events.
- Use a user-visible foreground service while automatic tracking/blocking is active, with a persistent notification and an explicit pause/stop control.
- Reuse the existing overlay-based blocker only where Android allows it. Do not claim it is impossible to bypass: Android system screens, some OEM behavior, multi-window and permission revocation can limit overlays.
- Never silently enable Accessibility. Do not add Accessibility permission unless a later design decision explicitly requires it and the user is clearly informed.
- Handle Android battery restrictions and Xiaomi background management with an honest protection-status screen.
- Fail safely: if tracking permission/service is lost, do not grant unearned credit. Show that protection is paused/unavailable.

## First implementation milestones

1. Add and test a daily accounting model with editable allowance and reward ratio.
2. Add separate productive-app and distracting-app selections.
3. Implement continuous foreground usage accounting (no manual timer/session).
4. Connect the accounting model to the Android blocker.
5. Add the Spanish Earn Your Time interface and first-run setup.
6. Build debug/release APKs with GitHub Actions and test on a physical Xiaomi phone.

## Existing codebase

This repository is a fork of FocusFeed (MIT). It contains Flutter UI, native Kotlin usage-event monitoring, an overlay blocker, local persistence, and CI. Its current Pomodoro/session model awards a fixed 20% of a completed manual focus session. That behavior is not the desired product and must be replaced in stages, with tests before changing the blocker lifecycle.

## Privacy

The app should remain offline. App usage, selected package names, daily totals and settings stay on-device. Do not add analytics, advertising, accounts, remote APIs or unnecessary package visibility.
