//
//  Helper.swift
//  FireBaseChat
//
//  Created by Kejsi Struga on 19/03/2018.
//  Copyright © 2018 Kejsi Struga. All rights reserved.
//

import Foundation
import FirebaseAuth
import UIKit
import FirebaseDatabase
import GoogleSignIn

class Helper {
    static let helper = Helper() // singleton, the helper instance exists only one time
    
    func loginAnonymously() {
        Auth.auth().signInAnonymously() { (user: User?, error) in
            if error  == nil {
                print("UserID: \(user!.uid)")
                let anonymousUser = Database.database().reference().child("users").child(user!.uid)
                anonymousUser.setValue([ "displayName" : "anonymous",
                    "id" : "\(user!.uid)"
                    ,"profileUrl" : ""
                    ])
                
                self.switchToNavigationViewController()
            } else {
                print(error!.localizedDescription)
            }
        }
    }

    func logInWithGoogle(_ authentication: GIDAuthentication) {
        
        let credential = GoogleAuthProvider.credential(withIDToken: authentication.idToken, accessToken: authentication.accessToken)
        
        Auth.auth().signIn(with: credential) { (user: User?, error: Error?) in
            
            if error != nil {
                print(error!.localizedDescription)
                return
            } else {
                let newUser = Database.database().reference().child("users").child(user!.uid)
                newUser.setValue([ "displayName" : "\(user!.displayName!)",
                                    "id" : "\(user!.uid)",
                                    "profileUrl" : "\(user!.photoURL!)"
                                  ])
                self.switchToNavigationViewController()
            }
            
        }
        
    }
    
    func switchToNavigationViewController() {
        // 1. Create a main storyboard instance
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        // 2. From main storyboard we instantiate a navigation controller a navigation controller;
        // The identifier of the navigation view will be set from the inspector at StoryboadID
        let navgVC = storyboard.instantiateViewController(withIdentifier: "NavgVC") as! UINavigationController
        // 3. Get the app delegate
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        // 4. Set Login Controller as root view controller
        appDelegate.window?.rootViewController = navgVC
    }
    
}
