//
//  ListViewDemoWindowController.m
//  IBCollectionView
//
//  Created by Kevin on 8/2/15.
//  Copyright (c) 2015 Icyblaze. All rights reserved.
//

#import "ListViewDemoWindowController.h"



@implementation ListItemView

-(void)drawRect:(NSRect)dirtyRect
{
    NSRect bounds = NSInsetRect(self.bounds, 0, 2);
    if (self.selected)
        [[NSColor yellowColor] setFill];
    else
        [[NSColor blueColor] setFill];
    NSRectFill(bounds);
}

@end

@implementation ListLayoutManager

-(CGFloat)itemViewHSpacing
{
    return 0;
}

-(NSSize)itemSize
{
    return NSMakeSize(_layoutWidth, 40);
}

-(NSRect)itemRectOfIndex:(NSInteger)index
{
    NSSize itemSize = [self itemSize];
    CGFloat itemHSpacing = [self itemViewHSpacing];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat headerHeight = [self sectionHeaderViewHeight];
    CGFloat itemMarginMaxY = [self itemViewMarginMaxY];
    
    CGFloat x = itemMarginMaxX;
    CGFloat y = floor(index * itemSize.height + index * itemHSpacing + headerHeight + itemMarginMaxY);
    return NSMakeRect(x, y, itemSize.width, itemSize.height);
    
}

-(NSInteger)itemIndexWithPoint:(NSPoint)point
{
    return 0;
}

-(CGFloat)contentHeightWithLayoutWidht:(CGFloat)layoutWidth
{
    _layoutWidth = layoutWidth;
    NSSize itemSize = [self itemSize];
    CGFloat itemHSpacing = [self itemViewHSpacing];

    CGFloat contentHeight = self.itemCount * itemSize.height;
    if (self.itemCount > 0)
        contentHeight += (self.itemCount - 1) + itemHSpacing;
    
    return [self sectionHeaderViewHeight] + [self sectionBottomViewHeight] + contentHeight;
}


@end

@interface ListViewDemoWindowController () <IBCollectionViewDataSource, IBCollectionViewDelegate>{
    ListLayoutManager *listLayoutManager;
}

@end

@implementation ListViewDemoWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    _collectionView = [[IBCollectionView alloc] initWithFrame: [self.window.contentView bounds]];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [_collectionView registerClass: [IBCollectionSectionView class] forViewReuseIdentifier: @"__secitonview__"];
    [_collectionView registerClass: [ListItemView class] forViewReuseIdentifier: @"__itemview__"];
    
    [self.window.contentView addSubview: _collectionView];
    [_collectionView reloadData];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModal];
}

#pragma mark DataSource
-(NSUInteger)collectionViewSectionCount:(IBCollectionView*)collectionView
{
    return 10;
}

-(NSUInteger)collectionViewItemCount:(IBCollectionView*)collectionView SectionIndex:(NSInteger)sectionIndex
{
    return 6;
}

#pragma mark Delegate
-(IBCollectionItemView*)collectionView:(IBCollectionView*)collectionView itemViewWithIndexSet:(IBSectionIndexSet*)indexSet
{
    IBCollectionItemView *itemView = [collectionView dequeueReusableViewWithIdentifier: @"__itemview__"];
    if (!itemView){
        itemView = [[ListItemView alloc] init];
        itemView.reuseIdentifier = @"__itemview__";
    }
    return itemView;
}

-(IBCollectionSectionView*)collectionView:(IBCollectionView*)collectionView sectionViewWithIndex:(NSInteger)index
{
    IBCollectionSectionView *sectionView = [collectionView dequeueReusableViewWithIdentifier: @"__secitonview__"];
    if (!sectionView){
        sectionView = [[IBCollectionSectionView alloc] init];
        sectionView.reuseIdentifier = @"__secitonview__";
    }
    return sectionView;
}

-(IBSectionViewLayoutManager*)collectionViewSectionLayoutManager:(IBCollectionView*)view SectionIndex:(NSInteger)sectionIndex
{
    if (!listLayoutManager)
        listLayoutManager = [[ListLayoutManager alloc] init];
    return listLayoutManager;
}


@end
