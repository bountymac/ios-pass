//
// RemoteAccessDatasource.swift
// Proton Pass - Created on 04/05/2023.
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

import Entities

public protocol RemoteAccessDatasourceProtocol: Sendable {
    func getAccess(userId: String) async throws -> Access
    func updatePassMonitorState(userId: String, request: UpdateMonitorStateRequest) async throws -> Access.Monitor
    func getUserPassInformations(userId: String) async throws -> PassUserInformations
}

public final class RemoteAccessDatasource: RemoteDatasource, RemoteAccessDatasourceProtocol, @unchecked Sendable {}

public extension RemoteAccessDatasource {
    func getAccess(userId: String) async throws -> Access {
        let endpoint = CheckAccessEndpoint()
        let response = try await exec(userId: userId, endpoint: endpoint)
        return response.access
    }

    func updatePassMonitorState(userId: String, request: UpdateMonitorStateRequest) async throws -> Access
        .Monitor {
        let endpoint = UpdateMonitorStateEndpoint(request: request)
        let response = try await exec(userId: userId, endpoint: endpoint)
        return response.monitor
    }
    
    func getUserPassInformations(userId: String) async throws -> PassUserInformations {
        let endpoint = GetPassUserInformationsEndpoint()
        let response = try await exec(userId: userId, endpoint: endpoint)
        return response.data
    }
}

