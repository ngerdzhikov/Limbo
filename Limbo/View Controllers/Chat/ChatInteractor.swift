//
//  ChatInteractor.swift
//  Limbo
//
//  Created by A-Team User on 24.08.18.
//  Copyright © 2018 A-Team User. All rights reserved.
//

let KEY_COORDINATES = "coordinates"
let KEY_NAME = "name"
let KEY_ANSWER = "answer"

let QUESTION_NAME = "What is your name?"

import UIKit
import RealmSwift
import MultipeerConnectivity

class ChatInteractor: NSObject, ChatInteractorInterface {
    
    var chatPresenter: ChatPresenterInterface!
    var chatDelegate: UsersConnectivityDelegate!
    var chatRoom: ChatRoomModel?
    var currentUser = RealmManager.currentLoggedUser()
    var messagesResults: Results<MessageModel>!
    var notificationToken: NotificationToken!
    
    var voiceRecorder: VoiceRecorder?
    
    init(chatDelegate: UsersConnectivityDelegate, chatPresenter: ChatPresenterInterface, chatRoom: ChatRoomModel) {
        self.chatDelegate = chatDelegate
        self.chatPresenter = chatPresenter
        self.chatRoom = chatRoom
        self.messagesResults = RealmManager.getMessagesForChatRoom(firstUser: self.currentUser!, chatRoom: chatRoom)
        super.init()
        self.initNotificationToken()
    }
    
    deinit {
        self.notificationToken.invalidate()
    }
    
    func handleMessage(message: String) {
        var message = message
        if message.count > 0 {
            
            if self.chatRoom!.usersChattingWith.first!.state == "Spectre" {
                SpectreManager.sendMessageToSpectre(message: message)
            }
            else if message == UserDefaults.standard.string(forKey: Constants.UserDefaults.antiCurse) && self.chatRoom!.usersChattingWith.first!.uniqueDeviceID == UserDefaults.standard.string(forKey: Constants.UserDefaults.curseUserUniqueDeviceID){
                CurseManager.removeCurse()
                NotificationManager.shared.presentItemNotification(withTitle: "Anti-Spell", andText: "You removed your curse with anti-spell")
            }
            else if self.chatRoom!.roomType == RoomType.Game.rawValue {
                self.sendMessageToGame(message: message)
            }
            else if message.count > 0 && self.currentUser!.curse != Curse.Silence.rawValue {
                if self.currentUser?.curse == Curse.Posession.rawValue {
                    message = message.shuffle()
                }
                self.sendMessageToUser(message: message)
            }
            else if self.currentUser!.curse == Curse.Silence.rawValue{
                self.chatPresenter.silencedCallBack()
            }
        }
    }
    
    func sendMessageToUser(message: String) {
        let messageModel = MessageModel()
        messageModel.messageString = message
        messageModel.messageType = MessageType.Message.rawValue
        messageModel.sender = self.currentUser
        if (self.chatRoom?.usersChattingWith.count)! > 1 {
            messageModel.chatRoomUUID = self.chatRoom!.uuid
        }
        else {
            messageModel.chatRoomUUID = self.currentUser!.uniqueDeviceID.appending(self.currentUser!.username)
        }
        
        for user in chatRoom!.usersChattingWith {
            if let peerID = self.chatDelegate.getPeerIDForUID(uniqueID: user.uniqueDeviceID) {
                _ = self.chatDelegate.sendMessage(messageModel: messageModel, toPeerID: peerID)
            }
        }
        messageModel.chatRoomUUID = self.chatRoom!.uuid
        RealmManager.addNewMessage(message: messageModel)
    }
    
    func sendMessageToGame(message: String) {
        
        let messageBeforeThis = self.messagesResults.last?.messageString
        var key: String
        
        let messageModel = MessageModel()
        messageModel.messageString = message
        messageModel.sender = self.currentUser
        if messageBeforeThis == QUESTION_NAME {
            key = KEY_NAME
        }
        else if messageBeforeThis!.contains("|") || messageBeforeThis!.contains("Invalid") {
            key = KEY_COORDINATES
        }
        else {
            key = KEY_ANSWER
        }
        let dataDict = [key: message]
        
        let success = self.chatDelegate?.sendJSONtoGame(dataDict: dataDict, toPeerID: (self.chatDelegate?.getPeerIDForUID(uniqueID: self.chatRoom!.usersPeerIDs.first!)!)!)
        if success! {
            let realm = try! Realm()
            if let chatRoom = RealmManager.chatRoom(forUUID: self.chatRoom!.uuid) {
                try? realm.write {
                    realm.add(messageModel)
                    messageModel.chatRoomUUID = chatRoom.uuid
                }
            }
        }
    }
    
    func initNotificationToken() {
        self.notificationToken = self.messagesResults.observe({ changes in
            switch changes {
            case .initial:
//                self.chatPresenter.didFetchMessages()
                print()
            case .update(_, _, let insertions, _):
                
                if insertions.count > 0 {
                    print("new insertion\n\n")
                    self.chatPresenter.newMessage(message: self.messagesResults.last!)
                }
            case .error(let error):
                print(error)
            }
        })
    }
    
    func getMessageResults() -> Results<MessageModel>? {
        return self.messagesResults
    }
    
    func currentRoomName() -> String {
        return chatRoom!.name
    }
    
    func clearHistory(completionHandler: ()) {
        let realm = try! Realm()
        realm.beginWrite()
        realm.delete(self.messagesResults)
        try! realm.commitWrite()
        completionHandler
    }
    
    func finishedPickingImage(pickedImage: UIImage) {
        let message = MessageModel()
        message.messageType = MessageType.Photo.rawValue
        message.additionalData = UIImageJPEGRepresentation(pickedImage, 1.0)
        message.sender = self.currentUser!
        var imageName = message.additionalData?.base64EncodedString().suffix(10).appending(".jpeg")
        imageName = imageName?.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "a")
        message.messageString = imageName!
        let fileToSaveTo = FileManager.getDocumentsDirectory().appendingPathComponent("Limbo", isDirectory: true).appendingPathComponent(imageName!, isDirectory: false)
        do {
            try message.additionalData?.write(to: fileToSaveTo, options: Data.WritingOptions.atomic)
        }
        catch {
            print(error)
        }
        if (self.chatRoom?.usersChattingWith.count)! > 1 {
            message.chatRoomUUID = self.chatRoom!.uuid
        }
        else {
            message.chatRoomUUID = self.currentUser!.uniqueDeviceID.appending(self.currentUser!.username)
        }
        for user in chatRoom!.usersChattingWith {
            if let peerID = self.chatDelegate?.getPeerIDForUID(uniqueID: user.uniqueDeviceID) {
                _ = self.chatDelegate!.sendMessage(messageModel: message, toPeerID: peerID)
            }
        }
        message.additionalData = nil
        message.chatRoomUUID = self.chatRoom!.uuid
        RealmManager.addNewMessage(message: message)
    }
}
