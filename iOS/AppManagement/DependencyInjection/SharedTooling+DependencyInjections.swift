//
// SharedTooling+DependencyInjection.swift
// Proton Pass - Created on 07/06/2023.
// Copyright (c) 2023 Proton Technologies AG
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

import Core
import Factory
import ProtonCore_Keymaker

/// Contain tools shared between main iOS app and extensions
final class SharedToolingContainer: SharedContainer {
    typealias FullKeychainService = SettingsProvider & Keychain

    static let shared = SharedToolingContainer()
    let manager = ContainerManager()

    func resetCache() {
        manager.reset(scope: .cached)
    }
}

// MARK: Shared Logging tools

extension SharedToolingContainer {
    var logManager: Factory<LogManager> {
        self { LogManager(module: .hostApp) }
            .onArg(PassLogModule.autoFillExtension) { LogManager(module: .autoFillExtension) }
            .onArg(PassLogModule.keyboardExtension) { LogManager(module: .keyboardExtension) }
    }

    var logFormatter: Factory<LogFormatterProtocol> {
        self { LogFormatter(format: .txt) }
    }
}

// MARK: Data tools

extension SharedToolingContainer {
    var appData: Factory<AppData> {
        self { AppData(keychain: self.keychain(),
                       mainKeyProvider: self.keymaker(),
                       logManager: self.logManager()) }
    }

    var apiManager: Factory<APIManager> {
        self { APIManager(logManager: self.logManager(),
                          appVer: "ios-pass@\(Bundle.main.fullAppVersionName)",
                          appData: self.appData(),
                          preferences: self.preferences()) }
    }
}

// MARK: User centric tools

extension SharedToolingContainer {
    // This is set in a cached scope to be able to reset when needed
    // To reset you can call SharedToolingContainer.shared.manager.reset(scope: .cached)
    var preferences: Factory<Preferences> {
        self { Preferences() }
            .cached
    }
}

// MARK: Keychain tools

extension SharedToolingContainer {
    var keychain: Factory<FullKeychainService> {
        self { PPKeychain() }
    }

    var autolocker: Factory<Autolocker> {
        self { Autolocker(lockTimeProvider: self.keychain()) }
    }

    var keymaker: Factory<Keymaker> {
        self { Keymaker(autolocker: self.autolocker(), keychain: self.keychain()) }
    }
}

extension SharedToolingContainer: AutoRegistering {
    func autoRegister() {
        manager.defaultScope = .singleton
    }
}
