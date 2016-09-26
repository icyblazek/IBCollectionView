//
//  IBSectionViewLayoutManager.m
//  IBCollectionView
//
//  Created by Kevin on 15/12/14.
//  Copyright (c) 2014 Icyblaze. All rights reserved.
//

#import "IBSectionViewLayoutManager.h"

@interface IBSectionViewLayoutManager (){
}

@end

@implementation IBSectionViewLayoutManager

-(CGFloat)itemViewMarginMinX
{
    return 10;
}

-(CGFloat)itemViewMarginMinY
{
    return 10;
}

-(CGFloat)itemViewMarginMaxX
{
    return 10;
}

-(CGFloat)itemViewMarginMaxY
{
    return 10;
}

-(CGFloat)itemViewWSpacing
{
    return 10;
}

-(CGFloat)itemViewHSpacing
{
    return 10;
}

-(NSSize)itemSize
{
    return NSMakeSize(100, 100);
}

-(CGFloat)sectionHeaderViewHeight
{
    return 20;
}

-(CGFloat)sectionBottomViewHeight
{
    return 20;
}

-(NSRect)itemRectOfIndex:(NSInteger)index
{
    NSSize itemSize = [self itemSize];
    CGFloat itemWSpacing = [self itemViewWSpacing];
    CGFloat itemHSpacing = [self itemViewHSpacing];
    
    CGFloat itemMarginMinX = [self itemViewMarginMinX];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat headerHeight = [self sectionHeaderViewHeight];
    CGFloat itemMarginMaxY = [self itemViewMarginMaxY];
    
    CGFloat usedWidth = _layoutWidth - (itemMarginMinX + itemMarginMaxX);
    NSInteger itemCol = usedWidth / (itemSize.width + itemWSpacing);
    
    if (itemCol == 0)
        itemCol = 1;
    
    CGFloat actualWSpace = itemWSpacing;
    BOOL autoWSpacing = YES;
    if (autoWSpacing && self.itemCount > itemCol){
        CGFloat tmp = usedWidth - itemCol * itemSize.width;
        actualWSpace = tmp / (itemCol + 1);
    }
    
    NSInteger drawIndexX = index % itemCol;
    NSInteger drawIndexY = index / itemCol;
    CGFloat x = floor(drawIndexX * itemSize.width + (drawIndexX + 1) * actualWSpace + itemMarginMinX);
    CGFloat y = floor(drawIndexY * itemSize.height + drawIndexY * itemHSpacing + itemMarginMaxY + headerHeight);
    NSRect result = NSMakeRect(x, y, itemSize.width, itemSize.height);
    return result;
}

-(NSInteger)itemIndexWithPoint:(NSPoint)point
{
    return 0;
}

-(CGFloat)contentHeightWithLayoutWidht:(CGFloat)layoutWidth
{
    _layoutWidth = layoutWidth;
    NSSize itemSize = [self itemSize];
    CGFloat itemWSpacing = [self itemViewWSpacing];
    CGFloat itemHSpacing = [self itemViewHSpacing];
    
    CGFloat itemMarginMinX = [self itemViewMarginMinX];
    CGFloat itemMarginMaxX = [self itemViewMarginMaxX];
    
    CGFloat itemMarginMinY = [self itemViewMarginMinY];
    CGFloat itemMarginMaxY = [self itemViewMarginMaxY];
    
    CGFloat usedWidth = layoutWidth - (itemMarginMinX + itemMarginMaxX);
    NSInteger itemCol = usedWidth / (itemSize.width + itemWSpacing);
    
    if (itemCol == 0)
        itemCol = 1;
    
    NSInteger itemRow = floor(self.itemCount / itemCol);
    if (self.itemCount > itemCol && self.itemCount % itemCol > 0)
        itemRow++;
    if (self.itemCount < itemCol)
        itemRow = 1;
    if (itemRow == 0)
        itemRow = 1;
    
    CGFloat tmpMaxHeight = itemRow * itemSize.height + (itemRow - 1) * itemHSpacing;
    tmpMaxHeight += itemMarginMinY + itemMarginMaxY;
    tmpMaxHeight += [self sectionHeaderViewHeight] + [self sectionBottomViewHeight];
    return tmpMaxHeight;
}

@end
