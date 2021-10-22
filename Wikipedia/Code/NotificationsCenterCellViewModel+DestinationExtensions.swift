
import Foundation

extension NotificationsCenterCellViewModel {
    
    enum SwipeAction {
        case markAsRead(SwipeActionData)
        case custom(SwipeActionData)
        case notificationSubscriptionSettings(SwipeActionData)
    }
    
    struct SwipeActionData {
        let text: String
        let destination: Router.Destination?
    }
    
    func primaryDestination(for configuration: Configuration) -> Router.Destination? {

        //First try to explicitly generate urls based on notification type to limit url side effects
        var calculatedURL: URL? = nil
        
        switch notification.type {
        case .userTalkPageMessage,
             .mentionInTalkPage,
             .pageReviewed,
             .pageLinked,
             .editMilestone,
             .failedMention:
            calculatedURL = fullTitleURL(for: configuration)
        case .mentionInEditSummary,
             .editReverted,
             .thanks:
            calculatedURL = fullTitleDiffURL(for: configuration)
        case .userRightsChange:
            calculatedURL = listGroupRightsURL
        case .connectionWithWikidata:
            //TODO: Doubtful that this is right, but not sure if Q identifer comes through this notification type or not.
            //If it does, use it and configuration object to build wikidata url
            //If it doesn't, might need to use the article page link to fetch the wikidata Q identifier, then build the wikidata url.
            calculatedURL = fullTitleURL(for: configuration)
        case .emailFromOtherUser:
            calculatedURL = customPrefixAgentNameURL(for: configuration, pageNamespace: .user)
        case .welcome:
            calculatedURL = gettingStartedURL(for: configuration)
        case .translationMilestone:
            
            //purposefully not allowing default to primaryURL from server below
            //business requirements are that there are no destination links for translations notification.
            return nil
        case .successfulMention:
        
            //TODO: This may be wrong. AgentName of a successful mention seems to be yourself, not the person you mentioned (no clean way to pull the person you mentioned).
            calculatedURL = customPrefixAgentNameURL(for: configuration, pageNamespace: .user)
        
        case .loginFailUnknownDevice,
             .loginFailKnownDevice,
             .loginSuccessUnknownDevice:
            calculatedURL = loginNotificationsHelpURL
            
        case .unknownSystemAlert,
             .unknownSystemNotice,
             .unknownAlert,
             .unknownNotice,
             .unknown:
            break
        }

        //If unable to calculate url, default to primary url returned from server
        if let finalPrimaryURL = (calculatedURL ?? notification.messageLinks?.primaryURL) {
            return configuration.router.destination(for: finalPrimaryURL)
        }
        
        return nil
    }
    
    func secondaryDestination(for configuration: Configuration) -> Router.Destination? {
        var calculatedURL: URL? = nil
        
        switch notification.type {
        case .userTalkPageMessage,
             .mentionInTalkPage,
             .mentionInEditSummary,
             .editReverted,
             .userRightsChange,
             .pageReviewed,
             .pageLinked,
             .connectionWithWikidata,
             .thanks,
             .unknownAlert,
             .unknownNotice:
            calculatedURL = customPrefixAgentNameURL(for: configuration, pageNamespace: .user)
        case .successfulMention:
            calculatedURL = fullTitleURL(for: configuration)
        case .failedMention,
             .emailFromOtherUser,
             .translationMilestone,
             .editMilestone,
             .welcome,
             .loginFailUnknownDevice,
             .loginFailKnownDevice,
             .loginSuccessUnknownDevice,
             .unknownSystemAlert,
             .unknownSystemNotice,
             .unknown:
            break
        }
        
        if let calculatedURL = calculatedURL {
            return configuration.router.destination(for: calculatedURL)
        }
        
        return nil
    }
    
