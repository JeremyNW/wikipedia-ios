@objc public final class RemoteNotificationsController: NSObject {
    private let operationsController: RemoteNotificationsOperationsController
    
    var viewContext: NSManagedObjectContext? {
        return operationsController.viewContext
    }
    
    @objc public required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        operationsController = RemoteNotificationsOperationsController(session: session, configuration: configuration, preferredLanguageCodesProvider: preferredLanguageCodesProvider)
        super.init()
    }
}

extension RemoteNotificationsController: PeriodicWorker {
    public func doPeriodicWork(_ completion: @escaping () -> Void) {
        //TODO: Disable polling for now, remove later
        //operationsController.doPeriodicWork(completion)
    }
}

extension RemoteNotificationsController: BackgroundFetcher {
    public func performBackgroundFetch(_ completion: @escaping (UIBackgroundFetchResult) -> Void) {
        //TODO: Disable polling for now, remove later
        //operationsController.performBackgroundFetch(completion)
    }
}
