//
//  ViewController.swift
//  Messenger
//
//  Created by Peter Iontsev on 5/21/18.
//  Copyright © 2018 Peter Iontsev. All rights reserved.
//

import UIKit
import JSQMessagesViewController

class ChatViewController: JSQMessagesViewController {
    //local property to store messages (an array)
    var messages = [JSQMessage]()
    // set messages body color
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.red)
    }() //red for testing, should be white with black text
    lazy var incomingBubble: JSQMessagesBubbleImage = {
       return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.black)
    }()
    //just do something when VC loads
    override func viewDidLoad() {
        super.viewDidLoad()
        //to obtain and show messages from Firebas
        let query = Constants.refs.databaseChats.queryLimited(toLast: 24) //create a query to get the last x chat messages
        _ = query.observe(.childAdded, with:
            //Firebase now starts “observing” the query for changes. When a new chat message is typed and sent by didPressSend(), it’s returned via the observer function
            {
            [weak self] snapshot in
            //using optional binding to unwrap and cast snapshot to a dictionary of strings
            if let data = snapshot.value as? [String: String],
                let id = data["sender_id"],
                let name = data["name"],
                let text = data["text"],
            !text.isEmpty {
                if let message = JSQMessage(senderId: id, displayName: name, text: text) {
                    self?.messages.append(message)
                    self?.finishReceivingMessage() //JSQMVC refreshes the UI and show the new message
                }
            }
        })
        //sender name
        let defaults = UserDefaults.standard  //create a temporary constant for the standard UserDefaults
        //to check if the keys jsq_id and jsq_name exist in the user defaults
        if let id = defaults.string(forKey: "jsq_id"), let name = defaults.string(forKey: "jsq_name") {
            //if they exist - assign the found id and name to senderId and senderDisplayName
            senderId = id
            senderDisplayName = name
        } else {
            //if they don't, assign a random numeric string to senderId and an empty string to senderDisplayName
            senderId = String(arc4random_uniform(99999))
            senderDisplayName = ""
            defaults.set(senderId, forKey: "jsq_id")
            defaults.synchronize() //save new senderId in the user defaults for key jsq_id
            showDisplayNameDialog() //show the display name alert dialog 
        }
        title = "Chat: \(senderDisplayName!)"
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDisplayNameDialog))
        tapGesture.numberOfTapsRequired = 1
        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        //
        //avatar/button hiding
        inputToolbar.contentView.leftBarButtonItem = nil
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
    }
    @objc func showDisplayNameDialog() {
        let defaults = UserDefaults.standard //create an alert controller
        let alert = UIAlertController(title: "Your Name", message: "Please enter your Name. You can change your display name again by tapping the navigation bar.", preferredStyle: .alert)
        alert.addTextField { textField in
            // text field is either provided with a value from UserDefaults, or with a random item from array
            if let name = defaults.string(forKey: "jsq_name") {
                textField.text = name
            } else { let names = ["Joker", "Skull", "Panther", "Morgana", "Fox", "Queen", "Navi", "Milady"]
                textField.text = names[Int(arc4random_uniform(UInt32(names.count)))]
            }
        }
        //add an action to the alert dialog. When the user taps “OK”, the closure is executed. In the closure, the sender display name is changed, as well as the view controller title, and the new name is stored in UserDefaults
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] _ in
            if let textField = alert?.textFields?[0], !textField.text!.isEmpty {
                self?.senderDisplayName = textField.text
                self?.title = "Chat: \(self!.senderDisplayName!)"
                defaults.set(textField.text, forKey: "jsq_name")
                defaults.synchronize()
            }
        }))
        present(alert, animated: true, completion: nil) //presents alert dialog
    }
    //returning the message data for a particular message by its index
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    //returns the total number of messages, based on the amount of items in the array
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    //delegate called by JSQ when it needs bubble image data. Ternary conditional operator is used to return the right bubble
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
    //we do not need avatars to be shown in message bubbles
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    //is called when the label text is needed. Determine if the message is sent by the current user, or sent by someone else. If by current user, label stays empty
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    //is called when the height of the top label is needed. If message by current user, label stays hidden
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    //to send messages
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let ref = Constants.refs.databaseChats.childByAutoId() //to create a value in Firebase, childByAutoId() method generates a unique key
        let message = ["sender_id": senderId,"name": senderDisplayName, "text": text] //to create a directory called message that contains all the information about the to-be-sent message
        ref.setValue(message) //setting reference to the value
        finishSendingMessage() //we are done!
    }
    //setting text/link color for incoming/outgoing messages
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        if !messages[indexPath.item].isMediaMessage {
            if messages[indexPath.item].senderId! == senderId {
                cell.textView.textColor = UIColor.white //black when background is red
            }else{
                cell.textView.textColor = UIColor.white
            }
            cell.textView.linkTextAttributes = [NSAttributedStringKey.foregroundColor.rawValue: cell.textView.textColor ?? UIColor.gray]
        }
        return cell
    }
}

























