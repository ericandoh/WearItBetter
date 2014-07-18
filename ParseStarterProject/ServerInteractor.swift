//
//  ServerInteractor.swift
//  ParseStarterProject
//
//  Code to handle all the server-interactions with this app (keeping it in one place for easy portability)
//  Mostly communications with Parse and PFObjects
//
//  Created by Eric Oh on 6/26/14.
//
//

import UIKit

@objc class ServerInteractor: NSObject {
    //---------------User Login/Signup/Interaction Methods---------------------------------
    class func registerUser(username: String, email: String, password: String, sender: NSObject)->Bool {
        var user: PFUser = PFUser();
        user.username = username;
        user.password = password;
        user.email = email;
        
        //user["friends"] = NSArray();
        user["viewHistory"] = NSArray();
        
        user.signUpInBackgroundWithBlock( {(succeeded: Bool, error: NSError!) in
            var signController: SignUpViewController = sender as SignUpViewController;
            if (!error) {
                //success!
                //sees if user has pending items to process
                //ServerInteractor.initialUserChecks();
                //user's first notification
                ServerInteractor.postDefaultNotif("Welcome to InsertAppName! Thank you for signing up for our app!");
                signController.successfulSignUp();
                
            } else {
                //var errorString: String = error.userInfo["error"] as String;
                var errorString = error.localizedDescription;
                //display this error string to user
                //send some sort of notif to refresh screen
                signController.failedSignUp(errorString);
            }
        });
        return true;
    }
    class func loginUser(username: String, password: String, sender: NSObject)->Bool {
        PFUser.logInWithUsernameInBackground(username, password: password, block: { (user: PFUser!, error: NSError!) in
            var logController: LoginViewController = sender as LoginViewController;
            if (user) {
                //successful log in
                //ServerInteractor.initialUserChecks();
                logController.successfulLogin();
            }
            else {
                //login failed
                //var errorString: String = error.userInfo["error"] as String;
                var errorString = error.localizedDescription;
                logController.failedLogin(errorString);
            }
        });
        return true;
    }
    //called when app starts + not anon user
    class func updateUser(sender: NSObject) {
        PFUser.currentUser().fetchInBackgroundWithBlock({(user: PFObject!, error: NSError!)->Void in
            var start: StartController = sender as StartController;
            if (!error) {
                //ServerInteractor.initialUserChecks();
                start.approveUser();
            }
            else {
                start.stealthUser();
            }
        });
    }
    
