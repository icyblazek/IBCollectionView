//
//  IBCollectionView.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//  https://github.com/icyblazek/IBCollectionView

#import "IBCollectionView.h"
#import <Carbon/Carbon.h>

typedef NS_ENUM(NSInteger, IBCollectionContentViewState) {
    IBCollectionContentViewStateNone            = 0,
    IBCollectionContentViewStateSelecting       = 1,
    IBCollectionContentViewStateDragging        = 2,
};

@interface IBCollectionContentView : NSView{
    
}

@end

@implementation IBCollectionContentView

-(id)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame: frameRect]){
        [self setPostsBoundsChangedNotifications: YES];
    }
    return self;
}


-(BOOL)acceptsFirstResponder
{
    return YES;
}

-(BOOL)isFlipped
{
    return YES;
}

@end

#pragma mark =========

@interface IBCollectionSelectionRegionView : NSView {
    NSRect frameRect;
}

@property (strong) NSColor *strokeColor;
@property (strong) NSColor *fillColor;

-(void)drawFrameWithRect:(NSRect)rectValue;

@end

@implementation IBCollectionSelectionRegionView

-(void)drawFrameWithRect:(NSRect)rectValue
{
    frameRect = rectValue;
    [self setNeedsDisplayInRect: self.bounds];
}

-(BOOL)isFlipped
{
    return YES;
}

-(void)drawRect:(NSRect)dirtyRect
{
    CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
    
    CGContextSaveGState(context);
    CGContextSetShouldAntialias(context, NO);
    CGContextAddRect(context, frameRect);
    if (self.strokeColor)
        CGContextSetStrokeColorWithColor(context, self.strokeColor.CGColor);
    else
        CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.4);
    CGContextStrokePath(context);
    
    if (self.fillColor)
        CGContextSetFillColorWithColor(context, self.fillColor.CGColor);
    else
        CGContextSetRGBFillColor(context, 0, 0, 0, 0.13);
    CGContextFillRect(context, frameRect);
    CGContextRestoreGState(context);
}

@end


@interface IBCollectionView (){
    IBCollectionContentView *collectionContentView;
    NSTrackingArea *collectionContentViewTrackingArea;
    
    NSMutableDictionary *reusableViews;
    NSMutableDictionary *visibleItemViews;
    NSMutableDictionary *visibleSectionViews;
    NSMutableDictionary *sectionViewCacheFrames;
    
    BOOL isSectionViewMode;
    
    IBSectionIndexSet *lastMovedItemIndexSet;
    IBSectionIndexSet *lastKeyNavItemIndexSet;//We use this var to track shift + arrow keys's last selection
    NSPoint firstMouseDownPoint;
    IBCollectionSelectionRegionView *_selectionRegionView;
    NSRect selectingRegionRect;
    IBCollectionContentViewState stateMode;
    IBCollectionItemView *draggingItemView;
    NSDraggingSession *draggingSession;
    
    NSInteger _sectionCount;
    NSMutableDictionary *itemCountInSection;
    
    NSWindow *dragginWindow;
}

@end

@implementation IBCollectionView


-(id)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame: frameRect]){

        [self setDrawsBackground: NO];
        //[self setBackgroundColor: [NSColor colorWithDeviceWhite:0.988 alpha:1]];

        [self setAutohidesScrollers: YES];
        [self setHasVerticalScroller: YES];
        [self setBorderType: NSNoBorder];
        //[self setWantsLayer:YES];
        
        self.focusRingType = NSFocusRingTypeNone;

        stateMode = IBCollectionContentViewStateNone;
        
        collectionContentView = [[IBCollectionContentView alloc] initWithFrame: self.bounds];
        [self setDocumentView: collectionContentView];

        selecteds = [[NSMutableArray alloc] init];
        reusableViews = [[NSMutableDictionary alloc] init];
        classMap = [[NSMutableDictionary alloc] init];
        sectionViewCacheFrames = [[NSMutableDictionary alloc] init];
        
        visibleSectionViews = [[NSMutableDictionary alloc] init];
        visibleItemViews = [[NSMutableDictionary alloc] init];
        
        self.selectionMode = IBCollectionViewSelectionMulitple;
        self.distinctSingleDoubleClick = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(onSynchronizedViewContentBoundsDidChange:)
                                                     name: NSViewBoundsDidChangeNotification
                                                   object: nil];

//        [[NSNotificationCenter defaultCenter] addObserver: self
//                                                 selector: @selector(didEndLiveScrollNotification:)
//                                                     name: NSScrollViewDidEndLiveScrollNotification
//                                                   object: nil];

        collectionContentViewTrackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
                                                    options: NSTrackingActiveInActiveApp | NSTrackingInVisibleRect | NSTrackingMouseMoved
                                                      owner: self
                                                   userInfo: nil];

        [collectionContentView addTrackingArea: collectionContentViewTrackingArea];
    }
    return self;
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
}

-(void)registerNib:(NSBundle *)nib forViewReuseIdentifier:(NSString *)identifier
{
    
}

-(void)registerClass:(Class)viewClass forViewReuseIdentifier:(NSString *)identifier
{
    if (viewClass == [IBCollectionSectionView class] || viewClass == [IBCollectionItemView class]){
        [classMap setObject: viewClass forKey: identifier];
        return;
    }
    if ([viewClass isSubclassOfClass: [IBCollectionSectionView class]] || [viewClass isSubclassOfClass: [IBCollectionItemView class]])
        [classMap setObject: viewClass forKey: identifier];
    else
        NSAssert(NO, @"registered class must be a subclass of IBCollectionItemView or IBCollectionSectionView");
}

-(id)dequeueReusableViewWithIdentifier:(NSString *)identifier
{
    if (!identifier)
        return nil;
    Class viewClass = [classMap objectForKey: identifier];
    if (!viewClass){
        NSLog(@"identifier(%@) have not yet registered", identifier);
        return nil;
    }
    NSMutableArray *cacheViews = [reusableViews objectForKey: identifier];
    
    if (!cacheViews){
        cacheViews = [[NSMutableArray alloc] init];
        [reusableViews setValue: cacheViews forKey: identifier];
    }
    
    id result = nil;
    if (cacheViews.count > 0){
        result = [cacheViews objectAtIndex: 0];
        [cacheViews removeObjectAtIndex: 0];
    }
    
    return result;
}

- (NSInteger)sectionCount
{
    if (_sectionCount<0) {
         _sectionCount = 0;
    }
    return _sectionCount;
}

- (NSInteger)itemCountInSectionIndex:(NSInteger)sectionIndex
{
    NSInteger itemCount = 0;
    if (itemCountInSection[@(sectionIndex)]) {
        return [itemCountInSection[@(sectionIndex)] integerValue];
    }
    return itemCount;
}


