//
//  IBCollectionView.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "IBCollectionView.h"
#import <Carbon/Carbon.h>

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

-(void)drawRect:(NSRect)dirtyRect
{
    [[NSColor whiteColor] setFill];
    NSRectFill(self.bounds);
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
        CGContextSetRGBStrokeColor(context, 1, 1, 1, 0.9);
    CGContextStrokePath(context);
    
    if (self.fillColor)
        CGContextSetFillColorWithColor(context, self.fillColor.CGColor);
    else
        CGContextSetRGBFillColor(context, 1, 1, 1, 0.3);
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
    NSPoint firstMouseDownPoint;
    IBCollectionSelectionRegionView *_selectionRegionView;
    NSRect selectingRegionRect;
    BOOL selectingRegion;
    
    NSInteger _sectionCount;
    NSMutableDictionary *itemCountInSection;
}

@end

@implementation IBCollectionView


-(id)initWithFrame:(NSRect)frameRect
{
    if (self = [super initWithFrame: frameRect]){
        [self setDrawsBackground: NO];
        [self setBackgroundColor: [NSColor whiteColor]];
        [self setAutohidesScrollers: YES];
        [self setHasVerticalScroller: YES];
        [self setBorderType: NSBezelBorder];
        
        collectionContentView = [[IBCollectionContentView alloc] initWithFrame: self.bounds];
        [self setDocumentView: collectionContentView];
        
        selecteds = [[NSMutableArray alloc] init];
        reusableViews = [[NSMutableDictionary alloc] init];
        classMap = [[NSMutableDictionary alloc] init];
        sectionViewCacheFrames = [[NSMutableDictionary alloc] init];
        
        visibleSectionViews = [[NSMutableDictionary alloc] init];
        visibleItemViews = [[NSMutableDictionary alloc] init];
        
        self.allowRegionSelection = YES;
        self.allowSelection = YES;
        self.allowShiftSelection = YES;
        self.distinctSingleDoubleClick = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(onSynchronizedViewContentBoundsDidChange:)
                                                     name: NSViewBoundsDidChangeNotification
                                                   object: nil];
        
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
    if (_sectionCount < 0) {
        if (_dataSource && [_dataSource respondsToSelector: @selector(collectionViewSectionCount:)])
            _sectionCount = [_dataSource collectionViewSectionCount: self];
        else
            _sectionCount = 0;
    }
    return _sectionCount;
}

- (NSInteger)itemCountInSectionIndex:(NSInteger)sectionIndex
{
    NSInteger itemCount = 0;
    if (itemCountInSection[@(sectionIndex)])
        itemCount = [itemCountInSection[@(sectionIndex)] integerValue];
    else{
        if (_dataSource && [_dataSource respondsToSelector: @selector(collectionViewItemCount:SectionIndex:)]){
            itemCount = [_dataSource collectionViewItemCount: self SectionIndex: sectionIndex];
            itemCountInSection[@(sectionIndex)] = @(itemCount);
        }
    }
    return itemCount;
}

