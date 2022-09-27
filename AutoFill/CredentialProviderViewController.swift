//
// CredentialProviderViewController.swift
// Proton Pass - Created on 26/09/2022.
// Copyright (c) 2022 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import AuthenticationServices
import Client
import Core
import ProtonCore_Keymaker
import ProtonCore_Services

final class CredentialProviderViewController: ASCredentialProviderViewController {
    @KeychainStorage(key: "sessionData")
    private var sessionData: SessionData?

    @KeychainStorage(key: "symmetricKey")
    private var symmetricKey: String?

    private lazy var coordinator: CredentialProviderCoordinator = {
        .init(apiService: PMAPIService(doh: PPDoH(bundle: .main)),
              container: .Builder.build(name: kProtonPassContainerName, inMemory: false),
              context: extensionContext,
              rootViewController: self)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        let keychain = PPKeychain()
        let keymaker = Keymaker(autolocker: Autolocker(lockTimeProvider: keychain), keychain: keychain)
        self._sessionData.setKeychain(keychain)
        self._sessionData.setMainKeyProvider(keymaker)
        self._symmetricKey.setKeychain(keychain)
        self._symmetricKey.setMainKeyProvider(keymaker)
        coordinator.start(sessionData: sessionData, symmetricKey: symmetricKey)
    }
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
    */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
    }

     /*Implement this method if your extension supports showing credentials in the QuickType bar.
     When the user selects a credential from your app, this method will be called with the
     ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
     Provide the password by completing the extension request with the associated ASPasswordCredential.
     If using the credential would require showing custom UI for authenticating the user, cancel
     the request with error code ASExtensionError.userInteractionRequired.

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        let databaseIsUnlocked = true
        if (databaseIsUnlocked) {
            let passwordCredential = ASPasswordCredential(user: "j_appleseed", password: "apple1234")
            self.extensionContext.completeRequest(withSelectedCredential: passwordCredential,
                                                  completionHandler: nil)
        } else {
            let error = NSError(domain: ASExtensionErrorDomain,
                                code:ASExtensionError.userInteractionRequired.rawValue)
            self.extensionContext.cancelRequest(withError: error)
        }
    }*/

    /*
     Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
     ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
     UI and call this method. Show appropriate UI for authenticating the user then provide the password
     by completing the extension request with the associated ASPasswordCredential.

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
    }
    */
}
