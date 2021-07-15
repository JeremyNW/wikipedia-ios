
import Foundation

extension EchoNotificationsFetcher {
    func registerForEchoNotificationsWithDeviceTokenString(deviceTokenString: String, completion: @escaping (Bool, Error?) -> Void) {
        //TODO: Use Configuration.swift, which wiki do we use
        //working: https://en.wikipedia.org/w/api.php?action=echopushsubscriptions&format=json&command=create&token=9a49637fab9cd98c0327849ef757fec760cd0091%2B%5C&provider=apns&providertoken=115414e7a529c0b2fb9ed65a6d26d29c6882b2c5264a9e5e4d9ce8ea43e96a2b&topic=org.wikimedia.wikipedia
        guard let bundleID = Bundle.main.bundleIdentifier else {
            completion(false, nil)
            return
        }
        guard let url = URL(string: "https://en.wikipedia.org") else {
            completion(false, nil)
            return
        }
        
        let bodyParameters: [String: String] = [
            "action": "echopushsubscriptions",
            "format": "json",
            "command": "create",
            "provider": "apns",
            "providertoken": deviceTokenString,
            "topic": bundleID
        ]
        print("🤷‍♀️deviceToken:\(deviceTokenString)")
        self.performTokenizedMediaWikiAPIPOST(to: url, with: bodyParameters) { result, response, error in
            guard error == nil else {
                completion(false, error)
                return
            }
            
            //todo: use RequestError instead here
            guard response?.statusCode == 200 else {
                completion(false, nil)
                return
            }
            
            if let errorDict = result?["error"] {
                completion(false, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    func deregisterForEchoNotificationsWithDeviceTokenString(deviceTokenString: String, completion: @escaping (Bool, Error?) -> Void) {
        //TODO: Use Configuration.swift, which wiki do we use
        guard let url = URL(string: "https://en.wikipedia.org/w/api.php?action=echopushsubscriptions&command=delete&providertoken=\(deviceTokenString)") else {
            completion(false, nil)
            return
        }
        
        let bodyParameters: [String: String] = [
            "action": "echopushsubscriptions",
            "format": "json",
            "command": "delete",
            "providertoken": deviceTokenString
        ]
        
        self.performTokenizedMediaWikiAPIPOST(to: url, with: bodyParameters) { result, response, error in
            guard error != nil else {
                completion(false, error)
                return
            }
            
            guard response?.statusCode == 200 else {
                completion(false, nil)
                return
            }
            
            completion(true, nil)
        }
    }
    
    func markNotificationAsRead(subdomain: String, notification: EchoNotification, completion: @escaping (Result<Void, Error>) -> Void) -> CancellationKey? {
        
        guard let url = url(subdomain: subdomain) else {
            completion(.failure(EchoError.failureToGenerateUrl))
            return nil
        }
        
        var notificationId: Int64? = nil
        notification.managedObjectContext?.performAndWait {
            notificationId = notification.id
        }
        
        guard let notificationId = notificationId else {
            completion(.failure(EchoError.failureToPullNotificationIdForMarkAsRead))
            return nil
        }
        
        let bodyParameters = ["action": "echomarkread",
                               "list": String(notificationId),
                               "format": "json"]
        
        return self.performTokenizedMediaWikiAPIPOST(to: url, with: bodyParameters) { result, response, error in
            
            if let error = error {
                completion(.failure(EchoError.serverFailureMarkingAsRead))
                return
            }
            
            if let queryDict = result?["query"] as? [String: Any],
               let echoMarkReadDict = queryDict["echomarkread"] as? [String: Any],
               let result = echoMarkReadDict["result"] as? String {
                if result == "success" {
                    completion(.success(()))
                    return
                }
            }
            
            completion(.failure(EchoError.serverFailureMarkingAsRead))
        }
    }
}
