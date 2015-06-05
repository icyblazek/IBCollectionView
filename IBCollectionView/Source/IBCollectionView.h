//
//  IBCollectionView.h
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "IBSectionIndexSet.h"
#import "IBCollectionItemView.h"
#import "IBCollectionSectionView.h"
#import "IBSectionViewLayoutManager.h"


@class IBCollectionView;

@protocol IBCollectionViewDataSource <NSObject>

@optional
-(NSUInteger)collectionViewSectionCount:(IBCollectionView*)collectionView;
-(id)collectionViewSectionObject:(IBCollectionView*)collectionView SectionIndex:(NSInteger)sectionIndex;
-(id)collectionViewSectionItemObject:(IBCollectionView*)view IndexSet:(IBSectionIndexSet*)indexSet;
@required
-(NSUInteger)collectionViewItemCount:(IBCollectionView*)collectionView SectionIndex:(NSInteger)sectionIndex;

@end

@protocol IBCollectionViewDelegate <NSObject>

//@optional
//-(void)collectionViewItemDidSelected:(IBCollectionView*)collectionView;
//-(void)collectionViewKeyDown:(IBCollectionView*)collectionView Event:(NSEvent*)theEvent;
//-(NSMenu*)collectionViewMenu:(IBCollectionView*)collectionView IndextSet:(IBSectionIndexSet*)indexSet;
//
//// Drag & Drop
//-(NSDragOperation)onCollectionViewDraggingEnter:(IBCollectionView*)collectionView DraggingInfo:(id <NSDraggingInfo>)sender;
//-(NSDragOperation)onCollectionViewDraggingUpdated:(IBCollectionView*)collectionView DraggingInfo:(id <NSDraggingInfo>)sender;
//-(void)onCollectionViewDraggingExited:(IBCollectionView*)collectionView DraggingInfo:(id <NSDraggingInfo>)sender;
//-(BOOL)onCollectionViewPerformDragOperation:(IBCollectionView*)collecitonView DraggingInfo:(id <NSDraggingInfo>)sender;
//-(void)onCollectionViewConcludeDragOperation:(IBCollectionView*)collectionView DraggingInfo:(id <NSDraggingInfo>)sender;
//-(void)collectionViewSwipeChange:(IBCollectionView*)collectionView Type:(NSInteger)type;

@required
-(IBCollectionItemView*)collectionView:(IBCollectionView*)collectionView itemViewWithIndexSet:(IBSectionIndexSet*)indexSet;

@optional
-(BOOL)collectionViewSectionIsExpand:(IBCollectionView*)collectionView SectionIndex:(NSInteger)sectionIndex;
-(CGFloat)collectionViewSectionHeight:(IBCollectionView*)collectionView SectionIndex:(NSInteger)sectionIndex;
-(IBCollectionSectionView*)collectionView:(IBCollectionView*)collectionView sectionViewWithIndex:(NSInteger)index;
-(IBSectionViewLayoutManager*)collectionViewSectionLayoutManager:(IBCollectionView*)view SectionIndex:(NSInteger)sectionIndex;
-(void)collectionView:(IBCollectionView*)view WillDisplaySectionView:(IBCollectionSectionView*)sectionView SectionIndex:(NSInteger)sectionIndex;
-(void)collectionView:(IBCollectionView*)view WillDisplayItemView:(IBCollectionItemView*)itemView indexSet:(IBSectionIndexSet*)indexSet;
-(void)collectionView:(IBCollectionView*)view didClickItemView:(IBSectionIndexSet*)indexSet;
-(void)collectionView:(IBCollectionView*)view didDoubleClickItemView:(IBSectionIndexSet *)indexSet;
-(void)collectionView:(IBCollectionView*)view didKeyDownEvent:(NSEvent*)theEvent;

@end


@interface IBCollectionView : NSScrollView{
    NSMutableArray *selecteds;
    NSMutableDictionary *classMap; // {identifier : class}
}

-(void)registerNib:(NSBundle *)nib forViewReuseIdentifier:(NSString *)identifier;
-(void)registerClass:(Class)viewClass forViewReuseIdentifier:(NSString *)identifier;
-(id)dequeueReusableViewWithIdentifier:(NSString *)identifier;

-(void)reloadData;
/**
 *  updateLayout is used when there is any view related changes.
 *  e.g. any IBSectionViewLayoutManager change should call this method.
 *  reloadData will lose selection, but updateLayout will not.
 */
-(void)updateLayout;

-(void)selectAll;
-(void)selectItemWithIndexSet:(IBSectionIndexSet*)indexSet;
-(void)selectItemWithIndexSets:(NSArray*)indexSets; //NSArray of IBSectionIndexSet
-(void)deselect;
-(void)deselectItemWithIndexSet:(IBSectionIndexSet*)indexSet;
-(void)deselectItemWithIndexSets:(NSArray*)indexSets; //NSArray of IBSectionIndexSet

-(IBSectionIndexSet*)itemIndexSetWithPoint:(NSPoint)point;
-(NSRect)itemRectWithIndexSet:(IBSectionIndexSet*)indexSet;
-(NSArray*)visibleItemIndexSets;
-(NSIndexSet*)visibleSectionIndexSets;

-(NSArray*)visibleItemViews;
-(IBCollectionItemView*)itemViewWithIndexSet:(IBSectionIndexSet*)indexSet;

-(NSPoint)scrollOffsetPoint;
-(void)scrollToOffsetPoint:(NSPoint)p;
-(void)scrollToTop;

-(id)itemDataAtIndexSet:(IBSectionIndexSet*)indexSet;

@property (nonatomic, weak) id <IBCollectionViewDataSource> dataSource;
@property (nonatomic, weak) id <IBCollectionViewDelegate> delegate;

@property (assign) BOOL enabled;
@property (assign) BOOL allowRegionSelection;
@property (assign) BOOL allowSelection;
@property (assign) BOOL allowShiftSelection;
@property (assign) BOOL fixedSectionHeaderView;
@property (assign) BOOL distinctSingleDoubleClick; //set to NO the double click will send a single click signle as well, default value is YES

@end