-(void)reloadData
{
    _sectionCount = -1;
    itemCountInSection = [[NSMutableDictionary alloc] init];
    
    [[collectionContentView subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [self _removeAllSelectedIndexes];
    [visibleSectionViews removeAllObjects];
    [visibleItemViews removeAllObjects];
    [reusableViews removeAllObjects];
    [sectionViewCacheFrames removeAllObjects];
    
    //we cache all the number data here. so we do not need to call datasource frequently.
    if (_dataSource) {
        if ([_dataSource respondsToSelector: @selector(collectionViewSectionCount:)]){
            _sectionCount = [_dataSource collectionViewSectionCount: self];
        }
        if (_sectionCount < 0) {
            _sectionCount = 0;
        }
        if ([_dataSource respondsToSelector: @selector(collectionViewItemCount:SectionIndex:)]){
            if (_sectionCount>0) {
                for(NSUInteger i = 0; i< _sectionCount; i++){
                    itemCountInSection[@(i)] = @([_dataSource collectionViewItemCount:self SectionIndex:i]);
                }
            }else{
                itemCountInSection[@(0)] = @([_dataSource collectionViewItemCount:self SectionIndex:0]);
            }
        }
    }
    
    isSectionViewMode = [self sectionCount]>0;
    
    NSSize contentSize = [self documentContentSize];
    if (contentSize.height > self.bounds.size.height){
        CGFloat tmpY = self.bounds.size.height - contentSize.height;
        [collectionContentView setFrame: NSMakeRect(0, tmpY, contentSize.width, contentSize.height)];
    }else
        [collectionContentView setFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [self scrollToTop];
    [self updateDisplayWithRect: self.documentVisibleRect];
    
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

/**
 *  updateLayout is used when there is any view related changes.
 *  e.g. any IBSectionViewLayoutManager change should call this method.
 *  reloadData will lose selection, but updateLayout will not.
 */
-(void)updateLayout;
{
    [[collectionContentView subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [sectionViewCacheFrames removeAllObjects];
    
    NSSize contentSize = [self documentContentSize];
    if (contentSize.height > self.bounds.size.height){
        CGFloat tmpY = self.bounds.size.height - contentSize.height;
        [collectionContentView setFrame: NSMakeRect(0, tmpY, contentSize.width, contentSize.height)];
    }else
        [collectionContentView setFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    
    [self updateDisplayWithRect: self.documentVisibleRect];//[collectionContentView addSubview: sectionView];
}

-(void)setFrame:(NSRect)frameRect
{
    NSPoint offsetPoint = [self scrollOffsetPoint];
    [super setFrame:frameRect];
    [self updateLayout];
    [self scrollToOffsetPoint:offsetPoint];
}

- (NSPoint)scrollOffsetPoint;
{
    NSRect visibleRect = [[self contentView] documentVisibleRect];
    return visibleRect.origin;
}

- (void)scrollToOffsetPoint:(NSPoint)p
{
    [collectionContentView scrollPoint:p];
}

-(void)scrollToTop
{
    [collectionContentView scrollPoint: NSMakePoint(0, 0)];
}

- (void)scrollToIndexSet:(IBSectionIndexSet*)indexSet
{
    if (!indexSet)
        return;

    NSRect visibleRect = [[self contentView] documentVisibleRect];
    //NSRect visibleRect = [self visibleRect]; do not use [self visibleRect]
    if (isSectionViewMode){
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:0];
        visibleRect.origin.y += layoutManager.sectionHeaderViewHeight;
        visibleRect.size.height -= layoutManager.sectionHeaderViewHeight;
    }
    
    NSPoint visiblePoint = visibleRect.origin;
    
    NSRect itemRect = [self itemRectWithIndexSet:indexSet];
    NSRect isRect = NSIntersectionRect(itemRect, visibleRect);

    if (!NSEqualRects(isRect, itemRect)) {
        if (itemRect.origin.y < visiblePoint.y){
            if (isSectionViewMode){
                IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:0];
                [collectionContentView scrollPoint: NSMakePoint(0, itemRect.origin.y - layoutManager.sectionHeaderViewHeight)];
            }else{
                [collectionContentView scrollPoint: NSMakePoint(0, itemRect.origin.y)];
            }
        }else if (NSMaxY(itemRect) > NSMaxY(visibleRect)){
            if (isSectionViewMode){
                IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:0];
                [collectionContentView scrollPoint: NSMakePoint(0, NSMaxY(itemRect) - visibleRect.size.height - layoutManager.sectionHeaderViewHeight)];
            }else{
                [collectionContentView scrollPoint: NSMakePoint(0, NSMaxY(itemRect) - visibleRect.size.height)];
            }
        }
        //[collectionContentView scrollPoint:itemRect.origin];
    }
}

- (NSMutableArray*)selectedItemIndexSets
{
    return selecteds;
}

#pragma mark - firstResponder actions

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if (_delegate && [_delegate respondsToSelector: @selector(validateMenuItem:)]){
        return [[_delegate performSelector:@selector(validateMenuItem:) withObject:menuItem] boolValue];
    }
    return NO;
}

- (void)delete:(id)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(delete:)])
        [_delegate performSelector:@selector(delete:) withObject:sender];
}

- (void)importAction:(id)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(importAction:)])
        [_delegate performSelector:@selector(importAction:) withObject:self];
}

- (void)exportAction:(id)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(exportAction:)])
        [_delegate performSelector:@selector(exportAction:) withObject:self];
}


- (void)_removeAllSelectedIndexes
{
    lastKeyNavItemIndexSet = nil;
    [selecteds removeAllObjects];
}

- (void)_addSelectedIndex:(IBSectionIndexSet*)idx
{
    lastKeyNavItemIndexSet = idx;
    if (![selecteds containsObject:idx]) {
        [selecteds addObject:idx];
    }
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (IBSectionIndexSet *idx in selecteds) {
        NSAssert(d[@(idx.hash)] == nil, @"duplicate index !?");
        [d setObject:idx forKey:@(idx.hash)];
    }
}

- (void)_addSelectedIndexes:(NSArray*)idxes
{
    for (IBSectionIndexSet *idx in idxes) {
        if (![selecteds containsObject:idx]) {
            [selecteds addObject:idx];
        }
    }

    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (IBSectionIndexSet *idx in selecteds) {
        NSAssert(d[@(idx.hash)] == nil, @"duplicate index !?");
        [d setObject:idx forKey:@(idx.hash)];
    }
}


- (void)selectAll:(id)sender
{
    NSMutableArray *indexes = [NSMutableArray array];
    NSInteger sectionCount = [self sectionCount];
    if (sectionCount > 0){
        for (NSInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++){
            NSInteger itemCount = [self itemCountInSectionIndex:sectionIndex];
            for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++)
                [indexes addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: itemIndex]];
        }
    }else {
        NSInteger itemCount = [self itemCountInSectionIndex:0];
        for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++)
            [indexes addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: itemIndex]];
    }
    
    [self _removeAllSelectedIndexes];
    [self _addSelectedIndexes:indexes];

    [self updateDisplayWithRect: collectionContentView.visibleRect];

    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

