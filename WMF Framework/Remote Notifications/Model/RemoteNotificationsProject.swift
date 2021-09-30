
import Foundation

public enum RemoteNotificationsProject {
    public typealias LanguageCode = String
    public typealias LocalizedLanguageName = String
    case language(LanguageCode, LocalizedLanguageName?)
    case commons
    case wikidata

    var notificationsApiWikiIdentifier: String {
        switch self {
        case .language(let languageCode, _):
            return languageCode + "wiki"
        case .commons:
            return "commonswiki"
        case .wikidata:
            return "wikidatawiki"
        }
    }
    
    public init?(apiIdentifier: String?, languageLinkController: MWKLanguageLinkController) {
        
        guard let apiIdentifier = apiIdentifier else {
            return nil
        }
        
        switch apiIdentifier {
        case "commonswiki":
            self = .commons
        case "wikidatawiki":
            self = .wikidata
        default:
            //confirm it is a recognized language
            let suffix = "wiki"
            let strippedIdentifier = apiIdentifier.hasSuffix(suffix) ? String(apiIdentifier.dropLast(suffix.count)) : apiIdentifier
            let recognizedLanguage = languageLinkController.allLanguages.first { languageLink in
                languageLink.languageCode == strippedIdentifier
            }
            
            if let recognizedLanguage = recognizedLanguage {
                self = .language(strippedIdentifier, recognizedLanguage.localizedName)
            } else {
                return nil
            }
        }
    }
}