-(void)reloadData
{
    _sectionCount = -1;
    itemCountInSection = [[NSMutableDictionary alloc] init];
    
    [[collectionContentView subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [selecteds removeAllObjects];
    [visibleSectionViews removeAllObjects];
    [visibleItemViews removeAllObjects];
    [reusableViews removeAllObjects];
    [sectionViewCacheFrames removeAllObjects];
    
    isSectionViewMode = [self sectionCount] > 0;
    
    NSSize contentSize = [self documentContentSize];
    if (contentSize.height > self.bounds.size.height){
        CGFloat tmpY = self.bounds.size.height - contentSize.height;
        [collectionContentView setFrame: NSMakeRect(0, tmpY, contentSize.width, contentSize.height)];
    }else
        [collectionContentView setFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    [self scrollToTop];
    [self updateDisplayWithRect: self.documentVisibleRect];
}

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
    
    [self updateDisplayWithRect: self.documentVisibleRect];
}

-(void)setFrame:(NSRect)frameRect
{
    [super setFrame: frameRect];
    [[collectionContentView subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    [sectionViewCacheFrames removeAllObjects];
    
    NSSize contentSize = [self documentContentSize];
    if (contentSize.height > self.bounds.size.height){
        CGFloat tmpY = self.bounds.size.height - contentSize.height;
        [collectionContentView setFrame: NSMakeRect(0, tmpY, contentSize.width, contentSize.height)];
    }else
        [collectionContentView setFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    
    [self updateDisplayWithRect: self.documentVisibleRect];
}

- (NSPoint)scrollOffsetPoint;
{
    NSRect visibleRect = [[self contentView] documentVisibleRect];
    return visibleRect.origin;
}

- (void)scrollToOffsetPoint:(NSPoint)p
{
    [collectionContentView scrollPoint: p];
}

-(void)scrollToTop
{
    [collectionContentView scrollPoint: NSMakePoint(0, 0)];
}

-(void)selectAll
{
    [selecteds removeAllObjects];
    
    NSMutableArray *indexs = [NSMutableArray array];
    NSInteger sectionCount = [self sectionCount];
    if (sectionCount > 0){
        for (NSInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++){
            NSInteger itemCount = [self itemCountInSectionIndex:sectionIndex];
            for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++)
                [indexs addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: itemIndex]];
        }
        [selecteds addObjectsFromArray: indexs];
    }else {
        NSInteger itemCount = [self itemCountInSectionIndex:0];
        for (NSInteger itemIndex = 0; itemIndex < itemCount; itemIndex++)
            [indexs addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: itemIndex]];
    }
    
    [self updateDisplayWithRect: collectionContentView.visibleRect];
}

-(void)selectItemWithIndexSet:(IBSectionIndexSet*)indexSet
{
    [selecteds removeAllObjects];
    [selecteds addObject: indexSet];
    
    [self updateDisplayWithRect: collectionContentView.visibleRect];
}

-(void)selectItemWithIndexSets:(NSArray*)indexSets
{
    [selecteds removeAllObjects];
    [selecteds addObjectsFromArray: indexSets];
    
    [self updateDisplayWithRect: collectionContentView.visibleRect];
}

-(void)deselect
{
    [selecteds removeAllObjects];
    [self updateDisplayWithRect: collectionContentView.visibleRect];
}

-(void)deselectItemWithIndexSet:(IBSectionIndexSet*)indexSet
{
    if ([selecteds containsObject: indexSet]){
        [selecteds removeObject: indexSet];
        [self updateDisplayWithRect: collectionContentView.visibleRect];
    }
}

-(void)deselectItemWithIndexSets:(NSArray*)indexSets
{
    NSInteger beforeCount = selecteds.count;
    [selecteds removeObjectsInArray: indexSets];
    if (selecteds.count != beforeCount)
        [self updateDisplayWithRect: collectionContentView.visibleRect];
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
                for (NSInteger i = 0; i < layoutManager.itemCount; i++){
                    IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: i];
                    NSRect itemRect = [layoutManager itemRectOfIndex: i];
                    itemRect = [self convertItemRect: itemRect fromSectionFrame: sectionRect];
                    if (NSPointInRect(point, itemRect)){
                        result = indexSet;
                        break;
                    }
                }
                *stop = YES;
            }
        }];
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        for (NSInteger i = 0; i < layoutManager.itemCount; i++){
            IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: i];
            NSRect itemRect = [layoutManager itemRectOfIndex: i];
            if (NSPointInRect(point, itemRect)){
                result = indexSet;
                break;
            }
        }
    }
    return result;
}

-(NSRect)itemRectWithIndexSet:(IBSectionIndexSet*)indexSet
{
    NSRect resultRect = NSZeroRect;
    if (isSectionViewMode){
        BOOL isExpand = YES;
        if (_delegate && [_delegate respondsToSelector: @selector(collectionViewSectionIsExpand:SectionIndex:)])
            isExpand = [_delegate collectionViewSectionIsExpand: self SectionIndex: indexSet.sectionIndex];
        if (isExpand){
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: indexSet.sectionIndex];
            resultRect = [layoutManager itemRectOfIndex: indexSet.itemIndex];
        }
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        resultRect = [layoutManager itemRectOfIndex: indexSet.itemIndex];
    }
    return resultRect;
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