    //loggin in with facebook
    class func loginWithFacebook(sender: NSObject) {
        //whats permissions
        //permissions at https://developers.facebook.com/docs/facebook-login/permissions/v2.0
        //sample permissions: ["user_about_me", "user_relationships", "user_birthday", "user_location"]
        let permissions: [AnyObject]? = ["user_about_me", "user_relationships"];
        PFFacebookUtils.logInWithPermissions(permissions, {
            (user: PFUser!, error: NSError!) -> Void in
            var logController: LoginViewController = sender as LoginViewController;
            if (error) {
                NSLog("Error message: \(error!.description)");
            } else if !user {
                logController.failedLogin("Uh oh. The user cancelled the Facebook login.");
            } else if user.isNew {
                //logController.failedLogin("User signed up and logged in through Facebook!")
                NSLog("Setting up initial stuff for user");
                //user["friends"] = NSArray();
                user["viewHistory"] = NSArray();
                //user's first notification
                ServerInteractor.postDefaultNotif("Welcome to InsertAppName! Thank you for signing up for our app!");
                user.saveEventually();
                logController.successfulLogin();
                
            } else {
                //logController.failedLogin("User logged in through Facebook!")
                logController.successfulLogin();
            }
        });
    }
    
    
    //logged in as anonymous user does NOT count
    //use this to check whether to go to signup/login screen or directly to home
    class func isUserLogged()->Bool {
        if (PFUser.currentUser() != nil) {
            if (PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser())) {
                //anonymous user
                return false;
            }
            return true;
        }
        return false;
    }
    //use this to handle disabling/enabling of signoff button
    class func isAnonLogged()->Bool {
        return PFAnonymousUtils.isLinkedWithUser(PFUser.currentUser());
    }
    class func logOutUser() {
        PFUser.logOut();
    }
    class func logInAnon() {
        PFAnonymousUtils.logInWithBlock {
            (user: PFUser!, error: NSError!) -> Void in
            if error {
                NSLog("Anonymous login failed.")
            } else {
                NSLog("Anonymous user logged in.")
            }
        }
    }
    class func resetPassword(email: String) {
        PFUser.requestPasswordResetForEmailInBackground(email)
    }
    
    class func getUserName()->String {
        //need to add check checking if I am anon
        return PFUser.currentUser().username;
    }
    //used in friend display panels to handle my user screen vs other user screens
    class func getCurrentUser()->FriendEncapsulator {
        return FriendEncapsulator(friend: PFUser.currentUser());
    }
    //------------------Image Post related methods---------------------------------------
    //separates + processes label string, and also uploads labels to server
    class func separateLabels(labels: String)->Array<String> {
        var arr = labels.componentsSeparatedByCharactersInSet(NSCharacterSet(charactersInString: ", "));
        arr = arr.filter({(obj: String)->Bool in obj != ""});
        
        
        var query = PFQuery(className: "SearchTerm");
        query.whereKey("term", containedIn: arr);
        query.findObjectsInBackgroundWithBlock({
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if (!error) {
                var foundLabel: String;
                for object:PFObject in objects as [PFObject] {
                    foundLabel = object["term"] as String;
                    NSLog("\(foundLabel) already exists as label, incrementing")
                    object.incrementKey("count");
                    object.saveInBackground();
                    arr.removeAtIndex(find(arr, foundLabel)!);
                }
                //comment below to force use of only our labels (so users cant add new labels?)
                var newLabel: PFObject;
                for label: String in arr {
                    NSLog("Adding new label \(label)")
                    newLabel = PFObject(className: "SearchTerm");
                    newLabel["term"] = label;
                    newLabel["count"] = 1;
                    newLabel.ACL.setPublicReadAccess(true);
                    newLabel.ACL.setPublicWriteAccess(true);
                    newLabel.saveInBackground();
                }
            }
        });
        
        
        return arr;
    }
    
    class func uploadImage(image: UIImage, labels: String) {
        if (isAnonLogged()) {
            return;
        } else {
            var newPost = ImagePostStructure(image: image, labels: labels);
            var sender = PFUser.currentUser().username;     //in case user logs out while object is still saving
            /*newPost.myObj.saveInBackgroundWithBlock({(succeeded: Bool, error: NSError!)->Void in
                NSLog("What");
                });*/
            
            var myLabels = newPost.myObj["labels"] as Array<String>;

            newPost.myObj.saveInBackgroundWithBlock({
                (succeeded: Bool, error: NSError!)->Void in
                if (succeeded && !error) {
                    var myUser: PFUser = PFUser.currentUser();
                    if (!(myUser["userIcon"])) {
                        //above may set to last submitted picture...? sometimes??
                        //might consider just resizing image to a smaller icon value and saving it again
                        PFUser.currentUser()["userIcon"] = newPost.myObj["imageFile"];
                        PFUser.currentUser().saveEventually();
                    }
                    var notifObj = PFObject(className:"Notification");
                    //type of notification - in this case, a Image Post (how many #likes i've gotten)
                    notifObj["type"] = NotificationType.IMAGE_POST.toRaw();
                    notifObj["ImagePost"] = newPost.myObj;
                    
                    ServerInteractor.processNotification(sender, targetObject: notifObj);
                    
                    //query + make a few matches with this post
                    
                    /*var pred: NSPredicate = NSPredicate(block: {
                        (evalObj: AnyObject!, bindings: [NSObject: AnyObject]!)->Bool in
                        var theirLabels = (evalObj as PFObject)["labels"] as Array<String>;
                        var count = 0;
                        for lab: String in myLabels {
                            if contains(theirLabels, lab) {
                                count += 1;
                                //must have 2 matches
                                if (count >= 2) {
                                    return true;
                                }
                            }
                        }
                        return false;
                        });*/
                    
                    var matchQueries: [PFQuery] = [];
                    var matchQuery: PFQuery;
                    if (myLabels.count == 0) {
                        matchQuery = PFQuery(className: "ImagePost");
                        matchQuery.whereKey("labels", equalTo: []);
                        matchQueries.append(matchQuery);
                    }
                    else if (myLabels.count < 2) {
                        for lab: String in myLabels {
                            matchQuery = PFQuery(className: "ImagePost");
                            //matchQuery.whereKey("labels", containsAllObjectsInArray: []);
                            //matchQuery.whereKey("labels", containedIn: );
                            matchQuery.whereKey("labels", containsAllObjectsInArray: [lab]);
                            matchQueries.append(matchQuery);
                        }
                    }
                    else {
                        for lab1: String in myLabels {
                            for lab2: String in myLabels {
                                if (lab1 != lab2) {
                                    matchQuery = PFQuery(className: "ImagePost");
                                    matchQuery.whereKey("labels", containsAllObjectsInArray: [lab1, lab2]);
                                    matchQueries.append(matchQuery);
                                }
                            }
                        }
                    }
                    var aMatchQuery = PFQuery.orQueryWithSubqueries(matchQueries);
                    
                    
                    aMatchQuery.whereKey("objectId", notEqualTo: newPost.myObj.objectId)
                    
                    aMatchQuery.findObjectsInBackgroundWithBlock({
                        (objects: [AnyObject]!, error: NSError!) -> Void in
                        
                        for (index, object: PFObject!) in enumerate(objects!) {
                            var pairObj = PFObject(className:"Pair");
                            //scramble order
                            if (random() % 2 == 0) {
                                pairObj["post1"] = newPost.myObj;
                                pairObj["post2"] = objects[index];
                            }
                            else {
                                pairObj["post2"] = newPost.myObj;
                                pairObj["post1"] = objects[index];
                            }
                            pairObj.saveInBackground();
                        }
                    });
                }
                else {
                    NSLog("Soem error of some sort");
                }
            });
        }
    }
    
    class func removePost(post: ImagePostStructure) {
        post.myObj.deleteInBackground();
    }
    
    //helper function to convert an array of ImagePostStructures into an array of its objectID's
    class func convertPostToID(input: Array<PairPostStructure?>)->NSMutableArray {
        var output = NSMutableArray();
        for post: PairPostStructure? in input {
            output.addObject(post!.myObj.objectId);
        }
        return output;
    }
    
    //return ImagePostStructure(image, likes)
    //counter = how many pages I've seen (used for pagination)
    //this method DOES fetch the images along with the data
    class func getPost(finishFunction: (imgStruct: PairPostStructure, index: Int)->Void, sender: HomeFeedController, excludes: Array<PairPostStructure?>) {
        //download - relational data is NOT fetched!
        var returnList = Array<PairPostStructure?>();
        //query
        var query = PFQuery(className:"Pair")
        //query.skip = skip * POST_LOAD_COUNT;
        query.limit = POST_LOAD_COUNT;
        query.orderByDescending("likes");
 
        var excludeList = convertPostToID(excludes);
        if (!isAnonLogged()) {
            excludeList.addObjectsFromArray((PFUser.currentUser()["viewHistory"] as NSArray))
        }
        query.whereKey("objectId", notContainedIn: excludeList);
        //query addAscending/DescendingOrder for extra ordering:
        query.findObjectsInBackgroundWithBlock {
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if !error {
                // The find succeeded.
                // Do something with the found objects
                sender.setPostArraySize(objects.count);
                for (index, object:PFObject!) in enumerate(objects!) {
                    var post = PairPostStructure(inputObj: object);
                    //self.readPost(post);
                    post.loadImage(finishFunction, index: index);
                }
            } else {
                // Log details of the failure
                NSLog("Error: %@ %@", error, error.userInfo)
            }
        }
        //return returnList;
    }
    class func resetViewedPosts() {
        PFUser.currentUser()["viewHistory"] = NSArray();
        PFUser.currentUser().saveEventually();
    }
    //returns a list of my submissions (once again restricted by POST_LOAD_COUNT
    //does NOT autoload the image with the file
    //return reference to PFFile as well - use to load files later on
    class func getSubmissions(skip: Int, loadCount: Int, user: FriendEncapsulator, notifyQueryFinish: (Int)->Void, finishFunction: (ImagePostStructure, Int)->Void)  {
        var query = PFQuery(className:"ImagePost")
        query.whereKey("author", equalTo: user.getName({}));
        query.limit = loadCount;
        query.skip = skip;
        query.orderByDescending("createdAt");
        query.findObjectsInBackgroundWithBlock {
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if !error {
                // The find succeeded.
                
                notifyQueryFinish(objects.count);
                
                // Do something with the found objects
                var post: ImagePostStructure?;
                for (index, object:PFObject!) in enumerate(objects!) {
                    post = ImagePostStructure(inputObj: object);
                    post!.loadImage(finishFunction, index: index);
                }
            } else {
                // Log details of the failure
                NSLog("Error: %@ %@", error, error.userInfo)
            }
        }
    }
    
    class func getSearchPosts(skip: Int, loadCount: Int, term: String, notifyQueryFinish: (Int)->Void, finishFunction: (ImagePostStructure, Int)->Void)  {
        var query = PFQuery(className:"ImagePost")
        query.whereKey("labels", containsAllObjectsInArray: [term]);
        query.limit = loadCount;
        query.skip = skip;
        query.orderByDescending("createdAt");
        query.findObjectsInBackgroundWithBlock {
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if !error {
                // The find succeeded.
                
                notifyQueryFinish(objects.count);
                
                // Do something with the found objects
                var post: ImagePostStructure?;
                for (index, object:PFObject!) in enumerate(objects!) {
                    post = ImagePostStructure(inputObj: object);
                    post!.loadImage(finishFunction, index: index);
                }
            } else {
                // Log details of the failure
                NSLog("Error: %@ %@", error, error.userInfo)
            }
        }
    }

    
    class func readPost(post: PairPostStructure) {
        var postID = post.myObj.objectId;
        PFUser.currentUser().addUniqueObject(postID, forKey: "viewHistory");
        PFUser.currentUser().saveEventually();
        
    }
    
    //------------------Notification related methods---------------------------------------
    class func processNotification(targetUserName: String, targetObject: PFObject)->Array<AnyObject?>? {
        return processNotification(targetUserName, targetObject: targetObject, controller: nil);
    }
    class func processNotification(targetUserName: String, targetObject: PFObject, controller: UIViewController?)->Array<AnyObject?>? {
        
        var query: PFQuery = PFUser.query();
        query.whereKey("username", equalTo: targetUserName)
        var currentUserName = PFUser.currentUser().username;
        query.findObjectsInBackgroundWithBlock({ (objects: [AnyObject]!, error: NSError!) -> Void in
            if (objects.count > 0) {
                //i want to request myself as a friend to my friend
                var targetUser = objects[0] as PFUser;
                targetObject.ACL.setReadAccess(true, forUser: targetUser)
                targetObject.ACL.setWriteAccess(true, forUser: targetUser)
                
                targetObject["sender"] = currentUserName;  //this is necessary for friends!
                targetObject["recipient"] = targetUserName;
                targetObject["viewed"] = false;
                
                targetObject.saveInBackground();
                
            }
        });
        return nil; //useless statement to suppress useless stupid xcode thing
    }
    
    class func getNotifications(controller: NotifViewController) {
        if (isAnonLogged()) {
            if (controller.notifList.count == 0) {
                controller.notifList.append(InAppNotification(message: "To see your notifications sign up and make an account!"));
            }
            return;
        }
        var query = PFQuery(className:"Notification")
        query.whereKey("recipient", equalTo: PFUser.currentUser().username);
        //want most recent first
        query.orderByDescending("createdAt");
        query.findObjectsInBackgroundWithBlock {
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if !error {
                // The find succeeded.
                // Do something with the found objects
                var object: PFObject;
                if (objects.count < controller.notifList.count) {
                    var stupidError = controller.notifList.count - objects.count
                    //var counter = objects.count - controller.notifList.count
                    //objects = controller.notifList[0...objects.count - counter]
                    //controller.notifList = controller.notifList[0...stupidError] as Array<InAppNotification?>
                    for index: Int in 0..<stupidError {
                        controller.notifList.removeLast()
                        //object = objects[0] as PFObject;
                    }
                    if (controller.notifList.count == 0) {
                        controller.tableView.reloadData();
                    }
                }
                for index:Int in 0..<objects.count {
                    object = objects![index] as PFObject;
                    if (index >= NOTIF_COUNT) {
                        if(object["viewed"]) {
                            object.deleteInBackground();
                            continue;
                        }
                    }
                    
                                        
                    if(index >= controller.notifList.count) {
                        var item = InAppNotification(dataObject: object);
                        //weird issue #7 error happening here, notifList is NOT dealloc'd (exists) WORK
                        controller.notifList.append(item);
                    }
                    else {
                        controller.notifList[index] = InAppNotification(dataObject: object, message: controller.notifList[index]!.messageString);
                    }
                    controller.notifList[index]!.assignMessage(controller);
                }
            } else {
                // Log details of the failure
                NSLog("Error: %@ %@", error, error.userInfo)
            }
        }
    }
    //used for default message notifications (i.e. "You have been banned for violating TOS" "Welcome to our app"
    //"Happy April Fool's Day!")
    class func postDefaultNotif(txt: String) {
        //posts a custom notification (like friend invite, etc)
        var notifObj = PFObject(className:"Notification");
        //type of notification - in this case, a default text one
        notifObj["type"] = NotificationType.PLAIN_TEXT.toRaw();
        notifObj["message"] = txt
        //notifObj.saveInBackground()
        
        ServerInteractor.processNotification(PFUser.currentUser().username, targetObject: notifObj);
    }
    //------------------Search methods---------------------------------------
    class func getSearchTerms(term: String, initFunc: (Int)->Void, receiveFunc: (Int, String)->Void, endFunc: ()->Void) {
        var query = PFQuery(className: "SearchTerm");
        query.whereKey("term", containsString: term);
        //query.orderByDescending("importance")
        query.findObjectsInBackgroundWithBlock({
            (objects: [AnyObject]!, error: NSError!)->Void in
            initFunc(objects.count);
            var content: String;
            for index: Int in 0..<objects.count {
                content = (objects[index] as PFObject)["term"] as String;
                receiveFunc(index, content);
            }
            endFunc();
        });
    }
}
