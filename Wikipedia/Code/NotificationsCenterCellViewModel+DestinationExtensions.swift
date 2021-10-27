
import Foundation

extension NotificationsCenterCellViewModel {
    
    enum SwipeAction {
        case markAsRead(SwipeActionData)
        case custom(SwipeActionData)
        case notificationSubscriptionSettings(SwipeActionData)
    }
    
    struct SwipeActionData {
        let text: String
        let destinationURL: URL?
    }
    
    //MARK: Public
    
    func primaryDestinationURL(for configuration: Configuration) -> URL? {

        //First try to explicitly generate urls based on notification type to limit url side effects
        var calculatedURL: URL? = nil
        
        switch notification.type {
        case .userTalkPageMessage,
             .mentionInTalkPage,
             .failedMention,
             .pageReviewed,
             .pageLinked,
             .editMilestone:
            calculatedURL = fullTitleURL(for: configuration)
        case .mentionInEditSummary,
             .editReverted,
             .thanks:
            calculatedURL = fullTitleDiffURL(for: configuration)
        case .userRightsChange:
            calculatedURL = userGroupRightsURL
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
        
            //TODO: AgentName of a successful mention seems to be yourself, not the person you mentioned (no clean way to pull the person you mentioned). Returning nil for now.
            //calculatedURL = customPrefixAgentNameURL(for: configuration, pageNamespace: .user)
            return nil
        
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
        return (calculatedURL ?? notification.messageLinks?.primaryURL)
    }
    
    func secondaryDestinationURL(for configuration: Configuration) -> URL? {
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
        
        return calculatedURL
    }
    
    func swipeActions(for configuration: Configuration) -> [SwipeAction] {
        
        var swipeActions: [SwipeAction] = []
        let markAsReadText = WMFLocalizedString("notifications-center-mark-as-read", value: "Mark as Read", comment: "Button text in Notifications Center to mark a notification as read.")
        let markAsReadActionData = SwipeActionData(text: markAsReadText, destinationURL: nil)
        swipeActions.append(.markAsRead(markAsReadActionData))
        
        switch notification.type {
        case .userTalkPageMessage:
            swipeActions.append(contentsOf: userTalkPageActions(for: configuration))
        case .mentionInTalkPage,
             .editReverted:
            swipeActions.append(contentsOf: mentionInTalkAndEditRevertedPageActions(for: configuration))
        case .mentionInEditSummary:
            swipeActions.append(contentsOf: mentionInEditSummaryActions(for: configuration))
        case .successfulMention:
            swipeActions.append(contentsOf: sucessfulMentionActions(for: configuration))
        case .failedMention:
            swipeActions.append(contentsOf: failedMentionActions(for: configuration))
        case .userRightsChange:
            swipeActions.append(contentsOf: userGroupRightsActions(for: configuration))
        case .pageReviewed:
            swipeActions.append(contentsOf: pageReviewedActions(for: configuration))
        case .pageLinked:
            swipeActions.append(contentsOf: pageLinkActions(for: configuration))
        case .connectionWithWikidata:
            swipeActions.append(contentsOf: connectionWithWikidataActions(for: configuration))
        case .emailFromOtherUser:
            swipeActions.append(contentsOf: emailFromOtherUserActions(for: configuration))
        case .thanks:
            swipeActions.append(contentsOf: thanksActions(for: configuration))
        case .translationMilestone,
             .editMilestone,
             .welcome:
            break
        case .loginFailKnownDevice,
             .loginFailUnknownDevice,
             .loginSuccessUnknownDevice:
            swipeActions.append(contentsOf: loginActions(for: configuration))

        case .unknownAlert,
             .unknownSystemAlert:
            swipeActions.append(contentsOf: genericAlertActions(for: configuration))
        
        case .unknownSystemNotice,
             .unknownNotice,
             .unknown:
            swipeActions.append(contentsOf: genericActions(for: configuration))

        }
        
        //TODO: add notification settings destination
        let notificationSubscriptionSettingsText = WMFLocalizedString("notifications-center-notifications-settings", value: "Notification settings", comment: "Button text in Notifications Center that automatically routes to the notifications settings screen.")
        let notificationSettingsActionData = SwipeActionData(text: notificationSubscriptionSettingsText, destinationURL: nil)
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
        let primaryLinkFragment: String?
        let agentName: String?
        let revisionID: String?
        let titleNamespace: PageNamespace?
        let languageVariantCode: String?
    }
    
    func destinationData(for configuration: Configuration) -> DestinationData? {
        
        guard let host = notification.primaryLinkHost ?? configuration.defaultSiteURL.host,
              let wiki = notification.wiki else {
            return nil
        }
        
        let title = notification.titleText?.denormalizedPageTitle?.percentEncodedPageTitleForPathComponents
        let fullTitle = notification.titleFull?.denormalizedPageTitle?.percentEncodedPageTitleForPathComponents
        let agentName = notification.agentName?.denormalizedPageTitle?.percentEncodedPageTitleForPathComponents
        let titleNamespace = PageNamespace(namespaceValue: Int(notification.titleNamespaceKey))
        let revisionID = notification.revisionID
        
        let primaryLinkFragment = notification.messageLinks?.primaryURL?.fragment
        
        return DestinationData(host: host, wiki: wiki, title: title, fullTitle: fullTitle, primaryLinkFragment: primaryLinkFragment, agentName: agentName, revisionID: revisionID, titleNamespace: titleNamespace, languageVariantCode: project.languageVariantCode)
        
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
        
        guard let namespace = data.titleNamespace,
              namespace == .userTalk,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.fragment = data.primaryLinkFragment
        return components.url
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
    
    //https://en.wikipedia.org/wiki/Special:ChangeCredentials
    func changePasswordURL(for configuration: Configuration) -> URL? {
        guard let data = destinationData(for: configuration) else {
            return nil
        }
        
        var components = URLComponents()
        components.host = data.host
        components.scheme = "https"
        components.path = "/wiki/Special:ChangeCredentials"
        return components.url
    }
    
    //https://www.mediawiki.org/wiki/Special:UserGroupRights
    var userGroupRightsURL: URL? {
        var components = URLComponents()
        components.host = Configuration.Domain.mediaWiki
        components.scheme = "https"
        components.path = "/wiki/Special:UserGroupRights"
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
        
        if let talkPageAction = titleTalkPageSwipeAction(for: configuration, yourPhrasing: true) {
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
        
        if let titleTalkPageAction = titleTalkPageSwipeAction(for: configuration, yourPhrasing: false) {
            swipeActions.append(titleTalkPageAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func mentionInEditSummaryActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func sucessfulMentionActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func failedMentionActions(for configuration: Configuration) -> [SwipeAction] {
        if let titleAction = titleSwipeAction(for: configuration) {
            return [titleAction]
        }
        
        return []
    }
    
    func userGroupRightsActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []

        //TODO: Go to [Associated User Group's Rights Page]
        //Not sure how to figure this out, need to see an example notifications response.
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let goToSpecialUserGroupRightsAction = userGroupRightsSwipeAction(for: configuration) {
            swipeActions.append(goToSpecialUserGroupRightsAction)
        }
        
        return swipeActions
    }
    
    func pageReviewedActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        return swipeActions
    }
    
    func pageLinkActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        //TODO: Go to [Article you edited] or [Article where link was made]
        //Not sure how to figure this out, need to see an example notifications response.
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        return swipeActions
    }
    
    func connectionWithWikidataActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        //TODO: Go to Wikidata item
        //Not sure how to figure wikidata item link, need to see an example notifications response.
        
        return swipeActions
    }
    
    func emailFromOtherUserActions(for configuration: Configuration) -> [SwipeAction] {
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            return [agentUserPageAction]
        }
        
        return []
    }
    
    func thanksActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        return swipeActions
    }
    
