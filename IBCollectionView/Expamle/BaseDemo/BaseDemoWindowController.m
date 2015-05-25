//
//  BaseDemoWindowController.m
//  IBCollectionView
//
//  Created by Kevin on 27/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "BaseDemoWindowController.h"

@interface BaseDemoWindowController () <IBCollectionViewDataSource, IBCollectionViewDelegate>

@end

@implementation BaseDemoWindowController


- (void)windowDidLoad
{
    [super windowDidLoad];
    
    _collectionView = [[IBCollectionView alloc] initWithFrame: [self.window.contentView bounds]];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [_collectionView registerClass: [IBCollectionItemView class] forViewReuseIdentifier: @"__itemview__"];
    
    [self.window.contentView addSubview: _collectionView];
    [_collectionView reloadData];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [NSApp stopModal];
}

#pragma mark DataSource
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

@end
