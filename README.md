# Pet Passport

Plan your pet's international trip without guessing the paperwork. iOS app that
generates a compliance timeline (microchip, rabies vaccine, blood-titer test,
APHIS-endorsed health certificate, import permit, quarantine) from an owner's
departure date + destination country.

## Status

Stage-1 scaffold. iOS 16+, SwiftUI, StoreKit 2, `xcodegen` project.

## Running locally

```bash
xcodegen generate
open PetPassport.xcodeproj
```

Or from CLI:

```bash
xcodegen generate
xcodebuild -project PetPassport.xcodeproj -scheme PetPassport \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test
```

## Product model

- **Free**: Canada, Mexico, United Kingdom — the three most-searched US-outbound destinations.
- **Pro ($9.99 lifetime)**: everything else (Japan, Australia, Germany, France, New Zealand, Ireland, Switzerland so far).

StoreKit product ID: `com.mypetpassport.app.pro.lifetime` — non-consumable.

## Bundle + team

- Bundle: `com.mypetpassport.app`
- Team: `NH2XFPC9KN`
- ASC app ID: _to be created in Stage 5_

## Structure

```
PetPassport/
  App/              PetPassportApp.swift — entry point
  Core/             Pure model + services (no SwiftUI)
    PricingConfig.swift
    PurchaseManager.swift     StoreKit 2 wrapper
    SettingsStore.swift       UserDefaults-backed prefs
    AnalyticsClient.swift     No-op; see PrivacyInfo.xcprivacy
    PetProfile.swift          Local-only pet records
    Destinations.swift        Catalog of countries + their rules
    Timeline.swift            Pure builder — lead times → absolute dates
  Features/         SwiftUI views
    RootView.swift
    OnboardingView.swift
    HomeView.swift
    PetProfileEditor.swift
    DestinationPickerView.swift
    TimelineSetupView.swift
    TimelineResultView.swift
    PaywallView.swift
    SettingsView.swift
  Resources/
    Info.plist
    PrivacyInfo.xcprivacy     NSPrivacyTracking=false, no data collected
    Configuration.storekit    StoreKit testing config
PetPassportTests/
  TimelineBuilderTests.swift
  DestinationCatalogTests.swift
  PurchaseManagerTests.swift
```

## Privacy posture

- No accounts. No sync. No network telemetry. Pet profiles live in
  `UserDefaults` on-device.
- `PrivacyInfo.xcprivacy` declares `NSPrivacyTracking: false` and
  `NSPrivacyCollectedDataTypes: []`.
- App Privacy nutrition label will answer **"No data collected"**.

## License

Proprietary. © 2026 anthony mcmurtrey. Trademarks belong to their respective owners.