-(void)selectItemWithIndexSet:(IBSectionIndexSet*)indexSet
{
    NSMutableArray *indexes = [NSMutableArray array];
    NSInteger sectionCount = [self sectionCount];
    if (sectionCount > 0){
        if (indexSet.sectionIndex>=0 && indexSet.sectionIndex<sectionCount) {
            NSInteger itemCount = [self itemCountInSectionIndex:indexSet.sectionIndex];
            if (indexSet.itemIndex>=0 && indexSet.itemIndex<itemCount) {
                [indexes addObject:indexSet];
            }
        }
    }else {
        NSInteger itemCount = [self itemCountInSectionIndex:0];
        if (indexSet.itemIndex>=0 && indexSet.itemIndex<itemCount) {
            [indexes addObject:indexSet];
        }
    }
    [self _removeAllSelectedIndexes];
    [self _addSelectedIndexes:indexes];

    [self updateDisplayWithRect: collectionContentView.visibleRect];
    
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

-(void)selectItemWithIndexSets:(NSArray*)indexSets
{
    NSMutableArray *indexes = [NSMutableArray array];
    NSInteger sectionCount = [self sectionCount];
    if (sectionCount > 0){
        for (IBSectionIndexSet *idx in indexSets) {
            if (idx.sectionIndex>=0 && idx.sectionIndex<sectionCount) {
                NSInteger itemCount = [self itemCountInSectionIndex:idx.sectionIndex];
                if (idx.itemIndex>=0 && idx.itemIndex<itemCount) {
                    [indexes addObject:idx];
                }
            }
        }
    }else {
        for (IBSectionIndexSet *idx in indexSets) {
            if (idx.sectionIndex == 0) {
                NSInteger itemCount = [self itemCountInSectionIndex:0];
                if (idx.itemIndex>=0 && idx.itemIndex<itemCount) {
                    [indexes addObject:idx];
                }
            }
        }
    }
    
    [self _removeAllSelectedIndexes];
    [self _addSelectedIndexes: indexes];
    
    [self updateDisplayWithRect: collectionContentView.visibleRect];
    
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

- (void)selectItemWithIndexSet:(IBSectionIndexSet*)idx byExtendingSelection:(BOOL)extendingSelection;
{
    IBSectionIndexSet *goodIdx = nil;
    NSInteger sectionCount = [self sectionCount];
    if (sectionCount > 0){
        if (idx.sectionIndex>=0 && idx.sectionIndex<sectionCount) {
            NSInteger itemCount = [self itemCountInSectionIndex:idx.sectionIndex];
            if (idx.itemIndex>=0 && idx.itemIndex<itemCount) {
                goodIdx = idx;
            }
        }
    }else {
        if (idx.sectionIndex == 0) {
            NSInteger itemCount = [self itemCountInSectionIndex:0];
            if (idx.itemIndex>=0 && idx.itemIndex<itemCount) {
                goodIdx = idx;
            }
        }
    }

    if (goodIdx) {
        if (extendingSelection) {
            [self _addSelectedIndexes: @[goodIdx]];
            [self updateDisplayWithRect: collectionContentView.visibleRect];
            if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
                [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
        }
        else{
            [self selectItemWithIndexSet:goodIdx];
        }
    }
}

- (void)deselectAll:(id)sender
{
    [self deselect];
}

-(void)deselect
{
    lastKeyNavItemIndexSet = nil;
    [self _removeAllSelectedIndexes];
    [self updateDisplayWithRect: collectionContentView.visibleRect];
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

-(void)deselectItemWithIndexSet:(IBSectionIndexSet*)indexSet
{
    if ([selecteds containsObject:indexSet]) {
        [selecteds removeObject:indexSet];
        [self updateDisplayWithRect: collectionContentView.visibleRect];
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
            [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
    }
}

-(void)deselectItemWithIndexSets:(NSArray*)indexSets
{
    NSInteger n = selecteds.count;
    [selecteds removeObjectsInArray:indexSets];
    NSInteger n1 = selecteds.count;
    if (n1!=n) {
        [self updateDisplayWithRect: collectionContentView.visibleRect];
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
            [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
    }
}

-(IBSectionIndexSet*)itemIndexSetWithPoint:(NSPoint)point
{
    __block IBSectionIndexSet *result = nil;
    if (isSectionViewMode){
        [sectionViewCacheFrames enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSRect sectionRect = [(NSValue*)obj rectValue];
            if (NSPointInRect(point, sectionRect)){
                
                NSInteger sectionIndex = [(NSString*)key integerValue];
                
                IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: sectionIndex];
                NSUInteger itemCount = [self itemCountInSectionIndex:sectionIndex];
                for (NSInteger i = 0; i < itemCount; i++){
                    IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: i];
                    NSRect itemRect = [layoutManager itemRectOfIndex:i];
                    itemRect = [self convertItemRect: itemRect fromSectionFrame: sectionRect];
                    if (NSPointInRect(point, itemRect)){
                        IBCollectionItemView *itemView = [self itemViewWithIndexSet:indexSet];
                        NSPoint p = point;
                        p.y -= itemView.superview.frame.origin.y;
                        p = [itemView convertPoint:p fromView:itemView.superview];
                        if ([itemView clickTest:p]) {
                            result = indexSet;
                        }
                        break;
                    }
                }
                *stop = YES;
            }
        }];
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        NSUInteger num = [itemCountInSection[@(0)] integerValue];
        for (NSInteger i = 0; i < num; i++){
            IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: i];
            NSRect itemRect = [layoutManager itemRectOfIndex:i];
            if (NSPointInRect(point, itemRect)){
                IBCollectionItemView *itemView = [self itemViewWithIndexSet:indexSet];
                NSPoint p = [itemView convertPoint:point fromView:itemView.superview];
                if ([itemView clickTest:p]) {
                    result = indexSet;
                }
                else{
                    return nil;
                }
                break;
            }
        }
    }
    return result;
}

-(NSRect)itemRectWithIndexSet:(IBSectionIndexSet*)indexSet
{
    NSRect itemRect = NSZeroRect;
    if (isSectionViewMode){
        BOOL isExpand = YES;
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSectionIsExpand:SectionIndex:)])
            isExpand = [_delegate collectionViewSectionIsExpand: self SectionIndex: indexSet.sectionIndex];
        if (isExpand){
            NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey:@(indexSet.sectionIndex)] rectValue];
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: indexSet.sectionIndex];
            itemRect = [layoutManager itemRectOfIndex: indexSet.itemIndex];
            itemRect = [self convertItemRect: itemRect fromSectionFrame: sectionViewFrame];
        }
    }
    else{
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:indexSet.sectionIndex];
        itemRect =  [layoutManager itemRectOfIndex: indexSet.itemIndex];
    }
    return itemRect;
}

-(NSArray*)visibleItemIndexSets
{
    return [self itemIndexsWithRect: collectionContentView.visibleRect];
}

-(NSIndexSet*)visibleSectionIndexSets
{
    return [self sectionIndexSetWithRect: collectionContentView.visibleRect];
}

-(NSArray*)visibleItemViews
{
    return  [visibleItemViews allValues];
}

-(IBCollectionItemView*)itemViewWithIndexSet:(IBSectionIndexSet*)indexSet
{
    if (!indexSet)
        return nil;
    return [visibleItemViews objectForKey: indexSet];
}

-(id)itemDataAtIndexSet:(IBSectionIndexSet*)indexSet
{
    return nil;
}

#pragma mark ==================== Mouse Event

- (NSView *)hitTest:(NSPoint)aPoint
{
    NSView *tmpView = [super hitTest: aPoint];
    if ([tmpView isKindOfClass: [IBCollectionSectionView class]] || [tmpView isKindOfClass: [IBCollectionItemView class]])
        return collectionContentView;
    return tmpView;
}
    /*
- (void)mouseMoved:(NSEvent *)theEvent;
{
    return;

    NSPoint localPoint = [theEvent locationInWindow];
    localPoint = [collectionContentView convertPoint: localPoint fromView: nil];
    
    IBSectionIndexSet *indexSet = [self itemIndexSetWithPoint: localPoint];
    if (!indexSet){
        if (lastMovedItemIndexSet){
            IBCollectionItemView *tmpView = [self itemViewWithIndexSet: lastMovedItemIndexSet];
            if (tmpView)
                [tmpView mouseExited: theEvent];
            lastMovedItemIndexSet = nil;
        }
    }
    else {
        if (lastMovedItemIndexSet){
            if (![indexSet isEqual: lastMovedItemIndexSet]){
                IBCollectionItemView *itemView = [self itemViewWithIndexSet: lastMovedItemIndexSet];
                if (itemView)
                    [itemView mouseExited: theEvent];
                lastMovedItemIndexSet = nil;
                
                itemView = [self itemViewWithIndexSet: indexSet];
                if (itemView && [itemView accpetMouseEventWithEvent: theEvent]){
                    [itemView mouseEntered: theEvent];
                    lastMovedItemIndexSet = indexSet;
                }
            }else {
                IBCollectionItemView *itemView = [self itemViewWithIndexSet: lastMovedItemIndexSet];
                if (itemView && [itemView accpetMouseEventWithEvent: theEvent])
                    [itemView mouseMoved: theEvent];
            }
        }else {
            IBCollectionItemView *itemView = [self itemViewWithIndexSet: indexSet];
            
            if (itemView && [itemView accpetMouseEventWithEvent: theEvent]){
                [itemView mouseEntered: theEvent];
                lastMovedItemIndexSet = indexSet;
            }
        }
    }
     
}
*/

- (void)rightMouseDown:(NSEvent *)theEvent
{
    BOOL commandKeyDown = ([theEvent modifierFlags] & NSCommandKeyMask) != 0;
    BOOL shiftKeyDown = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;
    BOOL optionKeyDown = ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
   
    if (commandKeyDown || shiftKeyDown || optionKeyDown) {
        [super rightMouseDown:theEvent];
        return;
    }
    
    //BOOL controlKeyDown = ([theEvent modifierFlags] & NSControlKeyMask) != 0;
    BOOL bNeedUpdateDisplay = NO;
    
    NSPoint localPoint = [collectionContentView convertPoint:[theEvent locationInWindow] fromView: nil];
    
    IBSectionIndexSet *indexSet = [self itemIndexSetWithPoint: localPoint];
    if (![selecteds containsObject:indexSet]) {
        //if the current click item already in selection. do not clean up selection.
        if (selecteds.count > 0){
            bNeedUpdateDisplay = YES;
            [self _removeAllSelectedIndexes];
        }
    }
    
    IBCollectionItemView *itemView = [self itemViewWithIndexSet:indexSet];
    if (indexSet && itemView){
        localPoint = [itemView convertPoint: localPoint fromView: collectionContentView];
        if ([itemView accpetSelectWithPoint: localPoint]){
            if (![selecteds containsObject:indexSet]) {
                [self _addSelectedIndex: indexSet];
                bNeedUpdateDisplay = YES;
            }
        }
    }
    
    if (bNeedUpdateDisplay){
        [self updateDisplayWithRect: self.documentVisibleRect];
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
            [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
    }
    
    NSMenu *menu = nil;
    BOOL trackedMouseEvent = NO;
    if (indexSet && itemView){
        if ([itemView accpetMouseEventWithEvent: theEvent])
            trackedMouseEvent = [itemView trackMouseEvent: theEvent];
        if (!trackedMouseEvent){
            //if (theEvent.clickCount == 1)
            //{
            //[self onItemViewSingleClick:indexSet];
            if (_delegate && [_delegate respondsToSelector: @selector(collectionViewMenu:IndextSet:)]){
                menu =  [self.delegate performSelector:@selector(collectionViewMenu:IndextSet:) withObject:self withObject:indexSet];
            }
            //}
        }
    }
    else{
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewMenu:)]){
            menu =  [self.delegate performSelector:@selector(collectionViewMenu:) withObject:self];
        }
    }
    
    if (menu) {
        NSEvent *event =  [NSEvent mouseEventWithType:NSRightMouseDown
                                             location:[theEvent locationInWindow]
                                        modifierFlags:NSRightMouseDownMask // 0x100
                                            timestamp:0
                                         windowNumber:[[self window] windowNumber]
                                              context:[[self window] graphicsContext]
                                          eventNumber:0
                                           clickCount:1
                                             pressure:1];
        [NSMenu popUpContextMenu:menu withEvent:event forView:collectionContentView];
    }
    
}