#pragma mark ==================== Mouse & Keyboard Event

- (NSView *)hitTest:(NSPoint)aPoint
{
    NSView *tmpView = [super hitTest: aPoint];
    if ([tmpView isKindOfClass: [IBCollectionSectionView class]] || [tmpView isKindOfClass: [IBCollectionItemView class]])
        return collectionContentView;
    return tmpView;
}

- (void)mouseMoved:(NSEvent *)theEvent;
{
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
    }else {
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

-(void)mouseDown:(NSEvent *)theEvent
{
    if (theEvent.modifierFlags & NSControlKeyMask)
        return [self rightMouseDown: theEvent];
    
    NSPoint localPoint = [theEvent locationInWindow];
    localPoint = [collectionContentView convertPoint: localPoint fromView: nil];
    firstMouseDownPoint = localPoint;
    
    BOOL isCommandKeyDown = 0 != (GetCurrentKeyModifiers() & cmdKey);
    BOOL bNeedUpdateDisplay = NO;
    
    if (!isCommandKeyDown){
        if (selecteds.count > 0){
            bNeedUpdateDisplay = YES;
            [selecteds removeAllObjects];
        }
    }
    
    IBSectionIndexSet *indexSet = [self itemIndexSetWithPoint: localPoint];
    IBCollectionItemView *itemView = [self itemViewWithIndexSet: indexSet];
    if (indexSet && itemView){
        localPoint = [itemView convertPoint: localPoint fromView: collectionContentView];
        if ([itemView accpetSelectWithPoint: localPoint]){
            [selecteds addObject: indexSet];
            bNeedUpdateDisplay = YES;
        }
    }
    if (bNeedUpdateDisplay)
        [self updateDisplayWithRect: self.documentVisibleRect];
    
    BOOL trackedMouseEvent = NO;
    if (indexSet && itemView){
        if ([itemView accpetMouseEventWithEvent: theEvent])
            trackedMouseEvent = [itemView trackMouseEvent: theEvent];
        if (!trackedMouseEvent){
            if (theEvent.clickCount == 1){
                if (self.distinctSingleDoubleClick) {
                    [self performSelector: @selector(onItemViewSingleClick:) withObject: indexSet afterDelay: [NSEvent doubleClickInterval]];
                }else
                    [self onItemViewSingleClick:indexSet];
            }else if (theEvent.clickCount == 2){
                if (self.distinctSingleDoubleClick)
                    [NSObject cancelPreviousPerformRequestsWithTarget: self];
                [self onItemViewDoubleClick: indexSet];
            }
        }
    }
    
    if (trackedMouseEvent)
        return;
    BOOL keepOn = YES;
    while (keepOn) {
        theEvent = [self.window nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask];
        switch ([theEvent type]) {
            case NSLeftMouseDragged:{
                if (_allowRegionSelection && !_selectionRegionView){
                    _selectionRegionView = [[IBCollectionSelectionRegionView alloc] initWithFrame: self.bounds];
                    [self addSubview: _selectionRegionView];
                }
                [self trackMouseDraggedEvent: theEvent];
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
    selectingRegion = NO;
}

-(void)trackMouseDraggedEvent:(NSEvent *)event
{
    NSPoint localPoint = [event locationInWindow];
    localPoint = [collectionContentView convertPoint: localPoint fromView: nil];
    
    if (_allowSelection && _allowRegionSelection){
        selectingRegion = YES;
        selectingRegionRect.origin = firstMouseDownPoint;
        selectingRegionRect.size.width = localPoint.x - firstMouseDownPoint.x;
        selectingRegionRect.size.height = localPoint.y - firstMouseDownPoint.y;
        if (selectingRegionRect.size.width > 0 && selectingRegionRect.size.height < 0){
            selectingRegionRect.size.height = fabs(selectingRegionRect.size.height);
            selectingRegionRect.origin.y = localPoint.y;
        }else if (selectingRegionRect.size.width < 0 && selectingRegionRect.size.height < 0){
            selectingRegionRect.origin = localPoint;
            selectingRegionRect.size.width = fabs(selectingRegionRect.size.width);
            selectingRegionRect.size.height = fabs(selectingRegionRect.size.height);
        }else if (selectingRegionRect.size.width < 0 && selectingRegionRect.size.height > 0){
            selectingRegionRect.origin.x = localPoint.x;
            selectingRegionRect.origin.y = firstMouseDownPoint.y;
            selectingRegionRect.size.width = fabs(selectingRegionRect.size.width);
        }
        
        NSArray *itemIndexs = [self itemIndexsWithRect: selectingRegionRect];
        [selecteds removeAllObjects];
        [selecteds addObjectsFromArray: itemIndexs];
        [self updateDisplayWithRect: self.documentVisibleRect];
        
        if (_selectionRegionView){
            NSRect drawRect = [_selectionRegionView convertRect: selectingRegionRect fromView: collectionContentView];
            [_selectionRegionView drawFrameWithRect: drawRect];
        }
    }
    [collectionContentView autoscroll: event];
}

-(void)keyDown:(NSEvent *)theEvent
{
    BOOL isCommandKeyDown = 0 != (GetCurrentKeyModifiers() & cmdKey);
    int keyDownCode = [[theEvent charactersIgnoringModifiers] characterAtIndex: 0];
    if (keyDownCode == 27){ //ESC
        [self deselect];
    }else if (isCommandKeyDown && keyDownCode == 97){ //Command + A
        [self selectAll];
    }
    if (_delegate && [_delegate respondsToSelector: @selector(collectionView:didKeyDownEvent:)])
        [_delegate collectionView: self didKeyDownEvent: theEvent];
}
#pragma mark ==================== Notification
-(void)onSynchronizedViewContentBoundsDidChange:(NSNotification*)n
{
    if (self.contentView == [n object]){
        [self updateDisplayWithRect: self.documentVisibleRect];
        [self removeUnvisibleViews: self.documentVisibleRect];
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
    NSUInteger itemCount = [self itemCountInSectionIndex: sectionIndex];
    layoutManager.itemCount = itemCount;
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
                                       forKey: [NSString stringWithFormat: @"%ld", sectionIndex]];
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
}


-(void)removeUnvisibleViews:(NSRect)visibleRect
{
    NSMutableArray *needRemoveViewKeys = [NSMutableArray array];
    [visibleSectionViews enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        IBCollectionSectionView *sectionView = obj;
        if (!NSIntersectsRect(sectionView.frame, visibleRect))
            [needRemoveViewKeys addObject: key];
    }];
    for (NSString *key in needRemoveViewKeys){
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

-(void)updateDisplayWithRect:(NSRect)rect
{
    NSIndexSet *sectionSet = [self sectionIndexSetWithRect: rect];
    if (isSectionViewMode){
        NSInteger sectionIndex = [sectionSet firstIndex];
        while (sectionIndex != NSNotFound) {
            NSString *tmpKey = [NSString stringWithFormat: @"%ld", sectionIndex];
            IBCollectionSectionView *sectionView = [visibleSectionViews objectForKey: tmpKey];
            if (!sectionView){
                if (_delegate && [_delegate respondsToSelector: @selector(collectionView:sectionViewWithIndex:)])
                    sectionView = [_delegate collectionView: self sectionViewWithIndex: sectionIndex];
            }
            NSAssert(sectionView, @"section view cant't no be nil");
            [visibleSectionViews setObject: sectionView forKey: tmpKey];
            
            NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey: tmpKey] rectValue];
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
                    itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
                }
            }else {
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
                        if (selectingRegion){
                            NSRect tmpRect = [itemView convertRect: selectingRegionRect fromView: collectionContentView];
                            if ([itemView accpetSelectWithRect: tmpRect])
                                itemView.selected = YES;
                            else
                                [selecteds removeObject: indexSet];
                        }else
                            itemView.selected = YES;
                    }else
                        itemView.selected = NO;
                    itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
                }
            }
            sectionIndex = [sectionSet indexGreaterThanIndex: sectionIndex];
        }
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: 0 LayoutManager: layoutManager];
        NSInteger itemIndex = [itemIndexSet firstIndex];
        while (itemIndex != NSNotFound) {
            IBSectionIndexSet *indexSet = [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: itemIndex];
            IBCollectionItemView *itemView = [visibleItemViews objectForKey: indexSet];
            if (!itemView){
                if (_delegate && [_delegate respondsToSelector: @selector(collectionView:itemViewWithIndexSet:)])
                    itemView = [_delegate collectionView: self itemViewWithIndexSet: indexSet];
            }
            NSAssert(itemView, @"item view cant't no be nil");
            
            itemView.frame = [layoutManager itemRectOfIndex: itemIndex];
            if (_delegate && [_delegate respondsToSelector: @selector(collectionView:WillDisplayItemView:indexSet:)])
                [_delegate collectionView: self WillDisplayItemView: itemView indexSet: indexSet];
            [visibleItemViews setObject: itemView forKey: indexSet];
            if (!itemView.superview)
                [collectionContentView addSubview: itemView];
            if ([selecteds containsObject: indexSet]){
                if (selectingRegion){
                    NSRect tmpRect = [itemView convertRect: selectingRegionRect fromView: collectionContentView];
                    if ([itemView accpetSelectWithRect: tmpRect])
                        itemView.selected = YES;
                    else
                        [selecteds removeObject: indexSet];
                }else
                    itemView.selected = YES;
            }else
                itemView.selected = NO;
            itemIndex = [itemIndexSet indexGreaterThanIndex: itemIndex];
        }
    }
}

