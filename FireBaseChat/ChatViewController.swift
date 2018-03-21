//
//  ChatViewController.swift
//  FireBaseChat
//
//  Created by Kejsi Struga on 19/03/2018.
//  Copyright © 2018 Kejsi Struga. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import MobileCoreServices // constants for video and image types - kUTTypeImage,kUTTypeMovie; These constants are of type CFString
import AVKit
import FirebaseDatabase
import FirebaseStorage // To store media data
import FirebaseAuth
import GoogleSignIn

class ChatViewController: JSQMessagesViewController {

    var avatarDict = [String: JSQMessagesAvatarImage]()
    var messages = [JSQMessage]()
    // From the URL of our app, to communicate with the root of our firebase app via the reference
    let messageRef = Database.database().reference().child("messages")
    let photoCache = NSCache<NSString, JSQPhotoMediaItem>() // to hold all downloaded photos, we'll use file url for the key of this "dictionary"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let currentUser = Auth.auth().currentUser {
            self.senderId = currentUser.uid
            if currentUser.isAnonymous == true {
                self.senderDisplayName = "Anonymous"
            } else {
                self.senderDisplayName = "\(String(describing: currentUser.displayName))"
            }
        }
        
        observeMessages()
    }
    
    func setupAvatar(_ url: String, messageId: String) {
        if url != "" {
            let fileUrl = URL(string: url)
            let data = try? Data(contentsOf: fileUrl!)
            let image = UIImage(data: data!)
            let userImg = JSQMessagesAvatarImageFactory.avatarImage(with: image, diameter: 30)
            self.avatarDict[messageId] = userImg
            self.collectionView.reloadData()
        } else {
            avatarDict[messageId] = JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "profileImage"), diameter: 30)
            collectionView.reloadData()
        }
    }
    
    func observeUser(_ id: String)
    {
        Database.database().reference().child("users").child(id).observe(.value, with: {
            snapshot in
            if let dict = snapshot.value as? [String: AnyObject]
            {
                let avatarUrl = dict["profileUrl"] as! String
                
                self.setupAvatar(avatarUrl, messageId: id)
            }
        })
        
    }
    
    // location of all messages in the database
    func observeMessages() {
        messageRef.observe(.childAdded, with: { snapshot in
            
            if let dict = snapshot.value as? [String: AnyObject] {
                let mediaType = dict["MediaType"] as! String
                let senderId = dict["senderId"] as! String
                let sendername = dict["senderName"] as! String
                self.observeUser(senderId)
                
                switch mediaType {
                    case "TEXT":
                        let text = dict["text"]
                        self.messages.append(JSQMessage(senderId: senderId, displayName: sendername, text: text as! String))
                    case "PHOTO":
                        let fileUrl = dict["fileURL"] as! String
                        let url = NSURL(string: fileUrl )
                        var photo = JSQPhotoMediaItem(image: nil)
                        
                        if self.photoCache.object(forKey: fileUrl as NSString) != nil {
                            photo = self.photoCache.object(forKey: fileUrl as NSString)
                            self.collectionView.reloadData()
                        } else {
                            /*
                             Uploading a photo is a time consuming task => we can dispatch it on another thread other than the main thread so that UI is not freezed;
                             Converting a URL to Data makes this process time consuming
                             */
                            DispatchQueue.global(qos: .userInteractive).async {
                                let data = NSData(contentsOf: url! as URL)
                                DispatchQueue.main.async {
                                    let image = UIImage(data: data! as Data)
                                    photo?.image = image
                                    print("Thread:: \(Thread.current)")
                                    self.collectionView.reloadData()
                                    self.photoCache.setObject(photo!, forKey: fileUrl as NSString)
                                }
                            }
                        }
                      
                        self.messages.append(JSQMessage(senderId: senderId, displayName: sendername, media: photo))
                        if self.senderId == senderId { // outgoing
                            photo?.appliesMediaViewMaskAsOutgoing = true
                        } else {
                            photo?.appliesMediaViewMaskAsOutgoing = false
                        }
                    case "VIDEO":
                        let fileURL = dict["fileURL"] as! String
                        let video = NSURL(string: fileURL)
                        let videoItem = JSQVideoMediaItem(fileURL: video! as URL, isReadyToPlay: true)
                        self.messages.append(JSQMessage(senderId: senderId, displayName: sendername, media: videoItem))
                        if self.senderId == senderId { // outgoing
                            videoItem?.appliesMediaViewMaskAsOutgoing = true
                        } else {
                            videoItem?.appliesMediaViewMaskAsOutgoing = false
                    }
                    default:
                        print("Unknown media type")
                }

                self.collectionView.reloadData()
            }
        })
    }
    
    // We will send data to firebase each time the send button is pressed
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        let newMessage = messageRef.childByAutoId()
        let messageData = ["text": text, "senderId": senderId, "senderName": senderDisplayName, "MediaType": "TEXT"]
        newMessage.setValue(messageData)
        // clear text field
        self.finishSendingMessage()
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        print("didTapMessageBubbleAtIndex: \(indexPath.item)")
        let message = messages[indexPath.item]
        
        if message.isMediaMessage {
            if let mediaItem = message.media  as? JSQVideoMediaItem {
                let player = AVPlayer(url: mediaItem.fileURL)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true, completion: nil)
            }
        }
    }
    
    // related to the extension
    /*
        1. We present a sheet view for users to pick an image or video
        2. Extract the item and encoded into video/image media
     */
    override func didPressAccessoryButton(_ sender: UIButton!) {
        
        // Show UIAlert and its options which are of type UIAlertAction
        let sheet = UIAlertController(title: "Media Message", message: "Please Select a Media", preferredStyle:
               UIAlertControllerStyle.actionSheet )
        let cancel = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel) { (alert: UIAlertAction) in
            
        }
        
        let photoLibrary = UIAlertAction(title: "Photo Library", style: UIAlertActionStyle.default) { (alert: UIAlertAction) in
            self.getMediaFrom(type: kUTTypeImage)
        }
        
        let videoLibrary = UIAlertAction(title: "Video Library", style: UIAlertActionStyle.default) { (alert: UIAlertAction) in
            self.getMediaFrom(type: kUTTypeMovie)
        }
        
        sheet.addAction(cancel)
        sheet.addAction(photoLibrary)
        sheet.addAction(videoLibrary)
        self.present(sheet, animated: true, completion: nil)
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        // use this view controller to pick images
        self.present(imagePicker, animated: true, completion: nil)
    }
    
    func getMediaFrom(type: CFString) {
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = [type as String]
        self.present(mediaPicker, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count // all messages sent by user
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        return cell
    }
    
    // feed message data to the collection view
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    // ui display msgs
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        let message = messages[indexPath.item]
        
        if message.senderId == self.senderId {
            return bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor.darkGray)
        } else { // incoming messages
            return bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor.blue)
        }
    }
    
    // avatar
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        
        return avatarDict[message.senderId]
      //  return JSQMessagesAvatarImageFactory.avatarImage(with: UIImage(named: "profileImage"), diameter: 30)
    }
    
    // Switch back to the login view, same procedure as for going from the login view to this view
    @IBAction func logoutBtn(_ sender: Any) {
        GIDSignIn.sharedInstance().signOut()
        
        do {
            try Auth.auth().signOut()
        } catch {
            print("Error while signing out: \(error)")
        }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginVC") as! LoginViewController
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window?.rootViewController = loginVC
    }
    
    func saveMediaToStorage (picture: UIImage?, video: URL?) {
        // location of the storage of our app
        // folder where we put all media files sent by this user hence the Auth.auth()
        if let picture = picture {
            let filePath = "\(Auth.auth().currentUser!.uid)/\(NSDate.timeIntervalSinceReferenceDate)" // timestamp as unique name for each image
            print(filePath)
            let data = UIImageJPEGRepresentation(picture, 0.1) // compress to 0.1
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpg"
            Storage.storage().reference().child(filePath).putData(data!, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription ?? "Error while accessing storage")
                    return
                }
                
                let fileURL = metadata!.downloadURLs![0].absoluteString
                let newMessage = self.messageRef.childByAutoId()
                let messageData = ["fileURL": fileURL, "senderId": self.senderId, "senderName": self.senderDisplayName,
                                   "MediaType": "PHOTO"]
                newMessage.setValue(messageData)
            }
        } else if let video = video {
            let filePath = "\(Auth.auth().currentUser!.uid)/\(Date.timeIntervalSinceReferenceDate)" // timestamp as unique name for each image
            
            let data = try? Data(contentsOf: video)
           
            let metadata = StorageMetadata()
            metadata.contentType = "video/mp4"
            Storage.storage().reference().child(filePath).putData(data! as Data, metadata: metadata) { (metadata, error) in
                if error != nil {
                    print(error?.localizedDescription)
                    return
                }
                
                let fileURL = metadata!.downloadURLs![0].absoluteString
                let newMessage = self.messageRef.childByAutoId()
                let messageData = ["fileURL": fileURL, "senderId": self.senderId, "senderName": self.senderDisplayName,
                                   "MediaType": "VIDEO"]
                newMessage.setValue(messageData)
            }
        }
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        print("Did finish picking")
//        extract the chosen image
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage {
            saveMediaToStorage(picture: picture, video: nil)
        } else if let video = info[UIImagePickerControllerMediaURL] as? NSURL {
            saveMediaToStorage(picture: nil, video: video as URL)
        }
        
        // dissapear the imagepicker after user has chosen photo
        self.dismiss(animated: true, completion: nil)
        collectionView.reloadData()
    }
}
