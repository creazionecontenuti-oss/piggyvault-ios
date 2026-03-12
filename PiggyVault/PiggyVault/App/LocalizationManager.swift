import SwiftUI
import Combine

enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case german = "de"
    case spanish = "es"
    case italian = "it"
    case french = "fr"
    case portuguese = "pt"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"
    case hindi = "hi"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .italian: return "Italiano"
        case .french: return "Français"
        case .portuguese: return "Português"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        case .hindi: return "हिन्दी"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇬🇧"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        case .italian: return "🇮🇹"
        case .french: return "🇫🇷"
        case .portuguese: return "🇵🇹"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .russian: return "🇷🇺"
        case .hindi: return "🇮🇳"
        }
    }
}

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
            Bundle.setLanguage(currentLanguage.rawValue)
            objectWillChange.send()
        }
    }
    
    private init() {
        if let stored = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let lang = SupportedLanguage(rawValue: stored) {
            self.currentLanguage = lang
        } else {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            if let lang = SupportedLanguage(rawValue: systemLang) {
                self.currentLanguage = lang
            } else {
                self.currentLanguage = .english
            }
        }
        Bundle.setLanguage(currentLanguage.rawValue)
    }
}

private var bundleKey: UInt8 = 0

final class BundleExtension: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let bundle = objc_getAssociatedObject(self, &bundleKey) as? Bundle else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    static func setLanguage(_ language: String) {
        defer { object_setClass(Bundle.main, BundleExtension.self) }
        objc_setAssociatedObject(
            Bundle.main,
            &bundleKey,
            language == "en" ? nil : Bundle(path: Bundle.main.path(forResource: language, ofType: "lproj") ?? ""),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
