//
//  IBCollectionItemView.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//  https://github.com/icyblazek/IBCollectionView

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

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
}

/**
 *  Click Test is used when the item view has it's own click event shape.
 *  Subclass and implement this method with custome shape.
 *
 *  @param p NSPoint relative to self
 *
 *  @return YES if did click on the item.
 */
- (BOOL)clickTest:(NSPoint)p;
{
    return YES;
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
