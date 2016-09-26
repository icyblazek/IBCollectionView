//
//  ViewSwitchDemoWindowController.h
//  IBCollectionView
//
//  Created by Kevin Lu on 2/9/15.
//  Copyright (c) 2015 Icyblaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IBCollectionView.h"

@interface ViewSwitchDemoWindowController : NSWindowController{
    IBCollectionView *_collectionView;
}

-(IBAction)btnSwitchClick:(id)sender;

@end
