// ∅ 2026 lil org

import Foundation

struct ProviderResponseError: Equatable {

    enum Context: Equatable {
        case dataJSON(String)
        case unauthorizedPublicKey(String)
        case transactionSignature(String)
    }

    let message: String
    let code: Int?
    let context: Context?

    init(
        message: String,
        code: Int? = nil,
        context: Context? = nil
    ) {
        self.message = message
        self.code = code
        self.context = context
    }

}

struct ResponseToExtension {
    
    let id: Int
    let json: [String: Any]
    
    enum Body {
        case ethereum(Ethereum)
        case solana(Solana)
        case multiple(Multiple)
        
        var json: [String: Any] {
            let data: Data?
            let jsonEncoder = JSONEncoder()

            switch self {
            case .ethereum(let body):
                data = try? jsonEncoder.encode(body)
            case .solana(let body):
                data = try? jsonEncoder.encode(body)
            case .multiple(let body):
                let dict: [String: Any] = [
                    "bodies": body.bodies.map { $0.json },
                    "providersToDisconnect": body.providersToDisconnect.map { $0.rawValue },
                    "provider": provider.rawValue
                ]
                return dict
            }

            if let data = data, var dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                dict["provider"] = provider.rawValue
                return dict
            } else {
                return [:]
            }
        }
        
        var provider: InpageProvider {
            switch self {
            case .ethereum:
                return .ethereum
            case .solana:
                return .solana
            case .multiple:
                return .multiple
            }
        }
    }

    enum Payload {
        case body(Body)
        case error(ProviderResponseError)
    }

    init(
        for request: SafariRequest,
        payload: Payload? = nil
    ) {
        self.id = request.id
        var json: [String: Any] = [
            "id": request.id,
            "name": request.name
        ]

        switch payload {
        case .body(let body):
            let bodyJSON = body.json
            json.merge(bodyJSON) { current, _ in current }

            if request.body.value.responseUpdatesStoredConfiguration {
                if let bodies = bodyJSON["bodies"] {
                    json["configurationToStore"] = bodies
                } else {
                    json["configurationToStore"] = bodyJSON
                }
            }
        case .error(let error):
            json["error"] = error.message
            json["provider"] = request.provider.rawValue
            if let code = error.code {
                json["errorCode"] = code
            }
            switch error.context {
            case .dataJSON(let dataJSON):
                json["errorDataJSON"] = dataJSON
            case .unauthorizedPublicKey(let publicKey):
                json["errorPublicKey"] = publicKey
            case .transactionSignature(let signature):
                json["errorSignature"] = signature
            case nil:
                break
            }
        case nil:
            break
        }

        self.json = json
    }
    
}
