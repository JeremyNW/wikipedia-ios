import Foundation
import CocoaLumberjackSwift

protocol NotificationCenterViewModelDelegate: AnyObject {
	func cellViewModelsDidChange()
    func reloadCellWithViewModelIfNeeded(_ viewModel: NotificationsCenterCellViewModel)
}

enum NotificationsCenterSection {
  case main
}

@objc
final class NotificationsCenterViewModel: NSObject {

    // MARK: - Properties

    let remoteNotificationsController: RemoteNotificationsController

	fileprivate var fetchedResultsControllers: [NSFetchedResultsController<RemoteNotification>] = []

    weak var delegate: NotificationCenterViewModelDelegate?
    
    private var cellViewModelsSet: Set<NotificationsCenterCellViewModel> = []
    private(set) var cellViewModels: [NotificationsCenterCellViewModel] = []
    
    private var isImporting = true
    private var isPagingEnabled = true

	// MARK: - Lifecycle

	@objc
    init(remoteNotificationsController: RemoteNotificationsController) {
		self.remoteNotificationsController = remoteNotificationsController
        super.init()
	}
    
    private func kickoffImportIfNeeded() {
        
        remoteNotificationsController.importNotificationsIfNeeded {
            DispatchQueue.main.async { [weak self] in
                self?.isImporting = false
                print("import complete")
            }
        }
    }
    
    public func fetchFirstPage() {
        
        guard let fetchedResultsController = remoteNotificationsController.fetchedResultsController() else {
            assertionFailure("Failure setting up first page fetched results controller")
            return
        }
        
        appendFetchedResultsController(fetchedResultsController: fetchedResultsController)
        fetchedResultsController.delegate = self
        
        try? fetchedResultsController.performFetch()
        syncCellViewModels()
        
        kickoffImportIfNeeded()
    }
    
    public func fetchNextPage() {
        
        guard isImporting == false else {
            DDLogDebug("Request to fetch next page while importing. Ignoring.")
            return
        }
        
        guard isPagingEnabled == true else {
            DDLogDebug("Request to fetch next page while paging is disabled. Ignoring.")
            return
        }
        
        guard let nextFetchedResultsController = remoteNotificationsController.fetchedResultsController(fetchOffset: cellViewModels.count) else {
            assertionFailure("Falure setting up next page fetched results controller")
            return
        }
        
        appendFetchedResultsController(fetchedResultsController: nextFetchedResultsController)
        nextFetchedResultsController.delegate = self
        try? nextFetchedResultsController.performFetch()
        
        guard (nextFetchedResultsController.fetchedObjects ?? []).count > 0 else {
            isPagingEnabled = false
            return
        }
        syncCellViewModels()
    }
    
    private func appendFetchedResultsController(fetchedResultsController: NSFetchedResultsController<RemoteNotification>) {
        self.fetchedResultsControllers.append(fetchedResultsController)
    }

    fileprivate func syncCellViewModels() {
    
        for fetchedResultsController in self.fetchedResultsControllers {
            
            guard let persistedNotifications = fetchedResultsController.fetchedObjects else {
                continue
            }
            
            for notification in persistedNotifications {
                let newViewModel = NotificationsCenterCellViewModel(notification: notification)
                if let currentIndex = cellViewModelsSet.firstIndex(of: newViewModel) {
                    
                    //view model already exists in data set. update existing view model with any valueable new data from the new view model (i.e., basically did the underlying core data notification change at all from the server). if it's not on screen, new data will be reflected when it scrolls on screen (this could probably be tested when we refresh. on current screen, when we refresh, if a notification comes back from the server looking different and that notification is persisted locally but not on screen yet, this section of code updates it to display the right thing when it is on screen).
                    
                    // if it IS on screen, trigger a cell reconfiguration from here.
                    
                    //this section may be overkill and/or incorrect, but for now it's needed for live reloading of
                    //notifications that have changed in core data while a view model is on screen.
                    //it seems to me a proper implementation of == in NotificationsCenterCellViewModel should automatically work
                    //but it doesn't (causes duplicate cells, etc).
                    let currentViewModel = cellViewModelsSet[currentIndex]
                    currentViewModel.copyAnyValueableNewDataFromNewViewModel(newViewModel)
                    delegate?.reloadCellWithViewModelIfNeeded(currentViewModel)
                } else {
                    cellViewModelsSet.insert(newViewModel)
                }
            }
        }
        
        self.cellViewModels = self.cellViewModelsSet.sorted { lhs, rhs in
            guard let lhsDate = lhs.notification.date,
                  let rhsDate = rhs.notification.date else {
                return false
            }
            return lhsDate > rhsDate
        }

        delegate?.cellViewModelsDidChange()
    }
}

extension NotificationsCenterViewModel: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controllerDidChangeContent")
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        print("controllerDidChangeContent")
        syncCellViewModels()
    }
}
