//
//  IBSectionViewLayoutManager.h
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//  https://github.com/icyblazek/IBCollectionView

#import <Foundation/Foundation.h>

@class IBCollectionView;

@interface IBSectionViewLayoutManager : NSObject{
    CGFloat _layoutWidth;
}
@property(assign) NSSize itemSize;
@property(assign) CGFloat itemViewWSpacing;
@property(assign) CGFloat itemViewHSpacing;

@property(assign) CGFloat itemViewMarginMinX;
@property(assign) CGFloat itemViewMarginMaxX;

@property(assign) CGFloat itemViewMarginMinY;
@property(assign) CGFloat itemViewMarginMaxY;

@property(assign) CGFloat sectionHeaderViewHeight;
@property(assign) CGFloat sectionBottomViewHeight;

-(NSRect)itemRectOfIndex:(NSInteger)index;
-(NSInteger)itemIndexWithPoint:(NSPoint)point;
-(CGFloat)contentHeightWithLayoutWidht:(CGFloat)layoutWidth;

-(NSUInteger)countOfColumn;
-(NSUInteger)columnOfIndex:(NSInteger)index;

@property (assign) IBCollectionView *collectionView;
@property (assign) NSInteger itemCount;


@end