//- (void)scrollWheel:(NSEvent *)theEvent
//{
//    BOOL shouldForwardScroll = NO;
//
//    if (fabs(theEvent.deltaX) > fabs(theEvent.deltaY))
//    {
//        // horizontal scroll
//        shouldForwardScroll = YES;
//    }
//    else
//    {
//        // vertical scroll
//        if (!self.hasVerticalScroller)
//        {
//            shouldForwardScroll = YES;
//        }
//    }
//
//    if (shouldForwardScroll)
//    {
//        
//        [[self nextResponder] scrollWheel:theEvent];
//    }
//    else
//    {
//        [super scrollWheel:theEvent];
//    }
//}

- (BOOL)isPressedMultipleSelectionCombination:(NSEvent*)theEvent
{
    BOOL commandKeyDown = ([theEvent modifierFlags] & NSCommandKeyMask) != 0;
    BOOL shiftKeyDown = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;
    BOOL controlKeyDown = ([theEvent modifierFlags] & NSControlKeyMask) != 0;
    BOOL optionKeyDown = ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
    BOOL isPressedMultipleSelectionCombination = (commandKeyDown && !shiftKeyDown && !controlKeyDown && !optionKeyDown) ||
    (shiftKeyDown && !commandKeyDown && !controlKeyDown && !optionKeyDown);

    return isPressedMultipleSelectionCombination;
}

-(void)mouseDown:(NSEvent *)theEvent
{
    BOOL controlKeyPressed = ([theEvent modifierFlags] & NSControlKeyMask) != 0;
    
    if (controlKeyPressed)
        return [self rightMouseDown: theEvent];
    
    NSPoint localPoint = [collectionContentView convertPoint:[theEvent locationInWindow] fromView: nil];
    firstMouseDownPoint = localPoint;
    
    BOOL bNeedUpdateDisplay = NO;
    BOOL clickedOnSelection = NO;
    BOOL isPressedMultipleSelectionCombination = [self isPressedMultipleSelectionCombination:theEvent];

    IBSectionIndexSet *indexSet = [self itemIndexSetWithPoint: localPoint];
    IBCollectionItemView *itemView = [self itemViewWithIndexSet:indexSet];
    if (indexSet && itemView){
        localPoint = [itemView convertPoint: localPoint fromView: collectionContentView];
        if ([itemView accpetSelectWithPoint: localPoint]){
            if ([selecteds containsObject:indexSet]) {
                clickedOnSelection = YES;
            }
        }
    }
    
    if (!clickedOnSelection) {
        stateMode = IBCollectionContentViewStateSelecting;
        if (_selectionMode == IBCollectionViewSelectionSingle || !isPressedMultipleSelectionCombination) {
            //if user did not press shift key or user press cmd key, clean up current selections.
            //This is Finder's behivour.
            if (selecteds.count > 0){
                bNeedUpdateDisplay = YES;
                [self _removeAllSelectedIndexes];
            }
        }
        
        if (indexSet && itemView){
            if ([itemView accpetSelectWithPoint: localPoint]){
                if (![selecteds containsObject:indexSet]) {
                    [self _addSelectedIndex:indexSet];
                    bNeedUpdateDisplay = YES;
                    if ([_delegate respondsToSelector:@selector(collectionViewDragPromisedFilesOfTypes:)]) {
                        stateMode = IBCollectionContentViewStateDragging;
                    }
                    else{
                        stateMode = IBCollectionContentViewStateSelecting;
                    }
                }
            }
        }
    }
    else{
        if (selecteds.count>0 && isPressedMultipleSelectionCombination) {
            [selecteds removeObject:indexSet];
            bNeedUpdateDisplay = YES;
        }
        
        if ([_delegate respondsToSelector:@selector(collectionViewDragPromisedFilesOfTypes:)]) {
            stateMode = IBCollectionContentViewStateDragging;
        }
        else{
            stateMode = IBCollectionContentViewStateSelecting;
        }
    }

    if (!isPressedMultipleSelectionCombination && _selectionMode == IBCollectionViewSelectionNone) {
        [self _removeAllSelectedIndexes];
        bNeedUpdateDisplay = YES;
        stateMode = IBCollectionContentViewStateNone;
    }
    
    if (stateMode == IBCollectionContentViewStateSelecting) {
        selectingRegionRect.origin = firstMouseDownPoint;
    }
    
    if (bNeedUpdateDisplay){
        [self updateDisplayWithRect: self.documentVisibleRect];
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
            [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
    }
    
    BOOL trackedMouseEvent = NO;
    if (indexSet && itemView){
        if ([itemView accpetMouseEventWithEvent: theEvent])
            trackedMouseEvent = [itemView trackMouseEvent: theEvent];
        if (!trackedMouseEvent){
            if (theEvent.clickCount == 1){
                if (self.distinctSingleDoubleClick) {
                    [self performSelector: @selector(onItemViewSingleClick:) withObject: indexSet afterDelay: [NSEvent doubleClickInterval]];
                }
                else{
                    [self onItemViewSingleClick:indexSet];
                }
            }else if (theEvent.clickCount == 2){
                if (self.distinctSingleDoubleClick) {
                    [NSObject cancelPreviousPerformRequestsWithTarget: self];
                }
                [self onItemViewDoubleClick: indexSet];
            }
        }
    }
    
    
    if (trackedMouseEvent){
        stateMode = IBCollectionContentViewStateNone;
        return;
    }
    
    if (stateMode == IBCollectionContentViewStateDragging) {
        
    }
    
    BOOL keepOn = YES;
    while (keepOn) {
        theEvent = [self.window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        switch ([theEvent type]) {
            case NSLeftMouseDragged:{
                keepOn = [self trackMouseDraggedEvent:theEvent];
                break;
            }
            case NSLeftMouseUp:
                [self mouseUp: theEvent];
                keepOn = NO;
                break;
            default:{
                break;
            }
        }
    }
}


-(void)mouseUp:(NSEvent *)theEvent
{
    if (_selectionRegionView){
        [_selectionRegionView removeFromSuperview];
        _selectionRegionView = nil;
    }
    stateMode = IBCollectionContentViewStateNone;
    draggingItemView = nil;
    draggingSession = nil;
}


-(BOOL)trackMouseDraggedEvent:(NSEvent *)event
{
    NSPoint localPoint = [collectionContentView convertPoint:[event locationInWindow] fromView: nil];
    
    if (stateMode == IBCollectionContentViewStateSelecting){
        
        if (_selectionMode == IBCollectionViewSelectionMulitple) {

            BOOL isPressedMultipleSelectionCombination = [self isPressedMultipleSelectionCombination:event];

            if (!_selectionRegionView){
                _selectionRegionView = [[IBCollectionSelectionRegionView alloc] initWithFrame: self.bounds];
                [self addSubview: _selectionRegionView];
            }
            
            selectingRegionRect.size.width = fabs(localPoint.x - firstMouseDownPoint.x);
            selectingRegionRect.size.height = fabs(localPoint.y - firstMouseDownPoint.y);
            if (selectingRegionRect.size.height<=0) {
                selectingRegionRect.size.height=1;
            }
            if (localPoint.x<firstMouseDownPoint.x) {
                selectingRegionRect.origin.x = localPoint.x;
            }
            else{
                selectingRegionRect.origin.x = firstMouseDownPoint.x;
            }
            
            if (localPoint.y<firstMouseDownPoint.y) {
                selectingRegionRect.origin.y = localPoint.y;
            }
            else {
                selectingRegionRect.origin.y = firstMouseDownPoint.y;
            }
            
            NSArray *itemIndexs = [self itemIndexsWithRect: selectingRegionRect];
            if (!isPressedMultipleSelectionCombination) {
                [self _removeAllSelectedIndexes];
            }
            [self _addSelectedIndexes: itemIndexs];
            
            [self updateDisplayWithRect: self.documentVisibleRect];
            
            if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
                [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
            
            if (_selectionRegionView){
                NSRect drawSelectionRect = [_selectionRegionView convertRect: selectingRegionRect fromView: collectionContentView];
                [_selectionRegionView drawFrameWithRect: drawSelectionRect];
            }
            
            [collectionContentView autoscroll: event];
        }
        else{
            if (_selectionRegionView){
                [_selectionRegionView removeFromSuperview];
                _selectionRegionView = nil;
            }
        }
       
    }
    else if (stateMode == IBCollectionContentViewStateDragging){

        if ([_delegate respondsToSelector:@selector(collectionViewDragPromisedFilesOfTypes:)]) {
            if (draggingItemView == nil) {
                
                NSArray *list = [_delegate collectionViewDragPromisedFilesOfTypes: self];
                
                IBSectionIndexSet *indexSet = [self itemIndexSetWithPoint: localPoint];
                draggingItemView = [self itemViewWithIndexSet:indexSet];
                NSRect imageLocation;
                imageLocation.origin = [self convertPoint:[event locationInWindow] fromView: nil];
                imageLocation.size = NSMakeSize(32, 32);
                
                [self dragPromisedFilesOfTypes:list fromRect:imageLocation source:self slideBack:NO event:event];
                return NO;
            }
        }
    }
    
    return YES;
}



#pragma mark ==================== Dragging Source


- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
    /*------------------------------------------------------
     NSDraggingSource protocol method.  Returns the types of operations allowed in a certain context.
     --------------------------------------------------------*/
    if (context == NSDraggingContextOutsideApplication) {
        return NSDragOperationCopy;
    }
    return NSDragOperationNone;
}

- (void)draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    stateMode = IBCollectionContentViewStateNone;
    draggingItemView = nil;
    draggingSession = nil;
    if (dragginWindow) {
        [dragginWindow close];
        dragginWindow = nil;
    }
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:namesOfPromisedFilesDroppedAtDestination:)]){
        return [_delegate collectionView:self namesOfPromisedFilesDroppedAtDestination:dropDestination];
    }
    return nil;
}

