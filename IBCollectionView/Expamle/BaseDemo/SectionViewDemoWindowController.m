//
//  SectionViewDemoWindowController.m
//  IBCollectionView
//
//  Created by Kevin on 6/1/15.
//  Copyright (c) 2015 Icyblaze. All rights reserved.
//

#import "SectionViewDemoWindowController.h"

@interface SectionViewDemoWindowController () <IBCollectionViewDataSource, IBCollectionViewDelegate>

@end

@implementation SectionViewDemoWindowController

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    _collectionView = [[IBCollectionView alloc] initWithFrame: [self.window.contentView bounds]];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [_collectionView registerClass: [IBCollectionSectionView class] forViewReuseIdentifier: @"__secitonview__"];
    [_collectionView registerClass: [IBCollectionItemView class] forViewReuseIdentifier: @"__itemview__"];
    
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
    return 24;
}

#pragma mark Delegate
-(IBCollectionItemView*)collectionView:(IBCollectionView*)collectionView itemViewWithIndexSet:(IBSectionIndexSet*)indexSet
{
    IBCollectionItemView *itemView = [collectionView dequeueReusableViewWithIdentifier: @"__itemview__"];
    if (!itemView){
        itemView = [[IBCollectionItemView alloc] init];
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


@end
