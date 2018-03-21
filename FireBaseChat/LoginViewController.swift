//
//  LoginViewController.swift
//  FireBaseChat
//
//  Created by Kejsi Struga on 19/03/2018.
//  Copyright © 2018 Kejsi Struga. All rights reserved.
//

import UIKit
import GoogleSignIn
import FirebaseAuth

class LoginViewController: UIViewController, GIDSignInUIDelegate, GIDSignInDelegate  {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        GIDSignIn.sharedInstance().clientID = "765640554079-jtla23q7l03vp4hcrhlvmjmudkggs33e.apps.googleusercontent.com"
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print(Auth.auth().currentUser)
        
        Auth.auth().addStateDidChangeListener({ (auth: Auth, user: User?) in
            if user != nil {
                print(user)
                Helper.helper.switchToNavigationViewController()
            } else {
                print("Unauthorized")
            }
        })
    }
    
    @IBAction func LoginBtn(_ sender: Any) {
       Helper.helper.loginAnonymously()
    }
    
    @IBAction func LoginGoogleBtn(_ sender: Any) {
        print("GoogleSignIn: \(GIDSignIn.sharedInstance())")
        GIDSignIn.sharedInstance().signIn()
    }
    
    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if error != nil {
            print ("Error while logging in: \(error!.localizedDescription)")
        } else {
            print("user.authentication: \(user.authentication)")
            Helper.helper.logInWithGoogle(user.authentication)
        }
    }
}
