//
//  Constants.swift
//  Messenger
//
//  Created by Peter Iontsev on 5/21/18.
//  Copyright © 2018 Peter Iontsev. All rights reserved.
//

import Foundation
import Firebase

struct Constants {
    struct refs {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("chats")
    }
}