- (void)draggingSession: (NSDraggingSession *)session
           movedToPoint: (NSPoint)screenPoint
{
    if (dragginWindow) {
        [dragginWindow setFrameOrigin:NSMakePoint(screenPoint.x + 15, screenPoint.y-20)];
        if (![dragginWindow isVisible]) {
            [dragginWindow orderFront:nil];
        }
    }
}

//- (BOOL)dragPromisedFilesOfTypes:(NSArray *)typeArray
//                        fromRect:(NSRect)aRect
//                          source:(id)sourceObject
//                       slideBack:(BOOL)slideBack
//                           event:(NSEvent *)theEvent
//{
//    NSLog(@"dragPromisedFilesOfTypes %@", typeArray);
//    NSImage *img = [NSImage imageNamed:@"t1White"];
//    NSPasteboard *pb = [NSPasteboard generalPasteboard];
//    [self dragImage:img at:aRect.origin offset:NSZeroSize event:theEvent pasteboard:nil source:sourceObject slideBack:slideBack];
//    return [super dragPromisedFilesOfTypes:typeArray fromRect:aRect source:sourceObject slideBack:slideBack event:theEvent];
//}

- (void)dragImage:(NSImage *)anImage
               at:(NSPoint)imageLoc
           offset:(NSSize)mouseOffset
            event:(NSEvent *)theEvent
       pasteboard:(NSPasteboard *)pboard
           source:(id)sourceObject
        slideBack:(BOOL)slideBack
{
    
    if (dragginWindow) {
        [dragginWindow close];
        dragginWindow = nil;
    }
    
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 30, 30)];
    NSMutableDictionary *d = [[NSMutableDictionary alloc] init];
    [d setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    [d setObject:[NSFont boldSystemFontOfSize:12] forKey:NSFontAttributeName];
    NSMutableParagraphStyle *p = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [p setAlignment:NSCenterTextAlignment];
    [d setObject:p forKey:NSParagraphStyleAttributeName];

    NSAttributedString *str = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%lu", [self.selectedItemIndexSets count]] attributes:d];
    NSSize size = [str size];
    size.width = ceil(size.width);
    size.height = ceil(size.height);

    NSRect rect = NSZeroRect;
    if (size.width<size.height) {
        rect = NSMakeRect(0, 0, size.height+8, size.height+8);
    }
    else{
        rect = NSMakeRect(0, 0, size.width+8, size.height+8);
    }

    NSImage *image = [[NSImage alloc] initWithSize:rect.size];
    [image lockFocus];
    NSBezierPath *b = [NSBezierPath bezierPathWithRoundedRect:rect cornerRadius:rect.size.height/2.0];
    [[NSColor colorWithDeviceRed:242/255.0 green:33/255.0 blue:36/255.0 alpha:1] set];
    [b fill];
    [str drawInRect:NSMakeRect((int)((rect.size.width-size.width)/2.0), (int)((rect.size.height-size.height)/2.0)+1, size.width, size.height)];
    [image unlockFocus];
    [imageView setImage:image];
    [imageView setImageFrameStyle:NSImageFrameNone];
    [imageView setImageScaling:NSImageScaleNone];
    [imageView setFrameSize:NSMakeSize(image.size.width, image.size.height)];

    
    dragginWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, image.size.width, image.size.height) styleMask:NSBorderlessWindowMask backing:NSBackingStoreRetained defer:YES];
    [dragginWindow setReleasedWhenClosed:NO];
    [dragginWindow setOpaque:NO];
    [dragginWindow setLevel:NSScreenSaverWindowLevel];
    [dragginWindow setBackgroundColor:[NSColor clearColor]];
    [[dragginWindow contentView] addSubview:imageView];
    [dragginWindow setFrameOrigin:NSMakePoint(-1000, -1000)];
    //[dragginWindow setFrameOrigin:NSMakePoint(imageLoc.x+mouseOffset.width+15, imageLoc.y+ mouseOffset.height -20)];
    //NSLog(@"imageLoc = %@", NSStringFromPoint(imageLoc));
    //NSLog(@"imageLoc = %@", NSStringFromPoint(imageLoc));

    [super dragImage:anImage at:imageLoc offset:mouseOffset event:theEvent pasteboard:pboard source:sourceObject slideBack:slideBack];
}

#pragma mark ==================== Dragging Destination

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:draggingEntered:)]){
        NSDragOperation op =  [_delegate collectionView:self draggingEntered:sender];
        if(op != NSDragOperationNone){
            
        }
        return op;
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:draggingUpdated:withIndexSet:)]){
      
        IBSectionIndexSet *idx = [self itemIndexSetWithPoint:[collectionContentView convertPoint:[sender draggingLocation] fromView: nil]];
        NSDragOperation op = [_delegate collectionView:self draggingUpdated:sender withIndexSet:idx];
        if(op != NSDragOperationNone){
           
        }
        return op;
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:draggingExited:)]){
        [_delegate collectionView:self draggingExited:sender];
    }
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:performDragOperation:withIndexSet:)]){
        IBSectionIndexSet *idx = [self itemIndexSetWithPoint:[collectionContentView convertPoint:[sender draggingLocation] fromView: nil]];
        return [_delegate collectionView:self performDragOperation:sender withIndexSet:idx];
    }
    
    return NO;
}

#pragma mark ==================== Keyboard Event