    func swipeActions(for configuration: Configuration) -> [SwipeAction] {
        
        var swipeActions: [SwipeAction] = []
        let markAsReadActionData = SwipeActionData(text: CommonStrings.notificationsCenterMarkAsRead, destination: nil)
        swipeActions.append(.markAsRead(markAsReadActionData))
        
        switch notification.type {
        case .userTalkPageMessage:
            swipeActions.append(contentsOf: userTalkPageActions(for: configuration))
        case .mentionInTalkPage,
             .editReverted:
            swipeActions.append(contentsOf: mentionInTalkAndEditRevertedPageActions(for: configuration))
        case .successfulMention:
            swipeActions.append(contentsOf: sucessfulMentionActions(for: configuration))
        case .failedMention:
            swipeActions.append(contentsOf: failedMentionActions(for: configuration))

        default:
            //TODO: FINISH SWIPE ACTIONS
            break
        }
        
        //TODO: add notification settings destination
        let notificationSettingsActionData = SwipeActionData(text: CommonStrings.notificationsCenterNotificationsSettings, destination: nil)
        swipeActions.append(.notificationSubscriptionSettings(notificationSettingsActionData))
        
        return swipeActions
    }
    
    
}

//MARK: Private Helpers - DestinationData

private extension NotificationsCenterCellViewModel {
    
    //common data used throughout url generation helpers
    struct DestinationData {
        let host: String
        let wiki: String
        let title: String? //ex: Cat
        let fullTitle: String? //ex: Talk:Cat
        let agentName: String?
        let revisionID: Int?
        let titleNamespace: PageNamespace?
        let languageVariantCode: String?
    }
    
    func destinationData(for configuration: Configuration) -> DestinationData? {
        
        guard let host = notification.destinationLinkHost ?? configuration.defaultSiteURL.host,
              let wiki = notification.wiki else {
            return nil
        }
        
        let title = notification.titleText?.denormalizedPageTitle
        let fullTitle = notification.titleFull?.denormalizedPageTitle
        let agentName = notification.agentName?.denormalizedPageTitle
        let titleNamespace = PageNamespace(namespaceValue: Int(notification.titleNamespace ?? ""))
        
        //TODO: add revision ID to managed object.
        let revisionID = 1
        
        return DestinationData(host: host, wiki: wiki, title: title, fullTitle: fullTitle, agentName: agentName, revisionID: revisionID, titleNamespace: titleNamespace, languageVariantCode: project.languageVariantCode)
        
    }
}

//MARK: Private Helpers - URL Generation Methods

private extension NotificationsCenterCellViewModel {
    
    /// Generates a wiki url with the title from the notification
        /// Prefixes title text with PageNamespace parameter
    func customPrefixTitleURL(for configuration: Configuration, pageNamespace: PageNamespace) -> URL? {
        guard let data = destinationData(for: configuration),
              let title = data.title else {
            return nil
        }

        let prefix = pageNamespace.canonicalName

        guard let url = configuration.articleURLForHost(data.host, languageVariantCode: data.languageVariantCode, appending: ["\(prefix):\(title)"]) else {
            return nil
        }

        return url
    }
    
    /// Generates a wiki url with the agentName from the notification
        /// Prefixes agentName text with PageNamespace parameter
    func customPrefixAgentNameURL(for configuration: Configuration, pageNamespace: PageNamespace) -> URL? {
        guard let data = destinationData(for: configuration),
              let agentName = data.agentName else {
            return nil
        }

        let prefix = pageNamespace.canonicalName

        guard let url = configuration.articleURLForHost(data.host, languageVariantCode: data.languageVariantCode, appending: ["\(prefix):\(agentName)"]) else {
            return nil
        }

        return url
    }
    
    /// Generates a wiki url with the full (i.e. already prefixed) title from the notification
    func fullTitleURL(for configuration: Configuration) -> URL? {
        guard let data = destinationData(for: configuration),
              let fullTitle = data.fullTitle else {
            return nil
        }
        
        guard let url = configuration.articleURLForHost(data.host, languageVariantCode: data.languageVariantCode, appending: [fullTitle]) else {
            return nil
        }
        
        return url
    }
    
    /// Generates a wiki diff url with the full (i.e. already prefixed) title from the notification
    func fullTitleDiffURL(for configuration: Configuration) -> URL? {
        guard let data = destinationData(for: configuration),
              let fullTitle = data.fullTitle,
              let revisionID = data.revisionID else {
            return nil
        }
        
        guard let url = configuration.expandedArticleURLForHost(data.host, languageVariantCode: data.languageVariantCode, queryParameters: ["title": fullTitle, "oldid": revisionID]) else {
            return nil
        }
        
        return url
    }
    
