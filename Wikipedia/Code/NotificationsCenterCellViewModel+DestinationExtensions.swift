
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
             .editMilestone,
             .successfulMention:
            calculatedURL = fullTitleURL(for: configuration)
        case .mentionInEditSummary,
             .editReverted,
             .thanks:
            calculatedURL = fullTitleDiffURL(for: configuration)
        case .userRightsChange:
            calculatedURL = userGroupRightsURL
        case .connectionWithWikidata:
            calculatedURL = connectionWithWikidataItemURL
        case .emailFromOtherUser:
            calculatedURL = customPrefixAgentNameURL(for: configuration, pageNamespace: .user)
        case .welcome:
            calculatedURL = gettingStartedURL(for: configuration)
        case .translationMilestone:
            
            //purposefully not allowing default to primaryURL from server below
            //business requirements are that there are no destination links for translations notification.
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
        case .failedMention,
             .successfulMention,
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
            swipeActions.append(contentsOf: successfulMentionActions(for: configuration))
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
        let primaryLinkFragment = notification.primaryLinkFragment
        
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
    
    var connectionWithWikidataItemURL: URL? {
        
        //Note: Sample notification json indicates that the wikidata item link is the second secondary link.
        //Return this link if we're fairly certain it's what we think it is
        
        guard let secondaryLinks = notification.messageLinks?.secondary,
              secondaryLinks.count > 1,
              let wikidataItemURL = secondaryLinks[1].url else {
            return nil
        }
        
        //Confirm host is a Wikidata environment.
        guard let host = wikidataItemURL.host,
              host.contains("wikidata") else {
            return nil
        }
        
        //see if any part of path contains a Q identifier
        let path = wikidataItemURL.path
        let range = NSRange(location: 0, length: path.count)
        
        guard let regex = try? NSRegularExpression(pattern: "Q[1-9]\\d*") else {
            return nil
        }
        
        guard regex.firstMatch(in: path, options: [], range: range) != nil else {
            return nil
        }
        
        return wikidataItemURL
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
    
    var primaryLinkMinusQueryItemsURL: URL? {
        guard let primaryLink = notification.messageLinks?.primary,
              let url = primaryLink.url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.queryItems?.removeAll()
        return components.url
    }
    
    //For a page link notification type (FROM page > TO page), this is the url of the TO page
    var pageLinkToURL: URL? {
        //Note: Sample notification json indicates that the url we want is listed as the primary URL
        //Ex. https://en.wikipedia.org/wiki/Cat?markasread=nnnnnnnn&markasreadwiki=enwiki
        return primaryLinkMinusQueryItemsURL
    }
    
    //https://www.mediawiki.org/wiki/Special:UserGroupRights
    var userGroupRightsURL: URL? {
        //Note: Sample notification json indicates that translated user group link we want is listed as the primary URL
        //Ex. https://en.wikipedia.org/wiki/Special:ListGroupRights?markasread=nnnnnnnn&markasreadwiki=enwiki#confirmed
        
        guard let url = primaryLinkMinusQueryItemsURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        
        components.fragment = nil
        return components.url
    }
    
    var specificUserGroupRightsURL: URL? {
        //Note: Sample notification json indicates that specific user group link we want is listed as the primary URL + fragment
        //Ex. https://en.wikipedia.org/wiki/Special:ListGroupRights?markasread=nnnnnnnn&markasreadwiki=enwiki#confirmed
        return primaryLinkMinusQueryItemsURL
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
    
    func successfulMentionActions(for configuration: Configuration) -> [SwipeAction] {
        var swipeActions: [SwipeAction] = []
        
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

        if let specificUserGroupRightsAction = specificUserGroupRightsSwipeAction {
            swipeActions.append(specificUserGroupRightsAction)
        }
        
        if let agentUserPageAction = agentUserPageSwipeAction(for: configuration) {
            swipeActions.append(agentUserPageAction)
        }
        
        if let userGroupRightsAction = userGroupRightsSwipeAction(for: configuration) {
            swipeActions.append(userGroupRightsAction)
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
        
        //Article you edited
        if let titleAction = titleSwipeAction(for: configuration) {
            swipeActions.append(titleAction)
        }
        
        //Article where link was made
        if let pageLinkToAction = pageLinkToAction {
            swipeActions.append(pageLinkToAction)
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
        
        if let wikidataItemAction = wikidataItemAction {
            swipeActions.append(wikidataItemAction)
        }
        
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
    
    //Go to [Article where link was made]
    var pageLinkToAction: SwipeAction? {
        guard let url = pageLinkToURL,
              let title = url.wmf_title else {
            return nil
        }
        
        let text = String.localizedStringWithFormat(CommonStrings.notificationsCenterGoToTitleFormat, title)
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to Wikidata item
    var wikidataItemAction: SwipeAction? {
        guard let url = connectionWithWikidataItemURL else {
            return nil
        }
        
        let text = WMFLocalizedString("notifications-center-go-to-wikidata-item", value: "Go to Wikidata item", comment: "Button text in Notifications Center that routes to a Wikidata item page.")
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to specific Special:UserGroupRights#{Type} page
    var specificUserGroupRightsSwipeAction: SwipeAction? {
        guard let url = specificUserGroupRightsURL,
              let type = url.fragment,
              let title = url.wmf_title else {
            return nil
        }
        
        let text = String.localizedStringWithFormat(CommonStrings.notificationsCenterGoToTitleFormat, "\(title)#\(type)")
        let data = SwipeActionData(text: text, destinationURL: url)
        return SwipeAction.custom(data)
    }
    
    //Go to Special:UserGroupRights
    func userGroupRightsSwipeAction(for configuration: Configuration) -> SwipeAction? {
        guard let url = userGroupRightsURL,
              let title = url.wmf_title else {
            return nil
        }
        
        let text = String.localizedStringWithFormat(CommonStrings.notificationsCenterGoToTitleFormat, title)
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
