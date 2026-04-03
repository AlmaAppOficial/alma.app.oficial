import Foundation
import FirebaseAnalytics
import FirebaseAuth

// MARK: - Analytics Events Enum
/// Type-safe Firebase Analytics events for the Alma meditation app
enum AnalyticsEvent {
    // Meditation lifecycle events
    case meditationStarted(meditationType: String, duration: Int)
    case meditationCompleted(meditationType: String, actualDuration: Int, scheduled: Int)
    case meditationSkipped(meditationType: String, secondsElapsed: Int)

    // Breathing exercises
    case breathingExerciseStarted(type: String, duration: Int)
    case breathingExerciseCompleted(type: String, actualDuration: Int)

    // Mood and journaling
    case moodLogged(mood: String, intensity: Int)
    case journalEntryCreated(category: String, wordCount: Int)

    // Onboarding
    case onboardingStepCompleted(step: Int, stepName: String)
    case onboardingCompleted(totalSteps: Int, timeToComplete: Int)

    // Subscription and trial
    case trialStarted(trial: String)
    case subscriptionStarted(productId: String, price: Double, currency: String)
    case subscriptionCancelled(productId: String, reason: String?)
    case subscriptionRenewed(productId: String, price: Double)

    // Notifications
    case notificationPermissionGranted
    case notificationPermissionDenied
    case notificationReceived(type: String)
    case notificationOpened(type: String)

    // Streak milestones
    case streakMilestone(days: Int)

    // Audio and content
    case audioPlayerOpened(contentType: String)
    case audioQualitySelected(quality: String)
    case ambientSoundEnabled(soundType: String)

    // Feature engagement
    case insightsViewOpened
    case profileUpdated(field: String)
    case settingsChanged(setting: String, newValue: String)

    // Search and discovery
    case meditationSearched(query: String)
    case filterApplied(filterType: String, value: String)

    // Error tracking
    case errorOccurred(errorCode: String, errorMessage: String, screen: String)

    // Screen view (handled separately via Analytics.logEvent with screen_view)
    case screenViewed(screenName: String)

    var eventName: String {
        switch self {
        case .meditationStarted:
            return "meditation_started"
        case .meditationCompleted:
            return "meditation_completed"
        case .meditationSkipped:
            return "meditation_skipped"
        case .breathingExerciseStarted:
            return "breathing_exercise_started"
        case .breathingExerciseCompleted:
            return "breathing_exercise_completed"
        case .moodLogged:
            return "mood_logged"
        case .journalEntryCreated:
            return "journal_entry_created"
        case .onboardingStepCompleted:
            return "onboarding_step_completed"
        case .onboardingCompleted:
            return "onboarding_completed"
        case .trialStarted:
            return "trial_started"
        case .subscriptionStarted:
            return "subscription_started"
        case .subscriptionCancelled:
            return "subscription_cancelled"
        case .subscriptionRenewed:
            return "subscription_renewed"
        case .notificationPermissionGranted:
            return "notification_permission_granted"
        case .notificationPermissionDenied:
            return "notification_permission_denied"
        case .notificationReceived:
            return "notification_received"
        case .notificationOpened:
            return "notification_opened"
        case .streakMilestone:
            return "streak_milestone"
        case .audioPlayerOpened:
            return "audio_player_opened"
        case .audioQualitySelected:
            return "audio_quality_selected"
        case .ambientSoundEnabled:
            return "ambient_sound_enabled"
        case .insightsViewOpened:
            return "insights_view_opened"
        case .profileUpdated:
            return "profile_updated"
        case .settingsChanged:
            return "settings_changed"
        case .meditationSearched:
            return "meditation_searched"
        case .filterApplied:
            return "filter_applied"
        case .errorOccurred:
            return "error_occurred"
        case .screenViewed:
            return "screen_viewed"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .meditationStarted(let type, let duration):
            return [
                "meditation_type": type,
                "scheduled_duration": duration
            ]
        case .meditationCompleted(let type, let actual, let scheduled):
            return [
                "meditation_type": type,
                "actual_duration": actual,
                "scheduled_duration": scheduled,
                "completion_rate": Double(actual) / Double(scheduled)
            ]
        case .meditationSkipped(let type, let seconds):
            return [
                "meditation_type": type,
                "seconds_elapsed": seconds
            ]
        case .breathingExerciseStarted(let type, let duration):
            return [
                "exercise_type": type,
                "duration": duration
            ]
        case .breathingExerciseCompleted(let type, let duration):
            return [
                "exercise_type": type,
                "actual_duration": duration
            ]
        case .moodLogged(let mood, let intensity):
            return [
                "mood": mood,
                "intensity": intensity
            ]
        case .journalEntryCreated(let category, let wordCount):
            return [
                "category": category,
                "word_count": wordCount
            ]
        case .onboardingStepCompleted(let step, let stepName):
            return [
                "step_number": step,
                "step_name": stepName
            ]
        case .onboardingCompleted(let totalSteps, let timeToComplete):
            return [
                "total_steps": totalSteps,
                "time_to_complete_seconds": timeToComplete
            ]
        case .trialStarted(let trial):
            return [
                "trial_type": trial
            ]
        case .subscriptionStarted(let productId, let price, let currency):
            return [
                "product_id": productId,
                AnalyticsParameterPrice: price,
                AnalyticsParameterCurrency: currency,
                AnalyticsParameterValue: price
            ]
        case .subscriptionCancelled(let productId, let reason):
            var params: [String: Any] = ["product_id": productId]
            if let reason = reason {
                params["cancellation_reason"] = reason
            }
            return params
        case .subscriptionRenewed(let productId, let price):
            return [
                "product_id": productId,
                AnalyticsParameterPrice: price
            ]
        case .notificationPermissionGranted:
            return nil
        case .notificationPermissionDenied:
            return nil
        case .notificationReceived(let type):
            return ["notification_type": type]
        case .notificationOpened(let type):
            return ["notification_type": type]
        case .streakMilestone(let days):
            return ["days": days]
        case .audioPlayerOpened(let contentType):
            return ["content_type": contentType]
        case .audioQualitySelected(let quality):
            return ["quality": quality]
        case .ambientSoundEnabled(let soundType):
            return ["sound_type": soundType]
        case .insightsViewOpened:
            return nil
        case .profileUpdated(let field):
            return ["field": field]
        case .settingsChanged(let setting, let value):
            return [
                "setting_name": setting,
                "new_value": value
            ]
        case .meditationSearched(let query):
            return [
                AnalyticsParameterSearchTerm: query
            ]
        case .filterApplied(let type, let value):
            return [
                "filter_type": type,
                "filter_value": value
            ]
        case .errorOccurred(let code, let message, let screen):
            return [
                "error_code": code,
                "error_message": message,
                "screen": screen
            ]
        case .screenViewed(let screenName):
            return [
                AnalyticsParameterScreenName: screenName
            ]
        }
    }
}

