//
//  IBCollectionSectionView.h
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IBCollectionSectionHeaderView : NSView{
    
}

@end

IB_DESIGNABLE
@interface IBCollectionSectionView : NSView{
    
}

-(void)trackHeaderViewWithVisibleRect:(NSRect)visibleRect;

@property (assign) BOOL hasHeader;
@property (assign) BOOL hasBottom;

@property (strong) IBOutlet NSView *headerView;
@property (strong) IBOutlet NSView *bottomView;
@property (strong) IBInspectable NSString *reuseIdentifier;

@end