-(void)navigateByArrowKey:(NSEvent*)theEvent
{
    unsigned short keyCode = [theEvent keyCode];
    BOOL shiftKeyPressed = ([theEvent modifierFlags] & NSShiftKeyMask) != 0;
    
    //shiftKeyPressed = NO;
    
    if (selecteds.count == 0){
        __block IBSectionIndexSet *idx = [IBSectionIndexSet sectionIndexSetWithSectionIndex:10000000000 ItemIndex:10000000000];
        [visibleItemViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[IBCollectionItemView class]]) {
                IBCollectionItemView *itemView = obj;
                if (itemView.indexSet.sectionIndex<idx.sectionIndex) {
                    idx.sectionIndex = itemView.indexSet.sectionIndex;
                    idx.itemIndex = itemView.indexSet.itemIndex;
                }
                else if (itemView.indexSet.sectionIndex==idx.sectionIndex && itemView.indexSet.itemIndex<idx.itemIndex) {
                    idx.itemIndex = itemView.indexSet.itemIndex;
                }
            }
        }];
        [self selectItemWithIndexSet:idx];
        [self scrollToIndexSet:idx];
        lastKeyNavItemIndexSet = idx;
        return;
    }
    
    if(lastKeyNavItemIndexSet==nil){
        lastKeyNavItemIndexSet = [self selectedItemIndexSets].firstObject;
    }
    
    
    
    /*
    NSMutableArray *tmpArray = [NSMutableArray arrayWithArray:selecteds];
    [tmpArray sortUsingComparator: ^NSComparisonResult(id obj1, id obj2) {
        IBSectionIndexSet *set1 = obj1;
        IBSectionIndexSet *set2 = obj2;
        NSInteger result = NSOrderedSame;
        if (set1.sectionIndex > set2.sectionIndex)
            result = NSOrderedAscending;
        else if (set1.sectionIndex < set2.sectionIndex)
            result = NSOrderedDescending;
        return result;
    }];
    IBSectionIndexSet *minIndexSet = [tmpArray firstObject];
    IBSectionIndexSet *maxIndexSet = [tmpArray lastObject];
    */
    
    NSInteger sectionIndex = 0;
    NSInteger itemIndex = 0;
    
    /*
     if (viewSizeManager.displayMode == kIBDisplay_ListView){
     if (key == NSLeftArrowFunctionKey || key == NSUpArrowFunctionKey){
     sectionRow = minIndexSet.sectionIndex;
     itemIndex = minIndexSet.itemIndex;
     if (minIndexSet.itemIndex == 0){
     sectionRow--;
     if (sectionRow < 0){
     sectionRow = 0;
     itemIndex = 0;
     }else
     itemIndex = itemCountWithRow(sectionRow) - 1;
     }else
     itemIndex--;
     }else {
     sectionRow = maxIndexSet.sectionIndex;
     itemIndex = maxIndexSet.itemIndex;
     
     NSInteger itemCount = itemCountWithRow(maxIndexSet.sectionIndex);
     if (maxIndexSet.itemIndex == itemCount - 1){
     sectionRow++;
     NSInteger sectionCount = _dataSource.count;
     if (sectionRow >= sectionCount){
     sectionRow = sectionCount - 1;
     itemIndex = itemCount - 1;
     }else
     itemIndex = 0;
     }else
     itemIndex++;
     }
     
     [self selectItemWithIndexSet:[IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionRow ItemIndex: itemIndex]];
     return;
     }
     */
    
    if (keyCode == kVK_LeftArrow){
        
        sectionIndex = lastKeyNavItemIndexSet.sectionIndex;
        itemIndex = lastKeyNavItemIndexSet.itemIndex;
        //left right arrow can never jump section
        
        //if the itemIndex is not the first column, do this navigation
        if ([[self layoutWithSectionIndex:sectionIndex] columnOfIndex:itemIndex]>0) {
            itemIndex--;
        }
    }
    else if (keyCode == kVK_RightArrow){
        sectionIndex = lastKeyNavItemIndexSet.sectionIndex;
        itemIndex = lastKeyNavItemIndexSet.itemIndex;
        //left right arrow can never jump section
        
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:sectionIndex];
        NSUInteger countOfColumn = [layoutManager countOfColumn];
        if ([layoutManager columnOfIndex:itemIndex]<countOfColumn-1) {
            itemIndex++;
        }
    }
    else if (keyCode == kVK_UpArrow){
        sectionIndex = lastKeyNavItemIndexSet.sectionIndex;
        itemIndex = lastKeyNavItemIndexSet.itemIndex;
        
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:sectionIndex];
        NSUInteger countOfColumn = [layoutManager countOfColumn];
        if (sectionIndex==0 && itemIndex<countOfColumn) {
            //at top already, do not move
        }
        else{
            if (itemIndex<countOfColumn) {
                sectionIndex--;
                itemIndex-=countOfColumn;
                NSUInteger topSectionItemCount = [self itemCountInSectionIndex:sectionIndex];
                itemIndex=topSectionItemCount+itemIndex;
            }else{
                itemIndex-=countOfColumn;
            }
        }
    }
    
    else if (keyCode == kVK_DownArrow){
        sectionIndex = lastKeyNavItemIndexSet.sectionIndex;
        itemIndex = lastKeyNavItemIndexSet.itemIndex;
        
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:sectionIndex];
        NSUInteger countOfSection = [self sectionCount];
        NSUInteger countOfColumn = [layoutManager countOfColumn];
        NSUInteger sectionItemCount = [self itemCountInSectionIndex:sectionIndex];
        if ((countOfSection==0 || sectionIndex==countOfSection-1) && ceil((double)(itemIndex+1)/(double)countOfColumn)==ceil((double)sectionItemCount/(double)countOfColumn)) {
            //at bottom already, do not move
        }
        else{
            if (itemIndex+countOfColumn>sectionItemCount-1) {
                if(sectionIndex+1>=countOfSection){
                    //no more section, do not move
                }
                else
                {
                    sectionIndex++;
                    itemIndex=(itemIndex+countOfColumn)-sectionItemCount;
                    //NSUInteger topSectionItemCount = [self itemCountInSectionIndex:sectionIndex];
                    //itemIndex=topSectionItemCount+itemIndex;
                }
            }else{
                itemIndex+=countOfColumn;
            }
        }
    }
    
    IBSectionIndexSet *idx = [IBSectionIndexSet sectionIndexSetWithSectionIndex:sectionIndex ItemIndex:itemIndex];
    if (shiftKeyPressed) {
        if(![selecteds containsObject:idx]){
            [self _addSelectedIndex:idx];
        }
        [self updateDisplayWithRect: collectionContentView.visibleRect];
    }else{
        [self selectItemWithIndexSet:idx];
    }
    [self scrollToIndexSet:idx];
    lastKeyNavItemIndexSet = idx;
    
}

-(void)keyDown:(NSEvent *)theEvent
{
    unsigned short keyCode = [theEvent keyCode];
    BOOL commandKeyPressed = ([theEvent modifierFlags] & NSCommandKeyMask) != 0;
    
    if (keyCode == kVK_Escape){ //ESC
        [super keyDown:theEvent];
        //[self deselect];//finder does not allow esc deselect, so do we.
    }
    else if (commandKeyPressed && keyCode == kVK_ANSI_A){ //Command + A
        [self selectAll:self];
    }
    else if (self.selectionMode != IBCollectionViewSelectionNone && !commandKeyPressed && (keyCode==kVK_UpArrow || keyCode==kVK_DownArrow || keyCode==kVK_LeftArrow || keyCode==kVK_RightArrow)){
        [self navigateByArrowKey:theEvent];
    }
    
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:didKeyDownEvent:)])
        [_delegate collectionView: self didKeyDownEvent: theEvent];
}


#pragma mark ==================== Notification

- (void)didEndScrollNotification:(NSNotification*)n
{
    //NSLog(@"didEndScrollNotification");
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewDidEndScroll:)])
        [_delegate collectionViewDidEndScroll:self];
}

