import CocoaLumberjackSwift

@objc public final class RemoteNotificationsController: NSObject {
    private let operationsController: RemoteNotificationsOperationsController
    private var alreadyImportedThisSession = false
    
    public var viewContext: NSManagedObjectContext? {
        return operationsController.viewContext
    }
    
    @objc public required init(session: Session, configuration: Configuration, preferredLanguageCodesProvider: WMFPreferredLanguageInfoProvider) {
        operationsController = RemoteNotificationsOperationsController(session: session, configuration: configuration, preferredLanguageCodesProvider: preferredLanguageCodesProvider)
        super.init()
    }
    
    @objc func deleteLegacyDatabaseFiles() {
        do {
            try operationsController.deleteLegacyDatabaseFiles()
        } catch (let error) {
            DDLogError("Failure deleting legacy RemoteNotifications database files: \(error)")
        }
    }
    
    public func importNotificationsIfNeeded(_ completion: @escaping () -> Void) {
        guard !alreadyImportedThisSession else {
            completion()
            return
        }
        
        operationsController.importNotificationsIfNeeded(completion)
        alreadyImportedThisSession = true
    }
    
    //todo: input param of filter enums/option sets
    public func fetchedResultsController(fetchLimit: Int = 10, fetchOffset: Int = 0) -> NSFetchedResultsController<RemoteNotification>? {
        
        guard let viewContext = self.viewContext else {
            return nil
        }
        
        let fetchRequest: NSFetchRequest<RemoteNotification> = RemoteNotification.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        fetchRequest.fetchLimit = fetchLimit
        fetchRequest.fetchOffset = fetchOffset

        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: viewContext, sectionNameKeyPath: nil, cacheName: nil)

        return fetchedResultsController
    }
}