    func loginActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let loginHelpAction = loginNotificationsSwipeAction(for: configuration) {
            swipeActions.append(loginHelpAction)
        }
        
        if let changePasswordSwipeAction = changePasswordSwipeAction(for: configuration) {
            swipeActions.append(changePasswordSwipeAction)
        }
        
        return swipeActions
    }
    
    func genericAlertActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let secondaryLinks = notification.messageLinks?.secondary {
            let secondarySwipeActions = secondaryLinks.compactMap { swipeActionForGenericLink(link:$0, configuration:configuration) }
            swipeActions.append(contentsOf: secondarySwipeActions)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        if let primaryLink = notification.messageLinks?.primary,
           let primarySwipeAction = swipeActionForGenericLink(link: primaryLink, configuration: configuration) {
            swipeActions.append(primarySwipeAction)
        }
        
        return swipeActions
    }
    
    func genericActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let diffAction = diffSwipeAction(for: configuration) {
            swipeActions.append(diffAction)
        }
        
        if let primaryLink = notification.messageLinks?.primary,
           let primarySwipeAction = swipeActionForGenericLink(link: primaryLink, configuration: configuration) {
            swipeActions.append(primarySwipeAction)
        }
        
        return swipeActions
    }
    
    //Go to [Username]'s user page
    func agentUserPageSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let agentName = notification.agentName,
              let url = customPrefixAgentNameURL(for: configuration, pageNamespace: .user) else {
            return nil
        }
        
        let format = WMFLocalizedString("notifications-center-go-to-user-page", value: "Go to %1$@'s user page", comment: "Button text in Notifications Center that routes to a web view of the user page of the sender that triggered the notification. %1$@ is replaced with the sender's username.")
        let text = String.localizedStringWithFormat(format, agentName)
        
        let data = SwipeActionData(text: text, destinationURL: url)
        
        return SwipeAction.custom(data)
    }
    
    //Go to diff
    func diffSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = fullTitleDiffURL(for: configuration) else {
            return nil
        }
        
        let text = WMFLocalizedString("notifications-center-go-to-diff", value: "Go to diff", comment: "Button text in Notifications Center that routes to a diff screen of the revision that triggered the notification.")
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to [your?] talk page
    func titleTalkPageSwipeAction(for configuration: Configuration, yourPhrasing: Bool = false) -> SwipeAction? {
        guard let url = fullTitleURL(for: configuration) else {
            return nil
        }
        
        
        let text = yourPhrasing ? WMFLocalizedString("notifications-center-go-to-your-talk-page", value: "Go to your talk page", comment: "Button text in Notifications Center that routes to user's talk page.") : WMFLocalizedString("notifications-center-go-to-talk-page", value: "Go to talk page", comment: "Button text in Notifications Center that routes to a talk page.")
        
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to [Name of article]
    func titleSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = fullTitleURL(for: configuration),
              let title = notification.titleText else {
            return nil
        }

        let text = String.localizedStringWithFormat(CommonStrings.notificationsCenterGoToTitleFormat, title)
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to Special:UserGroupRights
    func userGroupRightsSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = userGroupRightsURL else {
            return nil
        }
        
        //TODO: We should translate "Special:UserGroupRights" according to wiki.
        //Option 1: See if we can extract it from notification's urls.
        //Option 2: Look up Special namespace translation and UserGroupRights translation via https://es.wikipedia.org/w/api.php?action=query&format=json&meta=siteinfo&siprop=namespaces|specialpagealiases. We should update WikipediaLanguageCommandLineUtility.swift and regenerate files with this information.
        let text = String.localizedStringWithFormat(CommonStrings.notificationsCenterGoToTitleFormat, "Special:UserGroupRights")
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Login Notifications
    func loginNotificationsSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = loginNotificationsHelpURL else {
            return nil
        }
        
        let text = WMFLocalizedString("notifications-center-login-notifications", value: "Login Notifications", comment: "Button text in Notifications Center that routes user to login notifications help page in web view.")
        
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Change password
    func changePasswordSwipeAction(for configuration: Configuration) -> SwipeAction? {
        
        guard let url = changePasswordURL(for: configuration) else {
            return nil
        }
        
        let text = WMFLocalizedString("notifications-center-change-password", value: "Change Password", comment: "Button text in Notifications Center that routes user to change password screen.")
        
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    func swipeActionForGenericLink(link: RemoteNotificationLink, configuration: Configuration) -> SwipeAction? {
        guard let url = link.url,
              let text = link.label else {
            return nil
        }
        
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
}
