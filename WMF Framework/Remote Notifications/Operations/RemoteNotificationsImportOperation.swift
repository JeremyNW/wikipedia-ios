class RemoteNotificationsImportOperation: RemoteNotificationsOperation {
    let languageCode: String

    init(with apiController: RemoteNotificationsAPIController, modelController: RemoteNotificationsModelController, languageCode: String) {
        self.languageCode = languageCode
        super.init(with: apiController, modelController: modelController)
    }
    
    override func execute() {
            self.apiController.getAllNotifications(from: self.languageCode) { [weak self] result, error in
                
                guard let self = self else {
                    return
                }
                
                if let error = error {
                    self.finish(with: error)
                    return
                }

                guard let fetchedNotifications = result?.list else {
                    self.finish(with: RequestError.unexpectedResponse)
                    return
                }

                do {
                    let backgroundContext = self.modelController.newBackgroundContext()
                    try self.modelController.createNewNotifications(moc: backgroundContext, notificationsFetchedFromTheServer: Set(fetchedNotifications), completion: { [weak self] in

                        guard let self = self else {
                            return
                        }

                        self.finish()
                    })
                } catch let error {
                    self.finish(with: error)
                }
        }
    }
}