// MARK: - User Properties Enum
enum AnalyticsUserProperty {
    case subscriptionStatus(String) // "free", "trial", "paid"
    case language(String)
    case experienceLevel(String) // "beginner", "intermediate", "advanced"
    case totalMeditationsCompleted(Int)
    case currentStreak(Int)
    case onboardingCompleted(Bool)
    case meditationFrequency(String) // "daily", "weekly", "occasional"
    case preferredMeditationType(String)
    case notificationsEnabled(Bool)

    var propertyName: String {
        switch self {
        case .subscriptionStatus:
            return "subscription_status"
        case .language:
            return "language"
        case .experienceLevel:
            return "experience_level"
        case .totalMeditationsCompleted:
            return "total_meditations_completed"
        case .currentStreak:
            return "current_streak"
        case .onboardingCompleted:
            return "onboarding_completed"
        case .meditationFrequency:
            return "meditation_frequency"
        case .preferredMeditationType:
            return "preferred_meditation_type"
        case .notificationsEnabled:
            return "notifications_enabled"
        }
    }

    var value: String {
        switch self {
        case .subscriptionStatus(let status):
            return status
        case .language(let lang):
            return lang
        case .experienceLevel(let level):
            return level
        case .totalMeditationsCompleted(let count):
            return "\(count)"
        case .currentStreak(let days):
            return "\(days)"
        case .onboardingCompleted(let completed):
            return completed ? "true" : "false"
        case .meditationFrequency(let freq):
            return freq
        case .preferredMeditationType(let type):
            return type
        case .notificationsEnabled(let enabled):
            return enabled ? "true" : "false"
        }
    }
}

