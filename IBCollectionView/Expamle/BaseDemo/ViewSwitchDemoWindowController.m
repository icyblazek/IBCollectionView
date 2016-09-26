//
//  ViewSwitchDemoWindowController.m
//  IBCollectionView
//
//  Created by Kevin Lu on 2/9/15.
//  Copyright (c) 2015 Icyblaze. All rights reserved.
//

#import "ViewSwitchDemoWindowController.h"
#import "ListViewDemoWindowController.h"

enum ViewMode{
    kViewMode_Section,
    kViewMode_ListView
};
typedef enum ViewMode ViewMode;

@interface ViewSwitchDemoWindowController () <IBCollectionViewDataSource, IBCollectionViewDelegate>{
    ViewMode viewMode;
    ListLayoutManager *listLayoutManager;
    IBSectionViewLayoutManager *sectionLayoutManager;
}

@end

@implementation ViewSwitchDemoWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    viewMode = kViewMode_Section;
    
    NSRect bounds = [self.window.contentView bounds];
    bounds.size.height -= 60;
    _collectionView = [[IBCollectionView alloc] initWithFrame: bounds];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [_collectionView registerClass: [IBCollectionItemView class] forViewReuseIdentifier: @"__itemview_sectionitem__"];
    [_collectionView registerClass: [ListItemView class] forViewReuseIdentifier: @"__itemview_list__"];
    [_collectionView registerClass: [IBCollectionSectionView class] forViewReuseIdentifier: @"__secitonview__"];
    
    [self.window.contentView addSubview: _collectionView];
    [_collectionView reloadData];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModal];
}

-(IBAction)btnSwitchClick:(id)sender
{
    NSSegmentedControl *seg = sender;
    if (seg.selectedSegment == 0)
        viewMode = kViewMode_Section;
    else if (seg.selectedSegment == 1)
        viewMode = kViewMode_ListView;
    [_collectionView reloadData];
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
    static NSString *listItemIdentifier = @"__itemview_list__";
    static NSString *sectionItemIdentifier = @"__itemview_sectionitem__";
    IBCollectionItemView *itemView = nil;
    if (viewMode == kViewMode_Section){
        itemView = [collectionView dequeueReusableViewWithIdentifier: sectionItemIdentifier];
        if (!itemView){
            itemView = [[IBCollectionItemView alloc] init];
            itemView.reuseIdentifier = sectionItemIdentifier;
        }
    }else if (viewMode == kViewMode_ListView){
        itemView = [collectionView dequeueReusableViewWithIdentifier: listItemIdentifier];
        if (!itemView){
            itemView = [[ListItemView alloc] init];
            itemView.reuseIdentifier = listItemIdentifier;
        }
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
    if (viewMode == kViewMode_ListView){
        if (!listLayoutManager)
            listLayoutManager = [[ListLayoutManager alloc] init];
        return listLayoutManager;
    }else if (viewMode == kViewMode_Section){
        if (!sectionLayoutManager)
            sectionLayoutManager = [[IBSectionViewLayoutManager alloc] init];
        return sectionLayoutManager;
    }
    return nil;
}

@end
