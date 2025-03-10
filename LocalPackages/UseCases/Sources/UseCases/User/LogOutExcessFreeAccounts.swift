//
// LogOutExcessFreeAccounts.swift
// Proton Pass - Created on 29/07/2024.
// Copyright (c) 2024 Proton Technologies AG
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
//

import Client
import Core

/// Log out all excess free accounts. Return `true` if some accounts were logged out, `false` otherwise.
public protocol LogOutExcessFreeAccountsUseCase: Sendable {
    func execute() async throws -> Bool
}

public extension LogOutExcessFreeAccountsUseCase {
    func callAsFunction() async throws -> Bool {
        try await execute()
    }
}

public final class LogOutExcessFreeAccounts: LogOutExcessFreeAccountsUseCase {
    private let datasource: any LocalAccessDatasourceProtocol
    private let logOutUser: any LogOutUserUseCase

    public init(datasource: any LocalAccessDatasourceProtocol,
                logOutUser: any LogOutUserUseCase) {
        self.datasource = datasource
        self.logOutUser = logOutUser
    }

    public func execute() async throws -> Bool {
        let accesses = try await datasource.getAllAccesses()
        let freeAccesses = accesses.filter(\.access.plan.isFreeUser)
        guard freeAccesses.count > Constants.freeAccountsLimit else { return false }

        // Do not remove all free accounts but leave out the first ones
        for access in freeAccesses.dropFirst(Constants.freeAccountsLimit) {
            try await logOutUser(userId: access.userId)
        }

        return true
    }
}
