//
// InviteMultipleNewUserToShareEndpoint.swift
// Proton Pass - Created on 21/12/2023.
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

import Foundation
import ProtonCoreNetworking

struct InviteMultipleNewUserToShareEndpoint: Endpoint {
    typealias Body = InviteMultipleNewUsersToShareRequest
    typealias Response = CodeOnlyResponse

    var debugDescription: String
    var path: String
    var method: HTTPMethod
    var body: InviteMultipleNewUsersToShareRequest?

    init(shareId: String, request: InviteMultipleNewUsersToShareRequest) {
        debugDescription = "Invite multiple non Proton user to share"
        path = "/pass/v1/share/\(shareId)/invite/new_user/batch"
        method = .post
        body = request
    }
}

public struct InviteMultipleNewUsersToShareRequest: Sendable, Encodable {
    let newUserInvites: [InviteNewUserToShareRequest]

    public init(newUserInvites: [InviteNewUserToShareRequest]) {
        self.newUserInvites = newUserInvites
    }

    enum CodingKeys: String, CodingKey {
        case newUserInvites = "NewUserInvites"
    }
}