// MARK: - AnalyticsManager
final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private init() {
        setupAnalytics()
    }

    private func setupAnalytics() {
        // Firebase Analytics is automatically initialized when FirebaseApp.configure() is called
        // in the app delegate
        #if DEBUG
        print("[Analytics] ✓ AnalyticsManager initialized")
        #endif
    }

    // MARK: - Event Logging

    /// Log an analytics event with type safety
    /// - Parameter event: AnalyticsEvent enum case
    func logEvent(_ event: AnalyticsEvent) {
        var parameters = event.parameters ?? [:]

        // Add common context parameters
        addContextParameters(&parameters)

        #if DEBUG
        print("[Analytics] Event: \(event.eventName) - Params: \(parameters)")
        #endif

        Analytics.logEvent(event.eventName, parameters: parameters)
    }

    /// Log a custom event (for events not defined in AnalyticsEvent enum)
    /// - Parameters:
    ///   - eventName: Name of the event
    ///   - parameters: Event parameters
    func logCustomEvent(_ eventName: String, parameters: [String: Any]? = nil) {
        var params = parameters ?? [:]
        addContextParameters(&params)

        #if DEBUG
        print("[Analytics] Custom Event: \(eventName) - Params: \(params)")
        #endif

        Analytics.logEvent(eventName, parameters: params)
    }

    // MARK: - Screen Tracking

    /// Log a screen view
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Class name (optional)
    func logScreenView(_ screenName: String, screenClass: String? = nil) {
        var parameters: [String: Any] = [
            AnalyticsParameterScreenName: screenName
        ]

        if let screenClass = screenClass {
            parameters[AnalyticsParameterScreenClass] = screenClass
        }

        addContextParameters(&parameters)

        #if DEBUG
        print("[Analytics] Screen: \(screenName)")
        #endif

        Analytics.logEvent(AnalyticsEventScreenView, parameters: parameters)
    }

    // MARK: - User Properties

    /// Set a user property
    /// - Parameter property: AnalyticsUserProperty enum case
    func setUserProperty(_ property: AnalyticsUserProperty) {
        Analytics.setUserProperty(property.value, forName: property.propertyName)

        #if DEBUG
        print("[Analytics] User Property: \(property.propertyName) = \(property.value)")
        #endif
    }

    /// Set multiple user properties
    /// - Parameter properties: Array of AnalyticsUserProperty cases
    func setUserProperties(_ properties: [AnalyticsUserProperty]) {
        properties.forEach { setUserProperty($0) }
    }

    // MARK: - User Identification

    /// Set the user ID (call after authentication)
    /// - Parameter userId: The user's unique identifier
    func setUserId(_ userId: String) {
        Analytics.setUserID(userId)

        #if DEBUG
        print("[Analytics] User ID set: \(userId)")
        #endif
    }

    /// Clear user identification (call on logout)
    func clearUserId() {
        Analytics.setUserID(nil)

        #if DEBUG
        print("[Analytics] User ID cleared")
        #endif
    }

    // MARK: - Ecommerce Events

    /// Log a view item event (meditation or content preview)
    /// - Parameters:
    ///   - itemId: Unique item identifier
    ///   - itemName: Human-readable item name
    ///   - itemCategory: Category (e.g., "Sleep", "Focus", "Stress Relief")
    ///   - value: Monetary value (optional)
    ///   - currency: Currency code (optional)
    func logViewItem(
        itemId: String,
        itemName: String,
        itemCategory: String,
        value: Double? = nil,
        currency: String? = nil
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterItemID: itemId,
            AnalyticsParameterItemName: itemName,
            AnalyticsParameterItemCategory: itemCategory
        ]

        if let value = value {
            parameters[AnalyticsParameterValue] = value
        }

        if let currency = currency {
            parameters[AnalyticsParameterCurrency] = currency
        }

        addContextParameters(&parameters)

        #if DEBUG
        print("[Analytics] View Item: \(itemName) (\(itemId))")
        #endif

        Analytics.logEvent(AnalyticsEventViewItem, parameters: parameters)
    }

    /// Log add to cart/wishlist event
    /// - Parameters:
    ///   - itemId: Meditation or content ID
    ///   - itemName: Content name
    ///   - value: Price (optional)
    ///   - currency: Currency code (optional)
    func logAddToCart(
        itemId: String,
        itemName: String,
        value: Double? = nil,
        currency: String? = nil
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterItemID: itemId,
            AnalyticsParameterItemName: itemName
        ]

        if let value = value {
            parameters[AnalyticsParameterValue] = value
        }

        if let currency = currency {
            parameters[AnalyticsParameterCurrency] = currency
        }

        addContextParameters(&parameters)
        Analytics.logEvent(AnalyticsEventAddToCart, parameters: parameters)
    }

    /// Log begin checkout event
    /// - Parameters:
    ///   - value: Total value of checkout
    ///   - currency: Currency code
    ///   - itemCount: Number of items
    func logBeginCheckout(
        value: Double,
        currency: String,
        itemCount: Int? = nil
    ) {
        var parameters: [String: Any] = [
            AnalyticsParameterValue: value,
            AnalyticsParameterCurrency: currency
        ]

        if let itemCount = itemCount {
            parameters[AnalyticsParameterItems] = itemCount
        }

        addContextParameters(&parameters)
        Analytics.logEvent(AnalyticsEventBeginCheckout, parameters: parameters)
    }

    // MARK: - Funnel Tracking Helpers

    /// Log funnel step completion
    /// - Parameters:
    ///   - funnelName: Name of the funnel (e.g., "onboarding", "subscription_conversion")
    ///   - stepNumber: Step number in the funnel
    ///   - stepName: Name of the step
    ///   - additionalParams: Extra parameters for this step
    func logFunnelStep(
        funnelName: String,
        stepNumber: Int,
        stepName: String,
        additionalParams: [String: Any]? = nil
    ) {
        var parameters: [String: Any] = [
            "funnel_name": funnelName,
            "step_number": stepNumber,
            "step_name": stepName
        ]

        if let additional = additionalParams {
            parameters.merge(additional) { _, new in new }
        }

        addContextParameters(&parameters)

        #if DEBUG
        print("[Analytics] Funnel: \(funnelName) - Step \(stepNumber): \(stepName)")
        #endif

        Analytics.logEvent("funnel_step_completed", parameters: parameters)
    }

    /// Log funnel dropout
    /// - Parameters:
    ///   - funnelName: Name of the funnel
    ///   - stepNumber: Step where user dropped off
    ///   - reason: Reason for dropout (optional)
    func logFunnelDropout(
        funnelName: String,
        stepNumber: Int,
        reason: String? = nil
    ) {
        var parameters: [String: Any] = [
            "funnel_name": funnelName,
            "dropout_step": stepNumber
        ]

        if let reason = reason {
            parameters["dropout_reason"] = reason
        }

        addContextParameters(&parameters)

        #if DEBUG
        print("[Analytics] Funnel Dropout: \(funnelName) - Step \(stepNumber)")
        #endif

        Analytics.logEvent("funnel_dropout", parameters: parameters)
    }

    // MARK: - Context Parameters

    /// Add context parameters that should be included with every event
    private func addContextParameters(_ parameters: inout [String: Any]) {
        // Add app version
        if let version = Bundle.main.appVersion {
            parameters["app_version"] = version
        }

        // Add timestamp
        parameters["timestamp"] = Int(Date().timeIntervalSince1970)

        // Add locale
        parameters["locale"] = Locale.current.identifier
    }
}