-(void)onSynchronizedViewContentBoundsDidChange:(NSNotification*)n
{
    if (self.contentView == [n object]){
//#if USE_BATCH_THUMNAIL_QUERY
//        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewBeginScrolling:)])
//            [_delegate collectionViewBeginScrolling:self];
//#endif

        [self updateDisplayWithRect: self.documentVisibleRect];
        //[self removeUnvisibleViews: self.documentVisibleRect];
        //-(void)removeUnvisibleViews:(NSRect)visibleRect
        {
            NSRect visibleRect = self.documentVisibleRect;
            NSMutableArray *needRemoveViewKeys = [NSMutableArray array];
            [visibleSectionViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                IBCollectionSectionView *sectionView = obj;
                if (!NSIntersectsRect(sectionView.frame, visibleRect))
                    [needRemoveViewKeys addObject: key];
            }];
            for (id key in needRemoveViewKeys){
                NSView *tmpView = [visibleSectionViews objectForKey: key];
                [self removeSubViewToReusable: tmpView];
                [visibleSectionViews removeObjectForKey: key];
            }
            [needRemoveViewKeys removeAllObjects];

            [visibleItemViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                NSView *tmpView = obj;
                NSRect tmpRect = tmpView.frame;
                if (isSectionViewMode){
                    NSRect superViewRect = tmpView.superview.frame;
                    tmpRect.origin.y = superViewRect.origin.y + tmpRect.origin.y;
                }
                if (!NSIntersectsRect(tmpRect, visibleRect))
                    [needRemoveViewKeys addObject: key];
            }];

            for (NSString *key in needRemoveViewKeys){
                NSView *tmpView = [visibleItemViews objectForKey: key];
                [self removeSubViewToReusable: (IBCollectionItemView*)tmpView];
                [visibleItemViews removeObjectForKey: key];
            }
        }

//#if USE_BATCH_THUMNAIL_QUERY
//        static dispatch_source_t readtimer=NULL;
//        if(readtimer) {
//            dispatch_source_cancel(readtimer);
//            //dispatch_release(readtimer);
//            readtimer=NULL;
//        }
//        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//        readtimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
//        dispatch_source_set_timer(readtimer, dispatch_time(DISPATCH_TIME_NOW, 0.85 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
//        dispatch_source_set_event_handler(readtimer, ^{
//            if (readtimer) dispatch_source_cancel(readtimer);
//
//            //DDLogVerbose(@"th=%d", [NSThread mainThread]==[NSThread currentThread]);
//            dispatch_async( dispatch_get_main_queue(), ^{
//                [self didEndScrollNotification:nil];
//            });
//
//            //if (readtimer) dispatch_release(readtimer);
//            readtimer=NULL;
//        });
//        dispatch_resume(readtimer);
//#endif

    }
}

#pragma mark ==================== Private


-(IBSectionViewLayoutManager*)defaultLayoutManager
{
    static IBSectionViewLayoutManager *__defaultLayoutMananger;
    if (!__defaultLayoutMananger)
        __defaultLayoutMananger = [[IBSectionViewLayoutManager alloc] init];
    return __defaultLayoutMananger;
}

-(IBSectionViewLayoutManager*)layoutWithSectionIndex:(NSUInteger)sectionIndex
{
    IBSectionViewLayoutManager *layoutManager = nil;
    if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSectionLayoutManager:SectionIndex:)])
        layoutManager = [_delegate collectionViewSectionLayoutManager: self SectionIndex: sectionIndex];
    
    if (!layoutManager)
        layoutManager = [self defaultLayoutManager];
    layoutManager.itemCount = [self itemCountInSectionIndex:sectionIndex];
    return layoutManager;
}

-(NSSize)documentContentSize
{
    if (!_dataSource)
        return self.bounds.size;
    
    NSInteger sectionCount = [self sectionCount];
    
    CGFloat contentHeight = 0;
    NSSize contentSize = NSMakeSize(self.bounds.size.width, contentHeight);
    if (sectionCount == 0){
        
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        contentHeight = [layoutManager contentHeightWithLayoutWidht: self.bounds.size.width];
        if (contentHeight < self.bounds.size.height)
            contentHeight = self.bounds.size.height;
        contentSize.height = contentHeight;
        
    }else {
        
        CGFloat *sectionHeights = (CGFloat*)malloc(sizeof(CGFloat) * sectionCount);
        for (NSInteger index = 0; index < sectionCount; index++){
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: index];
            CGFloat tmpHeight = [layoutManager sectionHeaderViewHeight];
            BOOL isExpand = YES;
            if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSectionIsExpand:SectionIndex:)])
                isExpand = [_delegate collectionViewSectionIsExpand: self SectionIndex: index];
            if (isExpand)
                tmpHeight = [layoutManager contentHeightWithLayoutWidht: self.bounds.size.width];
            contentHeight += tmpHeight;
            sectionHeights[index] = tmpHeight;
        }
        if (contentHeight < self.bounds.size.height)
            contentHeight = self.bounds.size.height;
        contentSize.height = contentHeight;
        
        CGFloat startY = 0;
        for (NSInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++){
            CGFloat sectionHeight = sectionHeights[sectionIndex];
            [sectionViewCacheFrames setObject: [NSValue valueWithRect: NSMakeRect(0, startY, contentSize.width, sectionHeight)]
                                       forKey:@(sectionIndex)];
            startY += sectionHeight;
        }
        free(sectionHeights);
    }
    
    return contentSize;
}

-(void)removeSubViewToReusable:(NSView*)view
{
    NSString *reuseIdentifier = [view valueForKeyPath: @"reuseIdentifier"];
    if (reuseIdentifier && reuseIdentifier.length > 0){
        NSMutableArray *cacheViews = [reusableViews objectForKey: reuseIdentifier];
        if (cacheViews)
            [cacheViews addObject: view];
    }
    [view removeFromSuperview];
    if ([view isKindOfClass:[IBCollectionItemView class]]) {
        IBSectionIndexSet *indexset = [(IBCollectionItemView*)view indexSet];
        if (_delegate && [_delegate respondsToSelector: @selector(collectionView:didRemoveItemView:indexSet:)]){
            [_delegate collectionView:self didRemoveItemView:(IBCollectionItemView*)view indexSet:indexset];
        }
    }
}




