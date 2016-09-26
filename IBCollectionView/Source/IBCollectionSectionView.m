//
//  IBCollectionSectionView.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "IBCollectionSectionView.h"

@implementation IBCollectionSectionHeaderView

-(void)drawRect:(NSRect)dirtyRect
{
    [[NSColor controlDarkShadowColor] setFill];
    NSRectFill(self.bounds);
}

@end

@implementation IBCollectionSectionView

-(id)init
{
    if (self = [super init]){
        self.hasHeader = YES;
        self.hasBottom = NO;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [[NSColor redColor] setFill];
    NSRectFill(self.bounds);
    
    NSBezierPath *tmpPath = [NSBezierPath bezierPathWithRect: self.bounds];
    [[NSColor blackColor] setStroke];
    [tmpPath stroke];
}

-(NSArray*)subviews
{
    NSArray *subViews = [super subviews];
    NSMutableArray *tmpViews = [NSMutableArray arrayWithArray: subViews];
    if (self.headerView)
        [tmpViews removeObject: self.headerView];
    if (self.bottomView)
        [tmpViews removeObject: self.bottomView];
    return subViews;
}

-(BOOL)isFlipped
{
    return YES;
}

-(void)viewDidMoveToSuperview
{
    [super viewDidMoveToSuperview];
    if (self.hasHeader && !self.headerView)
        self.headerView = [[IBCollectionSectionHeaderView alloc] initWithFrame: NSMakeRect(0, 0, 0, 0)];
    
    if (self.headerView && self.headerView.superview != self)
        [super addSubview: self.headerView];
    
    if (self.bottomView && self.bottomView.superview != self)
        [super addSubview: self.bottomView];
}

-(void)trackHeaderViewWithVisibleRect:(NSRect)visibleRect
{
    if (self.headerView){
        NSRect headerViewRect = self.headerView.frame;
        NSRect tmpRect = visibleRect;
        tmpRect.size = headerViewRect.size;
        if (visibleRect.origin.y <= self.frame.origin.y)
            tmpRect.origin.y = 0;
        else{
            CGFloat maxHeaderY = self.frame.size.height - self.headerView.frame.size.height;
            if (self.hasBottom && self.bottomView)
                maxHeaderY -= self.bottomView.frame.size.height;
            tmpRect.origin.y = visibleRect.origin.y - self.frame.origin.y;
            if (tmpRect.origin.y > maxHeaderY)
                tmpRect.origin.y = maxHeaderY;
        }
        [self.headerView setFrameOrigin: tmpRect.origin];
    }
}

-(void)removeFromSuperview
{
    [[self subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [super removeFromSuperview];
}

@end