// MARK: - SwiftUI View Extension for Screen Tracking
import SwiftUI

extension View {
    /// Track when this view appears
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Class name (optional, defaults to view type)
    func trackScreen(_ screenName: String, screenClass: String? = nil) -> some View {
        self.onAppear {
            AnalyticsManager.shared.logScreenView(screenName, screenClass: screenClass)
        }
    }
}

// MARK: - Bundle Extension for Version
extension Bundle {
    var appVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}

// MARK: - Analytics Helper Functions (for common patterns)

/// Helper to log meditation completion with time tracking
/// - Parameters:
///   - type: Type of meditation
///   - scheduledDuration: Originally scheduled duration in seconds
///   - actualDuration: How long user actually meditated in seconds
func logMeditationCompletion(
    type: String,
    scheduledDuration: Int,
    actualDuration: Int
) {
    AnalyticsManager.shared.logEvent(
        .meditationCompleted(
            meditationType: type,
            actualDuration: actualDuration,
            scheduled: scheduledDuration
        )
    )
}

/// Helper to log subscription conversion
/// - Parameters:
///   - productId: In-app purchase product ID
///   - price: Price in local currency
///   - currency: ISO 4217 currency code (e.g., "BRL", "USD")
func logSubscriptionPurchase(
    productId: String,
    price: Double,
    currency: String
) {
    AnalyticsManager.shared.logEvent(
        .subscriptionStarted(
            productId: productId,
            price: price,
            currency: currency
        )
    )

    // Also set user property
    AnalyticsManager.shared.setUserProperty(
        .subscriptionStatus("paid")
    )
}

/// Helper to track onboarding progress
/// - Parameters:
///   - currentStep: Current step number (1-based)
///   - stepName: Name of the current step
///   - totalSteps: Total number of steps in onboarding
func logOnboardingStep(
    currentStep: Int,
    stepName: String,
    totalSteps: Int
) {
    AnalyticsManager.shared.logEvent(
        .onboardingStepCompleted(
            step: currentStep,
            stepName: stepName
        )
    )

    // Log progress percentage
    let progress = Double(currentStep) / Double(totalSteps) * 100
    AnalyticsManager.shared.logFunnelStep(
        funnelName: "onboarding",
        stepNumber: currentStep,
        stepName: stepName,
        additionalParams: ["progress_percent": progress]
    )
}
