//
//  IBSectionViewLayoutManager.h
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import <Foundation/Foundation.h>

@class IBCollectionView;

@interface IBSectionViewLayoutManager : NSObject{
    CGFloat _layoutWidth;
}


-(CGFloat)itemViewMarginMinX;
-(CGFloat)itemViewMarginMinY;
-(CGFloat)itemViewMarginMaxX;
-(CGFloat)itemViewMarginMaxY;
-(CGFloat)itemViewWSpacing;
-(CGFloat)itemViewHSpacing;
-(NSSize)itemSize;
-(CGFloat)sectionHeaderViewHeight;
-(CGFloat)sectionBottomViewHeight;

-(NSRect)itemRectOfIndex:(NSInteger)index;
-(NSInteger)itemIndexWithPoint:(NSPoint)point;
-(CGFloat)contentHeightWithLayoutWidht:(CGFloat)layoutWidth;

@property (assign) IBCollectionView *collectionView;
@property (assign) NSInteger itemCount;


@end
