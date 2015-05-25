//
//  IBCollectionItemView.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "IBCollectionItemView.h"

@implementation IBCollectionItemView

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor blueColor] setFill];
    
    if (self.selected){
        //draw selected status code
        [[NSColor yellowColor] setFill];
    }
    
    NSRectFill(self.bounds);
}


-(void)setSelected:(BOOL)value
{
    if (_selected != value){
        _selected = value;
        [self setNeedsDisplay: YES];
    }
}

-(BOOL)accpetMouseEventWithEvent:(NSEvent*)theEvent
{
    return YES;
}

-(BOOL)accpetSelectWithRect:(NSRect)rect
{
    if (NSIntersectsRect(self.bounds, rect))
        return YES;
    return NO;
}

-(BOOL)accpetSelectWithPoint:(NSPoint)point
{
    if (NSPointInRect(point, self.bounds))
        return YES;
    return NO;
}

-(void)mouseEntered:(NSEvent *)theEvent
{
    //mouse enter here
}

-(void)mouseExited:(NSEvent *)theEvent
{
    //"mouse exit here"
}

-(void)mouseMoved:(NSEvent *)theEvent
{
    //@"mouse move here"
}

-(BOOL)trackMouseEvent:(NSEvent *)theEvent
{
    return NO;
}

@end
