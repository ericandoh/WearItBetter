//
//  PairPostStruct.swift
//  WearItBetter
//
//  Created by Eric Oh on 7/17/14.
//
//

import UIKit

class PairPostStructure: NSObject {
    var myObj: PFObject;
    var post1: ImagePostStructure?;
    var post2: ImagePostStructure?;
    var img1: UIImage?;
    var img2: UIImage?;
    init(inputObj: PFObject) {
        //called when retrieving object (for viewing, etc)
        myObj = inputObj;
    }
    func loadImage(finishFunction: (imgStruct: PairPostStructure, index: Int)->Void, index: Int) {
        
        
        myObj["post1"].fetchIfNeededInBackgroundWithBlock({
            (object1:PFObject!, error: NSError!)->Void in
            
            self.post1 = ImagePostStructure(inputObj: object1);
            
            self.post1!.loadImage({
                (imgStruct: ImagePostStructure, index: Int)->Void in
                
                
                self.myObj["post2"].fetchIfNeededInBackgroundWithBlock({
                    (object2:PFObject!, error: NSError!)->Void in
                    
                    self.post2 = ImagePostStructure(inputObj: object2);
                    
                    self.post2!.loadImage({
                        (imgStruct: ImagePostStructure, index: Int)->Void in
                        
                        self.img1 = self.post1!.image;
                        self.img2 = self.post2!.image;
                        
                        finishFunction(imgStruct: self, index: index);
                        
                        }, index: index);
                    });
                }, index: index);
        });
    }
    func vote(vote: Bool) {
        if (vote) {
            self.post1!.like();
        }
        else {
            self.post2!.like();
        }
    }
    func getPost1Like()->Int {
        return self.post1!.getLikes();
    }
    func getPost2Like()->Int {
        return self.post2!.getLikes();
    }
}
