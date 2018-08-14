//
//  UsersConnectivity+Game.swift
//  Limbo
//
//  Created by A-Team User on 8.08.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import RealmSwift

extension UsersConnectivity {
    
    func handleGameData(data: Data, fromPeer peerID: MCPeerID) {
        let dictWithData = try! JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as! [String: Any]
        let messageModel = MessageModel()
        messageModel.messageString = dictWithData.first?.value as! String
        let realm = try! Realm()
        realm.beginWrite()
        messageModel.sender = RealmManager.userWith(uniqueID: peerID.displayName)
        messageModel.receivers.append(RealmManager.currentLoggedUser()!)
        realm.add(messageModel)
        try? realm.commitWrite()
        if let fromPeer = self.getPeerIDForUID(uniqueID: peerID.displayName) {
            let threadSafeMessage = ThreadSafeReference(to: messageModel)
            chatDelegate?.didReceiveMessage(threadSafeMessageRef: threadSafeMessage, fromPeerID: fromPeer)
        }
        
        print(dictWithData)
    }
    
    func foundGamePeer(peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print(info as Any)
        print(peerID)
        let username = String(peerID.displayName.prefix(upTo: peerID.displayName.index(peerID.displayName.startIndex, offsetBy: peerID.displayName.count - 5)))
        let userModel = UserModel(username: username, state: info!["gameName"]!, uniqueDeviceID: peerID.displayName)
        userModel.userID = -3
        let realm = try! Realm()
        if realm.objects(UserModel.self).filter("uniqueDeviceID == %@", peerID.displayName).first == nil {
            realm.beginWrite()
            realm.add(userModel)
            try! realm.commitWrite()
        }
        self.delegate?.didFindNewUser(user: userModel, peerID: peerID)
    }
}