-(NSIndexSet*)sectionIndexSetWithRect:(NSRect)rect
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    NSInteger sectionCount = [self sectionCount];
    
    if (sectionCount == 0)
        return indexSet;
    
    for (NSInteger sectionIndex = 0; sectionIndex < sectionCount; sectionIndex++){
        NSString *key = [NSString stringWithFormat: @"%ld", sectionIndex];
        NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey: key] rectValue];
        
        if (NSIntersectsRect(sectionViewFrame, rect) || NSPointInRect(rect.origin, sectionViewFrame))
            [indexSet addIndex: sectionIndex];
    }
    return indexSet;
}

-(NSIndexSet*)itemIndexSetWithRect:(NSRect)rect SectionIndex:(NSInteger)sectionIndex LayoutManager:(IBSectionViewLayoutManager*)layoutManager
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    if (isSectionViewMode){
        NSString *key = [NSString stringWithFormat: @"%ld", sectionIndex];
        NSRect sectionViewFrame = [[sectionViewCacheFrames objectForKey: key] rectValue];
        
        for (NSInteger itemIndex = 0; itemIndex < layoutManager.itemCount; itemIndex++){
            NSRect itemRect = [layoutManager itemRectOfIndex: itemIndex];
            itemRect = [self convertItemRect: itemRect fromSectionFrame: sectionViewFrame];
            if (NSIntersectsRect(itemRect, rect) || NSPointInRect(rect.origin, itemRect))
                [indexSet addIndex: itemIndex];
            
            if (itemRect.origin.y > NSMaxY(rect))
                break;
        }
    }else {
        for (NSInteger itemIndex = 0; itemIndex < layoutManager.itemCount; itemIndex++){
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
    NSMutableArray *indexs = [NSMutableArray array];
    if (isSectionViewMode){
        NSIndexSet *sectionSet = [self sectionIndexSetWithRect: rect];
        NSInteger sectionIndex = [sectionSet firstIndex];
        while (sectionIndex != NSNotFound) {
            IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: sectionIndex];
            
            NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: sectionIndex LayoutManager: layoutManager];
            [itemIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                [indexs addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: sectionIndex ItemIndex: idx]];
            }];
            sectionIndex = [sectionSet indexGreaterThanIndex: sectionIndex];
        }
    }else {
        IBSectionViewLayoutManager *layoutManager = [self layoutWithSectionIndex: 0];
        NSIndexSet *itemIndexSet = [self itemIndexSetWithRect: rect SectionIndex: 0 LayoutManager: layoutManager];
        [itemIndexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [indexs addObject: [IBSectionIndexSet sectionIndexSetWithSectionIndex: 0 ItemIndex: idx]];
        }];
    }

    return indexs;
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

@end
