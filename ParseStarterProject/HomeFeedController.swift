//
//  HomeFeedController.swift
//  ParseStarterProject
//
//  Displays images on your home feed with voting options
//
//  Created by Eric Oh on 6/25/14.
//
//

import UIKit

class HomeFeedController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var commentView: UIView               //use this for hiding and showing
    @IBOutlet var commentTableView: UITableView     //use this for specific table manipulations
    @IBOutlet var voteCounter: UILabel;
    
    var swiperNoSwipe: Bool = false;
    @IBOutlet var frontImageView: UIImageView
    @IBOutlet var backImageView: UIImageView
    
    @IBOutlet var frontLabel: UIButton
    @IBOutlet var backLabel: UIButton
    //which image we are viewing currently in firstSet
    var viewCounter = 0;
    
    //first set has images to display, viewCounter tells me where in array I am currently viewing
    var firstSet: Array<PairPostStructure?> = Array<PairPostStructure?>();
    //second set should be loaded while viewing first set (load in background), switch to this when we run out in firstSet
    var secondSet: Array<PairPostStructure?> = Array<PairPostStructure?>();
    
    //tells me how much of my set is loaded
    var loadedSet: Array<Bool> = Array<Bool>();
    //tells me which set is loading (first or second) - this should be most of the time the 2nd set
    var loadedSetNum: Int = 1;
    //tells me how many posts I have loaded so far (so I know if I have loaded all my posts)
    var loadedCount: Int = 0;
    
    //an array of comments which will be populated when loading app
    var commentList: Array<PostComment> = [];
    
    //am i looking at results or images
    var showingImg: Bool = true;
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        //self.view.bringSubviewToFront(frontImageView);
        
        commentView.hidden = true; //this should be set in storyboard but just in case
        frontLabel.setTitle("", forState: UIControlState.Normal);
        backLabel.setTitle("", forState: UIControlState.Normal);
    }
    override func viewDidAppear(animated: Bool) {
        resetToStart();
    }
    func resetToStart() {
        frontImageView!.image = LOADING_IMG;
        backImageView!.image = LOADING_IMG;
        
        viewCounter = 0;    //we are at start of image sequence
        loadedSetNum = 1;   //load into first set
        getPostCall();
    }
    func getPostCall() {
        loadedCount = 0;
        var otherExcludes: Array<PairPostStructure?>?
        if (loadedSetNum == 1) {
            otherExcludes = Array<PairPostStructure?>();
        }
        else {
            //do not include posts which we already loaded into our first set
            otherExcludes = firstSet;
        }
        ServerInteractor.getPost(getReturnList, sender: self, excludes: otherExcludes!);
    }
    func setPostArraySize(size: Int) {
        //called by server to set size of array of images we are fetching, before retrieving
        if (size == 0) {
            //we fetched an array of size 0...
            if (loadedSetNum == 1) {
                //this is our first set, and we have no images to display
                frontImageView!.image = ENDING_IMG;
                backImageView!.image = ENDING_IMG;
            }
        }
        if (loadedSetNum == 1) {
            firstSet = Array<PairPostStructure?>(count: size, repeatedValue: nil);
        }
        else {
            secondSet = Array<PairPostStructure?>(count: size, repeatedValue: nil);
        }
        loadedSet = Array<Bool>(count: size, repeatedValue: false); //none of values loaded yet
    }
    
    func getReturnList(imgStruct: PairPostStructure, index: Int){
        if (loadedSetNum == 1) {
            firstSet[index] = imgStruct;
            loadedSet[index] = true;
            if (index == viewCounter) {
                //my first image needs to be loaded ASAP, it is first image that needs to be shown
                frontImageView!.image = firstSet[viewCounter]!.img1;   //this changes it from the loading scene
                backImageView!.image = firstSet[viewCounter]!.img2;   //this changes it from the loading scene
            }
            loadedCount++;
            if (loadedCount == firstSet.count) {
                //finished loading all of first set, and there is more to load...?
                loadedSetNum = 2;
                getPostCall();
            }
        }
        else {
            secondSet[index] = imgStruct;
            loadedSet[index] = true;
            loadedCount++;
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func swipeLeft(sender: UISwipeGestureRecognizer) {
        /*
        var location: CGPoint = sender.locationInView(self.view);
        location.x -= 220;
        
        animateImageMotion(location, vote: false);*/
    }
    @IBAction func swipeRight(sender: UISwipeGestureRecognizer) {
        
        /*var location: CGPoint = sender.locationInView(self.view);
        location.x += 220;
        
        animateImageMotion(location, vote: true);*/
    }
    //insert methods here for clickign left or right
    func clickImg(choice: Bool) {
        NSLog("Clicked on image")
        if (loadedSetNum == 1 && (firstSet.count == 0 || frontImageView!.image == ENDING_IMG)) {
            resetToStart();
            return;
        }
        if (loadedSetNum == 1 && (!loadedSet[viewCounter])) {
            return;
        }
        if (frontImageView!.image == LOADING_IMG) {
            return;
        }
        
        firstSet[viewCounter]!.vote(choice);
        
        frontLabel.setTitle("+\(firstSet[viewCounter]!.getPost1Like())", forState: UIControlState.Normal);
        backLabel.setTitle("+\(firstSet[viewCounter]!.getPost2Like())", forState: UIControlState.Normal);
        
        NSLog( "+\(firstSet[viewCounter]!.getPost1Like())");
        NSLog( "+\(firstSet[viewCounter]!.getPost2Like())");
        showingImg = false;
        
        //set stuff to show stats
        
        frontImageView.hidden = true;
        backImageView.hidden = true;
    }
    @IBAction func frontConfirm(sender: AnyObject) {
        if (showingImg) {
            clickImg(true);
        }
        else {
            clickReload();
        }
    }
    @IBAction func backConfirm(sender: AnyObject) {
        if (showingImg) {
            clickImg(false);
        }
        else {
            clickReload();
        }
    }
    
    func clickReload() {
        NSLog("Reloading")
        viewCounter++;

        if (viewCounter == self.firstSet.count) {
            //loadedSetNum == 2
            viewCounter = 0;
            if (secondSet.count == 0) {
                resetToStart();
            }
            else if (secondSet.count != loadedCount) {
                loadedSetNum = 1;
                firstSet = secondSet;
                secondSet = [];
                frontImageView!.image = LOADING_IMG;   //this changes it from the loading scene
                backImageView!.image = LOADING_IMG;
            }
            else {
                firstSet = secondSet;
                getPostCall();
                frontImageView!.image = firstSet[viewCounter]!.img1;   //this changes it from the loading scene
                backImageView!.image = firstSet[viewCounter]!.img2;
            }
        }
        else {
            frontImageView!.image = firstSet[viewCounter]!.img1;   //this changes it from the loading scene
            backImageView!.image = firstSet[viewCounter]!.img2;
        }

        //...
        frontLabel.setTitle("", forState: UIControlState.Normal);
        backLabel.setTitle("", forState: UIControlState.Normal);
        frontImageView.hidden = false;
        backImageView.hidden = false;
        showingImg = true;
    }

    func performBufferLog() {
        NSLog("----------Logging---------")
        NSLog("VC: \(self.viewCounter) LoadedSetCount: \(self.loadedSet.count)");
        NSLog("FirstSetCount: \(self.firstSet.count) SecondSetCount: \(self.secondSet.count)")
        NSLog("LoadedSetNum: \(self.loadedSetNum)")
        NSLog("First img = loading? \(self.frontImageView!.image == LOADING_IMG)")
        NSLog("Second img = loading? \(self.backImageView!.image == LOADING_IMG)")
        NSLog("----------End Log---------")
    }
    func animateImageMotion(towardPoint: CGPoint, vote: Bool) {
        /*
        if (swiperNoSwipe) {
            //in middle of swiping - do nothing
            //later replace this with faster animation
            return;
        }
        if (frontImageView!.image == LOADING_IMG) {
            //front is loading still!
            return;
        }
        swiperNoSwipe = true;
        if let frontView = frontImageView {
            UIView.animateWithDuration(0.5, animations: {
                frontView.alpha = 0.0;
                frontView.center = towardPoint;
                }
                , completion: { completed in
                    //register vote to backend (BACKEND)
                    //set frontView's image to backView's image
                    if let backView = self.backImageView {
                        
                        var needRefresh = (frontView.image == ENDING_IMG);
                        frontView.image = backView.image;
                        //reset frontView back to front
                        frontView.frame = CGRect(origin: backView.frame.origin, size: backView.frame.size);
                        frontView.alpha = 1.0;
                        
                        if (!(needRefresh)) {
                            if (vote) {
                                //these are causing the object not found for update error
                                if (self.viewCounter >= self.firstSet.count) {
                                    NSLog("Houston we have a problem");
                                    self.performBufferLog();
                                }
                                self.firstSet[self.viewCounter]!.like();
                                self.voteCounter.textColor = UIColor.greenColor();
                            }
                            else {
                                self.firstSet[self.viewCounter]!.pass();
                                self.voteCounter.textColor = UIColor.redColor();
                            }
                            //mark post as read
                            ServerInteractor.readPost(self.firstSet[self.viewCounter]!);
                            
                            self.voteCounter!.text = "Last Post: +\(self.firstSet[self.viewCounter]!.getLikes())"
                            
                            self.viewCounter += 1
                            
                            if (self.viewCounter == self.firstSet.count) {
                                //we have reached end of our array
                                self.viewCounter = 0;
                            }
                            
                            if (self.loadedSetNum == 1) {
                                if (self.viewCounter == self.firstSet.count - 1) {
                                    //need to load 2nd set images, but first set isn't done loading!!!
                                    //this is impossible, since we just showed all of first set though!
                                    
                                    //actually, this might happen for an image queue size of 1
                                    NSLog("Potential Error: loadedSetNum did not update although list is completely loaded");
                                }
                                else if (self.loadedSet[self.viewCounter+1]) {
                                    self.backImageView!.image = (self.firstSet[self.viewCounter+1])!.image;
                                }
                                else {
                                    self.backImageView!.image = LOADING_IMG;
                                }
                            }
                            else {
                                if (self.viewCounter == self.firstSet.count - 1) {
                                    if (self.secondSet.count == 0) {
                                        self.backImageView!.image = ENDING_IMG;
                                        
                                        //this was there before 7/14
                                        if (self.frontImageView!.image == ENDING_IMG) {
                                            self.resetToStart();
                                        }
                                    }
                                    else if (self.loadedCount == self.secondSet.count) {
                                        //no need to check loading, they should all be loaded
                                        self.backImageView!.image = (self.secondSet[0])!.image;
                                    }
                                    else {
                                        if (self.secondSet.count > 0 && self.loadedSet[0]) {
                                            self.backImageView!.image = (self.secondSet[0])!.image;
                                        }
                                        else {
                                            self.backImageView!.image = LOADING_IMG;
                                        }
                                    }
                                }
                                else if (self.viewCounter == 0) {
                                    //only way for this to happen + !atEnd is if we just cycled through and just swiped past the last frame
                                    if (self.secondSet.count == 0) {
                                        //my 2nd set has nothing in it...
                                        self.firstSet = self.secondSet;
                                        self.backImageView!.image = LOADING_IMG;    //from ending
                                        //self.atEnd = true;
                                    }
                                    else if (self.loadedCount == self.secondSet.count) {
                                        //my 2nd set is all loaded and I can copy the 2nd set => 1st set and start loading right away
                                        self.firstSet = self.secondSet;
                                        //start loading another set of images
                                        if (self.firstSet.count > 1) {
                                            self.backImageView!.image = (self.firstSet[1])!.image;
                                            self.getPostCall();
                                        }
                                        else {
                                            //my set only has 1 thing in it
                                            NSLog("Setting as end");
                                            self.backImageView!.image = ENDING_IMG;
                                        }
                                    }
                                    else {
                                        //my 2nd set is still loading, I need to copy the 2nd set over to the 1st and keep on loading
                                        self.firstSet = self.secondSet;
                                        self.loadedSetNum = 1;
                                        if (self.firstSet.count > 1 && self.loadedSet[1]) {
                                            self.backImageView!.image = (self.firstSet[1])!.image;
                                        }
                                        else {
                                            self.backImageView!.image = LOADING_IMG;
                                        }
                                    }
                                }
                                else {
                                    self.backImageView!.image = (self.firstSet[self.viewCounter+1])!.image;
                                }
                            }
                        }
                        else {
                            //tell server to reset
                            self.backImageView!.image = LOADING_IMG;
                            ServerInteractor.resetViewedPosts();
                            self.resetToStart();
                        }
                        if (self.frontImageView!.image == ENDING_IMG) {
                            self.backImageView!.image = LOADING_IMG;
                        }
                        
                    }
                    self.swiperNoSwipe = false;
                });
        }*/
    }
    @IBAction func viewComments(sender: UIButton) {
        //initialize tableview with right arguments
        /*
        //load latest 20 comments, load more if requested in cellForRowAtIndexPath
        if (self.firstSet.count == 0 || (!self.firstSet[self.viewCounter])) {
            //there is no image for this post - no posts on feed
            //no post = no comments
            //this might happen due to network problems
            return;
        }
        //hide the table view that already exists and re-show it once it is loaded with correct comments
        commentView.hidden = false;
        self.view.bringSubviewToFront(commentView);
        
        NSLog("Comments for \(self.viewCounter)")
        self.commentList = Array<PostComment>();
        
        var currentPost: ImagePostStructure = self.firstSet[self.viewCounter]!
        
        currentPost.fetchComments({(input: NSArray)->Void in
            for index in 0..<input.count {
                self.commentList.append(PostComment(content: (input[index] as String)));
            }
            self.commentTableView.reloadData();
        });*/
    }
    @IBAction func exitComments(sender: UIButton) {
        /*commentView.hidden = true;
        //animate this?
        */
    }

    //--------------------TableView delegate methods-------------------------
    func tableView(tableView: UITableView?, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete method implementation.
        // Return the number of rows in the section.
        // last cell is always editable
        return commentList.count + 1;
    }
    
    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let cell: UITableViewCell = tableView!.dequeueReusableCellWithIdentifier("CommentCell", forIndexPath: indexPath) as UITableViewCell
        
        var index: Int = indexPath.row;
        
        cell.textLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = UIFont(name: "Helvetica Neue", size: 17);
        
        if (index == 0) {
            cell.textLabel.text = "Add Comment";
        }
        else {
            cell.textLabel.text = commentList[index - 1].commentString;
        }
        cell.selectionStyle = UITableViewCellSelectionStyle.None;
        return cell;
    }
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var index: Int = indexPath.row;
        if (index == 0) {
            let alert: UIAlertController = UIAlertController(title: "Write Comment", message: "Your Comment", preferredStyle: UIAlertControllerStyle.Alert);
                alert.addTextFieldWithConfigurationHandler(nil);
            //set alert text field size bigger - this doesn't work, we need a UITextView
            alert.addAction(UIAlertAction(title: "Comment!", style: UIAlertActionStyle.Default, handler: {(action: UIAlertAction!) -> Void in
                
                var currentPost: PairPostStructure = self.firstSet[self.viewCounter]!;
                /*
                //textFields[0].text
                currentPost.addComment((alert.textFields[0] as UITextField).text);
                
                self.commentList = Array<PostComment>();
                currentPost.fetchComments({(input: NSArray)->Void in
                    for index in 0..<input.count {
                        self.commentList.append(PostComment(content: (input[index] as String)));
                    }
                    self.commentTableView.reloadData();
                });*/
            }));
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: {(action: UIAlertAction!) -> Void in
                //canceled
            }));
            self.presentViewController(alert, animated: true, completion: nil)
        }
        else {
            //clicked on other comment - if implement comment upvoting, do it here
        }
    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath)->CGFloat {
        var cellText: NSString?;
        if (indexPath.row == 0) {
            cellText = "Add Comment";
        }
        else {
            cellText = commentList[indexPath.row - 1].commentString;
        }
        
        var cell: CGRect = tableView.frame;
        
        var textCell = UILabel();
        textCell.text = cellText;
        textCell.numberOfLines = 10;
        var maxSize: CGSize = CGSizeMake(cell.width, 9999);
        var expectedSize: CGSize = textCell.sizeThatFits(maxSize);
        return expectedSize.height + 20;
    }
}