-(void)updateDisplayWithRect:(NSRect)rect
{
    BOOL didSelectionChanged = NO;

    NSIndexSet *sectionSet = [self sectionIndexSetWithRect: rect];
    if (isSectionViewMode){

        //Update Sections
        NSInteger sectionIndex = [sectionSet firstIndex];
        while (sectionIndex != NSNotFound) {
            
            IBCollectionSectionView *sectionView = [visibleSectionViews objectForKey:@(sectionIndex)];
            if (!sectionView){
                if (_delegate && [_delegate respondsToSelector: @selector(collectionView:sectionViewWithIndex:)])
                    sectionView = [_delegate collectionView: self sectionViewWithIndex: sectionIndex];
            }
            NSAssert(sectionView, @"section view cant't no be nil");
            [visibleSectionViews setObject: sectionView forKey:@(sectionIndex)];
            
            NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey:@(sectionIndex)] rectValue];
            sectionView.frame = sectionViewFrame;
            
            if (_delegate && [_delegate respondsToSelector: @selector(collectionView:WillDisplaySectionView:SectionIndex:)])
                [_delegate collectionView: self WillDisplaySectionView: sectionView SectionIndex: sectionIndex];
            [collectionContentView addSubview: sectionView];
            
            BOOL isExpand = YES;
            if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSectionIsExpand:SectionIndex:)])
                isExpand = [_delegate collectionViewSectionIsExpand: self SectionIndex: sectionIndex];
            
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: sectionIndex];
            NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: sectionIndex LayoutManager: layoutManager];
            NSInteger itemIndex = [itemIndexSet firstIndex];
            if (!isExpand){
                
                while (itemIndex != NSNotFound) {
                    IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: itemIndex];
                    IBCollectionItemView *itemView = [visibleItemViews objectForKey: indexSet];

                    if (itemView && [itemView superview])
                        [itemView removeFromSuperview];
                    [visibleItemViews removeObjectForKey: indexSet];
                    [selecteds removeObject: indexSet];
                    didSelectionChanged = YES;
                    itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
                }
            
            }else {
                //Update header and bottom view size
                if (sectionView.hasHeader && sectionView.headerView)
                    [sectionView.headerView setFrameSize: NSMakeSize(self.bounds.size.width, [layoutManager sectionHeaderViewHeight])];
                if (sectionView.hasBottom && sectionView.bottomView)
                    [sectionView.bottomView setFrameSize: NSMakeSize(self.bounds.size.width, [layoutManager sectionBottomViewHeight])];
                if (!self.fixedSectionHeaderView)
                    [sectionView trackHeaderViewWithVisibleRect: collectionContentView.visibleRect];


                while (itemIndex != NSNotFound) {
                    IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: itemIndex];
                    IBCollectionItemView *itemView = [visibleItemViews objectForKey: indexSet];
                    if (!itemView){
                        if (_delegate && [_delegate respondsToSelector: @selector(collectionView:itemViewWithIndexSet:)])
                            itemView = [_delegate collectionView: self itemViewWithIndexSet: indexSet];
                    }
                    NSAssert(itemView, @"item view cant't no be nil");
                    
                    itemView.frame = [layoutManager itemRectOfIndex: itemIndex];
                    itemView.indexSet = indexSet;
                   
                    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:WillDisplayItemView:indexSet:)])
                        [_delegate collectionView: self WillDisplayItemView: itemView indexSet: indexSet];
                    
                    [visibleItemViews setObject: itemView forKey: indexSet];
                    
                    if (!itemView.superview || itemView.superview != sectionView){
                        if (sectionView.headerView)
                            [sectionView addSubview: itemView positioned: NSWindowBelow relativeTo: sectionView.headerView];
                        else
                            [sectionView addSubview: itemView];
                    }
                    
                    if ([selecteds containsObject: indexSet]){
                        itemView.selected = YES;
                        //don't update selection in updateDisplay method

//                        if (stateMode == IBCollectionContentViewStateSelecting){
//                            NSRect tmpRect = [itemView convertRect: selectingRegionRect fromView: collectionContentView];
//                            
//                            if(tmpRect.size.width <= 0){
//                                tmpRect.size = NSMakeSize(1, tmpRect.size.height);
//                            }
//                            if(tmpRect.size.height <= 0){
//                                tmpRect.size = NSMakeSize(tmpRect.size.width, 1);
//                            }
//                            
//                            if ([itemView accpetSelectWithRect: tmpRect]){
//                                itemView.selected = YES;
//                            }
//                            else{
//                                itemView.selected = NO;
//                                [selecteds removeObject: indexSet];
//                                didSelectionChanged = YES;
//                            }
//
//                        }else{
//                            itemView.selected = YES;
//                        }
                    }else{
                        itemView.selected = NO;
                    }
                    itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
                }
            }
            sectionIndex = [sectionSet indexGreaterThanIndex: sectionIndex];
        }
    
    }else {
        
        
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex:0];
        NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex:0 LayoutManager:layoutManager];
        NSInteger itemIndex = [itemIndexSet firstIndex];
        while (itemIndex != NSNotFound) {
            IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: itemIndex];
            IBCollectionItemView *itemView = [visibleItemViews objectForKey: indexSet];
            if (!itemView){
                if (_delegate && [_delegate respondsToSelector: @selector(collectionView:itemViewWithIndexSet:)]){
                    itemView = [_delegate collectionView: self itemViewWithIndexSet: indexSet];
                }
            }
            NSAssert(itemView, @"item view cant't no be nil");
            
            itemView.frame = [layoutManager itemRectOfIndex: itemIndex];
            itemView.indexSet = indexSet;
            if (_delegate && [_delegate respondsToSelector: @selector(collectionView:WillDisplayItemView:indexSet:)])
                [_delegate collectionView: self WillDisplayItemView: itemView indexSet: indexSet];
            [visibleItemViews setObject: itemView forKey: indexSet];
            if (!itemView.superview){
                [collectionContentView addSubview: itemView];
            }
            if ([selecteds containsObject: indexSet]){
                itemView.selected = YES;
                //don't update selection in updateDisplay method


//                if (stateMode == IBCollectionContentViewStateSelecting){
//                    NSRect tmpRect = [itemView convertRect: selectingRegionRect fromView: collectionContentView];
//                    if(tmpRect.size.width <= 0){
//                        tmpRect.size = NSMakeSize(1, tmpRect.size.height);
//                    }
//                    if(tmpRect.size.height <= 0){
//                        tmpRect.size = NSMakeSize(tmpRect.size.width, 1);
//                    }
//                    if ([itemView accpetSelectWithRect: tmpRect]){
//                        itemView.selected = YES;
//                    }
//                    else{
//                        itemView.selected = NO;
//                        [selecteds removeObject: indexSet];
//                        didSelectionChanged = YES;
//                    }
//                }else{
//                    itemView.selected = YES;
//                }
            }else{
                itemView.selected = NO;
            }
            itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
        }
    }
    
//    if (didSelectionChanged && _delegate && [_delegate respondsToSelector: @selector(collectionViewSelectionDidChange:)])
//        [self.delegate performSelector:@selector(collectionViewSelectionDidChange:) withObject:self];
}

-(NSIndexSet*)sectionIndexSetWithRect:(NSRect)rect
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    NSInteger sectionCount = [self sectionCount];
    
    if (sectionCount == 0){
        return indexSet;
    }
    
    for (NSInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++){
        NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey:@(sectionIndex)] rectValue];
        
        if (NSIntersectsRect(sectionViewFrame, rect) || NSPointInRect(rect.origin, sectionViewFrame))
            [indexSet addIndex: sectionIndex];
    }
    return indexSet;
}

-(NSIndexSet*)itemIndexSetWithRect:(NSRect)rect SectionIndex:(NSInteger)sectionIndex LayoutManager:(IBSectionViewLayoutManager*)layoutManager
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];

    if (isSectionViewMode){
        NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey:@(sectionIndex)] rectValue];
        NSUInteger itemCount = [self itemCountInSectionIndex:sectionIndex];
        for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++){
            NSRect itemRect = [layoutManager itemRectOfIndex: itemIndex];
            itemRect = [self convertItemRect: itemRect fromSectionFrame: sectionViewFrame];
            if (NSIntersectsRect(itemRect, rect) || NSPointInRect(rect.origin, itemRect))
                [indexSet addIndex: itemIndex];
            
            if (itemRect.origin.y > NSMaxY(rect))
                break;
        }
    }else {
        NSUInteger itemCount = [self itemCountInSectionIndex:sectionIndex];
        for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++){
            NSRect itemRect = [layoutManager itemRectOfIndex: itemIndex];
            if (NSIntersectsRect(itemRect, rect) || NSPointInRect(rect.origin, itemRect))
                [indexSet addIndex: itemIndex];
            
            if (itemRect.origin.y > NSMaxY(rect))
                break;
        }
    }
    return indexSet;
}

-(NSArray*)itemIndexsWithRect:(NSRect)rect
{
    NSMutableArray *indexes = [NSMutableArray array];
    if (isSectionViewMode){
        NSIndexSet *sectionSet = [self sectionIndexSetWithRect: rect];
        NSInteger sectionIndex = [sectionSet firstIndex];
        while (sectionIndex != NSNotFound) {
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: sectionIndex];
            
            NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: sectionIndex LayoutManager: layoutManager];
            [itemIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [indexes addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: idx]];
            }];
            sectionIndex = [sectionSet indexGreaterThanIndex: sectionIndex];
        }
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: 0 LayoutManager: layoutManager];
        [itemIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [indexes addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: idx]];
        }];
    }

    return indexes;
}

-(NSRect)convertItemRect:(NSRect)itemRect fromSectionFrame:(NSRect)sectionFrame
{
    NSRect result = itemRect;
    result.origin.y += sectionFrame.origin.y;
    return result;
}

-(void)onItemViewSingleClick:(IBSectionIndexSet*)indexSet
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:didClickItemView:)])
        [_delegate collectionView: self didClickItemView: indexSet];
}

-(void)onItemViewDoubleClick:(IBSectionIndexSet*)indexSet
{
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:didDoubleClickItemView:)])
        [_delegate collectionView: self didDoubleClickItemView: indexSet];
}

#pragma mark - NSPasteboardItemDataProvider

- (void)pasteboard:(NSPasteboard *)pasteboard item:(NSPasteboardItem *)item provideDataForType:(NSString *)type
{
    //NSLog(@"provideDataForType=%@", type);
}

- (void)pasteboardFinishedWithDataProvider:(NSPasteboard *)pasteboard
{
    //NSLog(@"pasteboardFinishedWithDataProvider");
}

@end