    //https://www.mediawiki.org/wiki/Special:ListGroupRights
    var listGroupRightsURL: URL? {
        var components = URLComponents()
        components.host = Configuration.Domain.mediaWiki
        components.scheme = "https"
        components.path = "/wiki/Special:ListGroupRights"
        return components.url
    }
    
    //https://www.mediawiki.org/wiki/Help:Login_notifications
    var loginNotificationsHelpURL: URL? {
        var components = URLComponents()
        components.host = Configuration.Domain.mediaWiki
        components.scheme = "https"
        components.path = "/wiki/Help:Login_notifications"
        return components.url
    }
    
    //https://en.wikipedia.org/wiki/Help:Getting_started
    func gettingStartedURL(for configuration: Configuration) -> URL? {
        
        guard let data = destinationData(for: configuration) else {
            return nil
        }
        
        var components = URLComponents()
        components.host = data.host
        components.scheme = "https"
        components.path = "/wiki/Help:Getting_started"
        return components.url
    }
}

//MARK: Private Helpers - Swipe Actions

private extension NotificationsCenterCellViewModel {
    func userTalkPageActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        if let talkPageAction = titleTalkPageAction(for: configuration, yourPhrasing: true) {
            swipeActions.append(talkPageAction)
        }
        
        return swipeActions
    }
    
    func mentionInTalkAndEditRevertedPageActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        if let titleTalkPageAction = titleTalkPageAction(for: configuration, yourPhrasing: false) {
            swipeActions.append(titleTalkPageAction)
        }
        
        if let titleAction = titleAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func sucessfulMentionActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let titleAction = titleAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func failedMentionActions(for configuration: Configuration) -> [SwipeAction] {
        if let titleAction = titleAction(for: configuration) {
            return [titleAction]
        }
        
        return []
    }
    
    //Go to [Username]'s user page
    func agentUserPageSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let agentName = notification.agentName,
              let url = customPrefixAgentNameURL(for: configuration, pageNamespace: .user) else {
            return nil
        }
        
        let format = WMFLocalizedString("notifications-center-go-to-user-page", value: "Go to %1$@'s user page", comment: "Button text in Notifications Center that routes to a web view of the user page of the sender that triggered the notification. %1$@ is replaced with the sender's username.")
        let text = String.localizedStringWithFormat(format, agentName)
        let destination = configuration.router.destination(for: url)
        
        let data = SwipeActionData(text: text, destination: destination)
        
        return SwipeAction.custom(data)
    }
    
    //Go to diff
    func diffSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = fullTitleDiffURL(for: configuration) else {
            return nil
        }
        
        let text = WMFLocalizedString("notifications-center-go-to-diff", value: "Go to diff", comment: "Button text in Notifications Center that routes to a diff screen of the revision that triggered the notification.")
        let destination = configuration.router.destination(for: url)
        
        let data = SwipeActionData(text: text, destination: destination)
        return SwipeAction.custom(data)
    }
    
    //Go to [your?] talk page
    func titleTalkPageAction(for configuration: Configuration, yourPhrasing: Bool = false) -> SwipeAction? {
        guard let url = fullTitleDiffURL(for: configuration) else {
            return nil
        }
        
        
        let text = yourPhrasing ? WMFLocalizedString("notifications-center-go-to-your-talk-page", value: "Go to your talk page", comment: "Button text in Notifications Center that routes to user's talk page.") : WMFLocalizedString("notifications-center-go-to-talk-page", value: "Go to talk page", comment: "Button text in Notifications Center that routes to a talk page.")
        
        let destination = configuration.router.destination(for: url)
        
        let data = SwipeActionData(text: text, destination: destination)
        return SwipeAction.custom(data)
    }
    
    //Go to [Name of article]
    func titleAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = fullTitleURL(for: configuration),
              let title = notification.titleText else {
            return nil
        }
        
        let format = WMFLocalizedString("notifications-center-go-to-title", value: "Go to %1$@", comment: "Button text in Notifications Center that routes to the page related to the notification. %1$@ is replaced with page title.")
        let text = String.localizedStringWithFormat(format, title)
        let destination = configuration.router.destination(for: url)
        
        let data = SwipeActionData(text: text, destination: destination)
        return SwipeAction.custom(data)
    }
}
