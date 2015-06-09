//
//  IBCollectionItemView.h
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IBSectionIndexSet;

IB_DESIGNABLE
@interface IBCollectionItemView : NSView{
    
}
@property(retain) IBSectionIndexSet *indexSet;

-(BOOL)accpetMouseEventWithEvent:(NSEvent*)theEvent;
-(BOOL)accpetSelectWithRect:(NSRect)rect;
-(BOOL)accpetSelectWithPoint:(NSPoint)point;
-(BOOL)trackMouseEvent:(NSEvent *)theEvent;

@property (nonatomic, assign) BOOL selected;
@property (strong) IBInspectable NSString *reuseIdentifier;

- (BOOL)clickTest:(NSPoint)p;

@end
