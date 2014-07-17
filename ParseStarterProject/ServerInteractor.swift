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
        
        user["friends"] = NSArray();
        user["viewHistory"] = NSArray();
        
        user.signUpInBackgroundWithBlock( {(succeeded: Bool, error: NSError!) in
            var signController: SignUpViewController = sender as SignUpViewController;
            if (!error) {
                //success!
                //sees if user has pending items to process
                ServerInteractor.initialUserChecks();
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
                ServerInteractor.initialUserChecks();
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
                ServerInteractor.initialUserChecks();
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
                user["friends"] = NSArray();
                user["viewHistory"] = NSArray();
                ServerInteractor.initialUserChecks();
                //user's first notification
                ServerInteractor.postDefaultNotif("Welcome to InsertAppName! Thank you for signing up for our app!");
                user.saveEventually();
                logController.successfulLogin();
                
            } else {
                //logController.failedLogin("User logged in through Facebook!")
                ServerInteractor.initialUserChecks();
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
    
    class func uploadImage(image: UIImage, exclusivity: PostExclusivity, labels: String) {
        if (isAnonLogged()) {
            return;
        } else {
            var newPost = ImagePostStructure(image: image, exclusivity: exclusivity, labels: labels);
            var sender = PFUser.currentUser().username;     //in case user logs out while object is still saving
            /*newPost.myObj.saveInBackgroundWithBlock({(succeeded: Bool, error: NSError!)->Void in
                NSLog("What");
                });*/
            
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
                    //ServerInteractor.saveNotification(PFUser.currentUser(), targetObject: notifObj)
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
    class func convertPostToID(input: Array<ImagePostStructure?>)->NSMutableArray {
        var output = NSMutableArray();
        for post: ImagePostStructure? in input {
            output.addObject(post!.myObj.objectId);
        }
        return output;
    }
    
    //return ImagePostStructure(image, likes)
    //counter = how many pages I've seen (used for pagination)
    //this method DOES fetch the images along with the data
    class func getPost(friendsOnly: Bool, finishFunction: (imgStruct: ImagePostStructure, index: Int)->Void, sender: HomeFeedController, excludes: Array<ImagePostStructure?>) {
        //download - relational data is NOT fetched!
        var returnList = Array<ImagePostStructure?>();
        //query
        var query = PFQuery(className:"ImagePost")
        //query.skip = skip * POST_LOAD_COUNT;
        query.limit = POST_LOAD_COUNT;
        query.orderByDescending("likes");
 
        
        var excludeList = convertPostToID(excludes);
        if (friendsOnly && !isAnonLogged()) {
            query.whereKey("author", containedIn: (PFUser.currentUser()["friends"] as NSArray));
            //query.whereKey("objectId", notContainedIn: excludeList);
            //both friends + everyone marked feed from your friends show up here, as long as your friend posted
            //query.whereKey("exclusive", equalTo: PostExclusivity.FRIENDS_ONLY.toRaw()); <--- leave this commented
            if (!isAnonLogged()) {
                excludeList.addObjectsFromArray((PFUser.currentUser()["viewHistory"] as NSArray))
            }
        }
        else {
            //must be an everyone-only post to show in popular feed
            query.whereKey("exclusive", equalTo: PostExclusivity.EVERYONE.toRaw());
            if (!isAnonLogged()) {
                excludeList.addObjectsFromArray((PFUser.currentUser()["viewHistory"] as NSArray))
            }
            //query.whereKey("objectId", notContainedIn: excludeList);
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
                    var post = ImagePostStructure(inputObj: object);
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

    
    class func readPost(post: ImagePostStructure) {
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
            else if (controller) {
                if(objects.count == 0) {
                    (controller! as FriendTableViewController).notifyFailure("No such user exists!");
                }
                else if (error) {
                    //controller.makeNotificationThatFriendYouWantedDoesntExistAndThatYouAreVeryLonely
                    (controller! as FriendTableViewController).notifyFailure(error.localizedDescription as String);
                }
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
    //you have just requested someone as a friend; this sends the friend you are requesting a notification for friendship
    class func postFriendRequest(friendName: String, controller: UIViewController) {
        if (friendName == "") {
            (controller as SettingsViewController).notifyFailure("Please fill in a name");
            return;
        }
        
        var notifObj = PFObject(className:"Notification");
        notifObj["type"] = NotificationType.FRIEND_REQUEST.toRaw();
        ServerInteractor.processNotification(friendName, targetObject: notifObj, controller: controller);
        
    }
    //you have just accepted your friend's invite; your friend now gets informed that you are now his friend <3
    //note: the func return type is to suppress some stupid thing that happens when u have objc stuff in your swift header
    class func postFriendAccept(friendName: String)->Array<AnyObject?>? {
        //first, query + find the user
        var notifObj = PFObject(className:"Notification");
        notifObj["type"] = NotificationType.FRIEND_ACCEPT.toRaw();
        //notifObj.saveInBackground();
        
        ServerInteractor.processNotification(friendName, targetObject: notifObj);
        return nil;
    }
    //call this method when either accepting a friend inv or receiving a confirmation notification
    class func addAsFriend(friendName: String)->Array<NSObject?>? {
        PFUser.currentUser().addUniqueObject(friendName, forKey: "friends");
        PFUser.currentUser().saveEventually();
        return nil;
    }
    //call this method when either removing a friend inv directly or when u receive 
    //a (hidden) removefriend notif
    //isHeartBroken: if false, must send (hidden) notif obj to user I am unfriending
    //isHeartBroken: if true, is the user who has just been broken up with. no need to notify friend
    //reason this is NOT a Notification PFObject: I should NOT notify the friend that I broke up with them
    //  (stealthy friend removal) => i.e. if I want to remove a creeper I got deceived into friending
    //RECEIVING END HAS BEEN IMPLEMENTED
    class func removeFriend(friendName: String, isHeartBroken: Bool)->Array<NSObject?>? {
        PFUser.currentUser().removeObject(friendName, forKey: "friends");
        PFUser.currentUser().saveInBackground();
        if (!isHeartBroken) {
            //do NOT use processNotification - we don't want to post a notification
            
            
            var query: PFQuery = PFUser.query();
            query.whereKey("username", equalTo: friendName)
            var currentUserName = PFUser.currentUser().username;
            query.findObjectsInBackgroundWithBlock({ (objects: [AnyObject]!, error: NSError!) -> Void in
                if (objects.count > 0) {
                    var targetUser = objects[0] as PFUser;
                    var breakupObj = PFObject(className:"BreakupNotice")
                    breakupObj["sender"] = PFUser.currentUser().username;
                    breakupObj["recipient"] = friendName;
                    
                    breakupObj.ACL.setReadAccess(true, forUser: targetUser)
                    breakupObj.ACL.setWriteAccess(true, forUser: targetUser)
                    
                    breakupObj.saveInBackground();
                    //send notification object
                }
            });
        }
        return nil;
    }
    
    //not currently used, but might be helpful later on/nice to have a default version
    class func getFriends()->Array<FriendEncapsulator?> {
        return getFriends(FriendEncapsulator(friend: PFUser.currentUser()));
    }
    
    //gets me a list of my friends!
    //used by friend table loader
    class func getFriends(user: FriendEncapsulator)->Array<FriendEncapsulator?> {
        var unwrapUser = user.friendObj;
        var returnList: Array<FriendEncapsulator?> = [];
        var friendz: NSArray;
        if (unwrapUser!.allKeys().bridgeToObjectiveC().containsObject("friends")) {
            //if this runs, the code will break catastrophically, just initialize "friends" with registration
            friendz = unwrapUser!["friends"] as NSArray;
        }
        else {
            NSLog("Updating an old account to have friends");
            friendz = Array<PFUser?>();
            unwrapUser!["friends"] = NSArray()
            unwrapUser!.saveInBackground();
        }
        var friend: String;
        for index in 0..<friendz.count {
            friend = friendz[index] as String;
            returnList.append(FriendEncapsulator(friendName: friend));
        }
        return returnList;
    }
    
    class func checkAcceptNotifs() {
        //possibly move friend accepts here?
        
        //add method to clear user's viewed post history (for sake of less clutter)
        //PFUser.currentUser()["viewHistory"] = NSArray();
        //PFUser.currentUser().saveInBackground();
        var queryForNotif = PFQuery(className: "Notification")
        queryForNotif.whereKey("recipient", equalTo: PFUser.currentUser().username);
        queryForNotif.orderByDescending("createdAt");
        queryForNotif.findObjectsInBackgroundWithBlock({
            (objects: [AnyObject]!, error: NSError!) -> Void in
            if !error {
                var object: PFObject;
                for index: Int in 0..<objects.count {
                    object = objects[index] as PFObject;
                    if(!(object["viewed"] as Bool)) {
                        if (object["type"]) {
                            if ((object["type"] as String) == NotificationType.FRIEND_ACCEPT.toRaw()) {
                                //accept the friend!
                                ServerInteractor.addAsFriend(object["sender"] as String);
                                //object["viewed"] = true;
                            }
                        }
                        object.saveInBackground()
                    }
                }
            }
        });
    }
    //checks that user should do whenever starting to use app on account
    class func initialUserChecks() {
        //check and see if user has any notice for removal of friends
        var query = PFQuery(className: "BreakupNotice");
        query.whereKey("recipient", equalTo: PFUser.currentUser().username);
        query.findObjectsInBackgroundWithBlock({ (objects: [AnyObject]!, error: NSError!) -> Void in 
            NSLog("No explanation");
            if (!error) {
                var object: PFObject;
                
                if (objects.count == 0 ){
                    ServerInteractor.checkAcceptNotifs();
                    return;
                }
                
                for index: Int in 0..<objects.count {
                    var last = (index == objects.count - 1);
                    object = objects[index] as PFObject;
                    ServerInteractor.removeFriend(object["sender"] as String, isHeartBroken: true);
                    
                    
                    var query = PFQuery(className: "Notification");
                    query.whereKey("sender", equalTo: object["sender"] as String);
                    query.whereKey("createdAt", lessThan: object.createdAt);
                    //query.lessThan("createdAt", object["createdAt"]);
                    query.findObjectsInBackgroundWithBlock({(objects: [AnyObject]!, error: NSError!) -> Void in
                        for index: Int in 0..<objects.count {
                            objects[index].deleteInBackgroundWithBlock({
                                (succeeded: Bool, error: NSError!)->Void in
                                    if (last) {
                                        object.deleteInBackground();
                                        ServerInteractor.checkAcceptNotifs();
                                    }
                                });
                            }
                    });
                }
            }
            else {
                NSLog("Error: Could not fetch");
            }
        });
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